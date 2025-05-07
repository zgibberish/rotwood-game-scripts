local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"
local waves = require "encounter.waves"
local krandom = require "util.krandom"
local spawnutil = require "util.spawnutil"

local fight_waves =
{
	waves.Raw{ mothball_teen = 1 },
	waves.Raw{ mothball_teen = 2 },
}

local PHASE_THRESHOLDS =
{
	0.8,	-- Phase 1 to 2
	0.5,	-- Phase 2 to 3
	0.4,	-- Phase 3 to 4
}

local TIME_BETWEEN_ATTACKS = { 7, 10 }
local HOWL_INITIAL_DELAY = 20
local HOWL_TO_HIDE_DELAY = 1

local RECLONE_DELAY_AFTER_DEATH = { 10, 15 } -- How many seconds after a clone dies must we wait before we can try cloning again?

local NUM_STALACTITES_TO_SPAWN_HOWL = 5
local NUM_STALACTITES_TO_SPAWN_RAGE = 8
--local SPAWN_DISTANCE_FROM_EDGE = 5

local AVOID_POSITION_DISTANCE = 35 --How close to Bandicoot is too close to spawn a stalactite?

local STALACTITE_PREFAB = "swamp_stalactite_network"

local stalactite_spawn_patterns_howl =
{
	["LINE_HORIZONTAL"] = function(self)
		local coinflip = krandom.Boolean()
		spawnutil.SpawnLine(STALACTITE_PREFAB, NUM_STALACTITES_TO_SPAWN_HOWL, {
			instigator = self.inst,
			start_pt = spawnutil.GetStartPointFromWorld(0.25, coinflip and 0.75 or 0.4),
			angle = 0,
			padding = 6,
			spawn_delay = 0.2,
			random_offset = { 0, 1 },
			avoid_position = { pos = self.inst:GetPosition(), proximity = AVOID_POSITION_DISTANCE },
		})
	end,
	["LINE_VERTICAL"] = function(self)
		local coinflip = krandom.Boolean()
		spawnutil.SpawnLine(STALACTITE_PREFAB, NUM_STALACTITES_TO_SPAWN_HOWL, {
			instigator = self.inst,
			start_pt = spawnutil.GetStartPointFromWorld(coinflip and 0.7 or 0.3, 0.2),
			angle = 90,
			padding = 6,
			spawn_delay = 0.2,
			random_offset = { 0, 1 },
			avoid_position = { pos = self.inst:GetPosition(), proximity = AVOID_POSITION_DISTANCE },
		})
	end,
	["LINE_ANGLE"] = function(self)
		local coinflip = krandom.Boolean()
		spawnutil.SpawnLine(STALACTITE_PREFAB, NUM_STALACTITES_TO_SPAWN_HOWL, {
			instigator = self.inst,
			start_pt = spawnutil.GetStartPointFromWorld( coinflip and 0.7 or 0.3, 0.75),
			angle = coinflip and -135 or -45,
			padding = 6,
			spawn_delay = 0.2,
			random_offset = { 0, 1 },
			avoid_position = { pos = self.inst:GetPosition(), proximity = AVOID_POSITION_DISTANCE },
		})
	end,
	["CIRCLE"] = function(self)
		spawnutil.SpawnShape(STALACTITE_PREFAB, NUM_STALACTITES_TO_SPAWN_HOWL, {
			instigator = self.inst,
			start_pt = spawnutil.GetStartPointFromWorld(0.5, .5),
			radius = 10,
			start_angle = 18,
			--end_angle = 180,
			spawn_delay = 0.2,
			--random_offset = { 0, 1 },
			avoid_position = { pos = self.inst:GetPosition(), proximity = AVOID_POSITION_DISTANCE },
		})
	end,
}

