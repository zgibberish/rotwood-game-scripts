local fmodtable = require "defs.sound.fmodtable"
local krandom = require "util.krandom"
local lume = require "util.lume"
local emotion = require "defs.emotion"

require "class"
require "util"

local Cooker = Class(function(self, inst)
	self.inst = inst
	self.button_mappings =
	{
		{ button = Controls.Digital.MINIGAME_WEST,  note = 1 },
		{ button = Controls.Digital.MINIGAME_NORTH, note = 2 },
		{ button = Controls.Digital.MINIGAME_EAST,  note = 3 },
		{ button = Controls.Digital.MINIGAME_SOUTH, note = 4 },
		{ button = Controls.Digital.MINIGAME_SOUTH, note = 5 },
		{ button = Controls.Digital.MINIGAME_EAST,  note = 6 },
		{ button = Controls.Digital.MINIGAME_NORTH, note = 7 },
		{ button = Controls.Digital.MINIGAME_WEST,  note = 8 },
	}
	self.button_inputs = lume.unique(lume.map(self.button_mappings, function(v)
		return v.button
	end))

	self._onminigame_complete = function(source, data)
		self:StopCookingSong(data.score / data.maxscore)
	end
end)

function Cooker:OnRemoveFromEntity()
	self.inst:RemoveEventCallback("minigame_complete", self._onminigame_complete)
end
function Cooker:OnRemoveEntity()
	self:OnRemoveFromEntity()
end


local SEQUENCES = -- 8 beats, 1 means a note is placed there, 0 means a rest
{
	easy =
	{
		1, 0, 0, 0, 1, 0, 1, 0
	},
	medium =
	{
		1, 0, 1, 0, 1, 0, 1, 0
	},
	hard =
	{
		1, 0, 1, 0, 1, 1, 1, 0
	}
}


local FIRST_LAST_NOTE =
{
		-- For musical reasons, the first and last notes should be chosen from this
		{ button = Controls.Digital.MINIGAME_WEST,  note = 1 },
		{ button = Controls.Digital.MINIGAME_EAST,  note = 3 },
		{ button = Controls.Digital.MINIGAME_SOUTH, note = 5 },
		{ button = Controls.Digital.MINIGAME_WEST,  note = 8 },
}

local MEDIUM_THRESHOLD = 0.4
local HARD_THRESHOLD = 0.7

local function CookItems(ingredients)
	local recipe_difficulty = 0
	for i = 1, #ingredients do
		local cookable_data = i.cookable_data

		-- Determine the difficulty of the recipe
		recipe_difficulty = recipe_difficulty + cookable_data.difficulty

		-- Determine the effects of the recipe
	end

end

function Cooker:GenerateButtonSequence(progress)
	assert(progress <= 1)
	local max_score = 0
	local sequence
	if progress >= HARD_THRESHOLD then
		sequence = SEQUENCES.hard
	elseif progress >= MEDIUM_THRESHOLD then
		sequence = SEQUENCES.medium
	else
		sequence = SEQUENCES.easy
	end

	local shuffled_buttons = krandom.ShuffleCopy(self.button_mappings) -- randomize the buttons
	for x = 1, #shuffled_buttons do
		if shuffled_buttons[x].note == 0 then
			table.remove(shuffled_buttons, x)
			break
		end
	end

	local first_last_button = krandom.ShuffleCopy(FIRST_LAST_NOTE)

	local button_sequence = {}
	button_sequence[1] = first_last_button[1]
	max_score = max_score + 1
	table.remove(first_last_button, 1)

	for i = 1, #sequence do
		if i ~= 1 then
			if sequence[i] == 1 then
				button_sequence[i] = shuffled_buttons[1]
				max_score = max_score + 1
				table.remove(shuffled_buttons, 1)
			else
				button_sequence[i] = { button = " ", note = 0 }
			end
		end
	end

	button_sequence[#button_sequence+1] = first_last_button[1]
	max_score = max_score + 1

	return { button_sequence = button_sequence, max_score = max_score }
end

function Cooker:DisplayCookingButton(button)
end

function Cooker:PlayCookingSong(player, sequence)
	-- TODO: How are you supposed to start cooking?
	sequence = sequence or self:GenerateButtonSequence(MEDIUM_THRESHOLD).button_sequence

	if self.stop_task then
		self.stop_task:Cancel()
		self.stop_task = nil
	end

	self.player = player
	self.player.components.playercontroller:SetInputStealer(self)
	self.inst:ListenForEvent("minigame_complete", self._onminigame_complete, player)

	for i,v in ipairs(AllPlayers) do
		if v ~= self.player then
			v:PushEvent("deafen", self.inst)
		end
	end

	TheAudio:StopPersistentSound("cooking_music") -- ensure not already running so play fires
	TheAudio:PlayPersistentSound("cooking_music", fmodtable.Event.mus_Cooking)
	TheAudio:SetPersistentSoundParameter("cooking_music", "Cooking_Beat_1", sequence[1].note)
	TheAudio:SetPersistentSoundParameter("cooking_music", "Cooking_Beat_2", sequence[2].note)
	TheAudio:SetPersistentSoundParameter("cooking_music", "Cooking_Beat_3", sequence[3].note)
	TheAudio:SetPersistentSoundParameter("cooking_music", "Cooking_Beat_4", sequence[4].note)
	TheAudio:SetPersistentSoundParameter("cooking_music", "Cooking_Beat_5", sequence[5].note)
	TheAudio:SetPersistentSoundParameter("cooking_music", "Cooking_Beat_6", sequence[6].note)
	TheAudio:SetPersistentSoundParameter("cooking_music", "Cooking_Beat_7", sequence[7].note)
	TheAudio:SetPersistentSoundParameter("cooking_music", "Cooking_Beat_8", sequence[8].note)
	TheAudio:SetPersistentSoundParameter("cooking_music", "Cooking_Beat_9", sequence[9].note)
end

function Cooker:StopCookingSong(percentComplete)
	if self.player then
		if percentComplete then
			if percentComplete >= 1.0 then
				self.inst:PushEvent("emote", emotion.emote.clap)
				self.inst:DoTaskInTime(2, function(inst) inst:PushEvent("emote", emotion.feeling.happy) end)
			elseif percentComplete > 0.0 then
				self.inst:PushEvent("emote", emotion.emote.dejected)
				self.inst:DoTaskInTime(2, function(inst) inst:PushEvent("emote", emotion.emote.shrug) end)
			else
				self.inst:PushEvent("emote", emotion.emote.angry)
				self.inst:DoTaskInTime(2, function(inst) inst:PushEvent("emote", emotion.feeling.neutral) end)
			end
		end

		self.player.components.playercontroller:SetInputStealer(nil)
		self.player = nil
	end
	if self.stop_task then
		self.stop_task:Cancel()
	end
	self.stop_task = self.inst:DoTaskInTime(3, function(inst)
		-- Delay to allow final music flourish.
		TheAudio:StopPersistentSound("cooking_music")
	end)
end


function Cooker:OnControl(controls, down)
	if not down then
		return
	end
	for _,desired_control in ipairs(self.button_inputs) do
		if controls:Has(desired_control) then
			self.player:PushEvent("oncontrol_music", { control = desired_control, })
		end
	end
end

return Cooker
