local Weight = require "components/weight"
local lume = require "util.lume"

local EquipmentStatDisplay = {
    [EQUIPMENT_STATS.s.RARITY] =
    {
        default = ITEM_RARITY.s.COMMON,
    },
    [EQUIPMENT_STATS.s.WEIGHT] =
    {
        icon = "images/icons_ftf/stat_weight.tex",
        displayvalue_fn = function(stat, amount)
            local str = Weight.GetWeightStringForValue(amount)
            return str
        end,
        hide_delta_value = true,
    },
    [EQUIPMENT_STATS.s.ARMOUR] =
    {
        icon = "images/ui_ftf/ic_stat_defend.tex",
        default = 0,
        round = 0.001,

        displayvalue_fn = function(stat, amount)
            amount = amount*100*2
            return lume.round(amount, 1)
        end,

        tt_fn = function(stat, amount)

        end,
    },
    [EQUIPMENT_STATS.s.HP] =
    {
        icon = "images/icons_ftf/stat_health.tex",
        default = 0,
    },
    [EQUIPMENT_STATS.s.DMG] =
    {
        icon = "images/icons_ftf/stat_weapon.tex",
        default = 0,
        round = 1,
    },
    [EQUIPMENT_STATS.s.CRIT] =
    {
        icon = "images/icons_ftf/stat_crit_chance.tex",
        default = 0,
        percent = true,
    },
    [EQUIPMENT_STATS.s.SPEED] =
    {
        icon = "images/icons_ftf/stat_speed.tex",
        default = 0,
        percent = true,
    },
    [EQUIPMENT_STATS.s.LUCK] =
    {
        icon = "images/icons_ftf/stat_luck.tex",
        default = 0,
        percent = true,
    },
    [EQUIPMENT_STATS.s.CRIT_MULT] =
    {
        icon = "images/icons_ftf/stat_crit_damage.tex",
        default = 0,
        percent = true,
        tt_fn = function(stat, amount)
            local str = STRINGS.UI.EQUIPMENT_STATS[string.upper(stat)].desc
            local mod = amount
            mod = mod * 100
            return string.format(str, mod)
        end,
    },
    [EQUIPMENT_STATS.s.FOCUS_MULT] =
    {
        icon = "images/icons_ftf/stat_focus.tex",
        default = 0,
        percent = true,
        tt_fn = function(stat, amount)
            local str = STRINGS.UI.EQUIPMENT_STATS[string.upper(stat)].desc
            amount = amount * 100
            return string.format(str, amount)
        end,
    },
}
return EquipmentStatDisplay
