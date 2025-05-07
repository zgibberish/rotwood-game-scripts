require "constants"
require "consolecommands"
local DebugNodes = require "dbui.debug_nodes"
local DebugWidget = require "dbui.debug_widget"

local rowId = 0 -- For giving each TreeNode() a unique name ID

--- Shows an expandable tree view of the widget hierarchy for the current screen.
local DebugWidgetExplorer = Class(DebugNodes.DebugNode, function(self)
	DebugNodes.DebugNode._ctor(self, "Debug Widget Explorer")

	self.expandAll = false
end)

DebugWidgetExplorer.PANEL_WIDTH = 600
DebugWidgetExplorer.PANEL_HEIGHT = 600
DebugWidgetExplorer.MENU_BINDINGS = DebugWidget.MENU_BINDINGS

function DebugWidgetExplorer:RenderPanel( ui, panel )

	if self.current_error then
		ui:Text(self.current_error)
		return
	end

	ui:TextColored(RGB(255, 255, 0), "Ctrl-click to open the selected widget in a new panel." )

	-- Expand/Collapse All
	local expandAllText = self.expandAll and "Collapse All" or "Expand All"
	local expandAllClicked = ui:Button(expandAllText)
	if expandAllClicked then
		self.expandAll = not self.expandAll
	end

	ui:Separator()

	local screenStack = TheFrontEnd:GetActiveScreen()
	if screenStack then
		rowId = 0
		self:ShowWidgetTree(ui, panel, screenStack, 0, expandAllClicked)
	else
		ui:Text("No active screen")
	end
end

function DebugWidgetExplorer:ShowWidgetTree(ui, panel, widget, indent, expandAllClicked)

	local name = DebugWidget:GetWidgetLabel(widget)

	-- Show a debug widget node when clicked
	if ui:Button(name .. "##" .. rowId) then
		panel:PushNode(DebugWidget(widget))
	end

	-- Draw bounding box if widget button is hovered
	if ui:IsItemHovered() then
		DebugWidgetBoundingBox:DrawDebugBoundingBox(ui, widget, RGB(255, 255, 0), 2)
	end

	rowId = rowId + 1

	local children = widget:GetChildren()
	if next(children) then
		ui:SameLineWithSpace()

		indent = indent + 10

		if expandAllClicked then
			ui:SetNextTreeNodeOpen(self.expandAll)
		end

		if ui:TreeNode("##".. rowId ) then
			for _, childWidget in pairs(children) do
				self:ShowWidgetTree(ui, panel, childWidget, indent, expandAllClicked)
			end

			ui:TreePop()
		end

		indent = indent - 10
	end
end

DebugNodes.DebugWidgetExplorer = DebugWidgetExplorer

return DebugWidgetExplorer
