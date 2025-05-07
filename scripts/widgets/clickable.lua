local Widget = require "widgets/widget"
local fmodtable = require "defs.sound.fmodtable"

-- A class that provides input functionality to any widget

local Clickable = Class(Widget, function(self, name)
	Widget._ctor(self, name or "Clickable")

	self:SetHoverCheck(true)
	self:SetNavFocusable()

	self.selected = false

	self.control = Controls.Digital.ACCEPT
	self.alt_control = Controls.Digital.CLICK_SECONDARY
	self.help_message = STRINGS.UI.HELP.SELECT

    self:SetScales(1,1,1)

    self.animate_scale = nil
    self.animate_scales = true

	self.gainfocus_sound = fmodtable.Event.hover
end)

function Clickable:SetGainFocusSound(sound)
	self.gainfocus_sound = sound
	return self
end

function Clickable:SetOnHighlight( fn )
    self.hilite_fn = fn
    return self
end

function Clickable:SetControl(ctrl)
	self.control = ctrl
	return self
end

function Clickable:SetHighlightWidget(w)
	self.highlight_widget = w
	return self
end

function Clickable:UpdateHighlight()
    if self.removed then
        return
    end
    if self.animate_scales then
        if self.down then
            if self.animate_scale_out_timing then self:ScaleTo(nil,self.scale_down,self.animate_scale_out_timing) else self:SetScale(self.scale_down) end
            self:SetBGMult(0.9)
        elseif self.hover or self.selected or self.focus then
            if self.animate_scale_in_timing then self:ScaleTo(nil,self.scale_hover,self.animate_scale_in_timing) else self:SetScale(self.scale_hover) end
            self:SetBGMult(1.8)
        else
            if self.animate_scale_out_timing then self:ScaleTo(nil,self.scale_normal,self.animate_scale_out_timing) else self:SetScale(self.scale_normal) end
            self:SetBGMult(1)
        end
    end
    if self.hilite_fn then
        self.hilite_fn( self.down, self.hover, self.selected, self.focus )
    end
end

function Clickable:SetBGMult( m )
    if self.highlight_widget then
		self.highlight_widget:SetMultColorAlpha(m)
    end
    return self
end

function Clickable:OnControl(controls, down, device_type, trace, device_id)
	if Clickable._base.OnControl(self, controls, down, device_type, trace, device_id) then return true end

	if not self:IsEnabled() or not self.focus then return false end

	if controls:Has(self.control) then

		if down then
			if not self.down then
				if self.controldown_sound then
					TheFrontEnd:GetSound():PlaySound(self.controldown_sound)
				end
				self.down = true
				if self.whiledown then
					self:StartUpdating()
				end
				if self.ondown then
					self.ondown()
				end
			end
		else
			if self.down then

				if self.controlup_sound then
					TheFrontEnd:GetSound():PlaySound(self.controlup_sound)
				end

				self.down = false
				if self.onup then
					self.onup()
				end
				self:Click(device_type, device_id)
				self:StopUpdating()
			end
		end

		return true
	end

	if controls:Has(self.alt_control) then

		if down then
			if not self.down then
				if self.aldcontroldown_sound then
					TheFrontEnd:GetSound():PlaySound(self.aldcontroldown_sound)
				end
				self.down = true
				if self.whiledown then
					self:StartUpdating()
				end
				if self.ondownalt then
					self.ondownalt()
				end
			end
		else
			if self.down then

				if self.altcontrolup_sound then
					TheFrontEnd:GetSound():PlaySound(self.altcontrolup_sound)
				end

				self.down = false
				if self.onupalt then
					self.onupalt()
				end
				self:AltClick(device_type, device_id)
				self:StopUpdating()
			end
		end

		return true
	end

end

-- Will only run if the button is manually told to start updating: we don't want a bunch of unnecessarily updating widgets
function Clickable:OnUpdate(dt)
	if self.down then
		if self.whiledown then
			self.whiledown()
		end
	end
end

function Clickable:SetOnGainFocus( fn )
    self.ongainfocus = fn
    return self
end

function Clickable:SetOnLoseFocus( fn )
    self.onlosefocus = fn
    return self
end

function Clickable:OnGainFocus()
	Clickable._base.OnGainFocus(self)

	if self:IsEnabled() and TheFrontEnd:GetFadeLevel() <= 0 and self.gainfocus_sound ~= nil then
		TheFrontEnd:GetSound():PlaySound(self.gainfocus_sound)
	end

    self:UpdateHighlight()

	if self.ongainfocus then
		self.ongainfocus()
	end
end

function Clickable:OnLoseFocus()
	Clickable._base.OnLoseFocus(self)

	self.down = false

    self:UpdateHighlight()

	if self.onup then
		self.onup()
	end
	if self.onlosefocus then
		self.onlosefocus()
	end
end

function Clickable:OnEnable()
end

function Clickable:OnDisable()
end

function Clickable:Select()
	self.selected = true
	self:OnSelect()
	return self
end

function Clickable:Unselect()
	self.selected = false
	self:OnUnselect()
	return self
end

function Clickable:OnSelect()
	if self.onselect then
		self.onselect()
	end
end

function Clickable:OnUnselect()
	if self:IsEnabled() then
		if not self.focus then
			self:LoseFocus()
		end
	else
		self:OnDisable()
	end
	if self.onunselect then
		self.onunselect()
	end
end

function Clickable:IsSelected()
	return self.selected
end

function Clickable:SetSelected(selected)
	if selected then self:Select() else self:Unselect() end
	return self
end

--- Triggers a click if there is a callback
function Clickable:Click(device_type, device_id)
	if self.onclick then
		self.onclick(device_type, device_id)
	end
	return self
end

--- Triggers a left-click if there is a callback
function Clickable:AltClick(device_type, device_id)
	if self.onclickalt then
		self.onclickalt(device_type, device_id)
	end
	return self
end

function Clickable:SetOnClickFn( fn )
	self.onclick = fn
	return self
end

function Clickable:SetOnClickAltFn( fn )
	self.onclickalt = fn
	return self
end

-- shim
function Clickable:SetOnClick( fn )
	return self:SetOnClickFn(fn)
end

function Clickable:SetOnClickAlt( fn )
	return self:SetOnClickAltFn(fn)
end

function Clickable:SetOnSelect( fn )
	self.onselect = fn
	return self
end

function Clickable:SetOnUnSelect( fn )
	self.onunselect = fn
	return self
end

function Clickable:SetOnDown( fn )
	self.ondown = fn
	return self
end

function Clickable:SetOnUp( fn )
	self.onup = fn
	return self
end

function Clickable:SetOnUp( fn )
	self.onup = fn
	return self
end

function Clickable:SetWhileDown( fn )
	self.whiledown = fn
	return self
end

function Clickable:SetHelpTextMessage(str)
	if str then
		self.help_message = str
	end
	return self
end

function Clickable:GetHelpText()
	local controller_id = TheInput:GetControllerID()
	local t = {}
	if not self:IsSelected() and self.help_message ~= "" then
		table.insert(t, TheInput:GetLocalizedControl(controller_id, self.control, false, false ) .. " " .. self.help_message)
	end
	return table.concat(t, "  ")
end

function Clickable:SetScales(normal, hover, down, animate_in_duration, animate_out_duration)
    -- Send in a value in seconds if you want this to animate. Something like 0.1
    self.animate_scale_in_timing = animate_in_duration or nil
    self.animate_scale_out_timing = animate_out_duration or animate_in_duration or nil
    self.scale_normal = normal
    self.scale_hover = hover
    self.scale_down = down
    return self
end

return Clickable
