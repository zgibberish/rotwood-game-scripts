--------------------------------------------------------------------------
--[[ Dependencies ]]
--------------------------------------------------------------------------

local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local UIAnim = require "widgets/uianim"
local easing = require "util.easing"

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------

local NUM_SEGS = 16
local DAY_COLOR = Vector3(254 / 255, 212 / 255, 86 / 255)
local DUSK_COLOR = Vector3(165 / 255, 91 / 255, 82 / 255)
local CAVE_DAY_COLOR = Vector3(174 / 255, 195 / 255, 108 / 255)
local CAVE_DUSK_COLOR = Vector3(113 / 255, 127 / 255, 108 / 255)
local DARKEN_PERCENT = .75

--------------------------------------------------------------------------
--[[ Constructor ]]
--------------------------------------------------------------------------

local UIClock = Class(Widget, function(self)
    Widget._ctor(self, "Clock")

    --Member variables
    self._cave = TheWorld ~= nil and TheWorld:HasTag("cave")
    self._caveopen = nil
    self._lastsinkhole = nil --cache last known sinkhole for optimization
    self._moonanim = nil
    self._anim = nil
    self._face = nil
    self._segs = {}
    self._daysegs = nil
    self._rim = nil
    self._hands = nil
    self._text = nil
    self._showingcycles = nil
    self._cycles = nil
    self._phase = nil
    self._moonphase = nil
    self._mooniswaxing = nil
    self._time = nil

    local basescale = 1
    self:SetScale(basescale, basescale, basescale)
    self:SetPosition(0, 0, 0)

    if not self._cave then
        self._moonanim = self:AddChild(UIAnim())
        self._moonanim:GetAnimState():SetBank("moon_phases_clock")
        self._moonanim:GetAnimState():SetBuild("moon_phases_clock")
        self._moonanim:GetAnimState():PlayAnimation("hidden")

        self._anim = self:AddChild(UIAnim())
        self._anim:GetAnimState():SetBank("clock01")
        self._anim:GetAnimState():SetBuild("clock_transitions")
        self._anim:GetAnimState():PlayAnimation("idle_day", true)
    end

    self._face = self:AddChild(Image("images/hud.xml", "clock_NIGHT.tex"))
    self._face:SetClickable(false)

    local segscale = .4
    for i = 1, NUM_SEGS do
        local seg = self:AddChild(Image("images/hud.xml", "clock_wedge.tex"))
        seg:SetScale(segscale, segscale, segscale)
        seg:SetHRegPoint(ANCHOR_LEFT)
        seg:SetVRegPoint(ANCHOR_BOTTOM)
        seg:SetRotation((i - 1) * (360 / NUM_SEGS))
        seg:SetClickable(false)
        table.insert(self._segs, seg)
    end

    if self._cave then
        self._rim = self:AddChild(UIAnim())
        self._rim:GetAnimState():SetBank("clock01")
        self._rim:GetAnimState():SetBuild("cave_clock")
        self._rim:GetAnimState():PlayAnimation("on")

        self._hands = self:AddChild(Widget("clockhands"))
        self._hands._img = self._hands:AddChild(Image("images/hud.xml", "clock_hand.tex"))
        self._hands._img:SetClickable(false)
        self._hands._animtime = nil
    else
        self._rim = self:AddChild(Image("images/hud.xml", "clock_rim.tex"))
        self._rim:SetClickable(false)

        self._hands = self:AddChild(Image("images/hud.xml", "clock_hand.tex"))
        self._hands:SetClickable(false)
    end

    self._text = self:AddChild(Text(FONTFACE.BODYTEXT, 33 / basescale))
    self._text:SetPosition(5, 0 / basescale, 0)

    --Default initialization
    self:UpdateWorldString()
    self:OnClockSegsChanged({ day = NUM_SEGS })

    --Register events
    self.inst:ListenForEvent("clocksegschanged", function(inst, data) self:OnClockSegsChanged(data) end, TheWorld)
    self.inst:ListenForEvent("cycleschanged", function(inst, data) self:OnCyclesChanged(data) end, TheWorld)
    if not self._cave then
        self.inst:ListenForEvent("phasechanged", function(inst, data) self:OnPhaseChanged(data) end, TheWorld)
        self.inst:ListenForEvent("moonphasechanged2", function(inst, data) self:OnMoonPhaseChanged2(data) end, TheWorld)
    end
    self.inst:ListenForEvent("clocktick", function(inst, data) self:OnClockTick(data) end, TheWorld)
end)

