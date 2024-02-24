-- tracks what you have done in a dungeon since the start of the dungeon

-- damage done x
-- damage taken x
-- enemies killed x
-- deaths x

-- loot collected x

-- healing done/ received

-- currency collected
-- currency spent
-- glitz generated (end of dungeon screen presentation)

-- ascension level completed (is it your first time)
-- any unlocks you might have achieved
local StatTracker = require "components.stattracker"

local fresh_data =
{
	-- general data

	perfect_dodges = 0,
	total_damage_done = 0,
	total_damage_taken = 0,
	total_kills = 0,
	total_deaths = 0,

	-- detailed data

	deaths = {}, -- how many times you have died
	kills = {}, -- which enemies you have killed
	damage_taken = {}, -- how much damage you have taken
	damage_done = {}, -- how much damage you have done
	loot = {}, -- what you have picked up
	hitstreaks = {}, -- hitstreak numbers
}

local DungeonTracker = Class(StatTracker, function(self, inst)
	StatTracker._ctor(self, inst)

	self:SetDefaultData(fresh_data)

    self._new_run_fn =  function() self:StartNewRun() end
    self.inst:ListenForEvent("start_new_run", self._new_run_fn)
    self._end_run_fn = function() self:EndCurrentRun() end
    self.inst:ListenForEvent("end_current_run", self._end_run_fn)

    self._on_health_delta = function(_, data) self:OnHealthDelta(data) end
    self._on_death = function(_, data) self:OnDeath(data) end
    self._on_kill = function(_, data) self:OnKill(data) end
	self._on_do_damage = function(_, data) self:OnDoDamage(data) end
	self._on_get_loot = function(_, data) self:OnGetLoot(data) end
	self._on_hitbox_collided_invincible = function(_, data) self:OnHitboxCollidedInvincible(data) end
	self._on_hitstreak_killed = function(_, data) self:OnHitStreakKilled(data) end

    self.inst:ListenForEvent("healthchanged", self._on_health_delta)
    self.inst:ListenForEvent("dying", self._on_death) -- Listen for 'dying' instead of 'death' because of multiplayer reviving.
    self.inst:ListenForEvent("kill", self._on_kill)
	self.inst:ListenForEvent("do_damage", self._on_do_damage)
	self.inst:ListenForEvent("get_loot", self._on_get_loot)
	self.inst:ListenForEvent("hitboxcollided_invincible", self._on_hitbox_collided_invincible)
	self.inst:ListenForEvent("hitstreak_killed", self._on_hitstreak_killed)
end)

function DungeonTracker:StartNewRun()
	self:Reset()
end

function DungeonTracker:EndCurrentRun()

end

function DungeonTracker:OnHealthDelta(data)
	local delta = data.new - data.old
	if data.silent or delta == 0 or data.attack == nil then return end

	-- took damage
	if delta < 0 then
		local tbl = self:GetValue("damage_taken")
		local tar = data.attack:GetAttacker().prefab
		tbl[tar] = (tbl[tar] or 0) + delta
		self:SetValue("damage_taken", tbl)

		self:DeltaValue("total_damage_taken", delta)
	end
end

function DungeonTracker:OnDeath(data)
	if data.attack then
		local tbl = self:GetValue("deaths")
		local tar = data.attack:GetAttacker().prefab
		table.insert(tbl, tar)
		self:SetValue("deaths", tbl)
		self:IncrementValue("total_deaths")
	end
end

function DungeonTracker:OnKill(data)
	local victim = data.attack:GetTarget()
	if victim then
		local tbl = self:GetValue("kills")
		local tar = victim.prefab
		tbl[tar] = (tbl[tar] or 0) + 1
		self:SetValue("kills", tbl)
		self:IncrementValue("total_kills")
	end
end

function DungeonTracker:OnDoDamage(attack)
	local tbl = self:GetValue("damage_done")
	local tar = attack:GetTarget().prefab
	tbl[tar] = (tbl[tar] or 0) + attack:GetDamage()
	self:SetValue("damage_done", tbl)
	self:DeltaValue("total_damage_done", attack:GetDamage())
end

function DungeonTracker:OnGetLoot(data)
	local tbl = self:GetValue("loot")
	local tar = data.item.name
	tbl[tar] = (tbl[tar] or 0) + data.count
	self:SetValue("loot", tbl)
end

function DungeonTracker:OnHitboxCollidedInvincible(data)
	if not self.inst.sg:HasStateTag("dodge") then
		return
	end
	self:IncrementValue("perfect_dodges")
end

function DungeonTracker:OnHitStreakKilled(data)
	local tbl = self:GetValue("hitstreaks")
	table.insert(tbl, data)
	self:SetValue("hitstreaks", tbl)
end

return DungeonTracker
