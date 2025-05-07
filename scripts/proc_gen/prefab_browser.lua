local Lume = require "util.lume"
local DebugNodes = require "dbui.debug_nodes"
local Enum = require "util.enum"
local PropAutogenData = require "prefabs.prop_autogen_data"
local ParticleSystemAutogenData = require "prefabs.particles_autogen_data"
local WorldAutogenData = require "prefabs.world_autogen_data"

PrefabBrowserContext = Enum
{
	"Prop",
	"UnderlayProp",
	"Destructible",
	"ParticleSystem",
	"Room",
	"RoomParticleSystem",
	"CreatureSpawner"
}

local POPUP_TITLE = "Prefab Browser"

local PrefabBrowser = Class(function(self, ContextUi)
	self.group_filter = ""
	self.filter_text = ""
	self.ContextUi = ContextUi
end)

function PrefabBrowser:Open(ui, context, MatchContext)
	self.context = context

	-- Initialize based on context.
	if self.context == PrefabBrowserContext.id.ParticleSystem 
		or self.context == PrefabBrowserContext.id.RoomParticleSystem 
	then
		self.editor = DebugNodes.ParticleEditor
		self.editor_name = "ParticleEditor"
		self.elements = ParticleSystemAutogenData
	elseif self.context == PrefabBrowserContext.id.Room then
		self.editor = DebugNodes.WorldEditor
		self.editor_name = "WorldEditor"
		self.elements = WorldAutogenData
	else
		self.editor = DebugNodes.PropEditor
		self.editor_name = "PropEditor"
		self.elements = PropAutogenData
	end
	self.groups = Lume(self.elements)
		:map(function(element) return element.group end)
		:unique()
		:sort()
		:result()
	table.insert(self.groups, 1, "") -- First element is empty string meaning "no group"
	if MatchContext then
		self.MatchContext = MatchContext
	elseif self.context == PrefabBrowserContext.id.Destructible then
		self.MatchContext = function(browser_element) return browser_element.script == "prop_destructible" end
	elseif self.context == PrefabBrowserContext.id.CreatureSpawner then
		self.MatchContext = function(browser_element) return browser_element.script == "creaturespawner" end
	else
		self.MatchContext = function(_) return true end
	end

	ui:OpenPopup(POPUP_TITLE)
end

function PrefabBrowser:ModalUi(ui, id)
	if not ui:BeginPopupModal(POPUP_TITLE, true) then
		return
	end
	id = id.."PropBrowser"
	ui:Text("Context: " .. PrefabBrowserContext:FromId(self.context))
	self.group_filter = self.groups and ui:_ComboAsString("Group"..id, self.group_filter, self.groups, true)
	self.filter_text = ui:_FilterBar(self.filter_text, id .. "FilterBar") or ""
	Lume(self.elements)
		:filter(function(prop)
			return not self.group_filter
				or self.group_filter == ""
				or prop.group == self.group_filter
		end, true)
		:filter(self.MatchContext, true)
		:keys()
		:filter(function(name) return string.match(name, self.filter_text) end)
		:sort()
		:each(function(name) self:ElementUi(ui, id..name, name) end)
	ui:EndPopup()
end

function PrefabBrowser:ElementUi(ui, id, name)
	id = id..name

	local same_line = self.ContextUi
	if self.ContextUi then
		-- If the user put anything on the line, stay on the same line.
		same_line = self.ContextUi(ui, id, name)
	end

	if same_line then
		ui:SameLineWithSpace()
	end
	if ui:Button(ui.icon.folder .. id) then
		self.editor:FindOrCreateEditor(name)
	end
	ui:SetTooltipIfHovered("Open in "..self.editor_name)

	ui:SameLineWithSpace()
	ui:Text(name)
end

return PrefabBrowser
