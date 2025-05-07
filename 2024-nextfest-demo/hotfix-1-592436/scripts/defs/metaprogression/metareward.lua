local MetaProgress = require "defs.metaprogression.metaprogress"
local Consumable = require"defs.consumable"
local Power = require"defs.powers"

local slotutil = require "defs.slotutil"
local reward_group_icons = require "gen.atlas.ui_ftf_reward_group_icons"

MetaProgress.Reward = Class(function(self, category, slot, id, count)
	local def = category.Items[slot][id]
	self.slot = slot
	self.def = def
	self.count = count or 1 -- default to 1. Only used when giving players items.

	if def ~= nil then
		-- if the reward has a def then give the reward easy access to the icon and pretty strings of the reward
		self.pretty = def.pretty
		self.icon = def.icon
	end
end)

function MetaProgress.Reward:UnlockRewardForPlayer(player)
	if self.def.slot == Power.Slots.PLAYER then
		player.components.unlocktracker:UnlockPower(self.def.name)
	elseif self.def.slot == Power.Slots.SKILL then
		player.components.unlocktracker:UnlockPower(self.def.name)
	elseif self.def.slot == Consumable.Slots.KEY_ITEMS then
		if self.def.recipes then
			for _, data in ipairs(self.def.recipes) do
				player.components.unlocktracker:UnlockRecipe(data.name)
			end
		end
	elseif self.def.slot == Consumable.Slots.MATERIALS then
		-- give the player an item
		player.components.inventoryhoard:AddStackable(self.def, self.count)
	else
		assert(true, string.format("Invalid progress Type! [%s - %s]", self.def.slot, self.def.name))
	end
end

local function GetIcon(group_id)
	local icon_name = ("reward_group_%s"):format(group_id)
	local tex = reward_group_icons.tex[icon_name] or reward_group_icons.tex["reward_group_temp"]
	return tex
end

MetaProgress.RewardGroup = Class(function(self, name, rewards)
	self.name = name
	self.icon = GetIcon(name) -- All reward groups will have the temp texture right now

	-- Currently does NOT validate that strings for these exist
	self.pretty = slotutil.GetPrettyStrings("REWARDGROUPS", name)

	self.rewards = rewards
end)

function MetaProgress.RewardGroup:GetRewards()
	return self.rewards
end

function MetaProgress.RewardGroup:GetIcon()
	return self.icon
end

function MetaProgress.RewardGroup:UnlockRewardForPlayer(player)
	for _, reward in ipairs(self:GetRewards()) do
		-- printf("Unlocking reward for player has part of reward group: %s", reward.def.name)
		reward:UnlockRewardForPlayer(player)
	end
end
