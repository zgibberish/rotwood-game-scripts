local Enum = require "util.enum"
local Padding = require "widgets.padding"
local ScrollBar = require "widgets.scrollbar"
local Widget = require "widgets.widget"


local scrollw = 16


local SCROLLBAR = Enum{
	"ALWAYS",
	"NEVER",
	"IF_NEEDED",
}

local ScrollPanel = Class(Widget, function(self)
	Widget._ctor(self, "ScrollPanel")
	self:SetHoverCheck(true)
	self.scroll_view = Widget()
	self.test = Widget()

	self.scroll_view = Widget()
	self.scroll_pos = self.scroll_view:AddChild ( Widget() )
	self.scroll_root = self.scroll_pos:AddChild( Widget() )
	self.scroll_root:SetName("SCROLL ROOT")
	self.scroll_offset = 0
	self.scrollbar_margin = 10
	self.scrollbar_y_offset = 0
	self.scrollbar_outer_margin = 0
	self.scrollbar_inset = 20
	self.was_click_down = false

	self.current_group = nil -- Queue of widgets added on Submit().

	self.scroll_bar = ScrollBar()
		:SetPercent(0)
		:SetStepSize(60)
		:SetCallback(
			function(p)
				self:SetScrollPercent(p,false)
			end)
	self:AddChildren { self.scroll_view, self.scroll_bar }

	self:SetSize( 400 * HACK_FOR_4K, 200 )

	self.show_bar = SCROLLBAR.s.ALWAYS
	self.can_page_updown = true
end)

ScrollPanel.SCROLLBAR = SCROLLBAR

function ScrollPanel:DebugDraw_AddSection(ui, panel)
	ScrollPanel._base.DebugDraw_AddSection(self, ui, panel)

	ui:Spacing()
	ui:Text("ScrollPanel")
	ui:Indent() do
		if ui:Button("RefreshView") then
			self:RefreshView()
		end
		ui:SetTooltipIfHovered("Force recalculate scrollpanel setup if you manually moved some widgets around with debug.")
	end
	ui:Unindent()
end

function ScrollPanel:OnAdded()
	self:StartUpdating()
end

function ScrollPanel:OnRemoved()
end

function ScrollPanel:SetCanPageUpDown(can_pgupdn)
	self.can_page_updown = can_pgupdn
	return self
end

function ScrollPanel:SetScrollPercent(p,animate, speed_override)
	local bottom_y, top_y, total_h = self:GetVirtualBounds()
	local offset = p * (total_h - self.h)
	self:SetScrollOffset( offset, animate, speed_override )
end

function ScrollPanel:GetScrollPercent()
	local bottom_y, top_y, total_h = self:GetVirtualBounds()
	return self.scroll_offset/(total_h - self.h)
end

function ScrollPanel:SetScrollSpeed( scroll_speed, max_scroll_speed )
	self.scroll_speed, self.max_scroll_speed = scroll_speed, max_scroll_speed
	return self
end

function ScrollPanel:SetStepSize(sz)
	self.scroll_bar:SetStepSize(sz)
	return self
end

function ScrollPanel:SetFn(fn)
	self.fn = fn
	return self
end

function ScrollPanel:Clear()
	self.scroll_root:DestroyAllChildren()
	self.scroll_offset = 0
	self.current_group = nil
	self:RefreshView()
end

function ScrollPanel:IsEmpty()
	return self.scroll_root:IsEmpty()
end

function ScrollPanel:AddScrollChild( widget, idx )
	self.scroll_root:AddChild( widget, idx )

	self:RefreshView()
	return widget
end

function ScrollPanel:AddScrollChildren( ... )
	self.scroll_root:AddChildren( ... )
	self:RefreshView()
	return self
end

function ScrollPanel:GetDefaultFocus()
	return self.scroll_root and self.scroll_root.children and #self.scroll_root.children > 0 and self.scroll_root.children[1]
end