local stalactite_spawn_patterns_rage =
{
	["LINES_HORIZONTAL"] = function(self)
		spawnutil.SpawnLine(STALACTITE_PREFAB, NUM_STALACTITES_TO_SPAWN_RAGE / 2 + 2, {
			instigator = self.inst,
			start_pt = spawnutil.GetStartPointFromWorld(0.15, 0.4),
			angle = 0,
			padding = 6,
			spawn_delay = 0.2,
			random_offset = { 0, 1 },
			avoid_position = { pos = self.inst:GetPosition(), proximity = AVOID_POSITION_DISTANCE },
		})
		spawnutil.SpawnLine(STALACTITE_PREFAB, NUM_STALACTITES_TO_SPAWN_RAGE / 2 + 2, {
			instigator = self.inst,
			start_pt = spawnutil.GetStartPointFromWorld(0.15, 0.75),
			angle = 0,
			padding = 6,
			spawn_delay = 0.2,
			random_offset = { 0, 1 },
			avoid_position = { pos = self.inst:GetPosition(), proximity = AVOID_POSITION_DISTANCE },
		})
	end,

	["LINES_VERTICAL"] = function(self)
		spawnutil.SpawnLine(STALACTITE_PREFAB, NUM_STALACTITES_TO_SPAWN_RAGE / 2 + 1, {
			instigator = self.inst,
			start_pt = spawnutil.GetStartPointFromWorld(0.3, 0.2),
			angle = 90,
			padding = 6,
			spawn_delay = 0.2,
			random_offset = { 0, 1 },
			avoid_position = { pos = self.inst:GetPosition(), proximity = AVOID_POSITION_DISTANCE },
		})
		spawnutil.SpawnLine(STALACTITE_PREFAB, NUM_STALACTITES_TO_SPAWN_RAGE / 2 + 1, {
			instigator = self.inst,
			start_pt = spawnutil.GetStartPointFromWorld(0.7, 0.35),
			angle = 90,
			padding = 6,
			spawn_delay = 0.2,
			random_offset = { 0, 1 },
			avoid_position = { pos = self.inst:GetPosition(), proximity = AVOID_POSITION_DISTANCE },
		})
	end,

	["CROSS"] = function(self)
		spawnutil.SpawnCross(STALACTITE_PREFAB, math.ceil(NUM_STALACTITES_TO_SPAWN_RAGE / 2), math.floor(NUM_STALACTITES_TO_SPAWN_RAGE / 2), {
			instigator = self.inst,
			center_pt = spawnutil.GetStartPointFromWorld(0.5, 0.6),
			start_percent_a = 0.5, start_percent_b = 0.5,
			use_same_length = true,
			angle_a = 0, angle_b = -90,
			padding_a = 10, padding_b = 10,
			spawn_delay = 0.2,
			random_offset = { 0, 1 },
			avoid_position = { pos = self.inst:GetPosition(), proximity = AVOID_POSITION_DISTANCE },
		})
	end,

	["CIRCLE"] = function(self)
		spawnutil.SpawnShape(STALACTITE_PREFAB, NUM_STALACTITES_TO_SPAWN_RAGE, {
			instigator = self.inst,
			start_pt = spawnutil.GetStartPointFromWorld(0.5, 0.5),
			radius = 12,
			start_angle = 18,
			--end_angle = 180,
			spawn_delay = 0.2,
			--random_offset = { 0, 1 },
			avoid_position = { pos = self.inst:GetPosition(), proximity = AVOID_POSITION_DISTANCE },
		})
	end,
}

-- Select and run a random pattern from the given pattern list
local function PlaySpawnPattern(inst, pattern_list)
	local rng = krandom.CreateGenerator()
	local pattern = rng:PickValue(pattern_list)

	assert(pattern_list, "List of spawn patterns has no entries!")
	pattern(inst)
end

-----------------------------------------------------------

local BossCoroBandicoot = Class(BossCoroutine, function(self, inst)
	BossCoroutine._ctor(self, inst)

	-- Check for phase changes
	self:CheckHealthPhaseTransition(PHASE_THRESHOLDS)
end)

function BossCoroBandicoot:SpawnSetDressing(data)
	BossCoroBandicoot._base.SpawnSetDressing(self, data)
	TheWorld.components.spawncoordinator:SpawnPropDestructibles(10, true)
end

function BossCoroBandicoot:GetAttackCooldown()
	-- can use phase or something to make these faster later
	return math.random(TIME_BETWEEN_ATTACKS[1], TIME_BETWEEN_ATTACKS[2])
end

function BossCoroBandicoot:StartCloneCooldown()
	-- can use phase or something to make these faster later
	local cooldown = math.random(RECLONE_DELAY_AFTER_DEATH[1], RECLONE_DELAY_AFTER_DEATH[2])
	self.inst.components.timer:StartTimer("clone_cooldown", cooldown, true)
