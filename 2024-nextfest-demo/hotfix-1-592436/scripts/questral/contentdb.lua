local ContentNode = require "questral.contentnode"
local Localization = require "questral.localization"
local ScriptLoader = require "questral.scriptloader"
local kassert = require "util.kassert"
local loc = require "questral.util.loc"
local strict = require "util.strict"


local ContentDB = Class(function(self, ...) self:init(...) end)
function ContentDB:init()
    self.data = {}
    self.strings = {}
    self.images = {}
    self.anims = {}
    self.quips = {}
    self.asset_tables_by_id = {}
    self.image_table_by_image_asset = {}
end

function ContentDB:AddContentList(t)
    -- Pairs even though we ignore keys.
    for _, v in pairs(t) do
        assert(v.GetContentID)
        self:AddContentItem(v)
    end
end

function ContentDB:AddRawContent( key, id, content )
    if not self.data[key] then
        self.data[key] = {}
    end
    assert( self.data[key][id] == nil or error( string.format( "Adding duplicate content ids: %s.%s\n%s", key, id, self.data[key][id]._added )))
    self.data[key][id] = content
end

function ContentDB:AddContentItem(content)

    local key, id = content:GetContentKey(), content:GetContentID()
    if id and not self:TryGet( key, id ) then
        kassert.assert_fmt(key, "No Content Key for id '%s'", id)
        if content.OnAddContent then
            content:OnAddContent(self)
        end

        -- Validation may add additional content (e.g. ReqAsset) so it needs to be called before we check content
        if content.ValidateDef then
            content:ValidateDef()
        end
        local data = content:GetContent()

        self:AddRawContent( key, id, content )

        if data then
            if data.strings then
                local path = string.format( "%s.%s", key, id )
                self:AddStringTable( data.strings, path )
            end
            if data.preloaded_textures then
                for _, path in pairs(data.preloaded_textures) do
                    self:RegisterImageRequirement( path, content )
                    self:AddImageLoadReference( path, content )
                end
            end
            if data.required_textures then
                for _, path in pairs(data.required_textures) do
                    self:RegisterImageRequirement( path, content )
                end
            end
            if data.preloaded_anims then
                for _, path in pairs(data.preloaded_anims) do
                    self:RegisterAnimRequirement( path, content )
                    self:AddAnimLoadReference( path, content )
                end
            end
            if data.required_anims then
                for _, path in pairs(data.required_anims) do
                    self:RegisterAnimRequirement( path, content )
                end
            end
            if data.quips then
                for k, quip in ipairs(data.quips) do
                    local path = string.format( "%s.%s.QUIP.%s.%d", key, id, quip.primary_tag, k )
                    self:AddQuip( quip, path )
                end
            end
            if data.convos then
                self:AddContentList( data.convos )
            end
            if data.preloaded_assets then
                for asset_id, _ in pairs(data.preloaded_assets) do
                    self:RegisterAssetRequirement( asset_id, content )
                    self:AddAssetLoadReference( asset_id, content )
                end
            end
            if data.required_assets then
                for asset_id, _ in pairs(data.required_assets) do
                    self:RegisterAssetRequirement( asset_id, content )
                end
            end
        end

        content:SetContentDB(self)
    end
end

function ContentDB:Get( key, id )
    local def = self:TryGet( key, id )
    assert(def or error(string.format("non-existent content: [%s].[%s]", key._classname or key, tostring(id))))
    return def
end

function ContentDB:TryGet( key, id )
    if type(key) == "table" then
        key = key:GetContentKey()
    end
    local t = self.data[key]
    if t then
        return t[id]
    end
end

function ContentDB:GetAll( key )
    if Class.IsClass(key) then
        key = key._classname
        dbassert(key)
    end

    return self.data[ key ]
end

function ContentDB:UnloadAll( key )
    if Class.IsClass(key) then
        key = key._classname
        dbassert(key)
    end

    self.data[ key ] = nil
end

-- TODO: Rename to RemoveContentItem and do the opposite of ContentDB:AddContentItem
function ContentDB:UnloadContent( key, id )
    if Class.IsClass(key) then
        key = key._classname
        dbassert(key)
    end

    self.data[key][id] = nil
end

function ContentDB:GetFiltered( class, pred )
    assert( class:has_mixin(ContentNode), "class is not a content type" )
    assert( self.data[ class._classname ] ~= nil, "no content for class "..class._classname )
    local ret = {}
    for _, v in pairs(self.data[class._classname]) do
        if pred == nil or pred(v) then
            table.insert(ret, v)
        end
    end
    table.sort( ret, function(x, y)
        local xid = x:GetContentID()
        local yid = y:GetContentID()
        return xid < yid
    end )
    return ret
end

function ContentDB:setCurrentLocalization( localization )
    self.current_localization = localization
end

function ContentDB:GetAllStrings()
    return self.strings
end

function ContentDB:GetString( id, language_id )
    local localization = self.current_localization
    if language_id then
        localization = self:Get(Localization, language_id)
    end

    if localization then
        return localization:GetString(id) or self.strings[id] or string.format( "MISSING:%s", id)
    else
        return self.strings[id] or string.format( "MISSING:%s", id)
    end
