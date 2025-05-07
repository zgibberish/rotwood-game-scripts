-- A custom constructor which creates a state as usual, and then adds it to a list to be added to the player's stategraph.
-- Rather than adding these skill states to the player on demand, we add them all and then route the player to the correct state so the embellisher can trust that the stategraph is final.

local _allplayerskillstates = {}

local PlayerSkillState = Class(State, function(self, args)
	State._ctor(self, args)
	table.insert(_allplayerskillstates, self)
end)

function PlayerSkillState:GetPlayerSkillStates()
	return _allplayerskillstates
end

return PlayerSkillState