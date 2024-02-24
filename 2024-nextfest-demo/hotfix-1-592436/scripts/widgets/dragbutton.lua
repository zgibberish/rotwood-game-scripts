local Widget = require "widgets/widget"
local Panel = require "widgets/panel"

local DragButton = Class(Widget, function(self)
    Widget._ctor(self, "DragButton")

    self:SetHoverCheck(true)

    self.w, self.h = 0, 0
    self.min, self.max = 0, 0

    self.bg = self:AddChild(Panel("images/ui_ftf/scrollbar_slider.tex"))
end)

function DragButton:SetDragFn(fn)
    self.dragfn = fn
    return self
end

function DragButton:Enable()
    DragButton._base.Enable(self)
    self:UpdateImage()
    return self
end

function DragButton:Disable()
    DragButton._base.Disable(self)
    self:UpdateImage()
    return self
end

function DragButton:SetColour(c)
    self.bg:SetColour(c)
    return self
end
function DragButton:SetHorizontal()
    self.horizontal = true
    return self
end

function DragButton:SetExtents(min, max)
    self.min, self.max = min, max
    return self
end

function DragButton:SetSize( w, h )
    self.w, self.h = w, h
    self.bg:SetSize(w, h)
    return self
end

function DragButton:UpdateImage()
    if not self.enabled then
        self:SetMultColor(0.1, 0.1, 0.1, 0.7)
    elseif self.down then
        self:SetMultColor(UICOLORS.LIGHT_TEXT_DARKER)
    elseif self.hover and self.enabled then
	    self:SetMultColor(UICOLORS.FOCUS)
    else
	    self:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
    end
end


function DragButton:StartDragging()
    self:SetFocus(true)
    self.down = true
    self.dragging = true
    local x, y = self:TransformFromWorld(TheInput:GetUIMousePos())

    self.drag_offset = y
    self:StartUpdating()
    self:UpdateImage()
    TheFrontEnd:LockFocus()
end

function DragButton:StopDragging()
    self.down = false
    self.dragging = false
    self:UpdateImage()
    self:StopUpdating()
    TheFrontEnd:LockFocus(false)
end

function DragButton:OnControl(controls, down)
	if down then
		if controls:Has(Controls.Digital.MENU_ACCEPT) and self.hover and not self.dragging then
			self:StartDragging()
			return true
		end
	else
		if controls:Has(Controls.Digital.MENU_ACCEPT) and self.dragging then
        		self:StopDragging()
		end
	end
end


function DragButton:OnGainHover()
    DragButton._base.OnGainHover(self)
    self:UpdateImage()
end

function DragButton:OnLoseHover()
    DragButton._base.OnLoseHover(self)
    if not self.dragging then
        self.down = false
        self:UpdateImage()
    end
end

function DragButton:OnLoseFocus()
    DragButton._base.OnLoseFocus(self)
    if not self.dragging then
        self.down = false
        self:UpdateImage()
    end
end

function DragButton:OnUpdate(dt)
    DragButton._base.OnUpdate(self, dt)

    if self.dragging then
        local mx, my = self:TransformFromWorld(TheFrontEnd:GetUIMousePos())
        local x,y = self:GetPos()
        
        if self.horizontal then
            local new_x = math.clamp(x + mx - self.drag_offset, self.min, self.max)
            
            if self.dragfn then
                local p = (new_x - self.min)/(self.max - self.min)  
                p = self.dragfn( p ) or p
                new_x = self.min + (self.max - self.min)*p
            end
            self:SetPos(new_x, y)
        else
            local new_y = math.clamp(y + my - self.drag_offset, self.min, self.max)
            
            
            if self.dragfn then
                local p = 1 - (new_y - self.min)/(self.max - self.min)  
                --self.dragfn( p )
                p = self.dragfn( p ) or p
                new_y = self.min + (self.max - self.min)*(1-p)
            end
            self:SetPos(x, new_y)
        end
    else
        self:StopUpdating()
    end

end

return DragButton
