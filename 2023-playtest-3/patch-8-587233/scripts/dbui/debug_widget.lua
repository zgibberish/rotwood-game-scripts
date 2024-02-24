local DebugNodes = require "dbui.debug_nodes"
local LayoutTestWidget = require "widgets.layouttestwidget"
require "consolecommands"
require "constants"

local DebugWidget = Class(DebugNodes.DebugNode, function(self, widget)
	DebugNodes.DebugNode._ctor(self, "Debug Widget")
	self.focus_widget = widget
	self.filter = ""
	self.can_select = true

	self.selectedLayoutTestWidget = nil
end)

DebugWidget.PANEL_WIDTH = 600
DebugWidget.PANEL_HEIGHT = 600

DebugWidget.MENU_BINDINGS = {
	{
		name = "Widget",
		bindings = {
			{
				name = "Widget Inspector",
				fn = function(params)
					params.panel:PushNode(DebugNodes.DebugWidget())
				end,
			},
			{
				name = "Widget Explorer",
				fn = function(params)
					params.panel:PushNode(DebugNodes.DebugWidgetExplorer())
				end,
			},
			{
				name = "Widget Tracer",
				fn = function(params)
					params.panel:PushNode(DebugNodes.DebugWidgetTracer())
				end,
			},
			{
				name = "Pick Screen",
				fn = function(params)
					local cmds = {}
					for i,screen in ipairs(TheFrontEnd.screenstack) do
						local key = ("[%i] %s"):format(i, screen._widgetname)
						cmds[key] = function()
							d_viewinpanel(screen)
						end
					end
					TheFrontEnd.debugMenu.quickfind:OpenListOfCommands(cmds)
				end,
			},
		},
	},
}



local function get_var_name(widget)
	if not widget.parent then
		return nil
	end
	local parent = widget.parent
	-- Lots of screens put their references in the screen but widgets under a
	-- root, so search until we find the widget.
	while parent do
		if not parent then
			break
		end
		for var_name,w in pairs(parent) do
			if w == widget and var_name ~= "default_focus" then
				return var_name
			end
		end
		if parent == TheFrontEnd.sceneroot then
			-- Assign FrontEnd as the parent so we can get the names for the
			-- variables.
			assert(not parent.parent, "We now support FrontEnd as a normal parent. Remove this special case.")
			parent = TheFrontEnd
		else
			parent = parent.parent
		end
	end
end

local function get_widget_label(widget, prefix)
	prefix = prefix or ""
	local var_name = get_var_name(widget) or "?"
	local name = widget._widgetname
	if not name or type(name) ~= "string" or name:len() == 0 then
		name = 'Unnamed Widget'
	end
	return ("%s%s (%s)"):format(prefix, var_name, name)
end

function DebugWidget:GetWidgetLabel(widget)
	return get_widget_label(widget, "")
end

function DebugWidget:GetFullName(widget, name, count)
	if name then
		name = string.format( "%s > %s", widget._widgetname, name )
		count = count + 1
	else
		name = widget._widgetname
		count = 1
	end

	if count < 5 and widget.parent then
		return self:GetFullName( widget.parent, name, count )
	else
		return name
	end
end

-- Helper class for drawing bounding boxes
DebugWidgetBoundingBox = Class(function(self)
end)

function DebugWidgetBoundingBox:WorldToDebugUI(x, y)
	-- Start a bunch of conversions to get our x & y values in the right coordinate space. Credit to Kaj =)
	-- x, y are in window space

	-- Window space to UI (is the function name misleading?)
	x, y = TheFrontEnd:UIToWindow(x,y)

	-- UI to imgui space. (0,0) at the top-left corner
	local sx, sy = TheSim:GetScreenSize()
	y = sy - y

	-- Take into account the debug UI's scale
	local scale = TheFrontEnd.imgui_font_size
	x = x / scale
	y = y / scale

	return x, y
end

