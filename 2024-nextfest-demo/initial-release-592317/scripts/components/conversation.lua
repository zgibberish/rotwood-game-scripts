local ConvoPlayer = require "questral.convoplayer"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local audioid = require "defs.sound.audioid"
local camerautil = require "util.camerautil"
local color = require "math.modules.color"
local emotion = require "defs.emotion"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"
require "class"


local CONVERSATION_CAMERA_PARAMETERS =
{
	-- Pitch transition parameters
	curve={ -- The curve of the pitch transition
		0.0,
		0,
		0.14285714924335,
		0.53733563423157,
		0.28571429848671,
		0.81406557559967,
		0.4285714328289,
		0.93907302618027,
		0.57142859697342,
		0.98554176092148,
		0.71428573131561,
		0.99809604883194,
		0.85714286565781,
		0.99994051456451,
		1.0,
		1.0,
	},
	duration=40, -- How long it takes the pitch transition to complete
	pitch=17,    -- Destination pitch

	-- Other presentation parameters
	zoom_amount = -15, -- how much to zoom in or out during conversation

	camera_x_offset = 0,  -- x offset during conversation (left/right positioning of actors in frame)
	camera_z_offset = 6,  -- z offset during conversation (up/right positioning of actors in frame)
	letter_box = true,    -- whether or not we should letterbox during conversation

	speech_box_z_offset = 500, -- z offset of the speech bubbles during conversation (relative to actor)
}

-- Put Conversation component on entities that can talk to the player.
local Conversation = Class(function(self, inst)
	self.inst = inst

	self.convoplayer = ConvoPlayer(self)
	self.focus_sources = {}

	self.persist = {
		memory = {},
	}
	self.temp = {}

	self.onstartmodal = function()
		-- Nonmodal conversations started via callback were likely started from
		-- a mouse click on a button press. We want to always go through the
		-- interaction system so gamepad and mouse are consistent.
		local player = self:GetTarget()
		local interactable = self.inst.components.interactable

		-- gracefully fail if for any reason player can no longer interact with NPC
		local caninteract, error = interactable:CanPlayerInteract(player, true)
		if not caninteract then
			TheLog.ch.Convo:printf("Could not interact: %s", error)
			return
		end

		local data = {
			target = self.inst,
			dir = 0,
		}
		-- Will trigger BeginModalConversation.
		player.components.playercontroller:SnapToInteractEvent(data)
	end
	self.ontalk = function()
		assert(self.was_modal, "Should start modal with BeginModalConversation.")
		-- This is the moment when the speech bubbles are animated out and we
		-- can present the next block.
		self:_OnTalk(true)
	end
	self.onrestartconvo = function()
		self:_RestartConversation(self:GetBestQuest(true))
	end
	self.onendconvo = function()
		self:_EndConversation(self.target)
		-- Don't need to try to restart the convo here. The interaction system
		-- will do it automatically if the npc has a valid interaction.
	end

	self.restart_delay = 1
end)

function Conversation:OnSave()
	if next(self.persist.memory) then
		return self.persist
	end
end

function Conversation:OnLoad(data)
	self.persist = data
end

function Conversation:GetTarget()
	return self.target
end

-- Shim for questral
function Conversation:GetPlayer()
	return self.target
end

function Conversation:SetFlagAsTemp(is_temp)
	self.temp_writing = is_temp
end

function Conversation:ActivatePrompt(player)
	if self.target and self.target ~= player then
		TheLog.ch.Conversation:print("ActivatePrompt ignored (target already exists)")
		return
	end
	self.target = player

	local npc_id = self.inst.prefab
	self.pretty_name = STRINGS.NAMES[npc_id]

	self.should_record_line = true
	self:_ConstructPrompt()
	self:_RestartConversation(self:GetBestQuest(true))

	self.inst:PushEvent("activate_convo_prompt")
end

