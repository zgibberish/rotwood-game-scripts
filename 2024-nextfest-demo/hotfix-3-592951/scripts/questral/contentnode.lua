-- Intended to be a mixin: Only a table of functions.
local ContentNode = {}

local ANIM, IMG, LOC = require("questral.util.contentutil").anim_img_loc()

function ContentNode:GetContent()
    return rawget( self, "_content" ) -- Will be nil if this class or instance defines no content.
end

function ContentNode:UseClassAsKey()
    assert(self._classname, "Must define _classname to UseClassAsKey.") -- rotwood classes don't auto store a name
    self.class_as_key = true
    -- TODO(quest): Can we
    -- self:SetContentID(contentutil.BuildClassNameFromCallstack(4)? May not be
    -- right, but a better default that can be overridden.
end

function ContentNode:SetContentID( id )
    self.content_id = id
end

function ContentNode:SetContentKey( key )
    self.content_key = key
end

function ContentNode:GetContentID()
    if self.class_as_key then
        return self.content_id
    else
        -- use explicit id if we have one, otherwise classname
        return self.content_id or self._classname
    end
end

function ContentNode:GetContentKey()
    if self.content_key then
        -- explicit content_key set
        return self.content_key
    elseif self.class_as_key then
        -- use our classname as key
        return self._classname
    else
        return "CLASSES"
    end
end

function ContentNode:_AffirmContent( key )
    local content = self:GetContent()
    if content == nil then
        content = {}
        self._content = content
    end

    local t = content[ key ]
    if t == nil then
        t = {}
        content[ key ] = t
    end

    return t
end

-- Looks up a category of content defined by 'key', deferring to the global accessor_fn to get it from the content DB.
function ContentNode:_ResolveContent( key, id )
    assert(id)
    local class = self
    while class do
        local content = rawget( class, "_content" )
        local path = content and content[ key ] and content[ key ][ id ]
        if path then
            return path
        end
        if class._class == class then
            class = class._base
        else
            class = class._class
        end
    end
end

function ContentNode:AddString(id, str)
    local strings = self:_AffirmContent( "strings" )

    assert( type(str) == "string" )
    -- Trim all questral strings since they usually have excessive trailing
    -- whitespace that causes false positive errors in po_vault.
    strings[ id ] = str:trim()
    return id
end

function ContentNode:GetConvo(id)

    local class = self
    while class do
        local content = rawget( class, "_content" )
        if content and  content.convos and content.convos[id] then
            return content.convos[id]
        end

        if class._class == class then
            class = class._base
        else
            class = class._class
        end
    end
end

function ContentNode:GetConvos()
    local content = self:GetContent()
    return content and content.convos or table.empty
end

function ContentNode:AddConvo(id, state_id, objective_id)
    local convos = self:_AffirmContent( "convos" )

    assert( type(id) == "string" )
    assert( convos[ id ] == nil or error( string.format( "convo '%s' redefined", id )))
    local Convo = require "questral.convo"
    convos[ id ] = Convo( self._classname .. "." .. id)
    convos[ id ].objective_id = objective_id
    return convos[ id ]:AddState(state_id)
end


function ContentNode:AddStrings(t, prefix)
    for id, v in pairs(t) do
        if prefix then
            id = prefix.."."..id
        end
        if type(v) == "string" then
            self:AddString(id, v)
        else
            self:AddStrings(v, id)
        end
    end
end

function ContentNode:AddQuips(quips)
    for _, v in ipairs(quips) do
        self:AddQuip(v)
    end
    return self
end

function ContentNode:AddQuip(quip)
    local quips = self:_AffirmContent( "quips" )
    -- PORT: Don't see a good reason to keep quips sorted.
    -- 4f64be326f76567b0552a4d6dc92cad8da65eb65 says "Store quips in a series
    -- of tables, indexed by primary key, so that we don't have to evaluate
    -- every single quip for every single query." But that still didn't justify
    -- it.
    table.insert(quips, quip)
    return quip
end

-- See QuipMatcher:_GenerateMatches!
function ContentNode:GetQuips()
    -- Does inherited content override, or merge quips? Currently not using
    -- rawget so we get inherited content.
    return self._content and self._content.quips or table.empty
end

function ContentNode:SetContentDB(db)
    rawset( self, "_db", db )
end

function ContentNode:GetContentDB()
    return self._db
end

function ContentNode:RequireTexture( id, path )
    local textures = self:_AffirmContent( "required_textures" )
    textures[ id ] = path:lower()
    return id
end

function ContentNode:RequireTextures(t)
    for id, path in pairs(t) do
        self:RequireTexture( id, path )
    end
end

function ContentNode:PreloadTexture( id, path )
    local textures = self:_AffirmContent( "preloaded_textures" )
    textures[ id ] = path:lower()
    return id
end

function ContentNode:PreloadTextures(t)
    for id, path in pairs(t) do
        self:PreloadTexture( id, path )
    end
end

function ContentNode:RequireAnim( id, path )
    local anims = self:_AffirmContent( "required_anims" )
    anims[ id ] = path:lower()
    return id
end

function ContentNode:RequireAnims(t)
    for id, path in pairs(t) do
        self:RequireAnim( id, path )
    end
end

function ContentNode:PreloadAnims(t)
    for id, path in pairs(t) do
        self:PreloadAnim(id, path)
    end
end

function ContentNode:PreloadAnim(id, path)
    local anims = self:_AffirmContent( "preloaded_anims" )
    anims[ id ] = path:lower()
    return id
end

function ContentNode:PreloadAsset( asset_id )
    assert( type(asset_id) == "string" )
    local assets = self:_AffirmContent( "preloaded_assets" )
    assets[ asset_id ] = asset_id
end

function ContentNode:PreloadAssets(t)
    for id, asset_id in pairs(t) do
        if type(id) == "number" then
            -- Are we adding assets as an array?
            self:PreloadAsset( asset_id )
        else
            LOGWARN( "PreloadAssets must be added in array-form, invalid key: %s", tostring(id))
        end
    end
end

function ContentNode:RequireAsset( asset_id )
    assert( type(asset_id) == "string" )
    local assets = self:_AffirmContent( "required_assets" )
    assets[ asset_id ] = asset_id
end

function ContentNode:RequireAssets(t)
    for id, asset_id in pairs(t) do
        if type(id) == "number" then
            -- Are we adding assets as an array?
            self:RequireAsset( asset_id )
        else
            LOGWARN( "RequireAssets must be added in array-form, invalid key: %s", tostring(id))
        end
    end
end

-- This only needs to be called when we are not added to the content_db through the generic path (e.g. AssetConfigs)
function ContentNode:AddRequiredContent()
    local assets = self:_AffirmContent( "required_assets" )
    for asset_id, _ in pairs(assets) do
        self:GetContentDB():RegisterAssetRequirement(asset_id, self)
    end

    local anims = self:_AffirmContent( "required_anims" )
    for _, path in pairs(anims) do
        self:GetContentDB():RegisterAnimRequirement(path, self)
    end

    local textures = self:_AffirmContent( "required_textures" )
    for _, path in pairs(textures) do
        self:GetContentDB():RegisterImageRequirement(path, self)
    end
end

function ContentNode:HasLoadReferences()
    return self._has_load_references
end

-- Call when this content needs its required content to be available
function ContentNode:AddLoadReferences()
    local assets = self:_AffirmContent( "required_assets" )
    for asset_id, _ in pairs(assets) do
        self:GetContentDB():AddAssetLoadReference(asset_id, self)
    end

    local anims = self:_AffirmContent( "required_anims" )
    for _, path in pairs(anims) do
        self:GetContentDB():AddAnimLoadReference(path, self)
    end

    local textures = self:_AffirmContent( "required_textures" )
    for _, path in pairs(textures) do
        self:GetContentDB():AddImageLoadReference(path, self)
    end
    self._has_load_references = true
end

-- Call when this content no longer needs its required content
function ContentNode:RemoveLoadReferences()
    local assets = self:_AffirmContent( "required_assets" )
    for asset_id, _ in pairs(assets) do
        self:GetContentDB():RemoveAssetLoadReference(asset_id, self)
    end

    local anims = self:_AffirmContent( "required_anims" )
    for _, path in pairs(anims) do
        self:GetContentDB():RemoveAnimLoadReference(path, self)
    end

    local textures = self:_AffirmContent( "required_textures" )
    for _, path in pairs(textures) do
        self:GetContentDB():RemoveImageLoadReference(path, self)
    end
    self._has_load_references = false
end

------------------------------------------------------------------------------------------------
-- Returns the paths to anims / textures / assets that this content Preloads or Requires
function ContentNode:GetDependentAnimPaths()
    local anim_paths = {}
    for _, path in pairs(self:_AffirmContent( "required_anims" )) do
        table.insert(anim_paths, path)
    end
    for _, path in pairs(self:_AffirmContent( "preloaded_anims" )) do
        table.insert(anim_paths, path)
    end
    return anim_paths
end

function ContentNode:GetDependentImagePaths()
    local image_paths = {}
    for _, path in pairs(self:_AffirmContent( "required_textures" )) do
        table.insert(image_paths, path)
    end
    for _, path in pairs(self:_AffirmContent( "preloaded_textures" )) do
        table.insert(image_paths, path)
    end
    return image_paths
end

function ContentNode:GetDependentAssetIDs()
    local assets = {}
    for asset_id, _ in pairs(self:_AffirmContent( "required_assets" )) do
        table.insert(assets, asset_id)
    end
    for asset_id, _ in pairs(self:_AffirmContent( "preloaded_assets" )) do
        table.insert(assets, asset_id)
    end
    return assets
end

------------------------------------------------------------------------------------------------

-- Always returns some string; if the Localized entry is not found, returns its content db path.
function ContentNode:LOC( strid )
    local key, id = self:GetContentKey(), self:GetContentID()
    return self:TryLOC( strid ) or string.format( "%s.%s.%s", key, id, strid )
end

-- Tries to lookup the localized string indexed by 'strid'
-- no return value if unfound
function ContentNode:TryLOC(strid)
    local fullid = self:GetLocPath( strid )
    if fullid then
        return LOC( fullid )
    end
end

function ContentNode:GetLocPath( strid )
    local class = self
    while class do
        local content = rawget( class, "_content" )
        if content and content.strings and content.strings[ strid ] then
            local key, id = class:GetContentKey(), class:GetContentID()
            return string.format( "%s.%s.%s", key, id, strid )
        end
        if class._class == class then
            class = class._base
        else
            class = class._class
        end
    end
end

function ContentNode:IMG(id)
    local path = self:_ResolveContent( "preloaded_textures", id ) or self:_ResolveContent( "required_textures", id )
    if path then
        return IMG( path )
    end
end

-- For use within strings
function ContentNode:IMG_PATH(id)
    local path = self:_ResolveContent( "preloaded_textures", id ) or self:_ResolveContent( "required_textures", id )
    if path then
        return path
    end
end

function ContentNode:ANIM(id)
    local path = self:_ResolveContent( "preloaded_anims", id ) or self:_ResolveContent( "required_anims", id )
    if path then
        return ANIM( path )
    end
end

function ContentNode:ASSET( asset_id )
    if self:_ResolveContent( "preloaded_assets", asset_id ) or self:_ResolveContent( "required_assets", asset_id ) then
        return ASSET( asset_id )
    end
end

return ContentNode