--------------------------------------------------------------------------
--[[ Member functions ]]
--------------------------------------------------------------------------

function UIClock:UpdateDayString()
    if self._cycles ~= nil then
        local cycles_lived = 0
        self._text:SetText(STRINGS.UI.HUD.CLOCKSURVIVED.."\n"..tostring(cycles_lived).." "..(cycles_lived == 1 and STRINGS.UI.HUD.CLOCKDAY or STRINGS.UI.HUD.CLOCKDAYS))
    end
    self._showingcycles = false
end

function UIClock:UpdateWorldString()
    if self._cycles ~= nil then
        local day_text = subfmt(STRINGS.UI.HUD.WORLD_CLOCKDAY_V2,{day_count = self._cycles + 1})
        self._text:SetText(day_text)
    end
    self._showingcycles = true
end

function UIClock:ShowMoon()
    local moon_syms =
    {
        full = "moon_full",
        quarter = self._mooniswaxing and "moon_quarter_wax" or "moon_quarter",
        new = "moon_new",
        threequarter = self._mooniswaxing and "moon_three_quarter_wax" or "moon_three_quarter",
        half = self._mooniswaxing and "moon_half_wax" or "moon_half",
    }

    self._moonanim:GetAnimState():OverrideSymbol("swap_moon", "moon_phases", moon_syms[self._moonphase] or "moon_full")
    if self._phase ~= nil then
        self._moonanim:GetAnimState():PlayAnimation("trans_out")
        self._moonanim:GetAnimState():PushAnimation("idle", true)
    else
        self._moonanim:GetAnimState():PlayAnimation("idle", true)
    end
end

function UIClock:IsCaveClock()
    return self._cave
end

local function CalculateLightRange(light, iscaveclockopen)
    return light:GetCalculatedRadius() * math.sqrt(1 - light:GetFalloff()) + (iscaveclockopen and 1 or -1)
end

local CAVE_LIGHT_MUST_TAGS = { "sinkhole", "lightsource" }
function UIClock:UpdateCaveClock(owner)
    if self._lastsinkhole ~= nil and
        self._lastsinkhole:IsValid() and
        self._lastsinkhole.Light:IsEnabled() and
        self._lastsinkhole:IsNear(owner, CalculateLightRange(self._lastsinkhole.Light, self._caveopen)) then
        -- Still near last found sinkhole, can skip FineEntity =)
        self:OpenCaveClock()
        return
    end

    self._lastsinkhole = FindEntity(owner, 20, function(guy) return guy:IsNear(owner, CalculateLightRange(guy.Light, self._caveopen)) end, CAVE_LIGHT_MUST_TAGS)

    if self._lastsinkhole ~= nil then
        self:OpenCaveClock()
    else
        self:CloseCaveClock()
    end
end

function UIClock:OpenCaveClock()
    if not self._cave or self._caveopen == true then
        return
    elseif self._caveopen == nil then
        self._rim:GetAnimState():PlayAnimation("on")
        self._hands._img:SetScale(1, 1, 1)
        self._hands._img:Show()
    else
        self._rim:GetAnimState():PlayAnimation("open")
        self._rim:GetAnimState():PushAnimation("on", false)
        self._hands._animtime = 0
        self:StartUpdating()
    end
    self._caveopen = true
end

function UIClock:CloseCaveClock()
    if not self._cave or self._caveopen == false then
        return
    elseif self._caveopen == nil then
        self._rim:GetAnimState():PlayAnimation("off")
        self._hands._img:Hide()
    else
        self._rim:GetAnimState():PlayAnimation("close")
        self._rim:GetAnimState():PushAnimation("off", false)
        self._hands._animtime = 0
        self:StartUpdating()
    end
    self._caveopen = false
end

--------------------------------------------------------------------------
--[[ Event handlers ]]
--------------------------------------------------------------------------

function UIClock:OnGainFocus()
    UIClock._base.OnGainFocus(self)
    self:UpdateDayString()
    return true
end

function UIClock:OnLoseFocus()
    UIClock._base.OnLoseFocus(self)
    self:UpdateWorldString()
    return true
end

