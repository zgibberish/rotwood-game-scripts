local Widget = require("widgets/widget")
local Text = require("widgets/text")
local easing = require("util.easing")

local DamageNumber = Class(Widget, function(self)
	Widget._ctor(self, "DamageNumber")

	self.text_root = self:AddChild(Widget())

	self.number = self.text_root:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.DAMAGENUM_PLAYER, "", UICOLORS.ATK_DO_DAMAGE))
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()


	self.start_x, self.start_y = nil, nil

	self.time_updating = 0

	self.y_offset_target = 50
	self.y_offset_target_time = 0.5

	self.x_offset_target = 25
	self.x_offset_target_time = 0.5

	self.x_offset_mod = 1

	self.fade_time = 0.66

	self.s_x = nil
	self.s_y = nil
	self.s_z = nil

	self.is_heal = false

	self.attacker = nil -- The attacker that created me; local only

	self:SetClickable(false)
end)

local healamount_to_fontsize =
{
	-- heal amount, fontsize
	{1,		FONTSIZE.DAMAGENUM_PLAYER},
	{50,	FONTSIZE.DAMAGENUM_PLAYER + 20},
	{100, 	FONTSIZE.DAMAGENUM_PLAYER + 30},
	{500, 	FONTSIZE.DAMAGENUM_PLAYER + 46},
	{1000, 	FONTSIZE.DAMAGENUM_PLAYER + 70},
}

local FOCUS_FONTSIZE_MULTIPLIER = 1.1
local CRIT_FONTSIZE_MULTIPLIER = 1.5

function DamageNumber:OnFaded()
	if self.attacker ~= nil then
		self.attacker.components.combat:RemoveDamageNumber(self)
	end
	self:Remove()
end

function DamageNumber:SetAttacker(attacker)
	assert(attacker and attacker:IsLocalOrMinimal())
	self.attacker = attacker
end

function DamageNumber:ApplyRemotePlayerPresentation(is_heal)
	if is_heal then
		return
	end

	-- If we are not a local or minimal entity, this will run to apply a different presentation to the FX.
	local REMOTE_PLAYER_SIZE_MULTIPLIER = 0.7 -- If the source of the damage is a remote player, make it smaller
	local REMOTE_PLAYER_ALPHA = 0.85 -- If the source of the damage is a remote player, make it faded
	
	-- Remote players damage numbers should be a bit smaller. Heals should still be large.

	if not is_heal then
		local font_size = self.number:GetFontSize()
		font_size = font_size * REMOTE_PLAYER_SIZE_MULTIPLIER
		self.number:SetFontSize(font_size)
		self:SetFadeAlpha(REMOTE_PLAYER_ALPHA)
	end
end

-- target entity
-- damage amount: (uint64) use Write7BitEncodedUInt for improved efficiency
-- num_sources: (uint8) aka attack chain count
-- active_numbers: (uint8, 0..7) multiplier used to offset 2D placement based on active damage numbers on attacker
-- display flags: is_focus, is_crit, is_heal, is_player, is_secondary_attack
function DamageNumber:InitNew(target, value, offset_mod, num_sources, active_numbers, is_focus, is_crit, is_heal, is_player, is_secondary_attack, playerID)
	local font_size = FONTSIZE.DAMAGENUM_MONSTER
	local damage_text = string.format("%s", value)

	self.x_offset_mod = offset_mod

	if target.AnimState then
		self.s_x, self.s_y, self.s_z = target.AnimState:GetSymbolPosition("head", 0, 0, 0)
	else
		self.s_x, self.s_y, self.s_z = target.Transform:GetWorldPosition()
	end

	local x,y = self:CalcLocalPositionFromWorldPoint(self.s_x, self.s_y, self.s_z)
	self:SetPosition(x, y)

	self:AlphaTo(0, self.fade_time, easing.inExpo, function() self:OnFaded() end)

	if is_focus then
		font_size = font_size * FOCUS_FONTSIZE_MULTIPLIER
		self.y_offset_target = 75
		self.fade_time = 1
		self:ScaleTo(1, 1.25, 0.33, easing.outExpo, function()
			self:ScaleTo(1.25, 1, 0.33, easing.inExpo)
		end)
		self.number:SetGlyphColor(UICOLORS.ATK_FOCUS)
	end

	if is_crit then
		font_size = font_size * CRIT_FONTSIZE_MULTIPLIER
		self.y_offset_target = self.y_offset_target * 1.5
		self.x_offset_mod = self.x_offset_mod * 3
		self.fade_time = self.fade_time * 1.5
		damage_text = string.format("%s!", damage_text)

		self.number:SetGlyphColor(UICOLORS.ATK_CRIT)
	end

	self.is_heal = is_heal

	if is_player then
		-- A player is taking damage
		font_size = FONTSIZE.DAMAGENUM_PLAYER
		self.y_offset_target_time = 1

		if not is_heal then
			self.x_offset_mod = 0
			self.fade_time = 2
			self.y_offset_target = -50
			self.number:SetGlyphColor(UICOLORS.ATK_TAKE_DAMAGE)
			self:ScaleTo(1, 1.5, 0.33, easing.outExpo, function()
				self:ScaleTo(1.5, 1, 0.33, easing.inExpo)
			end)
		end
	end

	if is_heal then
		local healfontsize = PiecewiseFn(value, healamount_to_fontsize)
		self.fade_time = 6
		self.y_offset_target = 150
		font_size = healfontsize
		self.number:SetGlyphColor(UICOLORS.HEAL)
	end

	if is_secondary_attack then
		-- secondary attacks (attack dice?)
		self.y_offset_target = self.y_offset_target * 0.5
		if not is_heal then
			self.number:SetGlyphColor(UICOLORS.ATK_SECONDARY_DAMAGE)
		end
	end

	local size = font_size - math.ceil(num_sources * 1.5)
	self.number:SetFontSize(size)
	self.number:SetText(damage_text)

	if playerID and TheNet:IsValidPlayer(playerID) and not TheNet:IsLocalPlayer(playerID) then
		self:ApplyRemotePlayerPresentation(is_heal)
	end

	active_numbers = active_numbers % 7
	self.y_offset_target = self.y_offset_target + (active_numbers-1) * 10
	self.x_offset_target = self.x_offset_target - (active_numbers-1) * 2
	self:StartUpdating()