function DebugWidgetBoundingBox:DrawDebugBoundingBox(ui, widget, color, size)
	local x1, y1, x2, y2 = widget:GetWorldBoundingBox()

	x1, y1 = DebugWidgetBoundingBox:WorldToDebugUI(x1, y1)
	x2, y2 = DebugWidgetBoundingBox:WorldToDebugUI(x2, y2)

	if x1 == x2 and y1 == y2 then
		-- If it has zero size, draw a point so we can see something.
		self:DrawDebugOriginPoint(ui, widget, color)
	end

	local lineWidth = (size or 1) * TheFrontEnd.imgui_font_size

	local ox, oy = TheSim:GetWindowInset()
	ui:DrawLine(ui.Layer.Background, ox + x1, oy + y1, ox + x2, oy + y1, color, lineWidth)
	ui:DrawLine(ui.Layer.Background, ox + x2, oy + y1, ox + x2, oy + y2, color, lineWidth)
	ui:DrawLine(ui.Layer.Background, ox + x2, oy + y2, ox + x1, oy + y2, color, lineWidth)
	ui:DrawLine(ui.Layer.Background, ox + x1, oy + y2, ox + x1, oy + y1, color, lineWidth)
end

function DebugWidgetBoundingBox:DrawDebugOriginPoint(ui, widget, color)

	local position = widget:GetWorldPosition()
	local x, y = position.x, position.y
	x, y = DebugWidgetBoundingBox:WorldToDebugUI(x, y)

	local size = 5 * TheFrontEnd.imgui_font_size
	local lineWidth = TheFrontEnd.imgui_font_size

	local ox, oy = TheSim:GetWindowInset()
	ui:DrawLine(ui.Layer.Background, ox + x - size, oy + y, ox + x + size, oy + y, color, lineWidth)
	ui:DrawLine(ui.Layer.Background, ox + x, oy + y - size, ox + x, oy + y + size, color, lineWidth)
end