-- Generally, the prompt is only constructed when we start a conversation, but
-- if a conversation has another screen popup partway through, then we'll
-- re-construct the prompt when the screen closes. We do this because
-- conversation relies on interaction which may require a new target for
-- screen/actions (like placers).
function Conversation:_ConstructPrompt()
	TheLog.ch.Conversation:print("ConstructPrompt", self.inst, self.target)
	self.prompt = TheDungeon.HUD:ShowNpcPrompt(self.inst, self.target)
		:Offset(0, 190)
end

function Conversation:DebugDrawEntity( ui, panel, colors )
	ui:Value("target (player)", self.target)
	if ui:CollapsingHeader("ConvoPlayer", ui.TreeNodeFlags.DefaultOpen) then
		ui:Indent()
		self.convoplayer:RenderDebugPanel(ui, panel)
		ui:Unindent()
	end
	panel:GetNode():AddFilteredAll(ui, panel, self)
end

function Conversation:Close(fn)
end

function Conversation:PlayEmote(agent, emote)
	-- Don't _TryRecordLine here because it's just state on npc and not on UI.

	-- TODO(dbriscoe): Add new locmacro to differentiate between these two?
	if emotion.emote[emote] then
		self.inst:PushEvent("emote", emote)

	elseif emotion.feeling[emote] then
		self.inst:PushEvent("feeling", emote)
	end
end

function Conversation:ClearMessage()
end

function Conversation:IsShowingMessage()
end

function Conversation:_SetSpeaker(agent)
	if not agent then
		-- Narration.
		self.prompt:ShowNpcName(nil)
		return
	end

	local name = ""
	local inst = agent.inst
	local show_name = true
	if agent.inst and agent.inst:HasTag("player") then
		self.prompt:SetTarget(agent.inst)
		name = agent.inst:GetCustomUserName()
		assert(agent.inst.uicolor, "What happened to player color?")
		-- tint = color(agent.inst.uicolor)
		show_name = false -- Don't show the player's name on speech bubbles
	elseif agent.inst then
		self.prompt:SetTarget(agent.inst)
		name = agent:GetName()
	else
		self.prompt:SetTarget(self.inst)
		name = self.pretty_name
		inst = self.inst
	end

	if self.temp_writing then
		name = ("%s <#RED>[%s]</>"):format(name, STRINGS.TALK.TITLE_TEMPWRITING)
	end

	local focalpoint = TheFocalPoint.components.focalpoint
	if self.was_modal and not focalpoint:HasExplicitTarget(inst) then
		self:_AddSecondarySpeaker(inst)
	end

	self.prompt:ShowNpcName(show_name and name)
	return inst
end

function Conversation:PlayLine(agent, line)
	self:_TryRecordLine(Conversation.PlayLine, agent, line)
	self:_ShowSpeechBalloon(line, agent)
end

function Conversation:PlayNarration(line)
	self:_TryRecordLine(Conversation.PlayNarration, line)
	self:_ShowSpeechBalloon(("<i>%s</i>"):format(line), nil)
end

function Conversation:_TryRecordLine(fn, ...)
	self.recorded_line = nil
	if self.should_record_line then
		self.should_record_line = false
		self.recorded_line = {
			fn = fn,
			args = { ... },
		}
	end
end

function Conversation:_GetPersonality(agent)
	if agent
		and agent.inst
		and agent.inst.components.npc
	then
		return agent.inst.components.npc:GetTextPersonality()
	end
	TheLog.ch.Conversation:print("Using default personality for invalid/non-npc:", agent)
	return Npc.BuildDefaultTextPersonality()
end

function Conversation:_ShowSpeechBalloon(line, agent)
	self:_SetSpeaker(agent)

	local cb
	if self.was_modal then
		cb = self.ontalk
	else
		cb = self.onstartmodal
	end

	self.prompt:ShowDialogBalloonSpooled(line, self:_GetPersonality(agent), cb, not self.was_modal)
	if not self.was_modal then
		-- Skip spool on attract line so it doesn't cause input delays in
		-- starting the conversation.
		-- TODO: Using ShowDialogBalloon instead prevents errors when mashing
		-- buttons to start a convo. Why?
		self.prompt:SnapSpool()
	end

	self.prompt:AnimateIn()