function ScrollPanel:AppendWidget( widget, layoutw, layouth, prev )
	if self.current_group == nil then
		self.current_group = Widget()
	end
	self.current_group:AddChild( widget )
	widget:LayoutBounds( layoutw or "after", layouth or "top", prev )
	return widget
end

function ScrollPanel:AppendNewLine( h )
	self:Submit()
	self:AppendWidget( Padding( 0, h or 24 ))
	self:Submit()
end

function ScrollPanel:Submit()
	if self.current_group then
		self:AddScrollChild( self.current_group )
		self.current_group:LayoutBounds( "left", "below" )
		self.current_group = nil
	end
end

function ScrollPanel:GetContentWidth()
	local w = self.current_group and self.current_group:GetSize() or 0
	return self.w - w
end


function ScrollPanel:IsChildVisible( child )

	local _, y1, _, y2 = child:GetBoundingBox()
	local _, y1 = self.scroll_root:TransformFromWidget(child, 0, y1)
	local _, y2 = self.scroll_root:TransformFromWidget(child, 0, y2)
	local bottom_y, top_y, total_h = self:GetVirtualBounds()

	local widget_min = math.min(y1, y2)
	local widget_max = math.max(y1, y2)

	local vp_min = -self.scroll_offset - self.h + top_y
	local vp_max = -self.scroll_offset + top_y

	if widget_min < vp_min then
		-- This widget is below our viewport. Scroll down
		return false
	elseif widget_max > vp_max then
		-- This widget is above our viewport. Scroll up
		return false
	end

	return true
end

function ScrollPanel:EnsureVisible( child, snap )

	local _, y1, _, y2 = child:GetBoundingBox()
	local _, y1 = self.scroll_root:TransformFromWidget(child, 0, y1)
	local _, y2 = self.scroll_root:TransformFromWidget(child, 0, y2)
	local bottom_y, top_y, total_h = self:GetVirtualBounds()

	local widget_min = math.min(y1, y2)
	local widget_max = math.max(y1, y2)

	local vp_min = -self.scroll_offset - self.h + top_y
	local vp_max = -self.scroll_offset + top_y

	if widget_min < vp_min then
		-- This widget is below our viewport. Scroll down
		self:SetScrollOffset( -widget_min - self.h + top_y + (self.virtual_top_margin or 0), not snap )
	elseif widget_max > vp_max then
		-- This widget is above our viewport. Scroll up
		self:SetScrollOffset( -widget_max + top_y - (self.virtual_bottom_margin or 0), not snap )
	end
end

-- Vertical distance between the scroll bar and the top and bottom of the scissor area
function ScrollPanel:SetBarInset( inset )
	self.scrollbar_inset = inset
	return self
end

function ScrollPanel:Scroll( delta )
	self:SetScrollOffset( self.scroll_offset + delta )
	return self
end



function ScrollPanel:SetScrollOffset( offset, animate, speed_override )
	local bottom_y, top_y, total_h = self:GetVirtualBounds()
	local max_scroll = math.max( 0, total_h - self.h )

	offset = math.max( math.min( max_scroll, offset or self.scroll_offset ), 0 )
	self.scroll_offset = offset

	local y = -top_y + offset
	self.dest_scroll_pos = y

	if not animate then
		self.dest_scroll_pos = y
		self.scroll_pos:SetPos( 0, y )
	end

	local p = 0
	if total_h - self.h > 0 then
		p = offset / (total_h - self.h)
	end
	self.scroll_bar:SetPercent( p )

	if self.fn then
		self.fn( offset )
	end
	return self
end

function ScrollPanel:ShowBar( viz )
	assert(SCROLLBAR:Contains(viz))
	self.show_bar = viz
	self:RefreshView()
	return self
end

