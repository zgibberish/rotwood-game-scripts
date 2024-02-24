local Lume = require "util.lume"

-- Return a random selection from choices, with those choices weigted by WeightFn.
-- This function can return nil if choices is empty, or if all choices have a weight of 0.
function WeightedChoice(rng, choices, WeightFn)
	if not (choices and next(choices)) then
		return nil
	end
	
	assert(type(next(choices)) == "number", "Dict-like tables for 'choices' will break determinism.")

	local weight_total = 0
	local weighted_choices = Lume(choices)
		:map(function(choice) 
			local weight = WeightFn(choice)
			weight_total = weight_total + weight
			return {
				choice = choice,
				weight = weight
			}
		end)
		:result()

	local choice = rng:Float(weight_total)
	local fallback
	for _, weighted_choice in ipairs(weighted_choices) do
		choice = choice - weighted_choice.weight
		if weighted_choice.weight ~= 0 then
			if choice <= 0 then
				return weighted_choice.choice
			end
			fallback = weighted_choice.choice
		end
	end
	return fallback
end
