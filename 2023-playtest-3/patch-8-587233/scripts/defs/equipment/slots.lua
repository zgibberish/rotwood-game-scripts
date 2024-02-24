-- default symbol swaps that each slot does
return {
	{
		name = "WEAPON",
		symbols = { "weapon_back01", "fx_spear_twirl01", "dangle01", "ball_mass", "shadow_untex", "shotput_spikes",
			"wipe", "feature01", "feature02", "lever01", "ammo_cannon01" },
		tags = { "required" }
	},

	-- Helmet
	{
		name = "HEAD",
		symbols = { "armor_head", "armor_head_back", "armor_head_visor", "armor_head_mask" },
		tags = { "armor" }
	},

	-- Body
	{
		name = "BODY",
		symbols = {
			"armor_body", "armor_arm_parts", "armor_arm_parts_narrow", -- body
			"armor_shoulder",                               -- shoulder
			"armor_wrist", "armor_hand", "armor_hand_parts", -- arms

		},
		tags = { "armor" }
	},

	{
		name = "WAIST",
		symbols = {
			"armor_waist", "armor_pelvis", "armor_leg_parts", -- waist
			"armor_foot_parts", "armor_knee", "armor_foot", -- legs
		},
		tags = { "armor" }
	},

	-- -- -- Shoulders
	-- {
	-- 	name = "SHOULDERS",
	-- 	symbols = { "armor_shoulder" },
	-- 	tags = { "armor" }
	-- },

	-- -- -- Gloves
	-- {
	-- 	name = "ARMS",
	-- 	symbols = { "armor_wrist", "armor_hand", "armor_hand_parts" },
	-- 	tags = { "armor" }
	-- },

	-- -- -- Legs/ Waist
	-- {
	-- 	name = "WAIST",
	-- 	symbols = {
	-- 		"armor_waist", "armor_pelvis", "armor_leg_parts", -- waist
	-- 		"armor_foot_parts", "armor_knee", "armor_foot", -- legs
	-- 	},
	-- 	tags = { "armor" }
	-- },

	-- {
	-- 	name = "LEGS",
	-- 	symbols = {
	-- 		"armor_waist", "armor_pelvis", "armor_leg_parts", -- waist
	-- 		"armor_foot_parts", "armor_knee", "armor_foot", -- legs
	-- 	},
	-- 	tags = { "armor" }
	-- },

	-- -- Feet
	-- {
	-- 	name = "LEGS",
	-- 	symbols = { "armor_foot_parts", "armor_knee", "armor_foot" },
	-- 	tags = { "armor" }
	-- },

	{
		name = "POTIONS",
		symbols = { "flask_line01", "fx_potion_break01" },
		tags = { "required", "no_ui" }
	},

	{
		name = "TONICS",
		symbols = {},
		tags = { "hidden", "no_ui" }
	},

	{
		name = "FOOD",
		symbols = {},
		tags = { "hidden", "no_ui" }
	},
}
