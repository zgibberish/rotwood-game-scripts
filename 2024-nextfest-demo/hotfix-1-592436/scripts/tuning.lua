local color = require "math.modules.color"
local Enum = require "util.enum"
local Strict = require "util.strict"
local Lume = require "util.lume"
local Weight = require "components/weight"

local HSB = color.HSBFromInts
local MONSTER_MOVE_SPEED_MOD = 1
local PLAYER_MOVE_SPEED_MOD = 1

--[[ Definitions:
Modifier - A named value (variable) that is mathematically combined (i.e. added or multiplied) with some
other game value to produce a modified value.
Name - A string value that identifies a Modifier.
ResolvedModifier - Multiple Sources may contribute to a single Mdifier. When all Sources for a Modifier are
mathematically combined (typically via addition), a ResolvedModifier is produced.
Source - Contributes to one or more modifiers.
Sink - Consumes ResolvedModifiers.
]]

EnemyModifierNames = Enum {
	"HealthMult",   -- all enemies, including bosses and minibosses
	"BasicHealthMult", -- all non-boss and non-miniboss enemies, explicitly merged with Health in code (monsterutil.lua, MakeBasicMonster and MakeStationaryMonster). Includes Elites.
	"BossHealthMult", -- bosses only, explicitly merged with Health in code (monsterutil.lua, ExtendToBossMonster)

	-- NOTE: The miniboss likely already has a modified health due to its assigned ENEMY_MULTIPLAYER_MODS.
	-- This value is a nudge above that likely-existing number, just to differentiate the Miniboss version from the
	-- Elite version of that mob that shows up elsewhere.
	"MinibossHealthMult", -- minibosses only, explicitly merged with Health in code (monsterutil.lua, MakeMiniboss)

	"SpawnCountMult",
	"StationarySpawnCountMult",
	"MinibossSpawnCountMult",

	"CooldownMult",
	"EliteCooldownMult",
	"BossCooldownMult",

	"CooldownMinMult",
	"EliteCooldownMinMult",
	"BossCooldownMinMult",

	"InitialCooldownMult",
	"EliteInitialCooldownMult",
	"BossInitialCooldownMult",

	"StartupFramesMult",
	"EliteStartupFramesMult",
	"BossStartupFramesMult",

	"EliteChance",
	"EliteSpawnCount", -- Further modify the amount returned from waves.elite_counts. Ascension that boosts it up, or power that boosts it down, etc.

	"DungeonTierDamageMult",
}

-- Multipliers default to 1; additives default to 0.
local ENEMY_MODIFIER_DEFAULTS = {}
for _, modifier in ipairs(EnemyModifierNames:Ordered()) do
	ENEMY_MODIFIER_DEFAULTS[modifier] = 1
end
ENEMY_MODIFIER_DEFAULTS[EnemyModifierNames.s.BasicHealthMult] = 0
ENEMY_MODIFIER_DEFAULTS[EnemyModifierNames.s.BossHealthMult] = 0
ENEMY_MODIFIER_DEFAULTS[EnemyModifierNames.s.MinibossHealthMult] = 0.5
ENEMY_MODIFIER_DEFAULTS[EnemyModifierNames.s.EliteChance] = 0
ENEMY_MODIFIER_DEFAULTS[EnemyModifierNames.s.EliteSpawnCount] = 0
ENEMY_MODIFIER_DEFAULTS[EnemyModifierNames.s.DungeonTierDamageMult] = 0
Strict.strictify(ENEMY_MODIFIER_DEFAULTS)

-- Enemy modifier tables keyed by Tier index.
-- NOTE @chrisp #meta - If you add a dungeon tier row here, you probably want to add corresponding rows to
-- WeaponILvlModifierSource and ArmourILvlModifierSource to balance game-play.
local DungeonTierModifierSource = {
	{ [EnemyModifierNames.s.HealthMult] = 0.0, [EnemyModifierNames.s.DungeonTierDamageMult] = 0.0 }, --Treemon Forest
	{ [EnemyModifierNames.s.HealthMult] = 0.1, [EnemyModifierNames.s.DungeonTierDamageMult] = 0.1 }, --Owlitzer Forest
	{ [EnemyModifierNames.s.HealthMult] = 0.2, [EnemyModifierNames.s.DungeonTierDamageMult] = 0.2 }, --Bandicoot Swamp
	{ [EnemyModifierNames.s.HealthMult] = 0.4, [EnemyModifierNames.s.DungeonTierDamageMult] = 0.4 }, --Thatcher Swamp
	{ [EnemyModifierNames.s.HealthMult] = 0.6, [EnemyModifierNames.s.DungeonTierDamageMult] = 0.6 },
	{ [EnemyModifierNames.s.HealthMult] = 0.8, [EnemyModifierNames.s.DungeonTierDamageMult] = 0.8 },
	{ [EnemyModifierNames.s.HealthMult] = 1.0, [EnemyModifierNames.s.DungeonTierDamageMult] = 1.0 },
	{ [EnemyModifierNames.s.HealthMult] = 1.2, [EnemyModifierNames.s.DungeonTierDamageMult] = 1.2 },
	{ [EnemyModifierNames.s.HealthMult] = 1.4, [EnemyModifierNames.s.DungeonTierDamageMult] = 1.4 },
	{ [EnemyModifierNames.s.HealthMult] = 1.6, [EnemyModifierNames.s.DungeonTierDamageMult] = 1.6 },
	{ [EnemyModifierNames.s.HealthMult] = 1.8, [EnemyModifierNames.s.DungeonTierDamageMult] = 1.8 },
}
Strict.strictify(DungeonTierModifierSource)

-- Enemy modifier tables keyed by ascension level.
-- Remember that ascension level starts at 0. Ascension 0 is NOT represented in this table.

-- Here's a spreadsheet to help sketch these numbers:
-- https://docs.google.com/spreadsheets/d/1hK80TeeUqjxuqK9M6RkYY5AR_XNrRaiiOKnRBtp64ss/edit#gid=0
local AscensionModifierSource = {
	-- The boss in Dungeon1 Frenzy1 should be about as strong as the boss in Dungeon2 Frenzy0.
	-- Boss D[n]F1 roughly == Boss D[n+1]F0

	{ -- Ascension 1
		-- Basic Health/Damage Modifiers:
		-- Elites are already being added in this, so we don't need to change these values too much to add more difficulty and health-loss due to attrition while moving room to room.
		-- However, since there is only one Boss and only one Miniboss, we can increase them a bit more so this change is more noticeable.
		[EnemyModifierNames.s.BasicHealthMult] = 0.10,
		[EnemyModifierNames.s.BossHealthMult] = 0.25,
		[EnemyModifierNames.s.MinibossHealthMult] = 0.15,
		[EnemyModifierNames.s.DungeonTierDamageMult] = 0.1, -- A bit damage dealt by enemies across the board, not as much as moving from D1 -> D2 though.

		[EnemyModifierNames.s.InitialCooldownMult] = -0.25,

		-- Star of the show: Enable Elite mobs, which present all new mechanics to learn for every mob.
		[EnemyModifierNames.s.EliteChance] = 0.25,
	},

	{ -- Ascension 2
		-- Basic Health/Damage Modifiers increase.
		-- Have a bigger jump than general. Now we want a bigger difficulty jump so the player feels like they should be clearing the next Dungeon first.
		[EnemyModifierNames.s.BasicHealthMult] = 0.25,
		[EnemyModifierNames.s.BossHealthMult] = 0.25,
		[EnemyModifierNames.s.MinibossHealthMult] = 0.25,
		[EnemyModifierNames.s.DungeonTierDamageMult] = 0.30,

		-- Star of the show: Introduce cooldown modifiers -- make all mobs more aggressive. This should be noticeable.
		[EnemyModifierNames.s.CooldownMult] = -0.4,
		[EnemyModifierNames.s.CooldownMinMult] = -0.6,
		[EnemyModifierNames.s.InitialCooldownMult] = -0.25,
		[EnemyModifierNames.s.EliteCooldownMult] = -0.4,
		[EnemyModifierNames.s.EliteCooldownMinMult] = -0.6,
		[EnemyModifierNames.s.EliteInitialCooldownMult] = -0.5,
		[EnemyModifierNames.s.BossCooldownMult] = -0.3, -- Some bosses already have 0 cooldown. This can't be a "star of the show".
		[EnemyModifierNames.s.BossCooldownMinMult] = -0.5,
		[EnemyModifierNames.s.BossInitialCooldownMult] = -0.5,

		[EnemyModifierNames.s.EliteChance] = 0.2,
		[EnemyModifierNames.s.EliteSpawnCount] = 3,
	},

	-- NOV2023: This is currently our "final ascension", so make this a bit chunkier for now to provide a difficult goal for skilled players.
	{ -- Ascension 3
		-- Basic Health/Damage Modifiers increase.
		-- Continue a steady increase over the previous ascension. This isn't a "star of the show" of this ascension.
		[EnemyModifierNames.s.BasicHealthMult] = 0.25,
		[EnemyModifierNames.s.BossHealthMult] = 0.35,
		[EnemyModifierNames.s.MinibossHealthMult] = 0.35,
		[EnemyModifierNames.s.DungeonTierDamageMult] = 0.30,

		-- Continue adjusting cooldowns by a small amount. Not as noticeable, subtle silent shift.
		-- By this point, initial cooldowns are 0.
		[EnemyModifierNames.s.CooldownMult] = -0.1,
		[EnemyModifierNames.s.CooldownMinMult] = -0.2,
		[EnemyModifierNames.s.InitialCooldownMult] = -0.5,
		[EnemyModifierNames.s.EliteCooldownMult] = -0.1,
		[EnemyModifierNames.s.EliteCooldownMinMult] = -0.2,
		[EnemyModifierNames.s.EliteInitialCooldownMult] = -0.5,
		[EnemyModifierNames.s.BossCooldownMult] = -0.1,
		[EnemyModifierNames.s.BossCooldownMinMult] = -0.2,
		[EnemyModifierNames.s.BossInitialCooldownMult] = -0.5,

		[EnemyModifierNames.s.StartupFramesMult] = -0.25,
		[EnemyModifierNames.s.EliteStartupFramesMult] = -0.25,
		[EnemyModifierNames.s.BossStartupFramesMult] = -0.25, -- Consider cranking this up.

		-- Star of the show: Convert more Normal mobs into Elite mobs. There should be a *lot* of Elites in this Ascension.
		[EnemyModifierNames.s.EliteChance] = 0.1,
		[EnemyModifierNames.s.EliteSpawnCount] = 8,
	},
}
Strict.strictify(AscensionModifierSource)

