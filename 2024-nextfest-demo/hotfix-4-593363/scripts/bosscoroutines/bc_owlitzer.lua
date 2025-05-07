local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"
local waves = require "encounter.waves"

-- Each entry corresponds to the # of players
local fight_waves =
{
	waves.Raw{ cabbagerolls = 1, gnarlic = 2 }, -- TODO: adjust once MP spawn logic is more settled.
	--[[waves.Raw{ cabbagerolls = 1, gnarlic = 3 },
	waves.Raw{ cabbagerolls = 2, gnarlic = 3 },
	waves.Raw{ cabbagerolls = 2, gnarlic = 3, zucco = 1 },]]
}

local PHASE_THRESHOLDS =
{
	0.85,	-- Phase 1 to 2
	0.60,	-- Phase 2 to 3
	0.30,	-- Phase 3 to 4
	0.00,   -- Lasts until the end of the fight
}

-- Use current phase to make these faster as phases increase
local TIME_BETWEEN_ATTACKS =
{
	{ 8, 10 },
	{ 8, 10 },
	{ 8, 10 },
	{ 8, 10 },
}

local SUPER_FLAP_PATTERNS =
{
	{ -- Phase 1
		"xxxxxx-----",
		"-----xxxxxx",
		"xxxxxx-----",
		"-----xxxxxx",
		"xxxxxx-----",
	},
	{ -- Phase 2
		"xxx-----xxx",
		"x----xxxxxx",
		"xxx-----xxx",
		"xxxxxxx----",
		"xxx-----xxx",
		"xxxxxxx----",
	},
	{ -- Phase 3
		"xxxxxxx----",
		"xxx----xxxx",
		"xxxxx----xx",
		"x----xxxxxx",
		"xxxxxx----x",
		"xx----xxxxx",
		"xxxxx----xx",
	},
	{ -- Phase 4
		"xx---xxxxxx",
		"xxxxxx---xx",
		"xxxx---xxxx",
		"xxxxxxxx---",
		"xxxxxx---xx",
		"xx---xxxxxx",
		"xxxxx---xxx",
		"---xxxxxxxx",
	},
}

local BossCoroOwlitzer = Class(BossCoroutine, function(self, inst)
	BossCoroutine._ctor(self, inst)
	-- Check for phase changes
	-- self:CheckHealthPhaseTransition(PHASE_THRESHOLDS)
end)

function BossCoroOwlitzer:SpawnSetDressing(data)
	BossCoroOwlitzer._base.SpawnSetDressing(self, data)
	--TheWorld.components.spawncoordinator:SpawnPropDestructibles(10, true)
end

function BossCoroOwlitzer:GetAttackCooldown()
	local current_phase = self:CurrentPhase() or 1
	local min, max = TIME_BETWEEN_ATTACKS[current_phase][1], TIME_BETWEEN_ATTACKS[current_phase][2]
	return math.random(min, max)
end

function BossCoroOwlitzer:SetMusicPhase(phase)
	TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_BossPhase", phase)
end

function BossCoroOwlitzer:SetUpFight()
	for id, data in pairs(self.inst.components.attacktracker.attack_data) do
		if data.timer_id then
			self.inst.components.timer:ResumeTimer(data.timer_id)
		end
	end
end

function BossCoroOwlitzer:SummonWave(wave)
	-- print("BossCoroOwlitzer:SummonWave(wave)")
	local enemy_list = TheWorld.components.roomclear:GetEnemies()
	if #enemy_list > 1 then
		return
	end

	local sc = TheWorld.components.spawncoordinator
	local custom_encounter = function(spawner)
		spawner:StartSpawningFromHidingPlaces()
		spawner:SpawnWave(wave, 0, 0)
	end
	sc:StartCustomEncounter(custom_encounter)
	self:SetMusicPhase(4)
end

-----------------------------------------------------------

function BossCoroOwlitzer:DoIdleBehavior()
	self:WaitForNotBusy()
	self:SendEvent("idlebehavior")
	self:WaitForSeconds(self:GetAttackCooldown(), true)
end

function BossCoroOwlitzer:DoDiveBomb()
	self:WaitForNotBusy()
	self:SendEvent("divebomb")
	self:WaitForEvent("divebomb_over")
end

function BossCoroOwlitzer:DoSuperFlapWait()
	self:WaitForNotBusy()
	self:SendEvent("superflap")
	self:WaitForEvent("super_flap_wait")
end

function BossCoroOwlitzer:GetSuperFlapPattern()
	return SUPER_FLAP_PATTERNS[self:CurrentPhase()]
end

function BossCoroOwlitzer:DoSuperFlap()
	self:SendEvent("do_super_flap")
	self:WaitForEvent("superflap_over")
end

function BossCoroOwlitzer:DoBarf()
	self:WaitForNotBusy()
	self:SendEvent("barf")
	self:WaitForEvent("barf_over")
end

function BossCoroOwlitzer:DoPhaseChange()
	-- self:WaitForNotBusy()
	self:SendEvent("do_phase_change")
	self:WaitForEvent("superflap_over")
	self:SetPhase(self:CurrentPhase() + 1)
end
-----------------------------------------------------------

