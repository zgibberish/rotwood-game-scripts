local DebugDraw = require "util.debugdraw"
local DebugSettings = require "debug.inspectors.debugsettings"
local DebugNodes = require "dbui.debug_nodes"
local Enum = require "util.enum"
local lume = require "util.lume"


local TransformType = Enum{
	"All",
	"UI",
	"World",
}

local DebugEntityExplorer = Class(DebugNodes.DebugNode, function(self)
	DebugNodes.DebugNode._ctor(self, "Debug Entity Explorer")

	self.options = DebugSettings("EntityExplorer.options")
		:Option("filter_component", "")
		:Option("filter_name", "")
		:Option("filter_prefabname", "")
		:Option("only_prefabs", false)
		:Option("transform_type", TransformType.s.All)
end)

DebugEntityExplorer.PANEL_WIDTH = 600
DebugEntityExplorer.PANEL_HEIGHT = 1200

function DebugEntityExplorer:RenderPanel( ui, panel )
	self.options:Enum(ui, "Transform Type", "transform_type", TransformType:Ordered())
	self.options:Toggle(ui, "Only prefab instances", "only_prefabs")
	self.options:SaveIfChanged("filter_prefabname", ui:FilterBar(self.options.filter_prefabname, "Filter prefab", "Prefab name pattern..."))
	self.options:SaveIfChanged("filter_name", ui:FilterBar(self.options.filter_name, "Filter entity name", "Name pattern..."))
	self.options:SaveIfChanged("filter_component", ui:FilterBar(self.options.filter_component, "Filter component", "Lua component name pattern..."))

	-- not persistent, not saved
	self.net_id = ui:_FilterBar(self.net_id, "Filter network id", "id...") or ""
	ui:SameLineWithSpace()
	if ui:Button(ui.icon.list, ui.icon.width) then
		DebugNodes.DebugNetwork:FindOrCreateEditor()
	end

	ui:BeginChild("DebugEntityExplorer")
	if ui:BeginTable("world-ents", 2) then
		for guid,ent in pairs(Ents) do
			local tt = self.options.transform_type
			local ok_transform = tt == TransformType.s.All
				or (tt == TransformType.s.UI	and ent.UITransform)
				or (tt == TransformType.s.World and ent.Transform)
			local ok_prefab = ent.prefab or not self.options.only_prefabs
			local ok_component = not self.options.filter_component
				or self.options.filter_component:len() == 0
				or lume(ent.components)
					:keys()
					:match(function(v)
						return ui:MatchesFilterBar(self.options.filter_component, v)
					end)
					:result()
			local ok_name       = ui:MatchesFilterBar(self.options.filter_name, (ent.name or ""))
			local ok_prefabname = ui:MatchesFilterBar(self.options.filter_prefabname, (ent.prefab or ""))
			local ok_net_id     = ui:MatchesFilterBar(self.net_id, tostring(ent.Network and ent.Network:GetEntityID() or ""))

			if ok_transform
				and ok_prefab
				and ok_component
				and ok_name
				and ok_prefabname
				and ok_net_id
			then
				ui:TableNextColumn()
				panel:AppendTable(ui, ent)
				local is_hovered = ui:IsItemHovered()

				ui:TableNextColumn()
				local id = tostring(ent)
				if ent:HasTag("widget") then
					if ui:Button("Debug Widget##"..id) then
						d_viewinpanel(ent.widget)
					end
				elseif ent.Transform then
					if ui:Button("Teleport to##"..id) then
						c_goto(ent)
					end
					ui:SetTooltipIfHovered({
						"Pos: ".. tostring(ent:GetPosition()),
						string.format("Rotation: %0.3f", ent.Transform:GetRotation()),
					})
					is_hovered = is_hovered or ui:IsItemHovered()
				end

				if ent.Transform and is_hovered then
					DebugDraw.GroundHex(ent:GetPosition(), nil, 1, WEBCOLORS.YELLOW)
				end
			end
		end
		ui:EndTable()
	end
	ui:EndChild()
end

DebugNodes.DebugEntityExplorer = DebugEntityExplorer

return DebugEntityExplorer