-- TODO: modify miniboss health based on multiplayer count -- give them more health than normal scaled enemies because they will be focused so hard
local ENEMY_MULTIPLAYER_MODS =
{
	-- Enemy modifier tables keyed by player count (from 1P to 4P).
	-- SpawnCount reasoning:
	-- 		2 PLAYERS
	--			1 mobs * 1.25 =  1.25		1 -> 1
	--			2 mobs * 1.25 =  2.5		2 -> 2 or 3
	--			3 mobs * 1.25 =  3.75		3 -> 4
	--			4 mobs * 1.25 =  5			4 -> 5
	--		3 PLAYERS
	--			1 mobs * 1.5 =  1.5			1 -> 1 or 2
	--			2 mobs * 1.5 =  3			2 -> 3
	--			3 mobs * 1.5 =  4.5			3 -> 4 or 5
	--			4 mobs * 1.5 =  6			4 -> 6
	--		4 PLAYERS
	--			1 mobs * 1.75 =  1.75		1 -> 2
	--			2 mobs * 1.75 =  3.5		2 -> 3 or 4
	--			3 mobs * 1.75 =  5.25		3 -> 5
	--			4 mobs * 1.75 =  7			4 -> 7
	BASIC = {
		{},
		{ [EnemyModifierNames.s.SpawnCountMult] = 0.25, [EnemyModifierNames.s.StationarySpawnCountMult] = 0.25 },
		{ [EnemyModifierNames.s.SpawnCountMult] = 0.50, [EnemyModifierNames.s.StationarySpawnCountMult] = 0.50 },
		{ [EnemyModifierNames.s.SpawnCountMult] = 0.75, [EnemyModifierNames.s.StationarySpawnCountMult] = 0.75 },
	},

	MINOR = {
		{ [EnemyModifierNames.s.HealthMult] = 0.0 },
		{ [EnemyModifierNames.s.HealthMult] = 0.5 },
		{ [EnemyModifierNames.s.HealthMult] = 0.5, [EnemyModifierNames.s.SpawnCountMult] = 0.50, [EnemyModifierNames.s.StationarySpawnCountMult] = 0.50 },
		{ [EnemyModifierNames.s.HealthMult] = 1.2, [EnemyModifierNames.s.SpawnCountMult] = 0.50, [EnemyModifierNames.s.StationarySpawnCountMult] = 0.50 },
	},

	MAJOR = {
		{ [EnemyModifierNames.s.HealthMult] = 0.0 },
		{ [EnemyModifierNames.s.HealthMult] = 1.0 },
		{ [EnemyModifierNames.s.HealthMult] = 1.5, [EnemyModifierNames.s.SpawnCountMult] = 0.50, [EnemyModifierNames.s.StationarySpawnCountMult] = 0.50 },
		{ [EnemyModifierNames.s.HealthMult] = 2.0, [EnemyModifierNames.s.SpawnCountMult] = 0.50, [EnemyModifierNames.s.StationarySpawnCountMult] = 0.50 },
	},

	SWARM = {
		{ [EnemyModifierNames.s.SpawnCountMult] = 0.00 },
		{ [EnemyModifierNames.s.SpawnCountMult] = 0.25, [EnemyModifierNames.s.StationarySpawnCountMult] = 0.25 },
		{ [EnemyModifierNames.s.SpawnCountMult] = 0.25, [EnemyModifierNames.s.StationarySpawnCountMult] = 0.25 },
		{ [EnemyModifierNames.s.SpawnCountMult] = 0.50, [EnemyModifierNames.s.StationarySpawnCountMult] = 0.50 },
	},

	ELITE = {
		{ [EnemyModifierNames.s.HealthMult] = 0.00 },
		{ [EnemyModifierNames.s.HealthMult] = 1.25 },
		{ [EnemyModifierNames.s.HealthMult] = 1.75 },
		{ [EnemyModifierNames.s.HealthMult] = 2.25, [EnemyModifierNames.s.SpawnCountMult] = 0.50, [EnemyModifierNames.s.StationarySpawnCountMult] = 0.50 },
	},

	-- By setting Health multipliers here rather than BossHealth, we allow this ENEMY_MULTIPLAYER_MODS.BOSS tuning
	-- table to be used by non-Boss enemies (for better or worse).
	BOSS = {
		{ [EnemyModifierNames.s.HealthMult] = 0.00 },
		{ [EnemyModifierNames.s.HealthMult] = 0.50 },
		{ [EnemyModifierNames.s.HealthMult] = 1.00 },
		{ [EnemyModifierNames.s.HealthMult] = 1.25 },
	}
}

-- Item levels are closely related to dungeon tiers. Items found in a dungeon will have item levels equal to, or
-- slightly greater than, the dungeon tier.

-- Enumerate the modifiers that can be applied to player attributes. Note that different sources (e.g. weapon, armour)
-- may apply them.
local PlayerModifierNames = Enum {
	"AmmoMult",
	"CritChance",
	"CritDamageMult",
	"DamageMult",
	"FocusMult",
	"Luck",
	"RollVelocityMult",
	"SpeedMult",
	"DungeonTierDamageReductionMult",
}

local PLAYER_MODIFIER_DEFAULTS = {}
for _, modifier in ipairs(PlayerModifierNames:Ordered()) do
	PLAYER_MODIFIER_DEFAULTS[modifier] = 1
end
PLAYER_MODIFIER_DEFAULTS[PlayerModifierNames.s.Luck] = 0
PLAYER_MODIFIER_DEFAULTS[PlayerModifierNames.s.CritChance] = 0
PLAYER_MODIFIER_DEFAULTS[PlayerModifierNames.s.FocusMult] = 0
PLAYER_MODIFIER_DEFAULTS[PlayerModifierNames.s.SpeedMult] = 0
PLAYER_MODIFIER_DEFAULTS[PlayerModifierNames.s.CritDamageMult] = 0
PLAYER_MODIFIER_DEFAULTS[PlayerModifierNames.s.DungeonTierDamageReductionMult] = 0
Strict.strictify(PLAYER_MODIFIER_DEFAULTS)

-- Weapon modifier tables keyed by item level.
-- Note: Right now, WeaponMultiplier.s.DamageMult here is matched to EnemyModifiers.s.HealthMult in DungeonTierModifiers.
local WeaponILvlModifierSource = {
	-- These damage values also get modified by WeaponWeightModifierSource and WeaponRarityModifierSource below.
	-- A Light weapon will be slightly below "balanced", and a Heavy weapon will be slightly above "balanced".
	{ [PlayerModifierNames.s.DamageMult] = 0.05 }, -- TREEMON FOREST -- If the first dungeon is 0.0, then it will provide no damage boost.
	{ [PlayerModifierNames.s.DamageMult] = 0.1 },  -- OWLITZER FOREST
	{ [PlayerModifierNames.s.DamageMult] = 0.2 },  -- BANDICOOT SWAMP
	{ [PlayerModifierNames.s.DamageMult] = 0.4 },
	{ [PlayerModifierNames.s.DamageMult] = 0.6 },
	{ [PlayerModifierNames.s.DamageMult] = 0.8 },
	{ [PlayerModifierNames.s.DamageMult] = 1.0 },
	{ [PlayerModifierNames.s.DamageMult] = 1.2 },
	{ [PlayerModifierNames.s.DamageMult] = 1.4 },
	{ [PlayerModifierNames.s.DamageMult] = 1.6 },
	{ [PlayerModifierNames.s.DamageMult] = 1.8 },
}