-- Starting phase. Melee/Wind Flap/Dive Bomb
function BossCoroOwlitzer:PhaseOne()
	--print("BossCoroOwlitzer:PhaseOne()")
	if self.inst.components.combat:GetTarget() == nil then
		self:DoIdleBehavior()
		return
	end

	self:DoConditionalFunction(self.WaitForSeconds, self:GetAttackCooldown(), true)

	self:DoConditionalFunction(self.DoDiveBomb)
	self:DoConditionalFunction(self.WaitForNotBusy) -- If owlitzer gets stunned, wait until it recovers to resume
end

-- Melee/Dive/Flap/Dive Bomb
function BossCoroOwlitzer:PhaseTwo()
	--print("BossCoroOwlitzer:PhaseTwo()")

	if self.inst.components.combat:GetTarget() == nil then
		self:DoIdleBehavior()
		return
	end

	self:DoConditionalFunction(self.WaitForSeconds, self:GetAttackCooldown(), true)

	self:DoConditionalFunction(self.DoDiveBomb)
	self:DoConditionalFunction(self.WaitForNotBusy)
end


-- Melee/Dive/Summon Mobs/Flap/Dive Bomb
function BossCoroOwlitzer:PhaseThree()
	--print("BossCoroOwlitzer:PhaseThree()")

	if self.inst.components.combat:GetTarget() == nil then
		self:DoIdleBehavior()
		return
	end

	self:DoConditionalFunction(self.DoBarf)
	self:DoConditionalFunction(self.WaitForNotBusy)

	self:DoConditionalFunction(self.WaitForSeconds, self:GetAttackCooldown(), true)

	self:DoConditionalFunction(self.DoDiveBomb)
	self:DoConditionalFunction(self.WaitForNotBusy)
end

-- Melee/Dive/Barf/Dive Bomb/Summon Mobs/Super Flapping/Fly By.
function BossCoroOwlitzer:PhaseFour()
	--print("BossCoroOwlitzer:PhaseFour()")
	if self.inst.components.combat:GetTarget() == nil then
		self:DoIdleBehavior()
		return
	end

	-- Summon wave to protect self during barf
	self:DoConditionalFunction(self.WaitForNotBusy)
	self:DoConditionalFunction(self.SummonWave, fight_waves[1])
	self:DoConditionalFunction(self.DoBarf)
	self:DoConditionalFunction(self.WaitForNotBusy)

	self:DoConditionalFunction(self.WaitForSeconds, self:GetAttackCooldown(), true)

	self:DoConditionalFunction(self.DoDiveBomb)
	self:DoConditionalFunction(self.WaitForNotBusy)

	self:DoConditionalFunction(self.WaitForSeconds, self:GetAttackCooldown(), true)

	self:DoConditionalFunction(self.DoSuperFlapWait)
	self:DoConditionalFunction(self.DoSuperFlap) -- After super flap fly by, it'll go immediately into the dive bomb
	self:DoConditionalFunction(self.WaitForNotBusy)

	self:DoConditionalFunction(self.WaitForSeconds, self:GetAttackCooldown(), true)
end

-----------------------------------------------------------
local function SetupLowHealthPhase(inst)
	inst.sg.mem.lowhealth = true -- Set for more barf loops, spawn blowable spike balls, etc.
	inst.sg.mem.doflyby = true -- Set to enable transition to fly by from super flap.
end

function BossCoroOwlitzer:DEBUG_OnlySuperFlap()
	self:DoSuperFlapWait()
	self:DoSuperFlap() -- After super flap fly by, it'll go immediately into the dive bomb
	self:WaitForNotBusy()
end

function BossCoroOwlitzer:Main()
	-- Will start after cine completes.
	self:SetUpFight()

	-- music transitions are being triggered in the SG in the specific phase_transition state
	self:SetMusicPhase(1)

	self.inst.components.attacktracker:SetMinimumCooldown(0) -- It's aggressive on the battlefield; set minimum cooldown to less than normal.

	-- DEBUG STUFF --
	-- self:DoUntilHealthPercent(0, self.DoDiveBomb)
	-- SetupLowHealthPhase(self.inst)
	-- self:SetPhase(4)
	-- self:DoUntilHealthPercent(0, self.DEBUG_OnlySuperFlap)
	-- self:StartNewPhase()
	-- SetupLowHealthPhase(self.inst) -- Enable low health behaviours.
	-- DEBUG STUFF --

	-- Phase 1:
	self:SetConditionalFunction(function() return self:HealthAbovePercent(PHASE_THRESHOLDS[1]) end)
	self:DoUntilHealthPercent(PHASE_THRESHOLDS[1], self.PhaseOne)

	self:DoPhaseChange() -- from 1 to 2
	self:StartNewPhase()

	-- Phase 2:
	self:SetConditionalFunction(function() return self:HealthAbovePercent(PHASE_THRESHOLDS[2]) end)
	self:DoUntilHealthPercent(PHASE_THRESHOLDS[2], self.PhaseTwo)

	self:DoPhaseChange() -- from 2 to 3
	self:StartNewPhase()

	-- Phase 3:
	SetupLowHealthPhase(self.inst) -- Enable low health behaviours.
	self:SetConditionalFunction(function() return self:HealthAbovePercent(PHASE_THRESHOLDS[3]) end)
	self:DoUntilHealthPercent(PHASE_THRESHOLDS[3], self.PhaseThree)

	self:DoPhaseChange() -- from 3 to 4
	self:StartNewPhase()

	-- Phase 4:
	self:SetConditionalFunction(function() return self:HealthAbovePercent(0) end)
	self:DoUntilHealthPercent(PHASE_THRESHOLDS[4], self.PhaseFour)
end

return BossCoroOwlitzer