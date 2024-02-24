local emotion = require "defs.emotion"
local fmodtable = require "defs.sound.fmodtable"
local kassert = require "util.kassert"
require "class"

local feeling_params = {
	-- Parameter values passed to fmod.
	neutral = 0,
	happy = 1,
}

for key,val in pairs(emotion.feeling) do
	kassert.assert_fmt(feeling_params[key], "Missing feeling '%s'.", key)
end


local TalkAudio = Class(function(self, inst)
	self.inst = inst

	local key = self.inst.prefab .."_chat_LP"
	self.talk_sound = fmodtable.Event[key]
	if not self.talk_sound then
		TheLog.ch.Audio:printf("WARNING: prefab '%s' doesn't have a chat event. Expected '%s'. Falling back to npc_scout_chat_LP.",
			self.inst.prefab,
			key)
		self.talk_sound = fmodtable.Event.npc_blah_talk_LP
	end
	assert(self.talk_sound, "Missing fallback chat audio event. Please update above code.")

	self.talk_id = "lipflap_id"
	self.last_feeling = emotion.feeling.neutral
	self.is_talking = false

	self._ontalk = function() self:StartTalk() end
	self.inst:ListenForEvent("talk", self._ontalk)

	self._onshutup = function() self:StopTalk() end
	self.inst:ListenForEvent("shutup", self._onshutup)

	self._onfeeling = function(source, feeling) self:SetFeeling(feeling) end
	self.inst:ListenForEvent("feeling", self._onfeeling)

	self._onblah = function() self:TriggerBlah() end
	self.inst:ListenForEvent("speech_blah", self._onblah)

end)

function TalkAudio:OnRemoveFromEntity()
	self.inst:RemoveEventCallback("feeling", self._onfeeling)
	self.inst:RemoveEventCallback("shutup", self._onshutup)
	self.inst:RemoveEventCallback("talk", self._ontalk)
	self.inst:RemoveEventCallback("speech_blah", self._onblah)
end
function TalkAudio:OnRemoveEntity()
	self:OnRemoveFromEntity()
end


function TalkAudio:StartTalk()
	if self.is_talking then
		-- When player skips, sometimes we get two talks without a shutup.
		return
	end
	self.is_talking = true
	self.inst.SoundEmitter:PlaySound(self.talk_sound, self.talk_id)
	-- We often send feeling before talk, so the sound may not exist when
	-- feeling is set. Set the feeling after playing to ensure it's set.
	self:SetFeeling(self.last_feeling)
end

function TalkAudio:StopTalk()
	self.is_talking = false
	self.inst.SoundEmitter:KillSound(self.talk_id)
end

function TalkAudio:TriggerBlah()
	-- TheDungeon.HUD:MakePopText({ target = self.inst, button = "blah", color = UICOLORS.GREEN, size = 25, fade_time = .5 })
	self.inst.SoundEmitter:SetParameter(self.talk_id, "speech_blah", 1)
end

function TalkAudio:SetFeeling(feeling)
	assert(feeling, "Received no feeling data?")
	self.last_feeling = feeling
	self.inst.SoundEmitter:SetParameter(self.talk_id, "feeling", feeling_params[feeling])
end



return TalkAudio
