local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"
local waves = require "encounter.waves"

-- Each entry corresponds to the # of players
local fight_waves =
{
	waves.Raw{ cabbagerolls = 1, gnarlic = 2 },
	waves.Raw{ cabbagerolls = 1, gnarlic = 3 },
	waves.Raw{ cabbagerolls = 2, gnarlic = 3 },
	waves.Raw{ cabbagerolls = 2, gnarlic = 3, zucco = 1 },
}

local PHASE_THRESHOLDS =
{
	0.8,	-- Phase 1 to 2
	0.4,	-- Phase 2 to 3
}

-- Use current phase to make these faster as phases increase
local TIME_BETWEEN_ATTACKS =
{
	{ 8, 10 },
	{ 8, 10 },
	{ 8, 10 },
}

local BossCoroThatcher = Class(BossCoroutine, function(self, inst)
	BossCoroutine._ctor(self, inst)

	-- Check for phase changes
	self:CheckHealthPhaseTransition(PHASE_THRESHOLDS)
end)

function BossCoroThatcher:SpawnSetDressing(data)
	BossCoroThatcher._base.SpawnSetDressing(self, data)
	--TheWorld.components.spawncoordinator:SpawnPropDestructibles(10, true)
end

function BossCoroThatcher:GetAttackCooldown()
	local current_phase = self.inst.boss_coro:CurrentPhase() or 1
	local min, max = TIME_BETWEEN_ATTACKS[current_phase][1], TIME_BETWEEN_ATTACKS[current_phase][2]
	return math.random(min, max)
end

function BossCoroThatcher:SetMusicPhase(phase)
	TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_BossPhase", phase)
end

function BossCoroThatcher:SetUpFight()
	for id, data in pairs(self.inst.components.attacktracker.attack_data) do
		if data.timer_id then
			self.inst.components.timer:ResumeTimer(data.timer_id)
		end
	end
end

local SPAWN_WAVE_POST_WAIT_TIME = 3

function BossCoroThatcher:SummonWave(wave)
	-- print("BossCoroThatcher:SummonWave(wave)")
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
	-- need to wait for a bit to ensure the enemies have spawned before the next command
	self:WaitForSeconds(SPAWN_WAVE_POST_WAIT_TIME)
end

-----------------------------------------------------------

function BossCoroThatcher:DoIdleBehavior()
	self:WaitForNotBusy()
	self.inst.boss_coro:SendEvent("idlebehavior")
	self:WaitForSeconds(self:GetAttackCooldown(), true)
end

function BossCoroThatcher:DoDiveBomb()
	self:WaitForNotBusy()
	self.inst.boss_coro:SendEvent("divebomb")
	self:WaitForEvent("divebomb_over")
end

function BossCoroThatcher:DoSuperFlapWait()
	self:WaitForNotBusy()
	self.inst.boss_coro:SendEvent("superflap")
	self:WaitForEvent("super_flap_wait")
end

function BossCoroThatcher:DoSuperFlap()
	self.inst.boss_coro:SendEvent("do_super_flap")
	self:WaitForEvent("superflap_over")
end

function BossCoroThatcher:DoBarf()
	self:WaitForNotBusy()
	self.inst.boss_coro:SendEvent("barf")
	self:WaitForEvent("barf_over")
end

-----------------------------------------------------------

-- Starting phase. Melee/Wind Flap/Dive Bomb
function BossCoroThatcher:PhaseOne()
	--print("BossCoroThatcher:PhaseOne()")
	if self.inst.components.combat:GetTarget() == nil then
		self:DoIdleBehavior()
		return
	end

	self:WaitForSeconds(self:GetAttackCooldown(), true)
	self:DoDiveBomb()
	self:WaitForNotBusy() -- If owlitzer gets stunned, wait until it recovers to resume
end

-- Melee/Dive/Summon Mobs/Flap/Dive Bomb
function BossCoroThatcher:PhaseTwo()
	--print("BossCoroThatcher:PhaseTwo()")
	if self.inst.components.combat:GetTarget() == nil then
		self:DoIdleBehavior()
		return
	end

	self:DoBarf()
	self:WaitForNotBusy()

	self:WaitForSeconds(self:GetAttackCooldown(), true)
	self:DoDiveBomb()
	self:WaitForNotBusy()
end

-- Melee/Dive/Barf/Dive Bomb/Summon Mobs/Super Flapping/Fly By.
function BossCoroThatcher:PhaseThree()
	--print("BossCoroThatcher:PhaseThree()")
	if self.inst.components.combat:GetTarget() == nil then
		self:DoIdleBehavior()
		return
	end

	self:DoBarf()
	self:WaitForNotBusy()

	self:WaitForSeconds(self:GetAttackCooldown(), true)
	self:DoDiveBomb()
	--self:WaitForNotBusy()

	-- Summon mobs then do super flap
	self:SummonWave(fight_waves[#AllPlayers])
	self:WaitForSeconds(10)

	self:WaitForNotBusy()
	self:DoSuperFlapWait()
	--self:WaitForDefeatedPercentage(0.6)

	self:DoSuperFlap() -- After super flap fly by, it'll go immediately into the dive bomb
	self:WaitForNotBusy()

	self:WaitForSeconds(self:GetAttackCooldown(), true)
end

-----------------------------------------------------------
local function SetupLowHealthPhase(inst)
	inst.sg.mem.lowhealth = true -- Set for more barf loops, spawn blowable spike balls, etc.
	inst.sg.mem.doflyby = true -- Set to enable transition to fly by from super flap.

	-- Set all existing spike traps to be blown.
	--[[local spikeballs = TheSim:FindEntitiesXZ(0, 0, 1000, { "spikeball" })
	for _, spikeball in pairs(spikeballs) do
		spikeball.components.powermanager:RemoveIgnorePower("owlitzer_super_flap")
	end]]
end

function BossCoroThatcher:Main()
	-- Will start after cine completes.
	self:SetUpFight()
	self:SetMusicPhase(1)

	self.inst.components.attacktracker:SetMinimumCooldown(0) -- It's aggressive on the battlefield; set minimum cooldown to less than normal.

	-- FOR DEBUG USE
	--self:DoUntilHealthPercent(0, self.DoDiveBomb)

	-- Phase 1:
	self:SetMusicPhase(1)
	self:DoUntilHealthPercent(PHASE_THRESHOLDS[1], self.PhaseOne)

	-- Phase 2:
	-- music transitions are being triggered in the SG in the specific phase_transition state
	self:DoUntilHealthPercent(PHASE_THRESHOLDS[2], self.PhaseTwo)
	self:WaitForNotBusy() -- Set to prevent going into fly_by from the super flap from phase 2 to 3

	-- Transition to phase 3
	SetupLowHealthPhase(self.inst) -- Enable low health behaviours.

	-- Phase 3:
	-- music transitions are being triggered in the SG in the specific phase_transition state
	self:DoUntilHealthPercent(0, self.PhaseThree)
end

return BossCoroThatcher
