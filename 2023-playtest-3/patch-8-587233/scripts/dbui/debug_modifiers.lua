local DebugNodes = require "dbui.debug_nodes"

local DebugModifiers = Class(DebugNodes.DebugNode, function(self)
	DebugNodes.DebugNode._ctor(self, "Debug Modifiers")
end)

DebugModifiers.PANEL_WIDTH = 400
DebugModifiers.PANEL_HEIGHT = 200

function DebugModifiers:RenderPanel( ui, node )

	ui:Columns(3)

	ui:Text("CTRL")
	ui:NextColumn()

	ui:Text("ALT")
	ui:NextColumn()

	ui:Text("SHIFT")
	ui:NextColumn()

	ui:Separator()

	ui:Text( tostring(TheInput:IsKeyDown(InputConstants.Keys.CTRL) ) )
	ui:NextColumn()

	ui:Text( tostring(TheInput:IsKeyDown(InputConstants.Keys.ALT) ) )
	ui:NextColumn()

	ui:Text( tostring(TheInput:IsKeyDown(InputConstants.Keys.SHIFT) ) )
	ui:NextColumn()

	ui:Columns()

end

DebugNodes.DebugModifiers = DebugModifiers

return DebugModifiers