local WeaponWeightModifierSource = {
	-- Light Weapons do slightly less damage, Heavy Weapons do slightly more damage.
	[Weight.EquipmentWeight.s.Light] =
	{
		[PlayerModifierNames.s.DamageMult] = -0.025,
	},
	[Weight.EquipmentWeight.s.Normal] =
	{
		[PlayerModifierNames.s.DamageMult] = 0,
	},
	[Weight.EquipmentWeight.s.Heavy] =
	{
		[PlayerModifierNames.s.DamageMult] = 0.025,
	},
}
local WeaponRarityModifierSource = {
	-- Rarity of the weapon slightly affects the damage output.
	[ITEM_RARITY.s.COMMON] =
	{
		[PlayerModifierNames.s.DamageMult] = -0.05,
	},
	[ITEM_RARITY.s.UNCOMMON] =
	{
		[PlayerModifierNames.s.DamageMult] = 0,
	},
	[ITEM_RARITY.s.EPIC] =
	{
		[PlayerModifierNames.s.DamageMult] = 0.05,
	},
	[ITEM_RARITY.s.LEGENDARY] =
	{
		[PlayerModifierNames.s.DamageMult] = 0.1,
	},
	[ITEM_RARITY.s.TITAN] =
	{
		[PlayerModifierNames.s.DamageMult] = 0.15,
	},
}
-- Armour modifier tables keyed by item level.
-- Note: Right now, ArmourModifiers.s.DungeonTierDamageReductionMult here is matched to CombatModifiers.s.DungeonTierDamageMult in
-- DungeonTierModifiers.

-- Spreadsheet to help sketch these numbers: https://docs.google.com/spreadsheets/d/15grup3aGw-N0WyFkQ9LITqLSyldMmtSbJ4SQOCSNEvw/edit#gid=0

local ArmourILvlModifierSource = {
	-- These are further modified by ArmourWeightModifierSource and ArmourRarityModifierSource below.
	-- A full set of Normal Armour of a given dungeon should result in this damage reduction, which is tuned in relation to the enemy's damage increase.
	-- A full set of Light Armour will be slightly below this, and a full set of Heavy Armour will be slightly above this.
	-- In addition, there are 3 tiers of Rarity within a dungeon: Common, Uncommon, and Epic. This will further adjust.
	{ [PlayerModifierNames.s.DungeonTierDamageReductionMult] = 0.05 }, -- If the first dungeon is 0.0, then it will provide no armour boost.
	{ [PlayerModifierNames.s.DungeonTierDamageReductionMult] = 0.1 },
	{ [PlayerModifierNames.s.DungeonTierDamageReductionMult] = 0.2 },
	{ [PlayerModifierNames.s.DungeonTierDamageReductionMult] = 0.4 },
	{ [PlayerModifierNames.s.DungeonTierDamageReductionMult] = 0.6 },
	{ [PlayerModifierNames.s.DungeonTierDamageReductionMult] = 0.8 },
	{ [PlayerModifierNames.s.DungeonTierDamageReductionMult] = 1.0 },
	{ [PlayerModifierNames.s.DungeonTierDamageReductionMult] = 1.2 },
	{ [PlayerModifierNames.s.DungeonTierDamageReductionMult] = 1.4 },
	{ [PlayerModifierNames.s.DungeonTierDamageReductionMult] = 1.6 },
	{ [PlayerModifierNames.s.DungeonTierDamageReductionMult] = 1.8 },
}

local ArmourWeightModifierSource = {
	[Weight.EquipmentWeight.s.Light] =
	{
		[PlayerModifierNames.s.DungeonTierDamageReductionMult] = -0.05,
	},
	[Weight.EquipmentWeight.s.Normal] =
	{
		[PlayerModifierNames.s.DungeonTierDamageReductionMult] = 0,
	},
	[Weight.EquipmentWeight.s.Heavy] =
	{
		[PlayerModifierNames.s.DungeonTierDamageReductionMult] = 0.3,
	},
}

local ArmourRarityModifierSource = {
	-- Rarity of the armour slightly affects the damage reduction.
	[ITEM_RARITY.s.COMMON] =
	{
		[PlayerModifierNames.s.DungeonTierDamageReductionMult] = -0.05,
	},
	[ITEM_RARITY.s.UNCOMMON] =
	{
		[PlayerModifierNames.s.DungeonTierDamageReductionMult] = 0,
	},
	[ITEM_RARITY.s.EPIC] =
	{
		[PlayerModifierNames.s.DungeonTierDamageReductionMult] = 0.05,
	},
	[ITEM_RARITY.s.LEGENDARY] =
	{
		[PlayerModifierNames.s.DungeonTierDamageReductionMult] = 0.1,
	},
	[ITEM_RARITY.s.TITAN] =
	{
		[PlayerModifierNames.s.DungeonTierDamageReductionMult] = 0.15,
	},
}

local default_vision_tuning =
{
	retarget_period = 1,
	aggro_range = 20,
	too_far_retarget = 1000, -- If this is lower than aggro_range, you can walk away from an enemy to make it lose its target and disengage from battle.
	retarget_range = 55,     -- If you have a target, and the target is farther away than this, allow switching to a more nearby target. (use 'too_near_switch_target')
	too_near_switch_target = 25, -- If there is a possible target within this range, and your existing target is further away than 'retarget_range'
	share_target_range = 50,
	share_target_tags = { "mob" },
	share_not_target_tags = { "INLIMBO" },
}
local elite_vision_tuning =
{
	retarget_period = 1,
	aggro_range = 70,
	too_far_retarget = 1000, -- If this is lower than aggro_range, you can walk away from an enemy to make it lose its target and disengage from battle.
	retarget_range = 60,     -- If you have a target, and the target is farther away than this, allow switching to a more nearby target. (use 'too_near_switch_target')
	too_near_switch_target = 25, -- If there is a possible target within this range, and your existing target is further away than 'retarget_range'
	share_target_range = 55,
	share_target_tags = { "mob" },
	share_not_target_tags = { "INLIMBO" },
}

local function GetLastPlayerCount()
	return TheDungeon:GetDungeonMap():GetLastPlayerCount() or 1
end

-- Merge tables of modifiers. 'modifiers' itself is an array-like tables of keys.
-- The mergeable tables are dict-like tables keyed by the modifiers.
-- (This is like Lume:sum(), but filtered against explicit keys).
function ResolveModifiers(modifiers, ...)
	local merged = {}
	local arg_count = select("#", ...)
	for _, modifier in ipairs(modifiers) do
		local sum = 0
		for i = 1, arg_count do
			local tuning = select(i, ...)
			local value = tuning[modifier]
			if value then
				sum = sum + value
			end
		end
		merged[modifier] = sum
	end
	Strict.strictify(merged)
	return merged
end