end

function Conversation:PlayRecipeMenu(agent, line, recipe)
	self:_TryRecordLine(Conversation.PlayRecipeMenu, agent, line, recipe)
	self:_SetSpeaker(agent)
	self.prompt:ShowRecipeMenu(self.target, line, self:_GetPersonality(agent), recipe, self.ontalk)
end

function Conversation:HideMenu()
end

function Conversation:SetSpeaker(agent)
	assert(agent.inst, "Speaker entity not created yet!")
end

function Conversation:StopTalking()
end

function Conversation:SetBlocker(val)
end

-- TODO(dbriscoe): Remove?
function Conversation:EndConvo()
	self:_EndConversation(self.target)
	self.target = nil
end

function Conversation:OnResumeFromCallback()
	-- TODO(dbriscoe): This setup allows us to resume conversation after
	-- placing or other interruptions, but needs polish.
	local player = self.convoplayer:GetPlayer()
	if player then
		assert(player.inst)
		self.target = player.inst
	end
	-- Action may have hidden the prompt without telling us.
	if not self.prompt or not self.prompt.inst:IsValid() then
		self:_ConstructPrompt()
		self.prompt:SetModal(true)
	end
	assert(self.prompt.inst:IsValid())
end

-- header can be a string or a quest
function Conversation:PresentOptions(options, header)

	if self.recorded_line then
		-- If you put Opt right after a single line of Talk, then we'll switch
		-- from nonmodal to modal and lose the original text. We don't use when
		-- we can advance to a dialogue line instead.
		local t = self.recorded_line
		t.fn(self, table.unpack(t.args))
		assert(not self.recorded_line)
		self.prompt:SnapSpool()
	end

	local did_back = false
	for k, option in ipairs(options) do

		local opt
		if option.is_back then
			assert(not did_back, "multiple back buttons!")
			opt = self.prompt:ShowActionButton(
				"<p img='images/ui_ftf_dialog/convo_end.tex' color=0>",
				option.txt or STRINGS.TALK.OPT_BACK,
				function()
					self.convoplayer:PickOption(k)
					-- TODO(dbriscoe): Implement going back to the main
					-- conversation loop?
				end,
				self.restart_delay,
				false)
			did_back = true
		else
			opt = self.prompt:ShowActionButton(option.right_text, option.txt, function()
				self.convoplayer:PickOption(k)
			end)
		end

		if not option:IsEnabled() then
			opt:Disable()
		end

		--~ if not option:IsEnabled() then
		--~ 	opt:Disable()
		--~ end

		--~ --do some checking on the functions available, in case the user is using an esoteric menu button type
		--~ if opt.MarkWithQuest then
		--~ 	local quests = option:GetQuestMarks()
		--~ 	if quests then
		--~ 		for _, quest in ipairs(quests) do
		--~ 			opt:MarkWithQuest(quest)
		--~ 		end
		--~ 	end
		--~ end

		--~ if opt.SetPercentChance then
		--~ 	local pc = option:GetPercentChance()
		--~ 	if pc then
		--~ 		opt:SetPercentChance(pc)
		--~ 	end
		--~ end


		--~ --we could get the success/failure tooltips here, too, to show that.
		--~ for i, tt in ipairs( option:GetTooltips() ) do
		--~ 	if not opt.AppendTooltip then
		--~ 		opt:SetTooltip( tt )
		--~ 	else
		--~ 		opt:AppendTooltip( tt )
		--~ 	end
		--~ end

		--~ if opt.AddTooltip then
		--~ 	local success
		--~ 	for i, tt in ipairs( option:GetSuccessTooltips() ) do
		--~ 		if type(tt) == "string" then
		--~ 			success = success or {self:LOC"SUCCESS_HEADER"}
		--~ 			table.insert(success, tt)
		--~ 		end
		--~ 	end
		--~ 	if success then
		--~ 		opt:AddTooltip(table.concat(success, "\n"))
		--~ 	end

		--~ 	local failure
		--~ 	for i, tt in ipairs( option:GetFailureTooltips() ) do
		--~ 		if type(tt) == "string" then
		--~ 			failure = failure or {self:LOC"FAILURE_HEADER"}
		--~ 			table.insert(failure, tt)
		--~ 		end
		--~ 	end
		--~ 	if failure then
		--~ 		opt:AddTooltip(table.concat(failure, "\n"))
		--~ 	end
		--~ end

		--~ if option.icon and opt.SetIcon then
		--~ 	opt:SetIcon(option.icon)
		--~ end

		--~ if option.sub_text and opt.SetSubText then
		--~ 	opt:SetSubText(option.sub_text)
		--~ end

		--~ if option.is_new then
		--~ 	opt:MarkAsNew()
		--~ end
	end

	self.prompt:SetModal(true)
		:ShowNpcName(self.pretty_name)
		:AnimateIn()
