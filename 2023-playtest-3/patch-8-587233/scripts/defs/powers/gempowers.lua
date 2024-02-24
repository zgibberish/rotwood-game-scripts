local Power = require("defs.powers.power")
local Equipment = require("defs.equipment")
local slotutil = require("defs.slotutil")
local power_icons = require "gen.atlas.ui_ftf_power_icons"
local Consumable = require "defs.consumable"
local fmodtable = require "defs.sound.fmodtable"
local powerutil = require "util.powerutil"
local combatutil = require "util.combatutil"

local function GetIcon(name)
	local icon_name = ("icon_equipment_%s"):format(name)

	local atlas = power_icons
	local icon = atlas.tex[icon_name]

	if not icon then
		printf("Failed to find icon: %s", icon_name)
		icon = "images/icons_ftf/item_temp.tex"
	end

	return icon
end

function Power.AddGemPower(name, data)
	if data.toolips == nil then
		data.tooltips = {}
	end

	data.icon = GetIcon(name)
	data.pretty = slotutil.GetPrettyStrings(Power.Slots.EQUIPMENT, name)

	data.power_type = Power.Types.EQUIPMENT
	data.can_drop = false
	data.selectable = false
	data.show_in_ui = false

	data.stackable = true
	if not data.max_stacks then
		data.max_stacks = 100
	end

	Power.AddPower(Power.Slots.EQUIPMENT, name, "equipmentpowers", data)
end

Power.AddGemPower("damage_bonus_cabbageroll",
{
	power_category = Power.Categories.DAMAGE,

	tuning =
	{
		[Power.Rarity.COMMON] = {
			-- %
			damage_bonus = StackingVariable(1):SetPercentage(),
		},
	},

	damage_mod_fn = function(pow, attack, output_data)
		if attack:GetAttacker() ~= attack:GetTarget() then
			if attack:GetTarget().prefab == "cabbageroll" or attack:GetTarget().prefab == "cabbageroll_elite" then
				local damagemult = pow.persistdata:GetVar("damage_bonus")

				if damagemult then
					output_data.damage_delta = output_data.damage_delta + (attack:GetDamage() * damagemult)
				end
			else
				return false
			end
		end

		return true
	end,
})