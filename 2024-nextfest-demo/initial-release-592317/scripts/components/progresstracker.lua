local StatTracker = require "components.stattracker"

local fresh_data =
{
	-- general data

	total_killing_blows = 0,
	total_deaths = 0,
	total_damage_done = 0,
	total_damage_taken = 0,
	total_num_runs = 0,
	total_perfect_dodges = 0,

	-- detailed data

	kills = {},
	num_runs = {},

	-- stores data about your best attempts against each boss in the game
	-- best attempt in a %
	boss_progress = {},

	-- non-numeric things
	run_state = RunStates.s.ACTIVE,
}

local ProgressTracker = Class(StatTracker, function(self, inst)
	StatTracker._ctor(self, inst)

	self:SetDefaultData(fresh_data)

    self._on_health_delta = function(_, data) self:OnHealthDelta(data) end
    self._on_death = function(_, data) self:OnDeath(data) end
    self._on_kill = function(_, data) self:OnKillingBlow(data) end
	self._on_do_damage = function(_, data) self:OnDoDamage(data) end
	self._on_hitbox_collided_invincible = function(_, data) self:OnHitboxCollidedInvincible(data) end
	self._on_end_run = function(_, data) self:OnEndRun(data) end

    self.inst:ListenForEvent("healthchanged", self._on_health_delta)
    self.inst:ListenForEvent("dying", self._on_death) -- Listen for 'dying' instead of 'death' because of multiplayer reviving.
    self.inst:ListenForEvent("kill", self._on_kill)
	self.inst:ListenForEvent("do_damage", self._on_do_damage)
	self.inst:ListenForEvent("hitboxcollided_invincible", self._on_hitbox_collided_invincible)
	self.inst:ListenForEvent("end_current_run", self._on_end_run)
end)

function ProgressTracker:OnHealthDelta(data)
	local delta = data.new - data.old

	if data.silent or delta == 0 or data.attack == nil then return end

	-- took damage
	if delta < 0 then
		self:DeltaValue("total_damage_taken", delta)
	end
end

function ProgressTracker:OnDeath(data)
	self:IncrementValue("total_deaths")
end

function ProgressTracker:OnKillingBlow(data)
	if data.attack and data.attack:GetTarget():HasTag("mob") then
		self:IncrementValue("total_killing_blows")
	end
end

function ProgressTracker:IncrementKillValue(key)
	local tbl = self:GetValue("kills")
	tbl[key] = (tbl[key] or 0) + 1
	self:SetValue("kills", tbl)
end

function ProgressTracker:GetNumKills(key)
	local tbl = self:GetValue("kills")
	if not key then
		key = "kills"
	end
	return tbl[key] or 0
end

function ProgressTracker:OnDoDamage(attack)
	self:DeltaValue("total_damage_done", attack:GetDamage())
end

function ProgressTracker:OnHitboxCollidedInvincible(data)
	if not self.inst.sg:HasStateTag("dodge") then
		return
	end
	self:IncrementValue("total_perfect_dodges")
end

local function _RecordBossProgress(self, data)
	if data.progress >= 1 then
		-- is there a boss in the room?
		-- find them & record what their health % is
		local enemies = FindEnemiesInRange(0, 0, 100) -- get all enemies on the stage
		local boss = nil
		for _, enemy in ipairs(enemies) do
			if enemy:HasTag("boss") then
				boss = enemy -- found the boss
				break
			end
		end

		if boss ~= nil then
			local tbl = self:GetValue("boss_progress")

			if not tbl then
				tbl = {}
			end

			local percent_health = boss.components.health:GetPercent()
			-- if the health % is less than previously recorded, save the value
			if percent_health < (tbl[boss.prefab] or 1) then
				tbl[boss.prefab] = boss.components.health:GetPercent()
				self:SetValue("boss_progress", tbl)
			end
		end
	end
end

function ProgressTracker:OnEndRun(data)
	if data.progress > 0 then
		self:IncrementValue("total_num_runs")

		local tbl = self:GetValue("num_runs")
		local tar = data.dungeon_id
		tbl[tar] = (tbl[tar] or 0) + 1
		self:SetValue("num_runs", tbl)

		_RecordBossProgress(self, data)
	end

	self:SetValue("run_state", data.run_state)
end

function ProgressTracker:GetBestBossAttempt(prefab)
	local tbl = self:GetValue("boss_progress")
	return tbl[prefab] or 1
end

function ProgressTracker:GetLastRunResult()
	return self:GetValue("run_state") or RunStates.s.ACTIVE
end

function ProgressTracker:WonLastRun()
	return self:GetLastRunResult() == RunStates.s.VICTORY
end

function ProgressTracker:AbandonedLastRun()
	return self:GetLastRunResult() == RunStates.s.ABANDON
end

function ProgressTracker:LostLastRun()
	return self:GetLastRunResult() == RunStates.s.DEFEAT
end

return ProgressTracker