local audioid = require "defs.sound.audioid"
local waves = require "encounter.waves"

local fight_waves =
{
	waves.Raw{ cabbageroll = 2, blarmadillo = 2 }, -- Phase 2 start
	waves.Raw{ cabbagerolls2 = 2, blarmadillo = 1, zucco = 1 }, -- Phase 3 start
	waves.Raw{ cabbagerolls2 = 2, blarmadillo = 2, yammo = 1 }, -- Phase 4 start
}

local reinforce_wave =
{
	waves.Raw{ cabbageroll = 2, blarmadillo = 1 },				--1p
	waves.Raw{ cabbageroll = 1, cabbagerolls2 = 1, yammo = 1 },	--2p
	waves.Raw{ cabbagerolls2 = 1, blarmadillo = 1, zucco = 1 },	--3p
	waves.Raw{ cabbagerolls2 = 2, blarmadillo = 1, zucco = 1 },	--4p
}

local PHASE_TWO_THRESHOLD = 0.85
local PHASE_THREE_THRESHOLD = 0.6
local PHASE_FOUR_THRESHOLD = 0.35
local TIME_BETWEEN_ROOT_ATTACKS = { 7, 10 }
local TIME_BETWEEN_FINAL_PHASE_LOOP = { 10, 13 }
local TIME_BETWEEN_REINFORCEMENTS = 3
local FIGHT_START_COOLDOWN = 1.6
local INITIAL_ROOT_COOLDOWN = 5

local root_attacks =
{
	["SPIN"] = function(inst, data) inst.components.rootattacker:DoSpinAttack(data) end,
	-- ["SPIRAL"] = function(inst, data) inst.components.rootattacker:DoSpiralAttack(data) end,
	["LINES"] = function(inst, data) inst.components.rootattacker:DoLinesAttack(data) end,
	["CIRCLE"] = function(inst, data) inst.components.rootattacker:DoCircleAttack(data) end,
	["CIRCLES"] = function(inst, data) inst.components.rootattacker:DoCirclesAttack(data) end,
	["H_LINES"] = function(inst, data) inst.components.rootattacker:DoHorizontalLineAttack(data) end,
	["V_LINES"] = function(inst, data) inst.components.rootattacker:DoVerticalLineAttack(data) end,
	["GRID"] = function(inst, data) inst.components.rootattacker:DoGridAttack(data) end,
}

local BossCoroMegaTreemon = Class(BossCoroutine, function(self, inst)
	BossCoroutine._ctor(self, inst)
end)

function BossCoroMegaTreemon:OnNetSerialize()
	local e = self.inst.entity

	e:SerializeBoolean(self.music_phase ~= nil)
	if self.music_phase then
		e:SerializeUInt(self.music_phase, 3) -- 0 thru 4
	end
end

function BossCoroMegaTreemon:OnNetDeserialize()
	local e = self.inst.entity

	local has_music_phase = e:DeserializeBoolean()
	if has_music_phase then
		local new_music_phase = e:DeserializeUInt(3)
		if new_music_phase ~= self.music_phase then
			self:SetMusicPhase(new_music_phase)
		end
	end
end

function BossCoroMegaTreemon:SpawnSetDressing(data)
	BossCoroMegaTreemon._base.SpawnSetDressing(self, data)
	TheWorld.components.spawncoordinator:SpawnPropDestructibles(10, true)
end

function BossCoroMegaTreemon:GetRootCooldown()
	-- can use phase or something to make these faster later
	return math.random(TIME_BETWEEN_ROOT_ATTACKS[1], TIME_BETWEEN_ROOT_ATTACKS[2])
end

function BossCoroMegaTreemon:GetTimeBetweenFinalPhaseLoop()
	return math.random(TIME_BETWEEN_FINAL_PHASE_LOOP[1], TIME_BETWEEN_FINAL_PHASE_LOOP[2])
end

