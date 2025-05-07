local Widget = require "widgets/widget"
local DragButton = require "widgets/dragbutton"
local ImageButton = require "widgets/imagebutton"
local Panel = require "widgets/panel"

local easing = require "util.easing"

local assets =
{
    bar = "images/ui_ftf/scrollbar_back.tex",

    btn_up = "images/global/square.tex",
    btn_down = "images/global/square.tex",
}

local ScrollBar = Class(Widget, function(self)
   
    Widget._ctor(self, "Scrollbar")
    self:SetHoverCheck(true)
    self.percent = .5
    self.percentshowing = .3
    self.flipped = false

    self.handle_width = 14
    self.button_height = 0
    
    self.bar = Panel(assets.bar)
        :SetName("BG")
        :SetNineSliceCoords(0, 10, self.handle_width, 15)
        :SetNineSliceBorderScale(0.5)
        :SetMultColor(UICOLORS.BACKGROUND_DARK)
    self.btn_drag = DragButton(assets.slider)
        :SetName("Handle")
        :SetDragFn(function(p) self:OnScroll(p) end)
        :SetNavFocusable(false)

    self.btn_drag.bg:SetNineSliceCoords(0, 10, self.handle_width, 15)
        :SetNineSliceBorderScale(0.5)
    self.btn_up = ImageButton(assets.btn_up)
        :SetName("Up")
        :SetSize( self.handle_width, self.button_height )
        :SetOnClickFn(function() self:OnUp() end)
        :SetNavFocusable(false)
        :Hide()
    self.btn_down = ImageButton(assets.btn_down)
        :SetName("Down")
        :SetSize( self.handle_width, self.button_height )
        :SetOnClickFn(function() self:OnDown() end)
        :SetNavFocusable(false)
        :Hide()

    self:AddChildren{
        self.bar,
        self.btn_drag, 
        self.btn_up,
        self.btn_down
    }

    self.total_sz = 0
    self.clip_sz = 0
    self:SetLength(300)
end)

function ScrollBar:Enable()
    ScrollBar._base.Enable(self)
    self.btn_up:Enable()
    self.btn_down:Enable()
    self.btn_drag:Enable()
    return self
end

function ScrollBar:Disable()
    ScrollBar._base.Disable(self)
    self.btn_up:Disable()
    self.btn_down:Disable()
    self.btn_drag:Disable()
    return self
end

function ScrollBar:OnUp()
    if self.clip_sz >= self.total_sz then
        return
    end
    local dp = self.stepsize / (self.total_sz - self.clip_sz)
    local percent = math.clamp(self.percent - dp,0,1)
    if percent ~= self.percent then
        self.percent = percent
        if self.fn then
            self.fn(self.percent)
        end
        self:UpdateHandle()
        return true
    end
end

function ScrollBar:OnDown()
    if self.clip_sz >= self.total_sz then
        return
    end
    local dp = self.stepsize / (self.total_sz - self.clip_sz)
    local percent = math.clamp(self.percent + dp,0,1)
    if percent ~= self.percent then
        self.percent = percent
        if self.fn then
            self.fn(self.percent)
        end
        self:UpdateHandle()
        return true
    end
end


function ScrollBar:OnPageUp()
    if self.clip_sz >= self.total_sz then
        return
    end
    local dp = self.clip_sz / (self.total_sz - self.clip_sz)
    local percent = math.clamp(self.percent - dp,0,1)
    if percent ~= self.percent then
        self.percent = percent
        if self.fn then
            self.fn(self.percent)
        end
        self:UpdateHandle()
        return true
    end
end

function ScrollBar:OnPageDown()
    if self.clip_sz >= self.total_sz then
        return
    end
    local dp = self.clip_sz / (self.total_sz - self.clip_sz)
    local percent = math.clamp(self.percent + dp,0,1)
    if percent ~= self.percent then
        self.percent = percent
        if self.fn then
            self.fn(self.percent)
        end
        self:UpdateHandle()
        return true
    end
end