function ScrollPanel:RefreshView()
	local bottom_y, top_y, total_h = self:GetVirtualBounds()

	-- The inner size is the size of our content area (minus scrollbar and outer margins)
	local inner_w = self:GetInnerWidth()
	local inner_h = self.h - self.scrollbar_outer_margin*2

	-- Place the scroll bar's position according to our width and margins.
	-- NOTE: We must do this whether the scroll bar is visible or not as we use it
	-- to step up/down (see HandleControlDown)
	local bar_x
	if self.left_scroll then
		bar_x = -self.w/2+scrollw/2 + self.scrollbar_outer_margin
	else
		bar_x = self.w/2-scrollw/2 - self.scrollbar_outer_margin
	end
	self.scroll_bar:SetPos( bar_x, self.scrollbar_y_offset )
	self.scroll_bar:SetLength( inner_h - self.scrollbar_inset*2 )
	self.scroll_bar:SetPercentShowing( math.max( self.h, total_h ), self.h )

	-- Scrollbar visibility.
	if self.show_bar == SCROLLBAR.s.NEVER then
		self.scroll_bar:Hide()
	elseif total_h <= self.h then
		self.scroll_bar:Disable():SetShown( self.show_bar == SCROLLBAR.s.ALWAYS  )
	else
		self.scroll_bar:Enable():Show()
	end


	-- Position our view so that its origin sits at the top-left of our content region.
	if self.scroll_bar:IsShown() and self.left_scroll then
		-- self.scroll_view:SetPos( -self.w/2 + self.scrollbar_outer_margin + scrollw + self.scrollbar_margin, inner_h/2)
		self.scroll_view:SetPos( self.scrollbar_outer_margin + scrollw + self.scrollbar_margin, inner_h/2)
	else
		self.scroll_view:SetPos( 0, inner_h/2)
	end

	-- Scissor our view.
	local scissorx = self.left_scroll and self.scrollbar_margin+scrollw or 0
	self.scroll_view:SetScissor( -self.w/2, -inner_h, inner_w, inner_h )

	self:SetScrollOffset( self.scroll_offset )

	return self
end

function ScrollPanel:IsScrollBarShown()
	return self.scroll_bar:IsShown()
end

function ScrollPanel:LeftScrollBar( left_bar )
	if left_bar == nil then
		left_bar = true
	end
	if left_bar ~= self.left_scroll then
		self.left_scroll = left_bar
		self:RefreshView()
	end

	return self
end

function ScrollPanel:GetScrollBarWidth()
	return scrollw
end

function ScrollPanel:GetInnerWidth()
	if self.show_bar == SCROLLBAR.s.NEVER then
		return self.w - self.scrollbar_outer_margin
	else
		return self.w - scrollw - self.scrollbar_margin - self.scrollbar_outer_margin
	end
end

-- Extra spacing on the bottom and top
function ScrollPanel:SetVirtualMargin( margin )
	self.virtual_top_margin = margin
	self.virtual_bottom_margin = margin
	self:RefreshView()
	return self
end

-- Extra spacing on the top
function ScrollPanel:SetVirtualTopMargin( margin )
	self.virtual_top_margin = margin
	self:RefreshView()
	return self
end

-- Extra spacing on the bottom
function ScrollPanel:SetVirtualBottomMargin( margin )
	self.virtual_bottom_margin = margin
	self:RefreshView()
	return self
end

-- The margin between the bar and the inner content of the scroll-panel
-- If it's a left-aligned bar, it's on the right
-- If it's a right-aligned bar, it's on the left
function ScrollPanel:SetScrollBarMargin( margin )
	self.scrollbar_margin = margin
	self:RefreshView()
	return self
end

-- The margin between the bar and the outer bounds of the scroll-panel
-- If it's a left-aligned bar, it's left, top and bottom
-- If it's a right-aligned bar, it's right, top and bottom
function ScrollPanel:SetScrollBarOuterMargin( margin )
	self.scrollbar_outer_margin = margin
	self:RefreshView()
	return self
end

-- The vertical offset of the scroll bar
-- If you don't want the scrollbar centered vertically within the panel
function ScrollPanel:SetScrollBarVerticalOffset( offset )
	self.scrollbar_y_offset = offset
	self:RefreshView()
	return self
end