end

function BossCoroBandicoot:StartBossMusic()
	local boss_music = fmodtable.Event.Mus_Bandicoot_LP
	TheAudio:PlayPersistentSound(audioid.persistent.boss_music, boss_music)
end

function BossCoroBandicoot:SetMusicPhase(phase)
	TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_BossPhase", phase)
end

local function OnEnterRageMode(inst)
	-- Upon enter rage mode, set the phase immediately to prevent doing non-rage attacks.
	inst.boss_coro:SetPhase(4)
end

function BossCoroBandicoot:SetUpFight()
	for id, data in pairs(self.inst.components.attacktracker.attack_data) do
		if data.timer_id then
			self.inst.components.timer:ResumeTimer(data.timer_id)
		end
	end
	self.inst:ListenForEvent("clone_death", function()
		self:StartCloneCooldown()
	end)

	self.inst:ListenForEvent("enter_rage_mode", OnEnterRageMode)

	-- Listen for when a stalactite lands on the ground & spawn mobs.
	self.inst:ListenForEvent("stalactite_landed", function(_, source)
		self.inst:PushEvent("spawn_mobs", source)
	end)
end

local SPAWN_WAVE_POST_WAIT_TIME = 3

function BossCoroBandicoot:SummonWave(wave)
	-- print("BossCoroBandicoot:SummonWave(wave)")
	if not TheWorld.components.roomclear:IsClearOfEnemies() then
		return
	end

	local sc = TheWorld.components.spawncoordinator
	local custom_encounter = function(spawner)
		spawner:StartSpawningFromHidingPlaces()
		spawner:SpawnWave(wave, 0, 0)
	end
	sc:StartCustomEncounter(custom_encounter)
	-- need to wait for a bit to ensure the enemies have spawned before the next command
	self:WaitForSeconds(SPAWN_WAVE_POST_WAIT_TIME)
end

-----------------------------------------------------------

function BossCoroBandicoot:DoIdleBehavior()
	self:WaitForNotBusy()
	self.inst.boss_coro:SendEvent("idlebehavior")
	self:WaitForSeconds(self:GetAttackCooldown(), true)
end

function BossCoroBandicoot:DoLaugh()
	self:WaitForNotBusy()
	self.inst.boss_coro:SendEvent("laugh")
	self:WaitForEvent("laugh_over")
end

function BossCoroBandicoot:DoHowl()
	self:WaitForNotBusy()
	self.inst.boss_coro:SendEvent("howl")
	self:WaitForEvent("spawn_stalactites")
	PlaySpawnPattern(self, stalactite_spawn_patterns_howl)
	self.inst:DoTaskInTime(2, function(inst) inst:PushEvent("spawn_spores") end)
	self:WaitForEvent("howl_over")
	TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.Music_Boss_StingerCounter, 1)
end

function BossCoroBandicoot:DoHide()
	self:WaitForNotBusy()
	self.inst.boss_coro:SendEvent("hide")
	self:WaitForEvent("hide_over")
end

