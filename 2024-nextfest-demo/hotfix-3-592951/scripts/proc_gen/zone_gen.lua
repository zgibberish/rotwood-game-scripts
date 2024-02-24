local PropProcGen = require "proc_gen.prop_proc_gen"
local Lume = require "util.lume"
local SceneProp = require "proc_gen.scene_prop"
local SceneSpacer = require "proc_gen.scene_spacer"
local SceneParticleSystem = require "proc_gen.scene_particle_system"
local SceneFx = require "proc_gen.scene_fx"
local Enum = require "util.enum"

local ZONES = PropProcGen.Zone:Ordered()
setmetatable(ZONES, nil)

local ROOM_TYPES = PropProcGen.RoomType:AlphaSorted()
setmetatable(ROOM_TYPES, nil)

DecorLayer = Enum {
	"Ground",
	"Canopy",
	"Shadow",
	"Light"
}

DecorTags = Lume(DecorLayer:Ordered())
	:map(function(decor_layer) 
		return "DECOR_TAG_"..decor_layer 
	end)
	:result()

local ZoneGen = Class(function(self)
	self.zones = {}
	self.scene_props = {}
	self.spacers = {}
	self.particle_systems = {}
	self.fxes = {}
	self.room_types = deepcopy(ROOM_TYPES)
	self.offstage = true
	self.non_walkable = false
	self.can_obscure_features = false
	self.enabled = true
	self.decor_layer = DecorLayer.s.Ground
end)

-- Construct a ZoneGen from a "raw" data table that holds exactly the same data as ZoneGen, but has no
-- metatable.
function ZoneGen.FromRawTable(raw_table)
	local zone_gen = ZoneGen()
	for k, v in pairs(raw_table) do
		zone_gen[k] = v
	end
	zone_gen.scene_props = Lume(raw_table.scene_props)
		:map(function(scene_prop)
			return SceneProp.FromRawTable(scene_prop)
		end)
		:result()
	zone_gen.spacers = raw_table.spacers 
		and Lume(raw_table.spacers)
			:map(function(spacer)
				return SceneSpacer.FromRawTable(spacer)
			end)
			:result()
		or {}
	zone_gen.particle_systems = raw_table.particle_systems 
		and Lume(raw_table.particle_systems)
			:map(function(particle_system)
				return SceneParticleSystem.FromRawTable(particle_system)
			end)
			:result()
		or {}
	zone_gen.fxes = raw_table.fxes 
		and Lume(raw_table.fxes)
			:map(function(fx)
				return SceneFx.FromRawTable(fx)
			end)
			:result()
		or {}
	return zone_gen
end

function ZoneGen:GetLabel()
	if self.name then
		return self.name
	end
	local decor_layer = self.decor_layer or DecorLayer.s.Ground
	local zones = next(self.zones)
		and Lume(self.zones)
			:reduce(function(current, zone)
				return current..", "..zone
			end)
			:result()
		or "<choose some zones>"
	return decor_layer..": "..zones
end

function ZoneGen:Ui(editor, ui, id)
	self.name = ui:_InputTextWithHint("Name"..id, self:GetLabel(), self.name)
	if self.name == "" then
		self.name = nil
	end
	self.offstage = ui:_Checkbox("Offstage"..id, self.offstage)
	if ui:IsItemHovered() then
		ui:SetTooltipMultiline({
			"Restrict to either offstage bounds when checked, or on-stage bounds when unchecked.",
			"E.g. include the 'near_side' zone with this unchecked to place props on the cliff overhang on the sides."
		})
	end
	if not self.offstage then
		self.non_walkable = ui:_Checkbox("Non-Walkable"..id, self.non_walkable ~= nil and self.non_walkable or false)
		ui:SetTooltipIfHovered("If set, restrict placements to non-walkable areas")
	end
	self.can_obscure_features = ui:_Checkbox("Can Obscure Features" .. id, self.can_obscure_features)
	if ui:IsItemHovered() then
		ui:SetTooltipMultiline({
			"Most ZoneGens place props on the floor and so should be set to NOT obscure features.",
			"Some ZoneGens have 'raised' props, like tree canopies; these should be permitted to obscure features."
		})
	end
	ui:FlagRadioButtons("Zones"..id, ZONES, self.zones)
	self.decor_layer = ui:_ComboAsString("Decor Layer"..id, self.decor_layer or DecorLayer.s.Ground, DecorLayer:Ordered())
	
	ListUi(editor, self, ui, id, {
		title = "Props",
		name = "scene_props",
		element_editor = "PropEditor",
		browser_context = PrefabBrowserContext.id.Prop,
		clipboard_context = SceneProp.CLIPBOARD_CONTEXT,
		ElementUi = function(ui, id, scene_prop)
			ui:SameLineWithSpace()
			if ui:Button(ui.icon.list) then
				editor.prop_refs:Open(ui, editor, self, scene_prop)
			end
			ui:SetTooltipIfHovered("Show all references to this prop in this SceneGen")
			editor.selected_color_variant = scene_prop:Ui(ui, id, editor.browser, editor.selected_color_variant) 
		end,
		ElementLabel = function(scene_prop) return scene_prop:GetLabel() end,
		Clone = SceneProp.FromRawTable,
		features = UI_FEATURE_ENABLE | UI_FEATURE_ORDERED
	})
	ListUi(editor, self, ui, id, {
		title = "Spacers",
		name = "spacers",
		clipboard_context = SceneSpacer.CLIPBOARD_CONTEXT,
		ElementUi = function(ui, id, element) element:Ui(ui, id) end,
		ElementLabel = function(element) return element:GetLabel() end,
		Construct = SceneSpacer,
		Clone = SceneSpacer.FromRawTable,
		features = UI_FEATURE_ENABLE | UI_FEATURE_ORDERED
	})
	ListUi(editor, self, ui, id, {
		title = "Particle Systems",
		name = "particle_systems",
		element_editor = "ParticleEditor",
		browser_context = PrefabBrowserContext.id.ParticleSystem,
		clipboard_context = SceneParticleSystem.CLIPBOARD_CONTEXT,
		ElementUi = function(ui, id, element) element:Ui(ui, id, editor.browser) end,
		ElementLabel = function(element) return element:GetLabel() end,
		Clone = SceneParticleSystem.FromRawTable,
		features = UI_FEATURE_ENABLE | UI_FEATURE_ORDERED
	})
	ListUi(editor, self, ui, id, {
		title = "Fx",
		name = "fxes",
		element_editor = "FxEditor",
		browser_context = PrefabBrowserContext.id.Fx,
		clipboard_context = SceneFx.CLIPBOARD_CONTEXT,
		ElementUi = function(ui, id, element) element:Ui(ui, id, editor.browser) end,
		ElementLabel = function(element) return element:GetLabel() end,
		Clone = SceneFx.FromRawTable,
		features = UI_FEATURE_ENABLE | UI_FEATURE_ORDERED
	})
	ui:FlagRadioButtons("Room Types"..id, ROOM_TYPES, self.room_types)
end

return ZoneGen