end

function ContentDB:AddString( id, str )
    self.strings[id] = str
end

function ContentDB:AddQuip( quip, path )
    assert(path)
    self.quips[quip.primary_tag] = self.quips[quip.primary_tag] or {}
    table.insert(self.quips[quip.primary_tag], quip)

    for ks, line in ipairs(quip.dialog) do
        -- Create a key for our quip and replace the English line with the string id.
        local id = string.format("%s.%d", path, ks )
        self:AddString(id, line)
        quip.dialog[ks] = id
    end
end

function ContentDB:AddStringTable( start_t, start_path )
    local function harvest(t, path)
        for k,v in pairs(t) do
            if loc.IsValidStringKey(k) then
                local id = path and string.format("%s.%s", path, k ) or k
                assert( self.strings[ id ] == nil, tostring(id) ) -- let's be defensive for now.
                self.strings[id] = v
            end

            if type(k) == "string"
                and type(v) == "table"
            then
                harvest(v, path and string.format("%s.%s", path, k) or k)
            end
        end
    end
    harvest(start_t, start_path)
end

function ContentDB:GetQuips(primary_tag)
    assert(primary_tag, "What is the primary tag?")
    return self.quips[primary_tag]
    --return self:Get( "Quips", "GENERAL" )
end

--------------------------

function ContentDB:HasImageRequirement( path )
    return self.images[path] ~= nil
end

function ContentDB:IsImageLoaded( path )
    return self.images[path].img ~= nil
end

function ContentDB:GetImageAsset( path )
    assert(self.images[path].img)
    return self.images[path].img
end

function ContentDB:GetNormalForImageAsset( img )
    if self.image_table_by_image_asset[img] then
        local norm_path = self.image_table_by_image_asset[img].norm_path
        if norm_path then
            return self.images[norm_path] and self.images[norm_path].img
        end
    end
end

function ContentDB:RegisterImageRequirement( path, source )
    assert( type(path) == "string" )
    local img_table = self.images[path]
    if not img_table then
        img_table = {path = path, req_sources = {}, load_ref_sources = {}}
        self.images[path] = img_table

        --do we have an implicit normal?
        local norm_path = string.gsub(path, "%.tex", ".normalmap.tex")
        if TheSim:FileExists(norm_path) then
            img_table.norm_path = norm_path
            self:RegisterImageRequirement(norm_path, path)
        end
    end

    img_table.req_sources[source] = true
    return img_table
end

function ContentDB:GetImageRequirementSources(path)
    local img_table = self.images[path]
    return table.getkeys(img_table.req_sources)
end

function ContentDB:AddImageLoadReference( path, source )
    local image_table = self.images[path]
    assert(image_table.req_sources[source])
    image_table.load_ref_sources[source] = true
end

function ContentDB:RemoveImageLoadReference( path, source )
    local image_table = self.images[path]
    image_table.load_ref_sources[source] = nil
end

--------------------------

function ContentDB:HasAnimRequirement( path )
    return self.anims[path] ~= nil
end

function ContentDB:IsAnimLoaded( path )
    return self.anims[path].anim ~= nil
end

function ContentDB:GetAnimAsset( path )
    assert(self.anims[path].anim)
    return self.anims[path].anim
end

function ContentDB:RegisterAnimRequirement( path, source )
    local anim_table = self.anims[path]
    if not anim_table then
        assert( type(path) == "string" )
        anim_table = {path = path, req_sources={}, load_ref_sources = {}}
        self.anims[path] = anim_table
    end
    anim_table.req_sources[source] = true

    return anim_table
end

function ContentDB:GetAnimRequirementSources(path)
    local anim_table = self.anims[path]
    return table.getkeys(anim_table.req_sources)
end

function ContentDB:AddAnimLoadReference( path, source )
    local anim_table = self.anims[path]
    assert(anim_table.req_sources[source])
    anim_table.load_ref_sources[source] = true
end

function ContentDB:RemoveAnimLoadReference( path, source )
    local anim_table = self.anims[path]
    anim_table.load_ref_sources[source] = nil
end

function ContentDB:_ResolveImageContentReferences(image, image_paths_that_need_resolving)
    if table.count(image.load_ref_sources) > 0 then
        image.img = image.img or engine.asset.Texture(image.path, true)
        if not image.img then
            print ("FAILED TO LOAD:", image.path)
        else
            self.image_table_by_image_asset[image.img] = image
            if image.norm_path then
                self:AddImageLoadReference(image.norm_path, image.path)
                table.insert_unique( image_paths_that_need_resolving, image.norm_path)
            end
        end
    else
        --if we have an implicit normal, unload it!
        if image.norm_path then
            self:RemoveImageLoadReference(image.norm_path, image.path)
            table.insert_unique( image_paths_that_need_resolving, image.norm_path)
        end
        if image.img then
            self.image_table_by_image_asset[image.img] = nil
        end
        image.img = nil
    end
end