function BossCoroBandicoot:DoClone(num_clones_data)
	self:WaitForNotBusy()

	-- Only clone if there are no clones on the battlefield.
	if self.inst:GetRandomEntityByTagInRange(10000, {"clone"}, true, true) then
		return
	end

	-- Don't clone this time if the players recently killed a clone.
	if self.inst.components.timer:HasTimer("clone_cooldown") then
		print("Not spawning a clone yet! On cooldown")
		return
	end

	local num_clones = num_clones_data[#AllPlayers] or 1
	self.inst.boss_coro:SendEvent("clone", num_clones)
	self:WaitForEvent("clone_over")
end

function BossCoroBandicoot:DoRage()
	self:WaitForNotBusy()
	self.inst.boss_coro:SendEvent("rage")
	self:WaitForEvent("spawn_stalactites")
	PlaySpawnPattern(self, stalactite_spawn_patterns_rage)
	--[[spawnutil.SpawnRandom(STALACTITE_PREFAB, NUM_STALACTITES_TO_SPAWN_RAGE, {
		instigator = self.inst,
		padding_from_edge = SPAWN_DISTANCE_FROM_EDGE,
		spawn_delay = 0.2,
	})]]
	self.inst:DoTaskInTime(2, function(inst) inst:PushEvent("spawn_spores") end)
	self:WaitForEvent("rage_over")
end

-----------------------------------------------------------

-- Start hiding.
function BossCoroBandicoot:PhaseOne()
	--print("BossCoroBandicoot:PhaseTwo()")
	if self.inst.components.combat:GetTarget() == nil then
		self:DoIdleBehavior()
		return
	end

	self:WaitForSeconds(self:GetAttackCooldown(), true)

	if not self.inst:HasTag("clone") then
		self:DoHowl()
		self:WaitForSeconds(HOWL_TO_HIDE_DELAY, true)
		self:SummonWave(fight_waves[1])
		self:DoHide()
	end
end

-- Clone & hide.
function BossCoroBandicoot:PhaseTwo()
	--print("BossCoroBandicoot:PhaseThree()")
	if self.inst.components.combat:GetTarget() == nil then
		self:DoIdleBehavior()
		return
	end

	-- If we've transitioned to rage mode, exit out before doing pre-rage attacks.
	if self.inst.sg.mem.is_rage_mode then
		return
	end

	if not self.inst:HasTag("clone") then
		self:DoClone(self.inst.tuning.num_clones_normal)
		self:DoLaugh()
	end

	self:WaitForSeconds(self:GetAttackCooldown(), true)

	if self.inst.sg.mem.is_rage_mode then
		return
	end

	if not self.inst:HasTag("clone") then
		self:DoHowl()
		self:WaitForSeconds(HOWL_TO_HIDE_DELAY, true)
		self:SummonWave(fight_waves[1])
		self:DoHide()
	end
end

-- Do rage attack. Only the parent does it.
function BossCoroBandicoot:PhaseThree()
	--print("BossCoroBandicoot:PhaseFour()")
	if self.inst.components.combat:GetTarget() == nil then
		self:DoIdleBehavior()
		return
	end

	self:WaitForSeconds(self:GetAttackCooldown(), true)

	if not self.inst:HasTag("clone") then
		self:DoRage()
		self:SummonWave(fight_waves[2])
	end
end

-- Rage attack & cloning.
function BossCoroBandicoot:PhaseFour()
	--print("BossCoroBandicoot:PhaseFive()")
	if self.inst.components.combat:GetTarget() == nil then
		self:DoIdleBehavior()
		return
	end

	self:WaitForSeconds(self:GetAttackCooldown(), true)

	if not self.inst:HasTag("clone") then
		self:DoClone(self.inst.tuning.num_clones_low_health)
		self:WaitForSeconds(self:GetAttackCooldown(), true)
		self:DoRage()
		self:SummonWave(fight_waves[2])
	--else
		--self:DoRage()
	end
end

-----------------------------------------------------------

function BossCoroBandicoot:Main()
	if not self.inst:HasTag("clone") then
		-- Will start after cine completes.
		self:SetUpFight()

		-- Initial spawn; do howl & hide.
		self:WaitForSeconds(HOWL_INITIAL_DELAY, true)
		self:DoHowl()
		self:WaitForSeconds(HOWL_TO_HIDE_DELAY, true)
		self:DoHide()
	end

	local coro = self.inst:HasTag("clone") and self.inst.parent and self.inst.parent.boss_coro or self.inst.boss_coro

	-- Phase 1: Start hiding & peek-a-boo attack.
	if not self.inst:HasTag("clone") then
		self:SetMusicPhase(1)
	end
	self:DoUntilHealthPercent(PHASE_THRESHOLDS[1], self.PhaseOne)

	-- Phase 2: Clone
	self:DoUntilHealthPercent(PHASE_THRESHOLDS[2], self.PhaseTwo)
	--if not self.inst:HasTag("clone") then
		--self:SetMusicPhase(2)
		--setting this in the animation because we want to use the initial cloning as a music transition
		--and we don't want this triggering during a pillar hide
	--end

	-- Phase 4: Start rage & bite attack
	if not self.inst:HasTag("clone") then
		self:SetMusicPhase(4)
	end
	self:DoUntilHealthPercent(PHASE_THRESHOLDS[3], self.PhaseThree)

	-- Phase 5: Clone x3
	if not self.inst:HasTag("clone") then
		self:SetMusicPhase(5)
	end
	self:DoUntilHealthPercent(0, self.PhaseFour)
end

return BossCoroBandicoot
