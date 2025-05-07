local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"
local waves = require "encounter.waves"

-- Each entry corresponds to the # of players
local fight_waves =
{
	waves.Raw{ swarmy = 1, woworm = 2 },
	waves.Raw{ swarmy = 1, woworm = 3 },
	waves.Raw{ swarmy = 2, woworm = 3 },
	waves.Raw{ swarmy = 2, woworm = 3, slowpoke = 1 },
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

function BossCoroThatcher:DoFullSwing()
	self:WaitForNotBusy()
	self.inst.boss_coro:SendEvent("fullswing")
	self:WaitForEvent("fullswing_over")
end

function BossCoroThatcher:DoHook()
	self:WaitForNotBusy()
	self.inst.boss_coro:SendEvent("hook")
	self:WaitForEvent("hook_over")
end

function BossCoroThatcher:DoSwingSmash()
	self.inst.boss_coro:SendEvent("swing_smash")
	self:WaitForEvent("swing_smash_over")
end

function BossCoroThatcher:DoAcidSplash()
	self:WaitForNotBusy()
	self.inst.boss_coro:SendEvent("acid_splash")
	self:WaitForEvent("acid_splash_over")
end

function BossCoroThatcher:DoAcidCoating()
	self:WaitForNotBusy()
	self.inst.boss_coro:SendEvent("acid_coating")
	self:WaitForEvent("acid_coating_over")
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
	self:DoFullSwing()
	self:WaitForNotBusy() -- If owlitzer gets stunned, wait until it recovers to resume
end

-- Melee/Dive/Summon Mobs/Flap/Dive Bomb
function BossCoroThatcher:PhaseTwo()
	--print("BossCoroThatcher:PhaseTwo()")
	if self.inst.components.combat:GetTarget() == nil then
		self:DoIdleBehavior()
		return
	end

	self:WaitForSeconds(self:GetAttackCooldown(), true)
	self:DoHook()
	self:WaitForNotBusy()
end

-- Melee/Dive/Barf/Dive Bomb/Summon Mobs/Super Flapping/Fly By.
function BossCoroThatcher:PhaseThree()
	--print("BossCoroThatcher:PhaseThree()")
	if self.inst.components.combat:GetTarget() == nil then
		self:DoIdleBehavior()
		return
	end

	self:WaitForSeconds(self:GetAttackCooldown(), true)
	self:DoSwingSmash()
	self:WaitForNotBusy()

	-- Summon mobs
	--self:SummonWave(fight_waves[#AllPlayers])
	--self:WaitForSeconds(10)

	self:WaitForSeconds(self:GetAttackCooldown(), true)
end

-----------------------------------------------------------

function BossCoroThatcher:Main()
	-- Will start after cine completes.
	self:SetUpFight()
	self:SetMusicPhase(1)

	--self.inst.components.attacktracker:SetMinimumCooldown(0) -- It's aggressive on the battlefield; set minimum cooldown to less than normal.

	-- FOR DEBUG USE
	--self:DoUntilHealthPercent(0, self.DoFullSwing)

	-- Phase 1:
	self:SetMusicPhase(1)
	self:DoUntilHealthPercent(PHASE_THRESHOLDS[1], self.PhaseOne)

	--self:DoAcidSplash()

	-- Phase 2:
	-- music transitions are being triggered in the SG in the specific phase_transition state
	self:DoUntilHealthPercent(PHASE_THRESHOLDS[2], self.PhaseTwo)

	--self:DoAcidSplash()
	--self:WaitForNotBusy()
	--self:DoAcidCoating()

	-- Phase 3:
	-- music transitions are being triggered in the SG in the specific phase_transition state
	self:DoUntilHealthPercent(0, self.PhaseThree)
end

return BossCoroThatcher
