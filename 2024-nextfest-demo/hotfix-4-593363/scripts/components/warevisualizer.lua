local animutil = require("util/animutil")
local Power = require("defs.powers.power")
local Strict = require "util.strict"
local Lume = require "util.lume"
local VendingMachinePrefabs = require "defs.vendingmachine_prefabs"
local SkillIconWidget = require "widgets.skilliconwidget"

local BORDER_BACK_SYMBOL = "border_back"
local BORDER_FRONT_SYMBOL = "border_front"
local ICON_SYMBOL = "icon"
local ITEM_SYMBOL = "item"

local POWER_BORDER_SYMBOLS <const> = {
	[Power.Rarity.COMMON] = {
		[Power.Categories.SUPPORT] ="common_support_pips_0-0.tex",
		[Power.Categories.DAMAGE] ="common_damage_pips_0-0.tex",
		[Power.Categories.SUSTAIN] ="common_sustain_pips_0-0.tex",
	},
	[Power.Rarity.EPIC] = {
		[Power.Categories.SUPPORT] ="epic_support_pips_1-1.tex",
		[Power.Categories.DAMAGE] ="epic_damage_pips_1-1.tex",
		[Power.Categories.SUSTAIN] ="epic_sustain_pips_1-1.tex",
	},
	[Power.Rarity.LEGENDARY] = {
		[Power.Categories.SUPPORT] ="legendary_support_pips_2-2.tex",
		[Power.Categories.DAMAGE] ="legendary_damage_pips_2-2.tex",
		[Power.Categories.SUSTAIN] ="legendary_sustain_pips_2-2.tex",
	},
}

local SKILL_BORDERS <const> = {
	[Power.Rarity.COMMON] = "common_skill.tex",
	[Power.Rarity.EPIC] = "epic_skill.tex",
	[Power.Rarity.LEGENDARY] = "legendary_skill.tex",
}

Strict.strictify(POWER_BORDER_SYMBOLS)

local DROPS_CURRENCY_BUILD = "drops_currency"
local DROPS_POTIONS_BUILD = "drops_potion"
local NON_POWER_WARE_OVERRIDES <const> = {
	upgrade = {
		build = DROPS_CURRENCY_BUILD,
		symbol = "power_upgrade",
	},
	corestone = {
		build = DROPS_CURRENCY_BUILD,
		symbol = "konjur_soul_lesser",
	},
	potion = {
		build = DROPS_POTIONS_BUILD,
		symbol = "potion",
	},
	shield = nil,
}
-- TODO @chrisp #vending - Once we have icons for all non-power wares, make this table strict.
-- Strict.strictify(NON_POWER_WARE_SYMBOLS)

local WareVisualizer = Class(function(self, inst)
	self.inst = inst
	self.inst:ListenForEvent("initialized_ware", function(_inst, ware_details) 
		self:Initialize(ware_details)
	end)
end)

function WareVisualizer:Initialize(ware_details)
	self.initialized = true
	self.ware_name = ware_details.ware_name
	self.power = ware_details.power
	self.power_type = ware_details.power_type
	
	local power_def = Lume(Power.GetAllPowers()):match(function(power)
		 return power.name == self.power
	end):result()

	local shown_symbol, hidden_symbol
	if power_def then
		shown_symbol = ICON_SYMBOL
		hidden_symbol = ITEM_SYMBOL
		self:_ManifestPowerWare(power_def, shown_symbol)
	else
		shown_symbol = ITEM_SYMBOL
		hidden_symbol = ICON_SYMBOL
		self:_ManifestNonPowerWare(shown_symbol)
	end

	animutil.HideSymbol(self.inst, hidden_symbol)
end

function WareVisualizer:IsInitialized()
	return self.initialized
end

function WareVisualizer:OnNetSerialize()
	self.inst.entity:SerializeString(self.ware_name or "")
	self.inst.entity:SerializeString(self.power or "")
	self.inst.entity:SerializeString(self.power_type or "")
end

function WareVisualizer:OnNetDeserialize()
	local ware_details = {
		ware_name = self.inst.entity:DeserializeString() or "",
		power = self.inst.entity:DeserializeString() or "",
		power_type = self.inst.entity:DeserializeString() or "",
	}
	if ware_details.ware_name ~= self.ware_name
		or ware_details.power ~= self.power
		or ware_details.power_type ~= self.power_type
	then
		self:Initialize(ware_details)
	end
end

function WareVisualizer:_ManifestPowerWare(power_def, shown_symbol)
	local power_type = self.power_type

	local rarity = Power.GetBaseRarity(power_def)
	local icon = power_def.icon
	local parts = Lume.split(icon, '/')
	local build = string.format("%s/%s.xml", parts[1], parts[2])
	local symbol = parts[3]

	animutil.OverrideSymbol(self.inst, shown_symbol, build, symbol)

	-- Skills use the BORDER_BACK_SYMBOL.
	-- Food and Powers use the BORDER_FRONT_SYMBOL.
	local shown_border, hidden_border, border
	if power_type == Power.Types.SKILL then
		shown_border = BORDER_BACK_SYMBOL
		hidden_border = BORDER_FRONT_SYMBOL
		border = SKILL_BORDERS[rarity]
		local colour = SkillIconWidget.RARITY_TO_ICON_COLOUR[rarity]
		animutil.OverrideSymbolMultColor(self.inst, shown_symbol, colour.r, colour.g, colour.b, 1.0)
	else
		shown_border = BORDER_FRONT_SYMBOL
		hidden_border = BORDER_BACK_SYMBOL
		border = POWER_BORDER_SYMBOLS[rarity][power_def.power_category]
	end
	animutil.OverrideSymbol(
		self.inst, 
		shown_border, 
		VendingMachinePrefabs.run_item_shop.BORDERS_BUILD, 
		border
	)
	animutil.HideSymbol(self.inst, hidden_border)
end

function WareVisualizer:_ManifestNonPowerWare(shown_symbol)
	local override = NON_POWER_WARE_OVERRIDES[self.ware_name]
	if override then
		animutil.OverrideSymbol(
			self.inst,
			shown_symbol,
			override.build,
			override.symbol
		)
	end
	animutil.HideSymbol(self.inst, BORDER_FRONT_SYMBOL)
	animutil.HideSymbol(self.inst, BORDER_BACK_SYMBOL)
end

return WareVisualizer
