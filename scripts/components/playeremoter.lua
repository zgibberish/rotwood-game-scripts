local Equipment = require("defs.equipment")

-- Player can equip emotes into different slots

local PlayerEmoter = Class(function(self, inst)
	self.inst = inst
	self.emotes =
	{
		-- Clockwise from top
		[1] = nil, -- Top
		[2] = nil, -- Top-right
		[3] = nil, -- Right
		[4] = nil, -- Bottom-right
		[5] = nil, -- Bottom
		[6] = nil, -- Bottom-left
		[7] = nil, -- Left
		[8] = nil, -- Top-left
	}
end)


function PlayerEmoter:EquipEmote(slot_index, emote_id)
	self.emotes[slot_index] = emote_id
end

function PlayerEmoter:GetEmotes()
	return self.emotes
end

function PlayerEmoter:GetEmote(slot_index)
	return self.emotes[slot_index]
end

function PlayerEmoter:DoEmote(slot_index)
	if self.inst.sg:HasStateTag("busy") then
		-- Allow them to emote if they are turning or presently in another emote
		if not self.inst.sg:HasStateTag("turning") and not self.inst.sg:HasStateTag("emote") then
			return
		end
	end
	local emote = self.emotes[slot_index]
	if emote ~= nil then
		self.inst.sg:GoToState(emote)
	end
end

return PlayerEmoter
