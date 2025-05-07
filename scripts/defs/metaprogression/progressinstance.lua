local MetaProgress = require "defs.metaprogression.metaprogress"

MetaProgress.ProgressInstance = Class(function(self, progress)
	self.persistdata = progress -- holds information like exp gained towards reward
	self.def = progress:GetDef() -- the def of what the rewards are
	self.mem = {} -- temp memory... do we need this for rewards?
end)

function MetaProgress.ProgressInstance:GetLocalizedName()
	return self.persistdata:GetLocalizedName()
end

function MetaProgress.ProgressInstance:GetEXP()
	return self.persistdata.exp
end

function MetaProgress.ProgressInstance:GetLevel()
	return self.persistdata.level
end

function MetaProgress.ProgressInstance:IncreaseLevel()
	local old = self:GetLevel()
	local new = old + 1
	self.persistdata.level = new
	self.persistdata.exp = 0
end

function MetaProgress.ProgressInstance:DeltaExperience(delta)
	local until_level = self:GetEXPUntilNextLevel()

	local actual_delta = math.min(delta, until_level)

	self.persistdata.exp = self.persistdata.exp + actual_delta
	local remaining = delta - actual_delta
	local used = delta - remaining

	return used, remaining
end

function MetaProgress.ProgressInstance:GetEXPForLevel(level)
	return MetaProgress.GetEXPForLevel(self.def, level)
end

function MetaProgress.ProgressInstance:GetRewardForLevel(level)
	return MetaProgress.GetRewardForLevel(self.def, level)
end

function MetaProgress.ProgressInstance:GetEXPUntilNextLevel()
	local level = self:GetLevel()
	local needed = self:GetEXPForLevel(level)
	return needed - self:GetEXP()
end

function MetaProgress.ProgressInstance:GrantExperience(exp)
	local total_used = 0
	local total_remaining = exp

	local level_up_log = {}
	local unlocks = {}

	while total_remaining > 0 and total_used < exp do
		local reward = nil
		local start_level = self:GetLevel()
		local start_exp = self:GetEXP()

		local used, remaining = self:DeltaExperience(total_remaining)
		total_used = total_used + used
		total_remaining = remaining

		local end_exp = self:GetEXP()

		if self:GetEXPUntilNextLevel() <= 0 then
			self:IncreaseLevel()
			reward = self:GetRewardForLevel(self:GetLevel())
			table.insert(unlocks, reward)
		end

		table.insert(level_up_log, {
			start_level = start_level,
			did_level = start_level ~= self:GetLevel(),
			reward = reward,

			start_exp = start_exp,
			end_exp = end_exp,
		})
	end

	return level_up_log, unlocks
end

function MetaProgress.ProgressInstance:PreviewExperienceGain(exp)
	local start_level = self:GetLevel()
	local start_exp = self:GetEXP()
	local remaining_exp = self:GetEXPUntilNextLevel()

	if exp >= remaining_exp then
		exp = exp - remaining_exp
		local level = start_level + 1

		while exp >= self:GetEXPForLevel(level) do
			exp = exp - self:GetEXPForLevel(level)
			level = level + 1
		end

		return level, exp
	else
		return start_level, start_exp + exp
	end
end

function MetaProgress.ProgressInstance:UnlockAllRewards()

end