function BossCoroMegaTreemon:PhaseOne()
	-- print("BossCoroMegaTreemon:PhaseOne()")
	self:DoRandomRootAttack({ "H_LINES", "LINES" })
	self:WaitForSeconds(self:GetRootCooldown(), true)
end

function BossCoroMegaTreemon:PhaseTwo()
	-- print("BossCoroMegaTreemon:PhaseTwo()")
	self:DoRandomRootAttack({ "V_LINES", "LINES" })
	self:WaitForSeconds(self:GetRootCooldown(), true)
end

function BossCoroMegaTreemon:PhaseThree()
	-- print("BossCoroMegaTreemon:PhaseThree()")
	self:DoRandomRootAttack({ "CIRCLES", "CIRCLE" })
	self:WaitForSeconds(self:GetRootCooldown(), true)
end

local elapsed_ticks_attack = 0
local elapsed_ticks_summon = 0
local attack_delay = 0
function BossCoroMegaTreemon:PhaseFour()
	--Attack loop timer
	if (elapsed_ticks_attack >= attack_delay) then
		self:DoRandomRootAttack({ "CIRCLES", "SPIN" })
		self:ThrowBombs(1, 3)
		elapsed_ticks_attack = 0
		attack_delay = self:GetTimeBetweenFinalPhaseLoop() * SECONDS
	else
		elapsed_ticks_attack = elapsed_ticks_attack + 1
	end
	--Summon loop timer
	if (elapsed_ticks_summon >= TIME_BETWEEN_REINFORCEMENTS * SECONDS) then
		self:DoIfAddsRemainingCount(2, function()
			self:SummonWave(reinforce_wave[#AllPlayers])
		end)
		elapsed_ticks_summon = 0
	else
		elapsed_ticks_summon = elapsed_ticks_summon + 1
	end
end

function BossCoroMegaTreemon:EnterDefensiveState()
	-- print("BossCoroMegaTreemon:EnterDefensiveState()")
	if not self.inst.sg:HasStateTag("block") then
		self:WaitForNotBusy()
		self.inst:PushEvent("enter_defend")
	end
end

function BossCoroMegaTreemon:ExitDefensiveState()
	-- print("BossCoroMegaTreemon:ExitDefensiveState()")
	self.inst:PushEvent("exit_defend")
end

function BossCoroMegaTreemon:SummonWave(wave)
	-- print("BossCoroMegaTreemon:SummonWave(wave)")
	local sc = TheWorld.components.spawncoordinator
	local custom_encounter = function(spawner)
		spawner:StartSpawningFromHidingPlaces()
		spawner:SpawnWave(wave, 0.1, 0, nil, true)
	end
	sc:StartCustomEncounter(custom_encounter)
	-- need to wait for a bit to ensure the enemies have spawned before the next command
	self:WaitForSeconds(TIME_BETWEEN_REINFORCEMENTS)
end

function BossCoroMegaTreemon:DoRandomRootAttack( patterns, times )
	self:WaitForNotBusy()
	local attack_patterns = {}
	times = times or 1
	for i = 1, times do
		table.insert(attack_patterns, root_attacks[patterns[#patterns > 1 and math.random(#patterns) or 1]])
	end
	self.inst.components.rootattacker:SetNumAttacks(times)
	self.inst:PushEvent("do_root_attacks", attack_patterns)
	self:WaitForEvent("done_root_attacks")
end

function BossCoroMegaTreemon:ThrowBombs( times, num )
	self:WaitForSeconds(0.2) -- wait a moment to avoid force finishing immediate attacks in throw_bombs handler
	self.inst:PushEvent("throw_bombs", {times = times, num = num})
	self:WaitForEvent("bomb_throw_done")
end

function BossCoroMegaTreemon:DoTaunt()
	self:WaitForNotBusy()
	self.inst:PushEvent("taunt")
	self:WaitForEvent("taunt_over")
end

function BossCoroMegaTreemon:SetMusicPhase(phase)
	TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_BossPhase", phase)
	self.music_phase = phase
end

function BossCoroMegaTreemon:SetMusicFinished(phase)
	TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_BossComplete", phase)
	TheWorld.components.ambientaudio:StartAmbient()
end

function BossCoroMegaTreemon:SetUpFight()
	for id, data in pairs(self.inst.components.attacktracker.attack_data) do
		if data.timer_id then
			self.inst.components.timer:ResumeTimer(data.timer_id)
		end
	end
end

function BossCoroMegaTreemon:Main()
	-- Will start after cine completes.
	self:SetUpFight()
	self:SetConditionalFunction(function() return self:HealthAbovePercent(PHASE_TWO_THRESHOLD) end)
	-- NEW PHASE STARTS ---

	self:DoConditionalFunction(function()
		self.inst.components.rootattacker:SetPhase(1)
		self:SetMusicPhase(1)
	end)
	self:DoConditionalFunction(self.WaitForSeconds, FIGHT_START_COOLDOWN, true)
	self:DoConditionalFunction(self.DoRandomRootAttack, {"SPIN"})
	self:DoConditionalFunction(self.WaitForSeconds, INITIAL_ROOT_COOLDOWN, true)
	self:DoUntilHealthPercent(PHASE_TWO_THRESHOLD, self.PhaseTwo)
	self:SetConditionalFunction(function() return self:HealthAbovePercent(PHASE_THREE_THRESHOLD) end)

	-- PHASE TRANSITION ---
	self:EnterDefensiveState()
	self:SetMusicPhase(0)
	self:SummonWave(fight_waves[1])
	self:WaitForDefeatedPercentage(0.65)

	-- NEW PHASE STARTS ---
	self:DoConditionalFunction(self.ExitDefensiveState)
	self:DoConditionalFunction(function()
		self.inst.components.rootattacker:SetPhase(2)
		self:SetMusicPhase(2)
		self:DoTaunt()
	end)
	self:DoConditionalFunction(self.ThrowBombs, 2, 1)
	self:DoConditionalFunction(self.DoRandomRootAttack, {"SPIN"})
	self:DoConditionalFunction(self.WaitForSeconds, INITIAL_ROOT_COOLDOWN, true)
	self:DoUntilHealthPercent(PHASE_THREE_THRESHOLD, self.PhaseTwo)
	self:SetConditionalFunction(function() return self:HealthAbovePercent(PHASE_FOUR_THRESHOLD) end)

	-- PHASE TRANSITION ---
	self:EnterDefensiveState()
	self:SetMusicPhase(0)
	self:SummonWave(fight_waves[2])
	self:WaitForDefeatedPercentage(0.6)

	-- NEW PHASE STARTS ---
	self:DoConditionalFunction(self.ExitDefensiveState)
	self:DoConditionalFunction(function()
		self.inst.components.rootattacker:SetPhase(3)
		self:SetMusicPhase(3)
		self:DoTaunt()
	end)
	self:DoConditionalFunction(self.ThrowBombs, 2, 2)
	self:DoConditionalFunction(self.DoRandomRootAttack, {"SPIN"})
	self:DoConditionalFunction(self.WaitForSeconds, INITIAL_ROOT_COOLDOWN, true)
	self:DoUntilHealthPercent(PHASE_FOUR_THRESHOLD, self.PhaseThree)

	-- PHASE TRANSITION ---
	self:EnterDefensiveState()
	self:SetMusicPhase(0)
	self:SummonWave(fight_waves[3])
	self:WaitForDefeatedPercentage(0.3)
	self:ExitDefensiveState()
	-- NEW PHASE STARTS ---
	self.inst.components.rootattacker:SetPhase(4)
	self:SetMusicPhase(4)
	self:DoTaunt()
	self:ThrowBombs(1, 3)
	self:DoRandomRootAttack({"SPIN"})
	self:WaitForSeconds(INITIAL_ROOT_COOLDOWN)
	self:DoUntilHealthPercent(0, self.PhaseFour)
end

return BossCoroMegaTreemon
