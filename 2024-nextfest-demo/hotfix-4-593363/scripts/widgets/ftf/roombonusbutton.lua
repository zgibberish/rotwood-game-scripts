local PowerDescriptionButton = require "widgets.ftf.powerdescriptionbutton"
local easing = require "util.easing"


--- A wide button showing a selectable room bonus.
--
-- RoomBonus-specific logic goes here. Visual definition in PowerDescriptionButton.
local RoomBonusButton = Class(PowerDescriptionButton, function(self)
    PowerDescriptionButton._ctor(self)

    -- Save the player who's picked this bonus
    self.currentlySetPlayer = nil
end)

function RoomBonusButton:SetBonus(power, islucky, can_select)
	return self:SetPower(power, islucky, can_select)
end

function RoomBonusButton:GetBonus()
	return self:GetPower()
end

-- If a player has picked this bonus, return it
function RoomBonusButton:GetPlayer()
	return self.currentlySetPlayer
end

function RoomBonusButton:IsPicked()
	return self.picked == true
end

function RoomBonusButton:SetPicked()
	self.picked = true
	self:DoSelectedPresentation()
	return self
end

function RoomBonusButton:SetNotPicked()
	self.picked = false
	self:DoUnselectedPresentation()
	return self
end


function RoomBonusButton:OnDisable()
	RoomBonusButton._base.OnDisable(self)
	self:DoDisablePresentation(self.picked)
end

return RoomBonusButton