end

function DamageNumber:InitOld(data)
	local attack = data.attack

	local font_size = FONTSIZE.DAMAGENUM_MONSTER

	local damage_text = string.format("%s", attack:GetDamage() or attack:GetHeal())

	self.x_offset_mod = data.x_offset_mod

	local target = attack:GetTarget()
	if target.AnimState then
		self.s_x, self.s_y, self.s_z = target.AnimState:GetSymbolPosition("head", 0, 0, 0)
	else
		self.s_x, self.s_y, self.s_z = target.Transform:GetWorldPosition()
	end

	local x,y = self:CalcLocalPositionFromWorldPoint(self.s_x, self.s_y, self.s_z)
	self:SetPosition(x, y)

	self:AlphaTo(0, self.fade_time, easing.inExpo, function() self:OnFaded() end)

	-- self.y_offset_target = math.clamp(data.damage * 0.5, 25, 100)
	if attack:GetFocus() then
		font_size = font_size * FOCUS_FONTSIZE_MULTIPLIER
		self.y_offset_target = 75
		self.fade_time = 1
		self:ScaleTo(1, 1.25, 0.33, easing.outExpo, function()
			self:ScaleTo(1.25, 1, 0.33, easing.inExpo)
		end)
		self.number:SetGlyphColor(UICOLORS.ATK_FOCUS)
	end

	if attack:GetCrit() then
		font_size = font_size * CRIT_FONTSIZE_MULTIPLIER
		self.y_offset_target = self.y_offset_target * 1.5
		self.x_offset_mod = self.x_offset_mod * 3
		self.fade_time = self.fade_time * 1.5
		damage_text = string.format("%s!", damage_text)

		self.number:SetGlyphColor(UICOLORS.ATK_CRIT)
	end

	self.is_heal = attack:GetHeal() ~= nil

	if data.is_player then
		-- A player is taking damage
		font_size = FONTSIZE.DAMAGENUM_PLAYER
		self.y_offset_target_time = 1

		if not self.is_heal then
			self.x_offset_mod = 0
			self.fade_time = 2
			self.y_offset_target = -50
			self.number:SetGlyphColor(UICOLORS.ATK_TAKE_DAMAGE)
			self:ScaleTo(1, 1.5, 0.33, easing.outExpo, function()
				self:ScaleTo(1.5, 1, 0.33, easing.inExpo)
			end)
		end
	end

	if self.is_heal then
		local healfontsize = PiecewiseFn(attack:GetHeal(), healamount_to_fontsize)
		self.fade_time = 6
		self.y_offset_target = 150
		font_size = healfontsize
		self.number:SetGlyphColor(UICOLORS.HEAL)
	end

	if not attack:SourceIsAttacker() and not attack:GetProjectile() then
		-- secondary attacks (attack dice?)
		self.y_offset_target = self.y_offset_target * 0.5
		if not self.is_heal then
			self.number:SetGlyphColor(UICOLORS.ATK_SECONDARY_DAMAGE)
		end
	end

	local num_sources = attack:GetNumInChain()

	local size = font_size - math.ceil(num_sources * 1.5)
	self.number:SetFontSize(size)
	self.number:SetText(damage_text)

	local attacker = attack:GetAttacker()
	if attacker ~= nil then
		self.attacker = attacker
		self.attacker.components.combat:AddDamageNumber(self)
		local active_numbers = self.attacker.components.combat:GetDamageNumbersCount() % 7
		self.y_offset_target = self.y_offset_target + (active_numbers-1) * 10
		self.x_offset_target = self.x_offset_target - (active_numbers-1) * 2
	end
	self:StartUpdating()
end


function DamageNumber:OnUpdate(dt)

	self.time_updating = self.time_updating + dt

	local y_offset = 0

	if not self.is_heal then
		y_offset = easing.outElastic(self.time_updating, 0, self.y_offset_target, self.y_offset_target_time, 50, 0.1)
	else
		y_offset = easing.linear(self.time_updating, 0, self.y_offset_target, self.y_offset_target_time)
	end

	local x_offset = easing.outExpo(self.time_updating, 0, self.x_offset_target * self.x_offset_mod, self.x_offset_target_time)
	local x,y = self:CalcLocalPositionFromWorldPoint(self.s_x, self.s_y, self.s_z)
	self:SetPosition(x + x_offset, y + y_offset)
end

return DamageNumber