function DebugWidget:RenderPanel( ui, panel )

	if self.current_error then
		ui:Text(self.current_error)
		return
	end

	-- If zero or one DebugWidget nodes are open, return true
	local numOpenWidgetPanels = TheFrontEnd:GetNumberOpenDebugPanels(DebugNodes.DebugWidget)
	if numOpenWidgetPanels <= 1 or ui:IsWindowFocused() then
		self.can_select = ui:_Checkbox("##shift to select", self.can_select)
		ui:SameLineWithSpace(5)
		ui:TextColored(RGB(255, 255, 0), "Hold SHIFT to select the widget under your cursor" )

		if self.can_select and TheInput:IsKeyDown(InputConstants.Keys.SHIFT) and not ui:WantCaptureMouse() then
			-- Fallback to focus widget to avoid deselection.
			local selectedWidget = TheFrontEnd:GetHitWidget() or TheFrontEnd:GetFocusWidget()
			if TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
				-- If you want buttons or other focusables, hold down ctrl too.
				selectedWidget = TheFrontEnd:GetFocusWidget()
			end

			if selectedWidget and selectedWidget.layoutTestWidget then
				self.selectedLayoutTestWidget = selectedWidget
			else
				self.focus_widget = selectedWidget
			end
		end
	end

	ui:Separator()

	if self.focus_widget and not self.focus_widget.inst:IsValid() then
		-- Don't crash when changing screens.
		self.focus_widget = nil
	end

	if self.focus_widget then
		self.menu_param = self.focus_widget

		self.name = self:GetFullName(self.focus_widget)

		local id = 0
		local hoveredWidget = nil
		if self.focus_widget.parent then
			ui:Text("Parent:")
			ui:SameLine()
			local name = get_widget_label(self.focus_widget.parent)
			if ui:Button(name.."###"..tostring(id)) then
				local parentNode = DebugWidget(self.focus_widget.parent)
				panel:PushNode( parentNode )
			end

			if ui:IsItemHovered() then
				hoveredWidget = self.focus_widget.parent
			end
		end

		local btn_w = 150
		ui:SameLine(ui:GetContentRegionAvail() - btn_w)
		if ui:Button("Save Widget as Image", btn_w) then
			local target_widget = self.focus_widget
			panel.show = false -- close so we're not in screenshot
			SetGameplayPause(false, "DebugWidget screenshot")
			TheGlobalInstance:DoTaskInTicks(5, function()
				-- Sim needs to tick to capture screenshot.
				SetGameplayPause(false, "DebugWidget screenshot")
				TheFrontEnd:Debug_GetChromaKeyOverlay():ScreenshotWidget(
					target_widget,
					function()
						d_viewinpanel(target_widget)
					end)
		end)
			return
		end
		ui:SetTooltipIfHovered({
			"Save as an image for mockups or marketing.",
			"Saves with magenta and black bg to make it easier to cut out.",
		})

		local name = get_widget_label(self.focus_widget, "self.")
		ui:TextColored(RGB(255, 255, 0), "Selected Widget:")
		ui:SameLine()
		ui:Button(name .. "###selected_widget")

		ui:SameLineWithSpace(20)

		local wasChanged, checkedValue = ui:Checkbox("Show Persistent Bounding Box", self.focus_widget:GetShowDebugBoundingBox())
		if wasChanged then
			self.focus_widget:SetShowDebugBoundingBox(checkedValue)
		end
		ui:SetTooltipIfHovered("Display bounding box (in magenta) even when other widgets are selected.")

		local children = self.focus_widget:GetChildren()
		if next(children) then
			if ui:TreeNode("Children") then
				for k, child in pairs(children) do
					id = id + 1
					local child_name = get_widget_label(child, "self.")
					if ui:Button( child_name.."###"..tostring(id) ) then
						local childNode = DebugWidget(child)
						panel:PushNode( childNode )
					end

					if ui:IsItemHovered() then
						hoveredWidget = child
					end
				end

				ui:TreePop()
			end
		else
			ui:TextColored(BGCOLORS.GREY, "<No Children>")
		end

		ui:Separator()

		-- Draw bounding box of the selected widget
		if self.focus_widget then
			local color = WEBCOLORS.CYAN
			DebugWidgetBoundingBox:DrawDebugBoundingBox(ui, self.focus_widget, color)
			DebugWidgetBoundingBox:DrawDebugOriginPoint(ui, self.focus_widget, color)
		end

		-- Draw bounding box on the parent/child widget selection button in this panel that's mouse-hovered
		if hoveredWidget then
			local color = WEBCOLORS.YELLOW
			DebugWidgetBoundingBox:DrawDebugBoundingBox(ui, hoveredWidget, color, 2)
		end

		if ui:CollapsingHeader("Layout Test Widget") then

			if ui:Button("Spawn Layout Test Widget") then
				if self.selectedLayoutTestWidget then
					self.selectedLayoutTestWidget:Remove()
				end
				self.selectedLayoutTestWidget = self.focus_widget:AddChild(LayoutTestWidget(self))
			end

			ui:Separator()

			-- Show layout test widget info
			if self.selectedLayoutTestWidget then
				local ok, result = xpcall( function() self.selectedLayoutTestWidget:DebugDraw_AddSection(ui, panel) end, generic_error )
				if not ok then
					print( result )
					self.current_error = result
				end
			end
		end

		ui:Separator()

		if ui:CollapsingHeader("Widget Info") then
			-- This is from the older DST system and recent changes broke bits
			-- of it, but it's useful to have a type-specific display.
			local ok, result = xpcall( function() self.focus_widget:DebugDraw_AddSection(ui, panel) end, generic_error )
			if not ok then
				print( result )
				self.current_error = result
			end
		end

		self:AddFilteredAll(ui, panel, self.focus_widget)
	else
		self.name = "Debug Widget"
		ui:TextColored( {0.8, 1.0, 0.0, 1.0}, "No widget selected" )
	end

	--loop over all widgets and draw bounding boxes for any that have the flag set
	local function RecursiveDrawBoundingBox(widget)
		for _, child in ipairs(widget:GetChildren()) do
			RecursiveDrawBoundingBox(child)
		end

		if widget:GetShowDebugBoundingBox() then
			local color = WEBCOLORS.MAGENTA
			DebugWidgetBoundingBox:DrawDebugBoundingBox(ui, widget, color)
		end
	end

	for i, v in ipairs(TheFrontEnd.screenstack) do
		RecursiveDrawBoundingBox(v)
	end

end

DebugNodes.DebugWidget = DebugWidget

return DebugWidget