function ScrollPanel:GetVirtualBounds()

	local x1, y1, x2, y2 = self.scroll_root:GetBoundingBox()

	local bottom_y = math.min(y1, y2) - (self.virtual_bottom_margin or 0)
	local top_y = math.max(y1, y2) + (self.virtual_top_margin or 0)
	local h = math.abs(top_y - bottom_y)

	return bottom_y, top_y, math.abs(top_y - bottom_y)
end

function ScrollPanel:SetSize(w, h)
	if self.w ~= w or self.h ~= h then
		self.w = w or self.w
		self.h = h or self.h
		self:InvalidateBBox()
		self:RefreshView()
	end
	return self
end

function ScrollPanel:GetBoundingBox()
	return -self.w/2, -self.h/2, self.w/2, self.h/2
end

-- TODO(dbriscoe): This doesn't seem to work well. The FtF system doesn't use
-- GetDefaultFocus so there's not focus forwarding happening here. Remove this
-- so the default widget navigation system can take over.
--
-- I think this is trying to allow navigating up and down within the scroll
-- panel, but the default widget OnFocusMove already does that.
--~ function ScrollPanel:OnFocusMove( dir )
--~ 	if dir == "down" or dir == "up" then
--~ 		local focus = self:GetFE():GetFocusWidget()
--~ 		if focus and self:IsAncestorOf( focus ) then
--~ 			local next_focus = focus:GetFocusDir( dir )
--~ 			if next_focus then
--~ 				next_focus:SetFocus()
--~ 				return true
--~ 			end
--~ 		end
--~ 	end
--~ end

function ScrollPanel:CheckMouseHover(x,y)
	-- return false end
	if self.ignore_input then return end
	if not self.shown then return end

	local blocked, hover = self.scroll_bar:CheckMouseHover( x, y )
	if blocked then
		return blocked, hover
	end

	if self.hover_check or self.blocks_mouse then
		local lx, ly = self:TransformFromWorld(x,y)
		if lx >= -self.w/2 and lx <= self.w/2 and ly >= -self.h/2 and ly <= self.h/2 then
			local h = self.h * 0.5
			if TheFrontEnd:GetDragWidget() and math.abs(ly) > h * 0.85 then
				if ly < 0 then
					self.scroll_bar:OnDown()
				else
					self.scroll_bar:OnUp()
				end
			end

			blocked, hover = self.scroll_root:CheckMouseHover( x, y )
			if blocked and hover then
				return blocked, hover
			end

			return true, self
		end
	end
end

function ScrollPanel:HandlePreControlDown( controls, device, trace, device_id )
	if controls:Has(Controls.Digital.MENU_SCROLL_FWD) then
		self:ScrollDown()
		-- return true
	elseif controls:Has(Controls.Digital.MENU_SCROLL_BACK) then
		self:ScrollUp()
		-- return true
	end
	if self.can_page_updown then
		if controls:Has(Controls.Digital.MENU_PAGE_DOWN) then
			return self.scroll_bar:OnPageDown()
		elseif controls:Has(Controls.Digital.MENU_PAGE_UP) then
			return self.scroll_bar:OnPageUp()
		end
	end
end

function ScrollPanel:ScrollUp()
	self.scroll_bar:OnUp()
	return self
end

function ScrollPanel:ScrollDown()
	self.scroll_bar:OnDown()
	return self
end

function ScrollPanel:IsDragging()
	return self.panel_dragging or false
end