end

function Conversation:_ClearState()
	self.was_modal = false
end

function Conversation:GetBestQuest(force_convo)
	local questcentral = self:GetPlayer().components.questcentral
	local castmanager = TheDungeon.progression.components.castmanager
	local actor = castmanager:GetNpcNode(self.inst)
	local qm = questcentral:GetQuestManager()
	-- TODO(dbriscoe): Confront should trigger the conversation instead of
	-- being a higher priority attract.
	local state, quest, node = qm:EvaluateHook(Quest.CONVO_HOOK.s.CONFRONT, actor)
	if not quest then
		local hook = Quest.CONVO_HOOK.s.CHAT_DUNGEON
		if TheWorld:HasTag("town") then
			hook = Quest.CONVO_HOOK.s.CHAT_TOWN
		end
		state, quest, node = qm:EvaluateHook(hook, actor)
	end

	if not quest and TheWorld:HasTag("town") then
		state, quest, node = qm:EvaluateHook(Quest.CONVO_HOOK.s.CHAT_TOWN_SHOP, actor)
	end

	if not quest then
		state, quest, node = qm:EvaluateHook(Quest.CONVO_HOOK.s.ATTRACT, actor)
	end

	if not quest and force_convo then
		qm:SpawnQuest("twn_fallback_chat", nil, nil, {
				giver = actor,
			})
		state, quest, node = qm:EvaluateHook(Quest.CONVO_HOOK.s.ATTRACT, actor)
	end

	return state, quest, node
end


function Conversation:Debug_ForceStartConvo(player, state, quest)
	self:Debug_ForceEndConvo(player)
	self:ActivatePrompt(player)
	self.prompt:ResetAll(function()
		local castmanager = TheDungeon.progression.components.castmanager
		local actor = castmanager:GetNpcNode(self.inst)
		self:_RestartConversation(state, quest, actor)
	end, 0, true)
end
function Conversation:Debug_ForceEndConvo(player)
	self.convoplayer:ClearConvo()
	if self.prompt then
		self:_EndConversation(player)
	end
end

function Conversation:CanStartModalConversation(player)
	local hud = TheDungeon.HUD
	if self.inst.components.timer:HasTimer("talk_cd") then
		return false, "talk_cd"
	elseif hud:IsHudSinkingInput() then
		-- TODO(dbriscoe): Is this check necessary?
		return false, "HUD"
	elseif hud:GetPromptTarget() then
		return false, "prompt"
	end
	if self.was_modal then
		return false, "in conversation"
	end
	return true
end

function Conversation:BeginModalConversation()
	assert(not self.was_modal, "Don't call inside a conversation.")
	assert(self.prompt, "Should have hit ActivatePrompt when within range.")
	assert(self.target)

	self.convoplayer:SetForceWaitAfterLine(false)
	self.was_modal = true
	TheLog.ch.Conversation:print("Start conversation", self.inst, self.target)
	self.target:PushEvent('conversation', { action = 'start', npc = self.inst, })

	self:_StartConversationCamera()
	self.prompt:Offset(0, CONVERSATION_CAMERA_PARAMETERS.speech_box_z_offset)

	self.prompt:BeginModalConversation(self.ontalk)
