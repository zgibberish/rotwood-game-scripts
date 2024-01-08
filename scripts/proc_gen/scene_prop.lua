local PropProcGen = require "proc_gen.prop_proc_gen"
local Lume = require "util.lume"
local PropAutogenData = require "prefabs.prop_autogen_data"
local DungeonProgress = require "proc_gen.dungeon_progress"
local PropColorVariant = require "proc_gen.prop_color_variant"
local SceneElement = require "proc_gen.scene_element"
local Canopy = require "prefabs.customscript.canopy"
local LightSpot = require "prefabs.customscript.lightspot"
require "proc_gen.weighted_choice"

local TILE_TYPES = PropProcGen.Tile:AlphaSorted()
setmetatable(TILE_TYPES, nil)

local PROP_FLAGS = PropProcGen.Tag:AlphaSorted()
setmetatable(PROP_FLAGS, nil)

local SceneProp = Class(SceneElement, function(self, prop, zone_gen)
	SceneElement._ctor(self)

	self.prop = prop
	self.tile_types = deepcopy(TILE_TYPES)
	self.flags = {}
	self.color_variants = {}

	if prop and zone_gen then
		local prop_prefab = PropAutogenData[prop]

		-- Add each prop color variant whose zone is in our ZoneGen's list.
		if zone_gen and next(zone_gen.zones) and prop_prefab.color_variants then
			self.color_variants = Lume(prop_prefab.color_variants)
				:filter(function(prefab_color_variant)
					return Lume(zone_gen.zones)
						:any(function(zone_gen_zone)
							return Lume(prefab_color_variant.zones):find(zone_gen_zone):result()
						end)
						:result()
				end)
				:map(function(prefab_color_variant)
					return PropColorVariant.FromDeprecatedVariant(prefab_color_variant)
				end)
				:result()
		end

		-- Initialize persistent radius from prop properties if possible.
		self.radius = 1
		if prop_prefab.physicssize then
			self.radius = prop_prefab.physicssize
		elseif prop_prefab.gridsize then
			local gridsize = prop_prefab.gridsize[1]
			self.radius = math.max(1, math.floor((gridsize.h + gridsize.w) / 4))
		end

		-- Pick up dungeon_progress_constraints too.
		self.dungeon_progress_constraints = (prop_prefab.proc_gen and prop_prefab.proc_gen.dungeon_progress_constraints)
			and deepcopy(prop_prefab.proc_gen.dungeon_progress_constraints)
			or DungeonProgress.DefaultConstraints()
	end
end)

SceneProp.CLIPBOARD_CONTEXT = "++SceneProp.CLIPBOARD_CONTEXT"

function SceneProp.FromRawTable(raw_table)
	local prop = SceneProp()
	for k, v in pairs(raw_table) do
		prop[k] = v
	end
	prop.color_variants = Lume(prop.color_variants):map(function(variant)
		return PropColorVariant.FromRawTable(variant)
	end):result()
	return prop
end

function SceneProp:GetDecorType()
	return DecorType.s.Prop
end

-- TODO @chrisp #scenegen - hard-coded tile types
local tile_types = {
	DIRT = PropProcGen.Tile.s.path,
	MOLD = PropProcGen.Tile.s.path,
	GRASS = PropProcGen.Tile.s.rough,
	FUZZ = PropProcGen.Tile.s.rough,
}

-- Return true if the specified tile_name maps to an accepted tile_type, or if the tile_name is unknown.
-- Return false if the specified tile_name is known but not in the whitelist of accepted tile types.
function SceneProp:CanPlaceOnTile(tile_name)
	local tile_type = tile_types[tile_name]
	return not tile_type or Lume(self.tile_types):find(tile_type):result()
end

function SceneProp:GetLabel()
	return self._base.GetLabel(self) or self.prop
end

function SceneProp:Ui(ui, id, prop_browser, selected_color_variant)
	ui:Text("Prop: "..self.prop)
	ui:SameLineWithSpace()
	if ui:Button(ui.icon.search..id) then
		prop_browser:Open(ui, PrefabBrowserContext.id.Prop)
	end
	ui:SetTooltipIfHovered("Choose different prop")

	self._base.Ui(self, ui, id)

	ui:FlagRadioButtons("Tile Types" .. id, TILE_TYPES, self.tile_types)
	ui:FlagRadioButtons("Flags"..id, PROP_FLAGS, self.flags)
	selected_color_variant = PropColorVariant.ColorVariantsUi(self, ui, id.."ColorVariants", selected_color_variant)

	local prefab = PropAutogenData[self.prop]

	self:CanopyUi(ui, id, prefab)
	self:LightSpotUi(ui, id, prefab)

	return selected_color_variant
end

function SceneProp:CanopyUi(ui, id, prefab)
	if prefab.script ~= "canopy" then
		return
	end
	local changed, canopy = ui:Checkbox(id.."Canopy", self.canopy ~= nil)
	ui:SetTooltipIfHovered("Override")
	if changed then
		if canopy then
			self.canopy = {
				script_args = {}
			}
		else
			self.canopy = nil
		end
	end
	if not self.canopy then
		ui:PushDisabledStyle()
	end
	ui:SameLineWithSpace()
	if ui:CollapsingHeader("Canopy"..id) and self.canopy then
		ui:Indent()
		Canopy.PropEdit(nil, ui, self.canopy)
		Canopy.LivePropEdit(nil, ui, self.canopy, Canopy.Defaults)
		ui:Unindent()
	end
	if not self.canopy then
		ui:PopDisabledStyle()
	end
end

function SceneProp:LightSpotUi(ui, id, prefab)	
	if prefab.script ~= "lightspot" then
		return
	end
	local changed, light_spot = ui:Checkbox(id.."Light Spot", self.light_spot ~= nil)
	ui:SetTooltipIfHovered("Override")
	if changed then
		if light_spot then
			self.light_spot = {
				script_args = {}
			}
		else
			self.light_spot = nil
		end
	end
	if not self.light_spot then
		ui:PushDisabledStyle()
	end
	ui:SameLineWithSpace()
	if ui:CollapsingHeader("Light Spot"..id) and self.light_spot then
		ui:Indent()
		LightSpot.LivePropEdit(nil, ui, self.light_spot, LightSpot.Defaults)
		ui:Unindent()
	end
	if not self.light_spot then
		ui:PopDisabledStyle()
	end
end

return SceneProp