function ScrollPanel:OnUpdate( dt )
	ScrollPanel._base.OnUpdate( self, dt )

	if TheInput:IsControlDown(Controls.Digital.MENU_ACCEPT)
		and not TheInput:IsMousePosReset() then
		local current_x, current_y = TheInput:GetUIMousePos() -- Get current mouse position
		local click_within_bounds = self:CheckHit( current_x, current_y ) -- Check if the mouse is within the bubbles bounding box

		if not self.was_click_down and click_within_bounds then
			-- We just clicked down! Let's start drag-checking
			self.panel_dragging_last_x, self.panel_dragging_last_y = nil, nil
			self.panel_drag_momentum = 0
			self.panel_drag_checking = true
			self.panel_dragging = false
		end

		if self.panel_dragging or self.panel_drag_checking then
			-- We're dragging
			local width, height = TheFrontEnd:GetScreenDims()
			local dist_y = current_y - (self.panel_dragging_last_y or current_y) -- Check how much it has moved since last time
			dist_y = dist_y * RES_Y / height -- Convert the distance dragged to screen coordinates
			-- Let's see if we dragged enough to start scrolling
			if self.panel_drag_checking then
				if math.abs( dist_y ) > RES_Y*0.01 then
					self.panel_drag_checking = false
					self.panel_dragging = true
					self.panel_drag_momentum = 0
					dist_y = 0 -- Reset the distance, so we don't jump after the threshold is met
				end
			end

			-- We're dragging the list with a click or touch input
			if self.panel_dragging then
				self:SetScrollOffset( self.scroll_offset + dist_y ) -- Actually scroll the list
				self.panel_drag_momentum = dist_y -- Save the momentum for when the click is released
			end

			self.panel_dragging_last_x, self.panel_dragging_last_y = current_x, current_y -- Save the new position for next time
		else
			self.panel_drag_checking = false
			self.panel_dragging = false
		end
	else
		-- Mouse up. No more dragging over here
		self.panel_drag_checking = false
		self.panel_dragging = false

		-- If there's leftover momentum after the click is released, continue scrolling
		if self.panel_drag_momentum and math.abs(self.panel_drag_momentum) < 0.1 then
			self.panel_drag_momentum = 0
		elseif self.panel_drag_momentum then
			self.panel_drag_momentum = self.panel_drag_momentum - self.panel_drag_momentum*dt*4
			self:SetScrollOffset( self.scroll_offset + self.panel_drag_momentum )
		end
	end
	self.was_click_down = TheInput:IsControlDown(Controls.Digital.MENU_ACCEPT) and self:CheckHit( TheInput:GetMousePos() )

	self:HandleGamepadSticks()

	local _, cy = self.scroll_pos:GetPos()
	if self.dest_scroll_pos then
		local dy = self.dest_scroll_pos - cy
		if math.abs(dy) <= 1 then
			self.scroll_pos:SetPos(0, self.dest_scroll_pos)
			self.dest_scroll_pos = nil
		else
			local max_scroll_speed = self.max_scroll_speed or 600*dt
			local scroll_speed = self.scroll_speed or 7.0
			local delta = math.min( math.min(1, scroll_speed*dt )*dy, max_scroll_speed)
			self.scroll_pos:SetPos(0, cy + delta)
		end
	end

	-- Check if there is a focused widget in the scroll panel, and scroll to it if needed
	-- Only if the focus was gained without the mouse (not hover)
	local current_focused_widget = TheFrontEnd:GetFocusWidget()
	if current_focused_widget and not current_focused_widget.hover and self:IsAncestorOf( current_focused_widget ) then
		self:EnsureVisible( current_focused_widget, true )
	end
end

function ScrollPanel:HandleGamepadSticks()
	if TheFrontEnd:IsRelativeNavigation() and self.enabled and not self.ignore_stick_scroll then

		-- TODO(dbriscoe): How are widgets supposed to know which device to use? Can we handle this with OnControl?
		local device_id_hack = 1
		local ry = TheInput:GetAnalogAxisValue(Controls.Analog.MENU_SCROLL_FWD, Controls.Analog.MENU_SCROLL_BACK, "gamepad", device_id_hack)
		local SPD = 50
		if math.abs(ry) > 0.1 then
			self:Scroll(SPD*ry)
		end
	end
	return self
end

function ScrollPanel:OnVizChange(viz)
	if viz then
		self:StartUpdating()
	else
		self:StopUpdating()
	end
end

function ScrollPanel:SetIgnoreStickScroll()
	self.ignore_stick_scroll = true
	return self
end

return ScrollPanel