end

function Conversation:_AddSecondarySpeaker(inst)
	assert(inst)
	self.focus_sources[inst] = true
	TheFocalPoint.components.focalpoint:StartFocusSource(inst, FocusPreset.CONVO)
end

function Conversation:_RestartConversation(state, quest, node)
	assert(self.target, "Lost player target but trying to restart.")
	self:_ClearEmotion()
	self:_ClearState()

	-- TODO(dbriscoe): Don't allow interaction unless we have a quest.
	assert(quest, "Couldn't find a quest! TODO: have fallback 'quest' (quip).")
	local questcentral = self:GetPlayer().components.questcentral
	local castmanager = TheDungeon.progression.components.castmanager

	self.convoplayer:SetSim(questcentral)
	self.convoplayer:SetPlayer(castmanager:GetPlayerNode(self.target))

	self:_PushQuest({ convo = state, quest = quest, node = node })
	self:_OnTalk(false)
end

function Conversation:_PushQuest(q)
	self.questinfo = q
	-- Force wait for the first line to complete so it acts as a hail.
	self.convoplayer:SetForceWaitAfterLine(true)
	self.convoplayer:StartConvoCoro(q.convo, q.quest, q.node, self.onendconvo)
	assert(self.prompt, "We pushed a coro that had no dialogue! Please fix the quest logic.")
end

function Conversation:IsInQuestConvo(quest, objective_id)
	dbassert(quest)
	return (self.prompt
		and self.questinfo
		and quest == self.questinfo.quest
		and (not objective_id or objective_id == self.questinfo.convo.convo.objective_id))
end

function Conversation:_OnTalk(is_modal)
	assert(self.prompt)
	-- TODO(dbriscoe): special handle for quips to make it non modal

	if is_modal then
		self.convoplayer:Advance()
		-- Conversation may be done at this point and _EndConversation called!
		-- Or we may have queued up a bunch of text on the prompt.
	end

	if not self.convoplayer:IsConvoDone() then
		assert(self.prompt, "Prompt shouldn't have been cleared unless the convo ended.")
		self.prompt:SetModal(is_modal)
			:AnimateIn()
	end
end

function Conversation:_EndConversation(player)
	--print(debugstack())
	assert(player)
	assert(self.convoplayer:IsConvoDone(), "How did we end without finishing?")
	TheLog.ch.Conversation:print("End conversation", self.inst, player)
	
	self:_EndConversationCamera()

	player:PushEvent('conversation', { action = 'end', npc = self.inst, })
	self:DeactivatePrompt(self.target)
	-- Unlike other interactions, conversations control when the interaction is
	-- cleared so player can enter other sg states during convo. ClearInteract
	-- *after* DeactivatePrompt so it doesn't try to clear the prompt again.
	self.inst.components.interactable:ClearInteract(player)
end

function Conversation:TryDeactivatePrompt(player)
	if player ~= self.target then
		TheLog.ch.Conversation:print("TryDeactivatePrompt ignored (target not matching)")
		return
	end
	if self.was_modal then
		-- Cannot externally deactivate while modal.
		return
	end
	self:DeactivatePrompt(player)
	return true
end

-- Called after exiting conversation or when walking away after initial hail
-- dialogue. We shouldn't deactivate the prompt in the middle of a conversation!
function Conversation:DeactivatePrompt(player)
	TheLog.ch.Conversation:print("DeactivatePrompt", self.inst, self.target)
	assert(player == self.target)
	assert(self.prompt)
	assert(not self.convoplayer:IsWaitingForCallback())

	-- We should have two possibilities:
	-- * convo is over
	-- * convo was never modal and player walked away

	self.convoplayer:ClearConvo()

	-- force the prompt's target back to myself so that the hud will actually close it
	self.prompt:SetTarget(self.inst)

	TheDungeon.HUD:HidePrompt(self.inst)
	self.prompt = nil
	self.target = nil
	self:_ClearEmotion()
	self:_ClearState()

	local timer = self.inst.components.timer
	if not timer:HasTimer("talk_cd") then
		timer:StartTimer("talk_cd", 1.0)
	end

	self.inst:PushEvent("deactivate_convo_prompt")

