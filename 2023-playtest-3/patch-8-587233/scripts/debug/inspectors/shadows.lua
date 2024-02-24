local GroundTiles = require "defs.groundtiles"
local strict = require "util.strict"

local function VerifyInterface(type)
	local expected_members = {
		'AddTreeNodeEnder',
		'SetDirty',
		'Refresh',
		'AddSectionStarter',
		'AddSectionEnder',
		'Button_CopyToGroup',
		'OnShadowTilesChanged',
		'mapshadowEditorPane'
	}
	for _, expected_member in ipairs(expected_members) do
		assert(type[expected_member],"Editor does not fully implement ShadowsUi interface: '"..expected_member.."' is unimplemented")
	end
end

function GetShadowsKeys()
	return {
		"shadow_tilegroup",
		"map_shadow",
	}
end

function CopyShadowsProperties(from, to)
	for _, k in ipairs(GetShadowsKeys()) do
		if from[k] then
			to[k] = deepcopy(from[k])
		end
	end
end

local function GetShadowTilesetList()
	local list = {}
	for i,v in pairs(GroundTiles.TileGroups) do
		if v.is_shadow_group then
			table.insert(list, i)
			table.sort(list, function (k1, k2) return string.lower(k1) < string.lower(k2) end)
		end
	end
	return list
end

function ShadowsUi(editor, ui, shadows, enabled)
	VerifyInterface(editor)

	if not ui:CollapsingHeader("Shadows") or not enabled then
		return
	end

	editor:AddSectionStarter(ui)

	ui:Indent()

	if ui:TreeNode("Shadow Tileset", ui.TreeNodeFlags.DefaultOpen) then
		local tileset_list = GetShadowTilesetList()

		local shadow_tilegroup = shadows.shadow_tilegroup or "forest_shadow"
		local tileset_idx = nil
		for i = 1, #tileset_list do
			if shadow_tilegroup == tileset_list[i] then
				tileset_idx = i
				break
			end
		end
		local new_idx = ui:_Combo("Params", tileset_idx, tileset_list)
		if new_idx ~= nil and new_idx ~= tileset_idx then
			local new_shadow_tilegroup = tileset_list[new_idx]
			if new_shadow_tilegroup == "forest_shadow" then
				new_shadow_tilegroup = nil
			end
			if shadows.shadow_tilegroup ~= new_shadow_tilegroup then
				shadows.shadow_tilegroup = new_shadow_tilegroup
				editor:SetDirty()
			end
			editor:OnShadowTilesChanged(editor.prefabname, shadows)
			editor:Refresh(editor.prefabname, shadows)
		end
		editor:AddTreeNodeEnder(ui)
	end

	if ui:TreeNode("Edit Map Shadow", ui.TreeNodeFlags.DefaultOpen) then
		local iscurrentworld = TheWorld ~= nil and TheWorld.prefab == editor.prefabname
		local map_shadow = iscurrentworld and TheWorld.map_shadow or nil

		editor.mapshadowEditorPane.map_shadow = map_shadow --reference actual table, not a copy!
		editor.mapshadowEditorPane:OnRender(editor.prefabname)

		if iscurrentworld then
			local new_map_shadow = editor.mapshadowEditorPane.map_shadow
			if new_map_shadow ~= nil then
				local empty = true
				for tiley = 1, #new_map_shadow do
					local row = new_map_shadow[tiley]
					for tilex = 1, #row do
						if row[tilex] ~= 0 then
							empty = false
							break
						end
					end
					if not empty then
						break
					end
				end
				if empty then
					new_map_shadow = nil
				end
			end
			if ui:Button("Reset Map Shadow") then
				shadows.map_shadow = nil
				editor:Refresh(editor.prefabname, shadows)
			end
			if not deepcompare(shadows.map_shadow, new_map_shadow) then
				shadows.map_shadow = deepcopy(new_map_shadow)
				editor:SetDirty()
			end
		end

		editor:AddTreeNodeEnder(ui)
	end

	ui:Unindent()

	editor:AddSectionEnder(ui)
end

local DrawLayer = strict.strictify{
	-- Values must match MapComponent::eDrawLayers
	DrawLayer_Ground = 0,
	DrawLayer_Shadows = 1,
	DrawLayer_Count = 2,
}

function RemoveShadowLayer(world)
	for _, shadow_layer in ipairs(world.shadow_layers) do
		world.Map:RemoveRenderLayer(shadow_layer, DrawLayer.DrawLayer_Shadows)
		MapLayerManager:ReleaseRenderLayer(shadow_layer)
	end
	world.shadow_layers = {}
end

function SetupShadowLayer(shadows, suppress_rebuild)
	-- The shadow layer tiles
	TheWorld.shadow_tilegroup = GroundTiles.TileGroups[shadows.shadow_tilegroup or "forest_shadow"]
	for tile_type = 1, #TheWorld.shadow_tilegroup.Order do
		local tiles = GroundTiles.Tiles[TheWorld.shadow_tilegroup.Order[tile_type]]
		if tiles then
			dbassert(tiles.shadow)
			local shadow_layer = MapLayerManager:CreateRenderLayer(
				tile_type, --embedded map array value
				resolvefilepath(tiles.tileset_atlas),
				resolvefilepath(tiles.tileset_image),
				resolvefilepath(tiles.noise_texture),
				tiles.colorize					-- this should probably go? Or is it a nice to have?
			)
			TheWorld.shadow_layers[#TheWorld.shadow_layers + 1] = shadow_layer
			TheWorld.Map:AddRenderLayer(shadow_layer, DrawLayer.DrawLayer_Shadows)
		end
	end

	-- for now fill the shadow layer with empty
	local width, height = TheWorld.Map:GetSize()
	for y = 1, height do
		for x = 1, width do
			local shadow_level = (shadows.map_shadow
				and shadows.map_shadow[y]
				and shadows.map_shadow[y][x]
				)
				or 0

			-- tileid is an index into our RenderLayers.
			-- Add 1 to skip the first entry, the impassable tile. There are no impassable tiles on the shadow layers.
			-- Add 1 more to transform from 0-based shadowlevel to 1-based tile_type.
			local tile_type = shadow_level + 2

			TheWorld.map_shadow[y][x] = shadow_level
			TheWorld.Map:SetTile(x - 1, y - 1, tile_type, DrawLayer.DrawLayer_Shadows)
		end
	end

	if not suppress_rebuild then
		TheWorld.Map:Rebuild()
	end
end

function ApplyShadows(shadows, suppress_rebuild)
	PostProcessor:SetShadowSoftness(0.5)
	TheSim:SetShadowBlends(0.4, 0.6, 0.5)
	SetupShadowLayer(shadows, suppress_rebuild)
end
