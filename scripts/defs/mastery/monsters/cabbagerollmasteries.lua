local Mastery = require "defs.mastery.mastery"
local templates = require"defs.mastery.masterytemplates"

local monster_id = "CABBAGEROLL"

local function add_mastery_fn(mastery_id, data)
	Mastery.AddMastery(Mastery.Slots.MONSTER_MASTERY, mastery_id, monster_id, data)
end

-- FOCUS HITS
templates.AddKillMonsterMastery(add_mastery_fn, monster_id)
templates.AddFocusKillMonsterMastery(add_mastery_fn, monster_id)
templates.AddLightAttackKillMonsterMastery(add_mastery_fn, monster_id)
templates.AddHeavyAttackKillMonsterMastery(add_mastery_fn, monster_id)
templates.AddSkillKillMonsterMastery(add_mastery_fn, monster_id)
templates.AddKillQuicklyMonsterMastery(add_mastery_fn, monster_id)
templates.AddKillWithNoDamageMastery(add_mastery_fn, monster_id)
templates.AddKillOneHitMastery(add_mastery_fn, monster_id)