function UIClock:OnClockSegsChanged(data)
    local day = data.day or 0
    local dusk = data.dusk or 0
    local night = data.night or 0
    assert(day + dusk + night == NUM_SEGS, "invalid number of time segs")

    local dark = true
    for k, seg in pairs(self._segs) do
        if k > day + dusk then
            seg:Hide()
        else
            seg:Show()

            local color
            if k <= day then
                color = self._cave and CAVE_DAY_COLOR or DAY_COLOR 
            else
                color = self._cave and CAVE_DUSK_COLOR or DUSK_COLOR
            end

            if dark then
                color = color * DARKEN_PERCENT
            end
            dark = not dark

            seg:SetMultColor(color.x, color.y, color.z, 1)
        end
    end
    self._daysegs = day
end

function UIClock:OnCyclesChanged(cycles)
    self._cycles = cycles
    if self._showingcycles then
        self:UpdateWorldString()
    else
        self:UpdateDayString()
    end
end

function UIClock:OnPhaseChanged(phase)
    if self._phase == phase then
        return
    end

    if self._phase == "night" then
        self._moonanim:GetAnimState():PlayAnimation("trans_in")
    end

    if phase == "day" then
        if self._phase ~= nil then
            self._anim:GetAnimState():PlayAnimation("trans_night_day")
            self._anim:GetAnimState():PushAnimation("idle_day", true)
        else
            self._anim:GetAnimState():PlayAnimation("idle_day", true)
        end
    elseif phase == "dusk" then
        if self._phase ~= nil then
            self._anim:GetAnimState():PlayAnimation("trans_day_dusk")
            self._anim:GetAnimState():PushAnimation("idle_dusk", true)
        else
            self._anim:GetAnimState():PlayAnimation("idle_dusk", true)
        end
    elseif phase == "night" then
        if self._phase ~= nil then
            self._anim:GetAnimState():PlayAnimation("trans_dusk_night")
            self._anim:GetAnimState():PushAnimation("idle_night", true)
        else
            self._anim:GetAnimState():PlayAnimation("idle_night", true)
        end
        self:ShowMoon()
    end

    self._phase = phase
end

function UIClock:OnMoonPhaseChanged2(data)
    if self._moonphase == data.moonphase and self._mooniswaxing == data.waxing then
        return
    end

    self._moonphase = data.moonphase
    self._mooniswaxing = data.waxing

    if self._phase == "night" then
        self:ShowMoon()
    end
end

function UIClock:OnClockTick(data)
    if not self._cave and self._time ~= nil then
        local prevseg = math.floor(self._time * NUM_SEGS)
        if prevseg < self._daysegs then
            local nextseg = math.floor(data.time * NUM_SEGS)
            if prevseg ~= nextseg and nextseg < self._daysegs then
                self._anim:GetAnimState():PlayAnimation("pulse_day")
                self._anim:GetAnimState():PushAnimation("idle_day", true)
            end
        end
    end

    self._time = data.time
    self._hands:SetRotation(self._time * 360)

    if self._showingcycles then
        self:UpdateWorldString()
    else
        self:UpdateDayString()
    end
end

--------------------------------------------------------------------------
--[[ Update ]]
--------------------------------------------------------------------------

function UIClock:OnUpdate(dt)
    local k = self._hands._animtime + dt * TheSim:GetTimeScale()
    self._hands._animtime = k

    if self._caveopen then
        local wait_time = 10 * TICKS
        local grow_time = 5 * TICKS
        local shrink_time = 3 * TICKS
        if k >= wait_time then
            k = k - wait_time
            if k < grow_time then
                local scale = easing.outQuad(k, 0, 1, grow_time)
                self._hands._img:SetScale(scale, scale * 1.15, 1)
            else
                k = k - grow_time
                if k < shrink_time then
                    self._hands._img:SetScale(1, easing.inOutQuad(k, 1.1, -.1, shrink_time), 1)
                else
                    self._hands._img:SetScale(1, 1, 1)
                    self._hands._animtime = nil
                    self:StopUpdating()
                end
            end
            self._hands._img:Show()
        end
    else
        local wait_time = 3 * TICKS
        local shrink_time = 6 * TICKS
        if k >= wait_time then
            k = k - wait_time
            if k < shrink_time then
                local scale = easing.inQuad(k, 1, -1, shrink_time)
                self._hands._img:SetScale(scale, scale, 1)
            else
                self._hands._img:Hide()
                self._hands._animtime = nil
                self:StopUpdating()
            end
        end
    end
end

--------------------------------------------------------------------------
--[[ End ]]
--------------------------------------------------------------------------

return UIClock