end

function Conversation:_ClearEmotion()
	self.inst:PushEvent("emote", nil)
	self.inst:PushEvent("feeling", self.inst.default_feeling or emotion.feeling.neutral)
end

function Conversation:_StartConversationCamera()
	--sound
	local params = {}
	params.fmodevent = fmodtable.Event.Snapshot_Interacting_LP
	self.interactable_snapshot = soundutil.PlayLocalSoundData(self.inst, params)
	TheAudio:SetPersistentSoundParameter(audioid.persistent.world_music, "isInteracting", 1)
	TheAudio:SetPersistentSoundParameter(audioid.persistent.room_music, "isInteracting", 1)

	-- Explictly focus on main conversation members so other players don't pull
	-- camera away from text.
	TheFocalPoint.components.focalpoint:AddExplicitTarget(self.target)
	TheFocalPoint.components.focalpoint:AddExplicitTarget(self.inst)

	-- Zoom
	TheCamera:SetZoom(CONVERSATION_CAMERA_PARAMETERS.zoom_amount)

	-- In case the conversation target is towards the edge of screen, still let us zoom right in on them.
	TheWorld.components.cameralimits:SetEnabled(false)

	-- Pitch
	camerautil.BlendPitch(self.inst, CONVERSATION_CAMERA_PARAMETERS)

	-- Letterbox
	if CONVERSATION_CAMERA_PARAMETERS.letter_box then
		TheFrontEnd:GetLetterbox():AnimateIn()
		-- In town, we don't want any cruft while talking. In dungeon, we need
		-- more informative UI but until we have that we'll show the unit
		-- frames with the hud.
		if TheWorld:HasTag("town") then
			TheDungeon.HUD:AnimateOut()
		else
			TheDungeon.HUD.player_unit_frames:FocusUnitFrame(self.target, 1)
		end
	end

	-- Offset to frame the actors
	TheCamera:SetOffset(0, 0, CONVERSATION_CAMERA_PARAMETERS.camera_z_offset)
end

function Conversation:_EndConversationCamera()
	if self.interactable_snapshot then
		soundutil.KillSound(self.inst, self.interactable_snapshot)
		self.interactable_snapshot = nil
	end
	TheAudio:SetPersistentSoundParameter(audioid.persistent.world_music, "isInteracting", 0)
	TheAudio:SetPersistentSoundParameter(audioid.persistent.room_music, "isInteracting", 0)
	
	local focalpoint = TheFocalPoint.components.focalpoint
	focalpoint:ClearExplicitTargets()
	for t in pairs(self.focus_sources) do
		focalpoint:StopFocusSource(t)
	end
	self.focus_sources = {}

	TheCamera:SetZoom(0)

	TheWorld.components.cameralimits:SetEnabled(true)

	-- Pitch
	local pitch_param = CONVERSATION_CAMERA_PARAMETERS
	pitch_param.pitch = camerautil.defaults.pitch
	camerautil.BlendPitch(self.inst, pitch_param)

	if CONVERSATION_CAMERA_PARAMETERS.letter_box then
		TheFrontEnd:GetLetterbox():AnimateOut()
		if TheWorld:HasTag("town") then
			TheDungeon.HUD:AnimateIn()
		else
			TheDungeon.HUD.player_unit_frames:FocusUnitFrame() -- none
		end
	end

	TheCamera:SetOffset(0, 0, 0)
end

function Conversation:GetDebugString()
	local str = [[
target: %s
memory: %s
]]
	return str:format(self.target, table.inspect(self.persist.memory))
end



return Conversation
