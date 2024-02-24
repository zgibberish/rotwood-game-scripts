local Power = require("defs.powers.power")
local slotutil = require("defs.slotutil")
local power_icons = require "gen.atlas.ui_ftf_power_icons"

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

function Power.AddHeartPower(name, data)
	if data.toolips == nil then
		data.tooltips = {}
	end

	data.icon = GetIcon(name)
	data.pretty = slotutil.GetPrettyStrings(Power.Slots.HEART, name)

	data.power_type = Power.Types.HEART
	data.can_drop = false
	data.selectable = false
	data.show_in_ui = false

	data.stackable = true
	if not data.max_stacks then
		data.max_stacks = 4
	end

	name = ("heart_%s"):format(name):lower()
	Power.AddPower(Power.Slots.HEART, name, "heartpowers", data)
end

Power.AddPowerFamily("HEART")

Power.AddHeartPower("megatreemon",
{
	power_category = Power.Categories.SUSTAIN,
	permanent = true,
	max_stacks = 400, -- max 400 extra health

	tuning =
	{
		[Power.Rarity.COMMON] = {
			health = StackingVariable(1):SetFlat(), -- # stacks = # max health increase
		},
	},

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			local health_mod = pow.persistdata:GetVar("health")
			inst.components.health:AddHealthAddModifier(pow.def.name, health_mod)
			inst.components.health:DoDelta(health_mod, true)
			pow.persistdata.did_init = true
		end
	end,

	on_stacks_changed_fn = function(pow, inst)
		local health_mod = pow.persistdata:GetVar("health")
		inst.components.health:AddHealthAddModifier(pow.def.name, health_mod)
		inst.components.health:DoDelta(health_mod, true)
	end,

	on_remove_fn = function(pow, inst)
		inst.components.health:RemoveHealthAddModifier(pow.def.name)
		pow.persistdata.did_init = false
	end,
})

Power.AddHeartPower("owlitzer",
{
	power_category = Power.Categories.SUPPORT,

	tags = { POWER_TAGS.PROVIDES_HEALING },

	max_stacks = 20, -- max heal of 20/ room

	tuning = {
		[Power.Rarity.COMMON] = { 
			heal = StackingVariable(1):SetFlat() 
		},
	},

	event_triggers =
	{
		["start_gameplay"] = function(pow, inst, data)
			local power_heal = Attack(inst, inst)
			power_heal:SetHeal(pow.persistdata:GetVar("heal"))
			power_heal:SetSource(pow.def.name)
			inst.components.combat:ApplyHeal(power_heal)

			inst:PushEvent("used_power", pow.def)
		end,
	}
})

Power.AddHeartPower("bandicoot",
{
	power_category = Power.Categories.SUPPORT,
	permanent = true,
	max_stacks = 40,

	tuning =
	{
		[Power.Rarity.COMMON] = {
			dodge_speed = StackingVariable(1):SetFlat(), --% distance further of dodge
		},
	},

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			local dodge_mod = pow.persistdata:GetVar("dodge_speed")
			inst.components.playerroller:AddDistanceMultModifier(pow.def.name, dodge_mod/100)
			pow.persistdata.did_init = true
		end
	end,

	on_stacks_changed_fn = function(pow, inst)
		local dodge_mod = pow.persistdata:GetVar("dodge_speed")
		inst.components.playerroller:AddDistanceMultModifier(pow.def.name, dodge_mod/100)
	end,

	on_remove_fn = function(pow, inst)
		inst.components.playerroller:RemoveDistanceMultModifier(pow.def.name)
		pow.persistdata.did_init = false
	end,
})

Power.AddHeartPower("thatcher",
{
	power_category = Power.Categories.SUPPORT,
	permanent = true,
	max_stacks = 40,

	tuning =
	{
		[Power.Rarity.COMMON] = {
			dodge_speed = StackingVariable(1):SetFlat(), --% distance further of dodge
		},
	},

	on_add_fn = function(pow, inst)
		if not pow.persistdata.did_init then
			local dodge_mod = pow.persistdata:GetVar("dodge_speed")
			inst.components.playerroller:AddDistanceMultModifier(pow.def.name, dodge_mod/100)
			pow.persistdata.did_init = true
		end
	end,

	on_stacks_changed_fn = function(pow, inst)
		local dodge_mod = pow.persistdata:GetVar("dodge_speed")
		inst.components.playerroller:AddDistanceMultModifier(pow.def.name, dodge_mod/100)
	end,

	on_remove_fn = function(pow, inst)
		inst.components.playerroller:RemoveDistanceMultModifier(pow.def.name)
		pow.persistdata.did_init = false
	end,
})
-- heart features should generally be powers that allow the player to fine-tune how their character controls
-- an armour power 