function ScrollBar:OnScroll(p)
    
    self.percent = math.clamp(p,0,1)
    if self.fn then
        self.fn(self.percent)
    end
    --self:UpdateHandle()
end

function ScrollBar:SetCallback(fn)
    self.fn = fn
    return self
end

function ScrollBar:SetStepSize(sz)
    self.stepsize = sz
    return self
end

function ScrollBar:SetPercent(p)
    self.percent = p
    self:UpdateHandle()
    return self
end

function ScrollBar:SetPercentShowing(total_sz, clip_sz)
    self.total_sz = total_sz
    self.clip_sz = clip_sz
    local val = clip_sz / total_sz
    self.percentshowing = math.min(1, val)
    self:UpdateHandle()
    return self

end

function ScrollBar:SetLength(len)
    self.len = len

    self.bar:SetSize(self.handle_width, len)
    self.btn_up:SetPosition(0, self.len/2 - self.button_height/2)
    self.btn_down:SetPosition(0, -self.len/2 + self.button_height/2)
    self:UpdateHandle()
    return self
end


function ScrollBar:UpdateHandle()
    
--    self.handle_sz = math.max(16, math.min(self.percentshowing*(self.len-self.button_height*2), self.len - self.button_height*2 - 16))
    self.handle_sz = math.max(16, math.min(self.percentshowing*(self.len-self.button_height*2), self.len - self.button_height*2 - 16 ))

    -- local nineslice_w, nineslice_h = self.handle_width, self.handle_sz + self.border_size*2*self.border_scale
--    local nineslice_w, nineslice_h = self.handle_width, self.handle_sz
    -- self.handle_sz = nineslice_h
    local min_val = self.len/2 - self.button_height - self.handle_sz/2 
    local max_val = -self.len/2 + self.button_height + self.handle_sz/2	

    self.btn_drag:SetExtents(max_val, min_val)
        :SetPosition(0, easing.linear(self.percent, min_val, max_val - min_val, 1))
        -- :MoveTo( 0, easing.linear(self.percent, min_val, max_val - min_val, 1), 0.2, easing.inOutQuad )
        :SetSize( self.handle_width, self.handle_sz)
end

--[[
function ScrollBar:HandleControlUp(controls)
    if controls:Has( Controls.Digital.MENU_ACCEPT ) then
        return true
    end
end


function ScrollBar:HandleControlDown(controls)

    if controls:Has( Controls.Digital.MENU_ACCEPT ) then
        local x, y = self:TransformFromWorld(TheGame:GetInput():GetMousePos())
        local click_p = y + self.len/2 - self.button_height*2

        if click_p < self.handle_sz/2 then
            self:SetPercent(1)
        elseif click_p > self.len - self.button_height*2 - self.handle_sz/2 then
            self:SetPercent(0)
        else
            local p = 1 - math.clamp((click_p - self.button_height - self.handle_sz/2) / (self.len - self.button_height*2 - self.handle_sz), 0, 1)
            self:SetPercent(p)
        end
        if self.fn then
            self.fn(self.percent)
        end

        return true
    end
end
]]

function ScrollBar:OnControl(controls,down)
	if down then
		if controls:Has(Controls.Digital.MENU_ACCEPT) then
			local mx,my = TheFrontEnd:GetUIMousePos()
			local x, y = self:TransformFromWorld(mx,my)
			local click_p = y + self.len/2 - self.button_height*2

			if click_p < self.handle_sz/2 then
				self:SetPercent(1)
			elseif click_p > self.len - self.button_height*2 - self.handle_sz/2 then
				self:SetPercent(0)
			else
				local p = 1 - math.clamp((click_p - self.button_height - self.handle_sz/2) / (self.len - self.button_height*2 - self.handle_sz), 0, 1)
				self:SetPercent(p)
			end

			if self.fn then
				self.fn(self.percent)
			end

			return true
		end
	else
		if controls:Has(Controls.Digital.MENU_ACCEPT) then
			return true
		end
	end
end

return ScrollBar
