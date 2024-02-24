-- Consider using debug_draggable prefab instead!
--
local Image = require "widgets/image"
local Widget = require "widgets/widget"
require "class"

local DraggableWorldWidget = Class(Widget, function(self, name, mode_2d)
    Widget._ctor(self, name)
    self:SetHoverCheck(true)
    self.world_space = not mode_2d
    self:StartUpdating()
    self.img = self:AddChild( Image("images/global/circle.tex")
        :SetMultColor(1, 1, 1, 0.5)
        :SetSize(32 * HACK_FOR_4K, 32 * HACK_FOR_4K))
end)

function DraggableWorldWidget:OnGainHover()
    self.img:SetSize(40 * HACK_FOR_4K,40 * HACK_FOR_4K)
end

function DraggableWorldWidget:OnLoseHover()
    self.img:SetSize(32 * HACK_FOR_4K,32 * HACK_FOR_4K)
end

function DraggableWorldWidget:HandleControlDown(controls)
    if controls:Has(Controls.Digital.ACCEPT) then
        self.dragging = true
    end
end

function DraggableWorldWidget:OnControl(controls, down)
    if controls:Has(Controls.Digital.ACCEPT) then
        self.dragging = true
    end
end

function DraggableWorldWidget:SetFocusColor( hasFocus )
    if hasFocus then
        self.img:SetMultColor(1, 1, 1, 0.5)
    else
        self.img:SetMultColor(1, 1, 1, 0.25)
    end
end

function DraggableWorldWidget:OnUpdate(dt)
    DraggableWorldWidget._base.OnUpdate(self, dt)
    if self.dragging then
        local x, y = TheInput:GetMousePos()
        local mx,my = TheFrontEnd:WindowToUI(x,y)

        local lx,ly = self.parent:TransformFromWorld(mx,my)

        self:SetPosition(lx, ly)
        if not TheInput:IsControlDown( Controls.Digital.ACCEPT ) then
            self.dragging = false
        end
    end

    if self.world_space then
        local px,py = self:GetPosition()
        local x,y = self.parent:TransformToWorld(px,py)

        local mx,my = TheFrontEnd:UIToWindow(x,y)
        local z
        x,z = TheSim:ScreenToWorldXZ(mx, my)

        self:OnUpdateWorldPosition(dt, x, z)
    end
end

function DraggableWorldWidget:OnUpdateWorldPosition(dt, x, z)
    -- Optional for callers to implement
end

return DraggableWorldWidget