--------------------------
-- Loads/Unloads files based on whether there are any active references to them.
function ContentDB:ResolveContentReferences( )
    --~ local _perf1 <close> = PROFILE_SECTION( "ContentDB:ResolveContentReferences" )
    -- Anims
    for _, anim in pairs(self.anims) do
        if table.count(anim.load_ref_sources) > 0 then
            anim.anim = anim.anim or engine.asset.Anim(anim.path)
            if not anim.anim then
                print("WARNING: Failed to load:", anim.path)
            end
        else
            anim.anim = nil
        end
    end

    --because images can cause their implicit normals to load or unload, we can't just iterate through the list once.
    local images_that_need_resolving = {}
    for _, image in pairs(self.images) do
        if table.count(image.load_ref_sources) > 0 then
            image.img = image.img or engine.asset.Texture(image.path, true)
            if not image.img then
                print("WARNING: Failed to load:", image.path)
            end
        else
            image.img = nil
        end
    end

    --process this list until it's empty
    while #images_that_need_resolving > 0 do
        local img_path = table.remove(images_that_need_resolving)
        self:_ResolveImageContentReferences(self.images[img_path], images_that_need_resolving)
    end

end

--------------------------

-- Called to establish that the game will require a config with the given id
-- If "force_config" is specified, that config will be used instead of the file on disk in the assets directory.
function ContentDB:RegisterAssetRequirement(asset_id, source, force_config)
    local asset_table = self.asset_tables_by_id[asset_id]
    assert(not asset_table or not force_config, "Cannot force a config for an asset_id that is already added")
    if not asset_table then
        local asset_config
        if force_config then
            asset_config = force_config
        else
            local AssetConfig = require "questral.assetconfig"
            asset_config = AssetConfig(asset_id, dofile("scripts/content/assets/" .. asset_id .. ".lua" ))
        end
        asset_table = {asset_id = asset_id, req_sources={}, load_ref_sources={}, asset_config=asset_config}
        self.asset_tables_by_id[ asset_id ] = asset_table
        asset_config:OnAddedToContentDB(self)
    end

    asset_table.req_sources[source] = true
end

function ContentDB:GetAssetRequirementSources(asset_id)
    local asset_table = self.asset_tables_by_id[asset_id]
    return table.getkeys(asset_table.req_sources)
end

-- Adds an active reference to asset_id, causing it to add references to all its dependencies
function ContentDB:AddAssetLoadReference(asset_id, source)
    local asset_table = self.asset_tables_by_id[asset_id]
    assert(asset_table.req_sources[source], asset_id)
    asset_table.load_ref_sources[source] = true
    if not asset_table.asset_config:HasLoadReferences() then
        asset_table.asset_config:AddLoadReferences()
    end
end

function ContentDB:RemoveAssetLoadReference(asset_id, source)
    local asset_table = self.asset_tables_by_id[asset_id]
    asset_table.load_ref_sources[source] = nil
    if asset_table.asset_config:HasLoadReferences() and table.count(asset_table.load_ref_sources) == 0 then
        asset_table.asset_config:RemoveLoadReferences()
    end
end

function ContentDB:UnregisterAllAssetRequirements()
    for asset_id, asset_table in ipairs(self.asset_tables_by_id) do
        if asset_table.asset_config:HasLoadReferences() then
            asset_table.asset_config:RemoveLoadReferences()
        end
    end
    table.clear( self.asset_tables_by_id )
end

function ContentDB:UnregisterAssetRequirement(asset_id)
    local asset_table = self.asset_tables_by_id[asset_id]
    if asset_table and asset_table.asset_config:HasLoadReferences() then
        asset_table.asset_config:RemoveLoadReferences()
    end
    self.asset_tables_by_id[asset_id] = nil
end

function ContentDB:HasAssetRequirement(asset_id)
    return self.asset_tables_by_id[asset_id]
end

function ContentDB:GetAssetConfig(asset_id)
    local asset_table = self.asset_tables_by_id[asset_id]
    assert(asset_table, string.format("%s has not been added to the ContentDB", asset_id))
    return asset_table.asset_config
end

function ContentDB:GetAllAssetConfigs()
    local all_assets = {}
    for asset_id, asset_table in pairs(self.asset_tables_by_id) do
        all_assets[ asset_id ] = asset_table.asset_config
    end
    return all_assets
end

--------------------------

-- Called from ScriptLoader.
function ContentDB:OnLoadScript(result, filename)
    local function AddIfContent( class )
        if class:has_mixin(ContentNode) and class:GetContentID() then
            self:AddContentItem( class )
        else
            print("[ContentDB] Not content:", class, class.GetContentID and class:GetContentID())
        end
    end

    if strict.is_strict( result ) then
        -- Not Content, but probably a Constants table.
    elseif type(result) == "boolean" or result == nil or type(result) == "function" then
        -- No return.
    elseif type(result) == "table" then
        -- Quite different from gln because this seems safer and simpler.
        if Class.IsClassOrInstance(result) then
            AddIfContent(result)
        else
            self:AddContentList(result)
        end
    end
end

ContentDB:add_mixin(ScriptLoader)
return ContentDB