local function BuildTuning()
    local Tuning = {
		-- victorc: 60Hz, hit shudder was expressed in ticks, is now anim frames
        HITSHUDDER_AMOUNT_LIGHT = 6,
        HITSHUDDER_AMOUNT_MEDIUM = 8,
        HITSHUDDER_AMOUNT_HEAVY = 12,

        PUSHBACK_DISTANCE_DEFAULT = 0.2,

        PLAYER_POSTHIT_IFRAMES = 8, -- NOTE: This kicks in -after- hitstop and hitstun is over. The entirety of hitstop/hitstun is invincible.
        PLAYER_HEALTH = 900,
        PLAYER_LUCK = 0.01,
        PLAYER_HITBOX_SIZE = 0.6, -- NOTE: Although the hitbox is printed in 2d on the floor, our hitboxes have to represent verticality, too. Size this based on the player's body, not just the position of the box around the feet.

		CRIT_PUSHBACK_MULT = 1,
		CRIT_HITSTOP_EXTRA_FRAMES = 2, -- expressed as anim frames

        HITSTOP_TO_PLAYER_EXTRA_FRAMES = 1, -- expressed as anim frames
		HITSTOP_PLAYER_QUICK_RISE_FRAMES = 2,
		HITSTOP_PLAYER_KILL_DELAY_FRAMES = 1, --when a player gets killed, how many anim frames should we wait before applying kill hitstop?
		HITSTOP_BOSS_KILL_DELAY_FRAMES = 2, --when a boss gets killed, how many anim frames should we wait before applying kill hitstop?

		HITSTOP_LAST_KILL_EXTRA_FRAMES = 5, -- expressed as anim frames
		LAST_KILL_DELTATIME_MULTIPLIER = 0.5, -- When we kill the last enemy in the room, how slow should our animstate move?
		LAST_KILL_DELTATIME_MULTIPLIER_FRAMES = 15, -- When we kill the last enemy in the room, for how many frames should our animstate slow?

        POTION_HOLD_TICKS = 0, -- Number of frames the player has to hold the "potion" button before we start to execute the potion drink. Prevents accidental presses.
        POTION_AOE_RANGE = 6, -- When a player drinks a potion, in what range should it heal friendlies?
        POTION_AOE_PERCENT = 0.4, -- When a player drinks a potion, what % of the self-heal should be applied to friendlies?

        REVIVE_TIME = 2,
        REVIVE_HEALTH_PERCENT = 0.4,

        ENEMY_FRIENDLY_FIRE_DAMAGE_MULTIPLIER = 1/3, -- When an enemy deals damage to another enemy how much should the damage be affected?

        GEM_DEFAULT_UPDATE_THRESHOLDS =
		{
			-- percentage of a level completed -- stored on creation of a gem with an associated bool for whether that threshold has been updated or not
			0.85,
			0.75,
			0.5,
			0.25,
			0.01, -- Basically, update the first time it happens
		},

		DEFAULT_MINIMUM_COOLDOWN = 2,

		PLAYER =
		{
			HIT_STREAK =
			{
				BASE_DECAY = 1.2,
				KILL_BONUS = 0.3,
				FOCUS_KILL_BONUS = 0.4,
				MAX_TIME = 1.65,
			},

			ROLL =
			{
				NORMAL =
				{
					IFRAMES = 12,
					DISTANCE = 3,
					LENGTH_ANIMFRAMES = 9,
				},
				LIGHT =
				{
					IFRAMES = 7,
					DISTANCE = 4.5,
					LENGTH_ANIMFRAMES = 5,
				},
				HEAVY =
				{
					IFRAMES = 10,
					DISTANCE = 2.7,
					LENGTH_ANIMFRAMES = 11,
				},
			},

			POTION_HOLD_REQUIREMENT_FRAMES = 5, -- How many frames does the player have to hold the 'potion' button before we accept that they wanted to drink. Used to prevent accidental drinks.
		},

		FLICKERS = -- Separating these out for easy access for a possible epilepsy-disabling mode
		{
			PLAYER_QUICK_RISE =
			{
				COLOR = { 170/255, 170/255, 170/255 },
				FLICKERS = 4,
				FADE = true,
				TWEENS = true,
			},
			BOMB_WARNING =
			{
				COLOR = { 204/255, 128/255, 204/255 },
				FLICKERS = 14,
				FADE = false,
				TWEENS = false,
			},
			SPIKE_WARNING =
			{
				COLOR = { 179/255, 51/255, 179/255 },
				FLICKERS = 4,
				FADE = false,
				TWEENS = false,
			},
			WEAPONS =
			{
				HAMMER =
				{
					CHARGE_COMPLETE =
					{
						COLOR = { 180/255, 180/255, 180/255, 1 },
						FLICKERS = 2,
						FADE = false,
						TWEENS = false,
					},
					FOCUS_SWING =
					{
						COLOR = { 0/255, 150/255, 190/255, .5 },
					},
				},
			},
			POWERS =
			{
				MULLIGAN = -- Player has iframes during this flicker
				{
					COLOR = { 90/255, 30/255, 90/255 },
					FLICKERS = 10,
					FADE = true,
					TWEENS = false,
				},
			},
		},

		BLINK_AND_FADES = -- Separating these out for easy access for a possible epilepsy-disabling mode
		{
			-- "FRAMES" IS ANIMATION FRAMES
			PLAYER_DEATH =
			{
				-- This happens after hitstop has finished
				-- On impact, immediately jump to this colour, then after the hitstop has finished, release the colour with this frame count as a fade
				COLOR = { 230/255, 160/255, 200/255 },
				FRAMES = 4,
			},

			POWER_DROP_KONJUR_PROXIMITY =
			{
				-- This is when the player touches the konjur blob, right before it bursts
				COLOR = { 100/255, 100/255, 100/255 },
				FRAMES = 4,
			},
		},

		KONJUR_ON_SKIP_SKILL = 35, --
		KONJUR_ON_SKIP_POWER = 35, -- Konjur given by skipping a power should be less than konjur given by choosing a "Konjur Reward" room. See konjurreward.lua
								   -- Also consider the amount a potion costs, currently 75K. Should one relic skip == a free potion? Skipping power should be "damn, I should have gone for Konjur Reward!" not rewarding itself
		KONJUR_ON_SKIP_POWER_FABLED = 100, -- comparable reward here is a Hard Konjur Reward, which is currently tuned as 130-170. Be less than that.

		LOOT =
		{
			--[[
			Legacy tuning, before we moved to a system of "chunkier" loot
			DROP_CHANCE = -- drop weights
			{
				-- total = 100, as long as that is true these are also % chances
			    [ITEM_RARITY.s.COMMON] = 60,-- 40,
			    [ITEM_RARITY.s.UNCOMMON] = 25,--30,
			    [ITEM_RARITY.s.RARE] = 10, --20,
			    [ITEM_RARITY.s.EPIC] = 4,-- 9,
			    [ITEM_RARITY.s.LEGENDARY] = 1,
			},
			--]]
		},

        POWERS =
        {
			DROP_SPAWN_INITIAL_DELAY_FRAMES = 1 * SECONDS, -- After the last enemy is killed in a room, how long should we wait before spawning the power drop? Give the player some time to process the final kill.
			DROP_SPAWN_SEQUENCE_DELAY_FRAMES_FABLED = 0.5 * SECONDS, -- When spawning multiple power drops (fabled relics), how much delay should exist between the two spawning?
			DROP_SPAWN_SEQUENCE_DELAY_FRAMES_PLAIN = 0.3 * SECONDS,

			DROP_CHANCE = -- starting drop chances
			{
			    COMMON = 80,
			    EPIC = 20,
			    LEGENDARY = 0,
			},

			DROP_CHANCE_INCREASE = -- when these types are not rolled, how much more likely should seeing one of them become next roll? measured in %
			{
				{ -- difficulty "1/ tutorial" rooms
					COMMON = 0,
					EPIC = 2,
					LEGENDARY = 1
				},
				{  -- difficulty "2/ easy" rooms
					COMMON = 0,
					EPIC = 2,
					LEGENDARY = 1
				},
				{  -- difficulty "3/ hard" rooms
					COMMON = 0,
					EPIC = 8,
					LEGENDARY = 4
				},
			},

			UPGRADE_PRICE =
			{
				COMMON = 75, -- Common to Epic
				EPIC = 150, -- Epic to Legendary
			},
        },

        GEAR =
        {
			STAT_ALLOCATION_PER_SLOT =
			{
				-- When we tune armour sets, we want to tune for how much the entire set should give you.
				-- If an armour set is meant to give 10% Damage Reduction, how should that 10% be divvied out across the pieces?
				BODY = 0.5,
				WAIST = 0.25,
				HEAD = 0.25,
			},

			WEAPONS =
	        {
				DAMAGE_PER_ILVL = 2,
				DAMAGE_RARITY_MULTIPLIERS =
				{
					-- If we are ilvl 10, our base damage bonus is 15*10 = 50.
					-- Based on rarity, modify that further:
					[ITEM_RARITY.s.COMMON] = 0,
					[ITEM_RARITY.s.UNCOMMON] = 1,
					[ITEM_RARITY.s.EPIC] = 1.25,
					[ITEM_RARITY.s.LEGENDARY] = 1.5,
					[ITEM_RARITY.s.TITAN] = 1.75,
				},

				BASE_FOCUS_DAMAGE_MULT = 1,
				BASE_CRIT_DAMAGE_MULT = 2,

				HAMMER =
				{
					BASE_DAMAGE = 60,
					BASE_CRIT = 0.01,
				},
				POLEARM =
				{
					BASE_DAMAGE = 50,
					BASE_CRIT = 0.01,
				},
				CANNON =
				{
					BASE_DAMAGE = 60,
					BASE_CRIT = 0.01,
					ROLL_VELOCITY = 11,
					AMMO = 6,
				},
				SHOTPUT =
				{
					-- Normal  DISTANCE = 3,
					-- Light DISTANCE = 4.5,
					-- Heavy DISTANCE = 2.25,
					BASE_DAMAGE = 75,
					BASE_CRIT = 0.01,
					ROLL_DISTANCE_OVERRIDE =
					{
						-- Make Normal a bit faster to make mobility better when having no ball / trying to line up ball shots
						-- Make Light a bit slower so that it's easier to steer
						-- Make Heavy a bit faster so it's easier to actually do Ball stuff
						NORMAL = 3.6,
						LIGHT = 4.25,
						HEAVY = 2.5,
					},
					AMMO = 2,
				},
				CLEAVER =
				{
					BASE_DAMAGE = 100,
					BASE_CRIT = 0.05,
				},
	        },

	        ARMOUR =
	        {
				ARMOUR_PER_ILVL = 0.01, --1% damage reduction per ilvl
				ARMOUR_MULTIPLIERS =
				{
					-- If we are ilvl 10, our base Armour is 10*50 = 500.
					-- Based on rarity, modify that further:
					[ITEM_RARITY.s.COMMON] = 0.75,
					[ITEM_RARITY.s.UNCOMMON] = 1,
					[ITEM_RARITY.s.EPIC] = 1.25,
					[ITEM_RARITY.s.LEGENDARY] = 1.5,
					[ITEM_RARITY.s.TITAN] = 1.75,
				},
	        },
        },

        MONSTER_RESEARCH =
        {
			RARITY_TO_EXP =
			{
				[ITEM_RARITY.s.UNCOMMON] = 10,
				[ITEM_RARITY.s.EPIC] = 30,
				[ITEM_RARITY.s.LEGENDARY] = 50,
			},
        },

        TRAPS =
        {
			DAMAGE_TO_PLAYER_MULTIPLIER = 1/3,

			trap_spike =
			{
				BASE_DAMAGE = 300,
				COLLISION_DATA = nil,
				HEALTH = nil,
			},
			trap_exploding =
			{
				BASE_DAMAGE = 500,
				COLLISION_DATA =
				{
					SIZE = .5,
					MASS = 1000000000000,
					COLLISIONGROUP = COLLISION.SMALLOBSTACLES,
					COLLIDESWITH = { COLLISION.CHARACTERS, COLLISION.ITEMS, COLLISION.GIANTS }
				},
				HEALTH = 1,
				WARNING_COLORS =
				{
					{0, 0, 0, 0},
					{140/255, 20/255, 100/255, 1},
					{255/255, 170/255, 200/255, 1},
				}
			},
			trap_zucco = {
				BASE_DAMAGE = 200,
			},
			trap_bananapeel = {
				BASE_DAMAGE = 0, -- This trap only applies a knockdown
			},
			trap_spores = {
				BASE_DAMAGE = 0, -- Most spores do 0 damage and only apply an effect.
				DAMAGE_VERSION_BASE_DAMAGE = 300, -- How much damage the DAMAGE spores do
				DAMAGE_VERSION_BASE_HEAL = 300, -- How much healing the HEAL spores do
				HEALTH = 1,
				COLLISION_DATA =
				{
					SIZE = .5,
					MASS = 1000000000000,
					COLLISIONGROUP = COLLISION.SMALLOBSTACLES,
					COLLIDESWITH = { }
				},
				VARIETIES =
				{
					trap_spores_juggernaut =
					{
						power = "juggernaut",
						stacks = 25,
						burst_fx = "fx_spores_juggernaut_all",
						target_fx = "spore_hit_juggernaut"
					},

					trap_spores_smallify =
					{
						power = "smallify",
						stacks = 1,
						burst_fx = "fx_spores_shrink_all",
						target_fx = "spore_hit_shrink"
					},

					trap_spores_shield =
					{
						power = "shield",
						stacks = 4,
						burst_fx = "fx_spores_shield_all",
						target_fx = "spore_hit_shield"
					},

					trap_spores_confused =
					{
						power = "confused",
						stacks = 1,
						burst_fx = "fx_spores_confused_all",
						target_fx = "spore_hit_confused"
					},

					trap_spores_heal =
					{
						power = "override",
						override_effect = "heal", -- Amount of healing is in TUNING.TRAPS.trap_spores, scaled down *1/3 against players
						burst_fx = "fx_spores_heal_all",
						target_fx = "spore_hit_heal",
						disable_hit_reaction = true,
					},

					trap_spores_damage =
					{
						power = "override",
						override_effect = "damage", -- Amount of damage is in TUNING.TRAPS.trap_spores, scaled down *1/3 against players
						burst_fx = "fx_spores_damage_all",
						target_fx = "spore_hit_damaged"
					},

					trap_spores_groak =
					{
						power = "override",
						override_effect = "summon_groak", -- Amount of damage is in TUNING.TRAPS.trap_spores, scaled down *1/3 against players
						burst_fx = "fx_spores_groak_all",
					},
				}
			},

			trap_acid = {
				BASE_DAMAGE = 30,
				TICKS_BETWEEN_PROCS = 45,
				AURA_APPLYER = true,
				DAMAGE_TO_MOBS_MULTIPLIER = 1/3,
			},

			trap_windtotem = {
				BASE_DAMAGE = 0,
				AURA_APPLYER = true,
				AURA_DATA =
				{
					effect = "windtotem_wind",
					beamhitbox = { -0.5, 50, 3.00 },
				},
			},

			trap_thorns =
			{
				BASE_DAMAGE = 60,
				COLLISION_DATA =
				{
					SIZE = 1.2,
					MASS = 1000000000000,
					COLLISIONGROUP = COLLISION.OBSTACLES,
					COLLIDESWITH = { COLLISION.CHARACTERS, COLLISION.ITEMS }
				},
				HEALTH = nil,
			},

			swamp_stalactite =
			{
				BASE_DAMAGE = 400,
				HEALTH = 200,
				fx = { "stalag", "konjur" },
			},

			swamp_stalagmite =
			{
				HEALTH = 200,
				fx = { "stalag", "konjur" },
			},

			trap_stalactite = {
				BASE_DAMAGE = 0,
			},

			owlitzer_spikeball = {
				BASE_DAMAGE = 40
			},

			tundra_torch =
			{
				HEAT_POINTS = 10,
				STAY_HEAT_TIME = 10,
				COOLDOWN = 0.2, -- Per second
			},
        },

		player = {
			run_speed = PLAYER_MOVE_SPEED_MOD * 8,
			attack_angle_clamp = 30, -- When the player moves forward during attacking, what angle should we clamp to?
			attack_angle_zero_deadzone = 20,  -- When the player attacks more-or-less directly in front of itself (relative to the waist), below what angle should we just clamp to 0?

			extra_controlqueueticks_on_hitstop_mult = 3, -- When the player has hitstop applied to them, modify their controlqueueticks by the amount of hitstop multiplied by this number.
														 -- Increase this if it feels like your button presses are being "eaten" by pressing again too early when you hit an enemy.
			extra_controlqueueticks_on_hitstop_maximum = 15, -- When the above modification happens, what is the maximum amount of frames we're allowed to add?
															 -- Decrease this if it feels like the game is sluggish to respond to your button presses when you press after hitting an enemy.
			extra_controlqueueticks_on_hitstop_minimum = 10, -- When the above modification happens, what is the maximum amount of frames we're allowed to add?
		},

		MYSTERIES = {
			ROOMS = {
				CHANCES = -- starting drop chances
				{
					monster = 30,
					potion = 5,
					powerupgrade = 5,
					wanderer = 60, --bank choice: when the other types are not rolled, they get increased chance to roll next time. that % comes from this choice
					-- ranger = 35, -- JAMBELL: Original tuning was 35, disabling for Early Access.
				},

				CHANCE_INCREASE = -- when these types are not rolled, how much more likely should seeing one of them become next roll? measured in %
				{
					monster = 15,
					potion = 10,
					powerupgrade = 10,
					ranger = 20,
					wanderer = 0, --bank choice
				},
			},
			MONSTER_CHANCES = {
				-- If a monster room is chosen,
				DIFFICULTIES =
				{
					medium = 35,
					hard = 65,
				},

				REWARDS =
				{
					medium = {
						plain = 50,
						coin = 50,
					},
					hard = {
						fabled = 60,
						coin = 40,
					},
				},
			},
		},

        ----- Monsters

        ----- Starting Forest
		cabbageroll_elite = {
			loot_value = 1/3,
			health = 450,
			base_damage = 135,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		cabbageroll = {
			loot_value = 1/40,
			health = 300,
			base_damage = 90,
			vision = default_vision_tuning,
			roll_animframes = 20,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 3,
			speedmult = {
				steps = 6,
				scale = 0.3,
				centered = true,
			},
			steeringlimit = 720,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.BASIC,
			charm_colors = {
				color_add = { 28/255, 0/255, 58/255, 1 },
				color_mult = { 255/255, 160/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		-- dummy tuning table, used only for the encounter debugger
		cabbagerolls2 =
		{
			health = 600,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.BASIC,
		},

		-- dummy tuning table, used only for the encounter debugger
		cabbagerolls =
		{
			health = 900,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.BASIC,
		},

		blarmadillo_elite = {
			loot_value = 1/3,
			health = 750,
			base_damage = 135,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		blarmadillo = {
			loot_value = 1/12,
			health = 500,
			base_damage = 90,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 4.2,
			roll_animframes = 10,
			speedmult = {
				steps = 5,
				scale = 0.2,
				centered = true,
			},
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.BASIC,
			steeringlimit = 360,
			charm_colors = {
				color_add = { 28/255, 0/255, 38/255, 1 },
				color_mult = { 220/255, 169/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
			charm_colors_projectile = {
				color_add = { 28/255, 0/255, 38/255, 1 },
				color_mult = { 220/255, 169/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		shellsquid_elite = {
			loot_value = 1.50,
			health = 750,
			base_damage = 135,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		shellsquid = {
			loot_value = 0.50,
			health = 500,
			base_damage = 90,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 4.2,
			dash = {
				duration_frames = 1 * SECONDS,
				fire_distance = 1.0,
				stopping_distance = 1.0,
				movespeed = 20, -- blarm roll is 12
				min_dash_distance = 15,
				max_dash_distance = 20,
			},
			pierce = {
				movespeed = 2,
			},
			speedmult = {
				steps = 5,
				scale = 0.2,
				centered = true,
			},
			steeringlimit = 360,
			charm_colors = {
				color_add = { 28/255, 0/255, 38/255, 1 },
				color_mult = { 220/255, 169/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
			charm_colors_projectile = {
				color_add = { 28/255, 0/255, 38/255, 1 },
				color_mult = { 220/255, 169/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		yammo_elite = {
			loot_value = 1,
			health = 2250,
			base_damage = 230,
			vision = elite_vision_tuning,
			charge_speed = MONSTER_MOVE_SPEED_MOD * 6.66,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		yammo = {
			loot_value = 1/3,
			health = 1500,
			base_damage = 200,
			hitstun_pressure_frames = 90,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 2.75,
			speedmult = {
				steps = 4,
				scale = 0.2,
				centered = false,
			},
			steeringlimit = 180,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.MAJOR,
			charm_colors = {
				color_add = { 28/255, 0/255, 58/255, 1 },
				color_mult = { 220/255, 169/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
			colorshift = {
				HSB(0, 100, 100),
				HSB(10, 100, 100),
				HSB(-8, 100, 100),
			},
		},

		zucco_elite = {
			loot_value = 1,
			health = 1500,
			base_damage = 180,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		zucco = {
			loot_value = 1/3,
			health = 1250, -- Because Zucco attacks relentlessly and doesn't try to avoid damage, if he has too low of health he'll just die. Make sure he has enough health to get a full attack chain or two off, while under pressure.
			base_damage = 135,
			hitstun_pressure_frames = 60,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 6.75,
			run_speed = MONSTER_MOVE_SPEED_MOD * 6.0,
			steeringlimit = 360,
			speedmult = {
				steps = 4,
				scale = 0.2,
				centered = false,
			},
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.MINOR,
			charm_colors = {
				color_add = { 38/255, 0/255, 68/255, 1 },
				color_mult = { 255/255, 145/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
			custom_puppet_scale = 0.3, -- it's a bit larger than cabbagerolls and blarmadillos
			colorshift = {
				HSB(0, 100, 100),
				HSB(-8, 100, 100),
				HSB(8, 100, 100),
			},
		},

		gourdo_elite = {
			loot_value = 1/2,
			health = 2500,
			base_damage = 200,
			butt_slam_pst_knockdown_seconds = 2,
			healing_seed = {
				health = 350,
				heal_amount = 350,
				heal_radius = 80,
				heal_period = 3.6,
			},
			vision = elite_vision_tuning,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		gourdo = {
			loot_value = 1/3,
			health = 1700,
			base_damage = 160,
			hitstun_pressure_frames = 90,
			butt_slam_pst_knockdown_seconds = 2,
			healing_seed = {
				health = 300,
				heal_amount = 150,
				heal_radius = 10,
				heal_period = 2.5,
			},
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 2.6,
			speedmult = {
				steps = 4,
				scale = 0.2,
				centered = false,
			},
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.MAJOR,
			steeringlimit = 180,
			charm_colors = {
				color_add = { 28/255, 0/255, 88/255, 1 },
				color_mult = { 160/255, 230/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
			charm_colors_projectile = {
				color_add = { 50/255, 0/255, 35/255, 1 },
				color_mult = { 200/255, 170/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
			charm_colors_seed = {
				color_add = { 50/255, 0/255, 35/255, 1 },
				color_mult = { 200/255, 170/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
			colorshift = {
				HSB(0, 100, 100),
				HSB(8, 100, 100),
				HSB(-8, 100, 100),
			},
			colorshift_miniboss = {
				HSB(-25, 100, 100),
				HSB(25, 100, 100),
				HSB(-25, 100, 100),
			},
		},

		eyev_elite = {
			loot_value = 1,
			health = 1200,
			base_damage = 90,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		eyev =
		{
			loot_value = 0.5,
			health = 750,
			base_damage = 60,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 5.5,
			hitstun_pressure_frames = 32,
			speedmult = {
				steps = 4,
				scale = 0.2,
				centered = false,
			},
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.MINOR,
			steeringlimit = 720,
			charm_colors = {
				color_add = { 38/255, 0/255, 68/255, 1 },
				color_mult = { 255/255, 145/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		treemon_elite = {
			loot_value = 1/3,
			health = 900,
			base_damage = 100,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		treemon = {
			loot_value = 1/12,
			base_damage = 50,
			health = 450,
			stationary = true,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.MINOR,
			vision = default_vision_tuning,
			charm_colors = {
				color_add = { 28/255, 0/255, 88/255, 1 },
				color_mult = { 160/255, 230/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
			charm_colors_projectile = {
				color_add = { 50/255, 0/255, 35/255, 1 },
				color_mult = { 200/255, 170/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		gnarlic_elite = {
			loot_value = 1,
			health = 600,
			base_damage = 140,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		gnarlic =
		{
			loot_value = 1/40,
			health = 200,
			base_damage = 90,
			vision = default_vision_tuning,
			roll_animframes = 20,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 3,
			speedmult = {
				steps = 6,
				scale = 0.3,
				centered = true,
			},
			steeringlimit = 720,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.BASIC,
			charm_colors = {
				color_add = { 28/255, 0/255, 58/255, 1 },
				color_mult = { 255/255, 160/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		beets_elite = {
			loot_value = 1/3,
			health = 600,
			base_damage = 150,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},
		beets =
		{
			loot_value = 1/40,
			health = 200,
			base_damage = 90,
			vision = default_vision_tuning,
			roll_animframes = 20,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 2,
			speedmult = {
				steps = 6,
				scale = 0.3,
				centered = true,
			},
			steeringlimit = 720,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.BASIC,
			charm_colors = {
				color_add = { 28/255, 0/255, 58/255, 1 },
				color_mult = { 255/255, 160/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		windmon_elite = {
			loot_value = 1/3,
			health = 800,
			base_damage = 80,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		windmon = {
			loot_value = 1/12,
			base_damage = 40,
			health = 450,
			stationary = true,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.MINOR,
			vision = default_vision_tuning,
			charm_colors = {
				color_add = { 28/255, 0/255, 88/255, 1 },
				color_mult = { 160/255, 230/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
			charm_colors_projectile = {
				color_add = { 50/255, 0/255, 35/255, 1 },
				color_mult = { 200/255, 170/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		----- Swamp
		mothball_elite = {
			loot_value = 1/5,
			health = 750, -- Although this is a mothball, this is likely the single elite in the room. It should still be meaningful. Be wary of tuning too low!
			base_damage = 70,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 3.5,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		mothball =
		{
			loot_value = 1/180,
			health =  100, -- Make sure when changing this, that it is still easy and satisfying to mow through collections of mothballs. Too much health means they aren't easy to mow through! I should be able to Spear Drill through and kill them.
			base_damage = 35,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 3,
			speedmult = {
				steps = 4,
				scale = 0.2,
				centered = false,
			},
			steeringlimit = 720,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.SWARM,
			charm_colors = {
				color_add = { 38/255, 0/255, 68/255, 1 },
				color_mult = { 255/255, 145/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		mothball_teen_elite = {
			loot_value = 1,
			health = 1200,
			base_damage = 75,
			escape_speed = 15,
			escape_time = 2,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		mothball_teen =
		{
			loot_value = 1/5,
			health = 750,
			base_damage = 50,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 6,
			speedmult = {
				steps = 4,
				scale = 0.2,
				centered = false,
			},
			steeringlimit = 720,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.MINOR,
			charm_colors = {
				color_add = { 38/255, 0/255, 68/255, 1 },
				color_mult = { 255/255, 145/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
			charm_colors_projectile = {
				color_add = { 50/255, 0/255, 35/255, 1 },
				color_mult = { 200/255, 170/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},

			escape_speed = 14,
			escape_time = 1.3,
		},

		mothball_teen_projectile =
		{
			movement_speed = 4,
			acceleration = 0.6,
			slow_down_time = 0.5,
		},

		-- Slow effect projectile
		mothball_teen_projectile_elite =
		{
			movement_speed = 6,
		},

		-- Confuse effect projectile
		mothball_teen_projectile2_elite =
		{
			movement_speed = 4,
			acceleration = 0.6,
			slow_down_time = 0.5,
		},

		mothball_spawner =
		{
			loot_value = 1/5,
			health = 1000,
			base_damage = 50,
			vision = default_vision_tuning,
			speedmult = {
				steps = 4,
				scale = 0.2,
				centered = false,
			},
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.BASIC,
			charm_colors = {
				color_add = { 38/255, 0/255, 68/255, 1 },
				color_mult = { 255/255, 145/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		sporemon_elite = {
			loot_value = 1/3,
			health = 1300,
			base_damage = 180,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
			stationary = true,
		},

		sporemon = {
			loot_value = 1/12,
			base_damage = 100,
			health = 800,
			stationary = true,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.MINOR,
			vision = default_vision_tuning,
			charm_colors = {
				color_add = { 28/255, 0/255, 88/255, 1 },
				color_mult = { 160/255, 230/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
			charm_colors_projectile = {
				color_add = { 50/255, 0/255, 35/255, 1 },
				color_mult = { 200/255, 170/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		mossquito_elite = {
			loot_value = 1/3,
			health = 600,
			base_damage = 120,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 3,
			spray_interval = 13,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		mossquito = {
			loot_value = 1/40,
			health = 450,
			base_damage = 90,
			vision = default_vision_tuning,
			roll_animframes = 20,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 2,
			speedmult = {
				steps = 6,
				scale = 0.3,
				centered = true,
			},
			steeringlimit = 720,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.BASIC,
			charm_colors = {
				color_add = { 28/255, 0/255, 58/255, 1 },
				color_mult = { 255/255, 160/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
			spray_interval = 26,
		},

		battoad_elite = {
			loot_value = 1/3,
			health = 1100,
			base_damage = 100,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		battoad =
		{
			loot_value = 1/4,
			health = 750,
			base_damage = 75,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 7, -- hopping speed
			walk_speed_fleeing = MONSTER_MOVE_SPEED_MOD * 10, -- hopping speed while running away after eating konjur
			run_speed = MONSTER_MOVE_SPEED_MOD * 6, -- flying speed
			speedmult = {
				steps = 4,
				scale = 0.2,
				centered = false,
			},
			steeringlimit = 720,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.MINOR,
			charm_colors = {
				color_add = { 38/255, 0/255, 68/255, 1 },
				color_mult = { 255/255, 145/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
			charm_colors_projectile = {
				color_add = { 50/255, 0/255, 35/255, 1 },
				color_mult = { 200/255, 170/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		bulbug_elite = {
			health = 1250 * 1.5,
			base_damage = 50 * 2,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		bulbug =
		{
			loot_value = 1,
			health = 1250,
			base_damage = 50,
			hitstun_pressure_frames = 60,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 6,
			speedmult = {
				steps = 4,
				scale = 0.2,
				centered = false,
			},
			steeringlimit = 720,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.MAJOR,
			charm_colors = {
				color_add = { 38/255, 0/255, 68/255, 1 },
				color_mult = { 255/255, 145/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
			charm_colors_projectile = {
				color_add = { 50/255, 0/255, 35/255, 1 },
				color_mult = { 200/255, 170/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		floracrane_elite = {
			health = 2250, -- tune relative to Yammo Elite
			base_damage = 180,
			bird_kick_move_speed = 3,
			vision = elite_vision_tuning,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		floracrane =
		{
			loot_value = 1,
			health = 1750,
			base_damage = 130,
			bird_kick_move_speed = 1.5,
			hitstun_pressure_frames = 80,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 4.5,
			speedmult = {
				steps = 4,
				scale = 0.2,
				centered = false,
			},
			steeringlimit = 720,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.MAJOR,
			charm_colors = {
				color_add = { 38/255, 0/255, 68/255, 1 },
				color_mult = { 255/255, 145/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		groak_elite = {
			health = 2000* 1.5,
			base_damage = 80 * 1.5,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 3,
			vision = elite_vision_tuning,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		groak = {
			loot_value = 1,
			health = 2000,
			base_damage = 80,
			hitstun_pressure_frames = 90,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 3,
			speedmult = {
				steps = 4,
				scale = 0.2,
				centered = false,
			},
			steeringlimit = 180,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.MAJOR,
			charm_colors = {
				color_add = { 28/255, 0/255, 58/255, 1 },
				color_mult = { 220/255, 169/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		slowpoke_elite = {
			loot_value = 1/3,
			health = 800 * 1.5,
			base_damage = 110 * 2,
			num_slams = 3,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		slowpoke = {
			loot_value = 1/20,
			health = 800,
			base_damage = 110,
			hitstun_pressure_frames = 90,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 2,
			speedmult = {
				steps = 4,
				scale = 0.2,
				centered = false,
			},
			steeringlimit = 90,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.MINOR,
			charm_colors = {
				color_add = { 28/255, 0/255, 58/255, 1 },
				color_mult = { 220/255, 169/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		swarmy = {
			loot_value = 1/20,
			health = 400,
			base_damage = 90,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 3.5,
			speedmult = {
				steps = 6,
				scale = 0.3,
				centered = true,
			},
			steeringlimit = 720,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.BASIC,
			charm_colors = {
				color_add = { 28/255, 0/255, 58/255, 1 },
				color_mult = { 255/255, 160/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		woworm_elite = {
			health = 900,
			base_damage = 220,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		woworm = {
			loot_value = 1/20,
			health = 500,
			base_damage = 110,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 2.2,
			speedmult = {
				steps = 6,
				scale = 0.3,
				centered = true,
			},
			steeringlimit = 720,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.BASIC,
			charm_colors = {
				color_add = { 28/255, 0/255, 58/255, 1 },
				color_mult = { 255/255, 160/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		totolili_elite = {
			loot_value = 1/3,
			health = 1200,
			base_damage = 180,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		totolili = {
			loot_value = 1/6,
			health = 600,
			base_damage = 90,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 3.5,
			speedmult = {
				steps = 6,
				scale = 0.3,
				centered = true,
			},
			steeringlimit = 720,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.MINOR,
			charm_colors = {
				color_add = { 28/255, 0/255, 58/255, 1 },
				color_mult = { 255/255, 160/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		----- Ice Biome
		warmy = {
			loot_value = 1, --FIX ME
			health = 600, -- FIX ME
			base_damage = 90, -- FIX ME
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 7.5,
			speedmult = {
				steps = 6,
				scale = 0.3,
				centered = true,
			},
			steeringlimit = 720,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.BASIC,
			charm_colors = {
				color_add = { 28/255, 0/255, 58/255, 1 },
				color_mult = { 255/255, 160/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		bunippy_elite = {
			health = 800,
			base_damage = 150,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},
		bunippy =
		{
			loot_value = 1/60,
			health = 400,
			base_damage = 90,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 4,
			speedmult = {
				steps = 6,
				scale = 0.3,
				centered = true,
			},
			steeringlimit = 720,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.BASIC,
			charm_colors = {
				color_add = { 28/255, 0/255, 58/255, 1 },
				color_mult = { 255/255, 160/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		meowl_elite = {
			health = 1000,
			base_damage = 200,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},
		meowl =
		{
			loot_value = 1/60,
			health = 500,
			base_damage = 100,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 4,
			speedmult = {
				steps = 6,
				scale = 0.3,
				centered = true,
			},
			steeringlimit = 720,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.BASIC,
			charm_colors = {
				color_add = { 28/255, 0/255, 58/255, 1 },
				color_mult = { 255/255, 160/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
		},

		antleer_elite = {
			loot_value = 1,
			health = 1400,
			base_damage = 200,
			vision = elite_vision_tuning,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		antleer = {
			loot_value = 1,
			health = 800,
			base_damage = 140,
			hitstun_pressure_frames = 60,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 3,
			speedmult = {
				steps = 4,
				scale = 0.2,
				centered = false,
			},
			steeringlimit = 180,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.MAJOR,
			charm_colors = {
				color_add = { 28/255, 0/255, 58/255, 1 },
				color_mult = { 220/255, 169/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
			colorshift = {
				HSB(0, 100, 100),
				HSB(10, 100, 100),
				HSB(-8, 100, 100),
			},
		},

		crystroll_elite = {
			loot_value = 1,
			health = 2400,
			base_damage = 240,
			vision = elite_vision_tuning,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.ELITE,
		},

		crystroll = {
			loot_value = 1,
			health = 1600,
			base_damage = 200,
			hitstun_pressure_frames = 60,
			vision = default_vision_tuning,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 2,
			speedmult = {
				steps = 4,
				scale = 0.2,
				centered = false,
			},
			steeringlimit = 180,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.MAJOR,
			charm_colors = {
				color_add = { 28/255, 0/255, 58/255, 1 },
				color_mult = { 220/255, 169/255, 255/255, 1 },
				bloom = { 64/255, 0/255, 70/255, 0.5 },
			},
			colorshift = {
				HSB(0, 100, 100),
				HSB(10, 100, 100),
				HSB(-8, 100, 100),
			},
		},

		----- Bosses

		bandicoot = {
			loot_value = 3,
			base_damage = 200,
			health = 17000,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 6,
			run_speed = MONSTER_MOVE_SPEED_MOD * 9,
			steeringlimit = 360,
			vision = {
				retarget_period = 1,
				aggro_range = 30,
				retarget_range = 55,
				too_near_switch_target = 25,
				too_far_retarget = 10000,
				share_target_range = 50,
				share_target_tags = { "mob" },
				share_not_target_tags = { "INLIMBO" },
			},
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.BOSS,
			num_clones_normal =
			{
				1, -- +real bandicoot = 2 monsters on battlefield (for 1 player)
				1,
				2,
				2, -- (4 players)
			},
			num_clones_low_health =
			{
				1,
				1,
				2,
				2,
			},
			max_mobs =
			{
				8,
				9,
				10,
				12,
			},
			spore_weights =
			{
				trap_spores_damage = 55,
				trap_spores_heal = 42.5,
				-- trap_spores_groak = 2.5,
			},
			clone_spawn_move_speed = 15,
		},

		bandicoot_clone = {
			loot_value = 0,
			base_damage = 1,
			health = 1000,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 6,
			run_speed = MONSTER_MOVE_SPEED_MOD * 9,
			steeringlimit = 360,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.BOSS,
			vision = {
				retarget_period = 1,
				aggro_range = 15,
				retarget_range = 55,
				too_near_switch_target = 25,
				too_far_retarget = 10000,
				share_target_range = 50,
				share_target_tags = { "mob" },
				share_not_target_tags = { "INLIMBO" },
			},
			clone_spawn_move_speed = 15,
		},

		thatcher = {
			loot_value = 2,
			base_damage = 200,
			health = 15000,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 8,
			run_speed = MONSTER_MOVE_SPEED_MOD * 8,
			steeringlimit = 360, -- TODO: untuned
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.BOSS,
			vision = {
				retarget_period = 1,
				aggro_range = 15,
				retarget_range = 55,
				too_near_switch_target = 25,
				too_far_retarget = 10000,
				share_target_range = 50,
				share_target_tags = { "mob" },
				share_not_target_tags = { "INLIMBO" },
			},
		},

		megatreemon = {
			loot_value = 3,
			base_damage = 270,
			health = 15000,
			stationary = true,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.BOSS,

			vision = {
				retarget_period = 1,
				aggro_range = 20,
				retarget_range = 55,
				too_near_switch_target = 25,
				too_far_retarget = 10000,
				share_target_range = 50,
				share_target_tags = { "mob" },
				share_not_target_tags = { "INLIMBO" },
			},
		},

		owlitzer = {
			loot_value = 2,
			base_damage = 180,
			health = 16000,
			walk_speed = MONSTER_MOVE_SPEED_MOD * 12,
			steeringlimit = 360,
			multiplayer_mods = ENEMY_MULTIPLAYER_MODS.BOSS,
			hitstun_pressure_frames = 120,
			vision = {
				retarget_period = 1,
				aggro_range = 15,
				retarget_range = 55,
				too_near_switch_target = 25,
				too_far_retarget = 10000,
				share_target_range = 50,
				share_target_tags = { "mob" },
				share_not_target_tags = { "INLIMBO" },
			},
		},

		----- Destructible Props
		PROP_DESTRUCTIBLE = {
			HEALTH = {
				LOW = 150,
				MEDIUM = 225,
				HIGH = 250,
				VERY_HIGH = 500,
			},
		},

		----- Friendly Minions
		minion_melee = {
			health = 1,
			base_damage = 75, -- TODO: make this take the base_damage of the equipped weapon upon spawn?
			vision = default_vision_tuning,
		},

		minion_ranged = {
			health = 1,
			base_damage = 50, -- TODO: make this take the base_damage of the equipped weapon upon spawn?
			vision = default_vision_tuning,
		},

		----- Default Tuning

		default_charm_colors = {
			-- Intentionally ugly to draw attention to itself, so we know we are missing a color set!
			color_add = { 255/255, 0/255, 255/255, 1 },
			color_mult = { 255/255, 255/255, 255/255, 1 },
			bloom = { 255/255, 0/255, 255/255, 1 },
		},

		----- npcs
		npc = {
			generic = {
				wander_dist = 6,
			},
		},

		-- Biome Exploration
		BIOME_EXPLORATION =
		{
			BASE = 150,
			MINIBOSS = 25,
			BOSS = 50,
		},

		-- Crafting

		CRAFTING =
		{
			--recipes
			ARMOUR_UPGRADE_PATH =
			{
				[ITEM_RARITY.s.COMMON] =
				{
					{ -- 2
						{ t = INGREDIENTS.s.MONSTER, r = ITEM_RARITY.s.UNCOMMON, a = 3 },
					},
					{ -- 3
						{ t = INGREDIENTS.s.MONSTER, r = ITEM_RARITY.s.UNCOMMON, a = 3 },
					},
				},

				[ITEM_RARITY.s.UNCOMMON] =
				{
					{ -- 2
						{ t = INGREDIENTS.s.MONSTER, r = ITEM_RARITY.s.UNCOMMON, a = 3 },
					},
					{ -- 3
						{ t = INGREDIENTS.s.MONSTER, r = ITEM_RARITY.s.UNCOMMON, a = 6 },
					},
				},

				[ITEM_RARITY.s.EPIC] =
				{
					{ -- 2
						{ t = INGREDIENTS.s.MONSTER, r = ITEM_RARITY.s.UNCOMMON, a = 3 },
					},
					{ -- 3
						{ t = INGREDIENTS.s.MONSTER, r = ITEM_RARITY.s.UNCOMMON, a = 6 },
					},
				},
			},

			TONICS =
			{
				COUNT = 5,
				[ITEM_RARITY.s.COMMON] =
				{
					{ t = INGREDIENTS.s.CURRENCY, r = ITEM_RARITY.s.COMMON, a = 1 },
				},

				[ITEM_RARITY.s.UNCOMMON] = {
					{ t = INGREDIENTS.s.CURRENCY, r = ITEM_RARITY.s.UNCOMMON, a = 1 },
				},

				[ITEM_RARITY.s.EPIC] =
				{
					{ t = INGREDIENTS.s.CURRENCY, r = ITEM_RARITY.s.EPIC, a = 1 },
				},
			},

			FOOD =
			{
				COUNT = 3,
				[ITEM_RARITY.s.COMMON] =
				{
					{ t = INGREDIENTS.s.CURRENCY, r = ITEM_RARITY.s.UNCOMMON, a = 1 },
				},

				[ITEM_RARITY.s.UNCOMMON] = {
					{ t = INGREDIENTS.s.CURRENCY, r = ITEM_RARITY.s.UNCOMMON, a = 1 },
				},

				[ITEM_RARITY.s.EPIC] =
				{
					{ t = INGREDIENTS.s.CURRENCY, r = ITEM_RARITY.s.EPIC, a = 1 },
				},
			},

			WEAPON =
			{
				[ITEM_RARITY.s.COMMON] =
				{
					{ t = INGREDIENTS.s.CURRENCY, r = ITEM_RARITY.s.COMMON, a = 1 },
				},

				[ITEM_RARITY.s.UNCOMMON] = {
					{ t = INGREDIENTS.s.CURRENCY, r = ITEM_RARITY.s.UNCOMMON, a = 1 },
					{ t = INGREDIENTS.s.MONSTER, r = ITEM_RARITY.s.UNCOMMON, a = 3 },
				},

				[ITEM_RARITY.s.EPIC] =
				{
					{ t = INGREDIENTS.s.CURRENCY, r = ITEM_RARITY.s.LEGENDARY, a = 1 },
					{ t = INGREDIENTS.s.MONSTER, r = ITEM_RARITY.s.EPIC, a = 3 },
				},

				[ITEM_RARITY.s.LEGENDARY] =
				{
					{ t = INGREDIENTS.s.CURRENCY, r = ITEM_RARITY.s.LEGENDARY, a = 1 },
					{ t = INGREDIENTS.s.MONSTER, r = ITEM_RARITY.s.LEGENDARY, a = 3 },
				},
			},

			ARMOUR_MEDIUM =
			{
				UPGRADE_PATH = true,
				[ITEM_RARITY.s.COMMON] =
				{
					{ t = INGREDIENTS.s.CURRENCY, r = ITEM_RARITY.s.UNCOMMON, a = 1 },
				},

				[ITEM_RARITY.s.UNCOMMON] = {
					{ t = INGREDIENTS.s.CURRENCY, r = ITEM_RARITY.s.UNCOMMON, a = 1 },
					{ t = INGREDIENTS.s.MONSTER, r = ITEM_RARITY.s.UNCOMMON, a = 1 },
				},

				[ITEM_RARITY.s.EPIC] =
				{
					{ t = INGREDIENTS.s.CURRENCY, r = ITEM_RARITY.s.UNCOMMON, a = 1 },
					{ t = INGREDIENTS.s.MONSTER, r = ITEM_RARITY.s.EPIC, a = 1 },
				},
			},
		},

		-- From DST
        MAX_SERVER_SIZE = 6,
        DEMO_TIME = 1020,
        TOTAL_DAY_TIME = 480,
        WILSON_RUN_SPEED = 6,
        BEEFALO_RUN_SPEED = {
			DEFAULT = 7,
		},
        STARTING_TEMP = 35,
        OVERHEAT_TEMP = 70,
        BEARDLING_SANITY = .4,
        MIN_INDICATOR_RANGE = 20,
        MAX_INDICATOR_RANGE = 50,
		GAMEMODE_STARTING_ITEMS = {},
        VOTE_KICK_TIME = 10 * 60, --10min
        DICE_ROLL_COOLDOWN = 30,
        WINTERS_FEAST_TREE_DECOR_LOOT = {},
    }

	--- Returns a table of resolved EnemyModifiers keyed by EnemyModifiers.s.
	--- If enemy_prefab is not nil, also merge in modifiers based on enemy category.
	function Tuning:GetEnemyModifiers(enemy_prefab)
		-- Remember that ascension level starts at 0. Ascension 0 is NOT represented in AscensionMultipliers.
		-- Merge all ascension multipliers up to the current ascension level.
		local ascension = TheDungeon.progression.components.ascensionmanager:GetCurrentLevel()
		local ascension_modifiers = {}
		for i = 1, ascension do
			table.insert(ascension_modifiers, AscensionModifierSource[i])
		end

		local dungeon_tier = TheSceneGen
			and TheSceneGen.components.scenegen:GetTier()
			or 1
		local dungeon = DungeonTierModifierSource[dungeon_tier]

		local multiplayer = {}
		if enemy_prefab then
			local enemy_tuning = self[enemy_prefab]
			if not enemy_tuning then
				TheLog.ch.Tuning:printf("No tuning table found for enemy [%s]", enemy_prefab)
			end
			if enemy_tuning and not enemy_tuning.multiplayer_mods then
				TheLog.ch.Tuning:printf("No multiplayer_mods found in tuning table for enemy [%s]", enemy_prefab)
			end
			local multiplayer_mods = enemy_tuning
				and enemy_tuning.multiplayer_mods
				or ENEMY_MULTIPLAYER_MODS.BASIC
			multiplayer = multiplayer_mods[GetLastPlayerCount()]
		end

		return ResolveModifiers(
			EnemyModifierNames:Ordered(),
			ENEMY_MODIFIER_DEFAULTS,
			dungeon,
			multiplayer,
			table.unpack(ascension_modifiers) -- Note that the unpack() needs to appear as the final argument.
		)
	end

	-- Resolved PlayerModifiers for the specified weapon, keyed by PlayerModifier.s.
	function Tuning:GetWeaponModifiers(weapon_type, ilvl, weight, rarity)
		return ResolveModifiers(
			PlayerModifierNames:Ordered(),
			PLAYER_MODIFIER_DEFAULTS,
			self.GEAR.WEAPONS[weapon_type],
			WeaponILvlModifierSource[ilvl],
			WeaponWeightModifierSource[weight],
			WeaponRarityModifierSource[rarity]
		)
	end

	-- Resolved PlayerModifiers for the specified armour, keyed by PlayerModifier.s.
	function Tuning:GetArmourModifiers(ilvl, weight, rarity)
		return ResolveModifiers(
			PlayerModifierNames:Ordered(),
			PLAYER_MODIFIER_DEFAULTS,
			self.GEAR.ARMOUR,
			ArmourILvlModifierSource[ilvl],
			ArmourWeightModifierSource[weight],
			ArmourRarityModifierSource[rarity]
		)
	end

	return Tuning
end

assert(#DungeonTierModifierSource == #ArmourILvlModifierSource and #DungeonTierModifierSource == #WeaponILvlModifierSource, "Please make sure that the number of DungeonTierModifiers, ArmourILvlModifier, and WeaponILvlModifierSource match! These are meant to be form one relationship.")

return BuildTuning
