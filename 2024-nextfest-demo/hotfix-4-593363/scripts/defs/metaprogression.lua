local MetaProgression = require "defs.metaprogression.metaprogress"

local function ValidateUnlocks()
	local lume = require("util/lume")
	local Power = require "defs.powers"
	local undroppable_powers = {}

	for _, slot in pairs(Power.Slots) do
		for name, def in pairs(Power.Items[slot]) do
			if def.can_drop and def.show_in_ui then
				undroppable_powers[name] = false
			end
		end
	end

	for _, slot in pairs(MetaProgression.Slots) do
		for name, def in pairs(MetaProgression.Items[slot]) do
			for _, reward in ipairs(def.rewards) do
				if reward:is_a(MetaProgression.RewardGroup) then
					for _, sub_reward in ipairs(reward:GetRewards()) do
						local power_name = sub_reward.def and sub_reward.def.name or ""
						if undroppable_powers[power_name] ~= nil then
							undroppable_powers[power_name] = true
						end
					end
				else
					local power_name = reward.def and reward.def.name or ""
					if undroppable_powers[power_name] ~= nil then
						undroppable_powers[power_name] = true
					end
				end
			end
		end
	end

	undroppable_powers = lume.filter(undroppable_powers, function(a) return not a end, true)

	if next(undroppable_powers) then
		print("THE FOLLOWING POWERS CANNOT BE UNLOCKED:")
		for name, _ in pairs(undroppable_powers) do
			printf("> %s", name)
		end
		assert(false, "There are powers that cannot be unlocked in the game! (see above for a list). Please add to a MetaProgress list (like biomeexploration.lua) or add to defaultunlocks.lua to prototype.")
	end
end

require "defs.metaprogression.metareward"
require "defs.metaprogression.progressinstance"
require "defs.metaprogression.defaultunlocks"

require "defs.metaprogression.biomeexploration"
require "defs.metaprogression.monsterresearch"

require "defs.equipmentgems.damagegems"
require "defs.equipmentgems.supportgems"
require "defs.equipmentgems.sustaingems"

require "defs.metaprogression.relationships_core"

ValidateUnlocks()

return MetaProgression
