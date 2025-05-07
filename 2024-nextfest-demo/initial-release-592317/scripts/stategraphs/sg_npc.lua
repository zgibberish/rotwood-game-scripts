local SGCommon = require("stategraphs/sg_common")
local lume = require("util/lume")

local EMOTE_STATES =
{
	greet = "greet",
	angry = "angry_pre",
	point = "point_pre",
	think = "think_pre",
	dubious = "dubious",
	clap = "clap",
	gesture = "gesture_pre",
	dejected = "dejected_pre",
	shrug = "shrug",

	laugh = "laugh",
	shocked = "shock",
	nervous = "nervous",
	eyeroll = "roll_eyes",
	gruffnod = "gruff_nod",
	bliss = "bliss",
	scared = "scared",

	closedeyes = "closedeyes",
	notebook = "notebook",
	takeitem = "takeitem",
	eat = "eat",

	notebook_start = "write_pre",
	notebook_stop = "write_pst",

	agree = "nod",
	disagree = "shake_head",

	wavelunn = "wavelunn"
}

local EMOTE_TO_MOUTH_ANIM =
{
	shocked = "shock_mouth",
	laugh = "laugh_mouth",
	-- eat = "eat_mouth",
}

local function RefreshMouthAnim(inst)
	if inst.sg.statemem.mouthoverride and EMOTE_TO_MOUTH_ANIM[inst.sg.statemem.mouthoverride] then
		local anim = EMOTE_TO_MOUTH_ANIM[inst.sg.statemem.mouthoverride]
		inst.mouth.AnimState:PlayAnimation(anim)
	else
		local anim, loop

		local feeling = inst.sg.mem.overridefeeling
		if feeling == nil then
			feeling = inst.sg.mem.feeling
		end

		local talking = inst.sg.mem.overridetalking
		if talking == nil then
			talking = inst.sg.mem.talking
		end

		if feeling == "happy" then
			anim = "happy_mouth_"
		else
			anim = "neutral_mouth_"
		end

		if talking then
			anim = anim.."talk"
			loop = true
		else
			anim = anim.."idle"
		end

		if inst.mouth then
			if not inst.mouth.AnimState:IsCurrentAnimation(anim) then
				local frame = inst.mouth.AnimState:GetCurrentAnimationFrame()
				inst.mouth.AnimState:PlayAnimation(anim, loop)
				if frame > 0 and frame < inst.mouth.AnimState:GetCurrentAnimationNumFrames() then
					inst.mouth.AnimState:SetFrame(frame)
				end
			end
		end
	end
end

local function OnFeeling(inst, feeling)
	if inst.sg.mem.feeling ~= feeling then
		inst.sg.mem.feeling = feeling
		RefreshMouthAnim(inst)
	end
end

local function OnTalk(inst)
	if not inst.sg.mem.talking then
		inst.sg.mem.talking = true
		RefreshMouthAnim(inst)
	end
end

local function OnShutUp(inst)
	if inst.sg.mem.talking then
		inst.sg.mem.talking = false
		RefreshMouthAnim(inst)
	end
end

local function OnMouthAcquired(inst)
	RefreshMouthAnim(inst)
end

--use nil to clear the override
local function OverrideFeeling(inst, feeling)
	if inst.sg.mem.overridefeeling ~= feeling then
		inst.sg.mem.overridefeeling = feeling
		RefreshMouthAnim(inst)
	end
end

--use nil to clear the override (false is used for overriding it to stop talking)
local function OverrideTalking(inst, talking)
	if inst.sg.mem.overridetalking ~= talking then
		inst.sg.mem.overridetalking = talking
		RefreshMouthAnim(inst)
	end
end

local function HeadHasAnim(inst, anim)
	if not inst.sg.mem.head_anims then
		inst.sg.mem.head_anims = lume.invert(inst.head.AnimState:GetCurrentBankAnimNames())
	end
	return inst.sg.mem.head_anims[anim] ~= nil
end

local function PlayAnimation(inst, anim, loop)
	inst.AnimState:PlayAnimation(anim, loop)
	if HeadHasAnim(inst, anim) then
		inst.head.AnimState:PlayAnimation(anim, loop)
	end
end

local function PushAnimation(inst, anim, loop)
	inst.AnimState:PushAnimation(anim, loop)
	if HeadHasAnim(inst, anim) then
		inst.head.AnimState:PushAnimation(anim, loop)
	end
end

local function ChooseEmote(inst, emote)
	local statename = EMOTE_STATES[emote]
	if statename ~= nil then
		local target = inst.components.conversation:GetTarget()
		if target ~= nil then
			SGCommon.Fns.TurnAndActOnTarget(inst, target, false, statename)
		else
			inst.sg:GoToState(statename)
			inst.sg.statemem.mouthoverride = emote
			RefreshMouthAnim(inst)
		end
		return true
	end
	return false
end

local events =
{
	SGCommon.Events.OnLocomote({ walk = true, turn = true }),
	SGCommon.Events.OnEmote(ChooseEmote),
	EventHandler("feeling", OnFeeling),
	EventHandler("talk", OnTalk),
	EventHandler("shutup", OnShutUp),
	EventHandler("mouthacquired", OnMouthAcquired),
}

local states =
{
	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			--Used by brain behaviors in case our size varies a lot
			if inst.sg.mem.idlesize == nil then
				inst.sg.mem.idlesize = inst.Physics:GetSize()
			end

			if SGCommon.Fns.TryEmote(inst, ChooseEmote) then
				return
			end

			PlayAnimation(inst, "idle", true)
			inst.sg.statemem.loops = math.min(4, math.random(5))
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.statemem.loops > 1 then
					inst.sg.statemem.loops = inst.sg.statemem.loops - 1
				else
					inst.sg:GoToState("idle_blink")
				end
			end),
		},
	}),

	State({
		name = "idle_blink",
		tags = { "idle" },

		onenter = function(inst)
			PlayAnimation(inst, "idle_blink")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "greet",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "greet")
		end,

		timeline =
		{
			FrameEvent(39, function(inst)
				inst.sg:RemoveStateTag("busy")
				SGCommon.Fns.TryEmote(inst, ChooseEmote)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "angry_pre",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "angry_pre")
		end,

		timeline =
		{
			FrameEvent(7, function(inst) OverrideFeeling(inst, "neutral") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.angry = true
				inst.sg:GoToState("angry_loop")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.angry then
				OverrideFeeling(inst, nil)
			end
		end,
	}),

	State({
		name = "angry_loop",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "angry_loop", true)
			OverrideFeeling(inst, "neutral")
			SGCommon.Fns.TryEndEmote(inst, "angry_pst")
		end,

		onexit = function(inst)
			if not inst.sg.statemem.endingemote then
				OverrideFeeling(inst, nil)
			end
		end,
	}),

	State({
		name = "angry_pst",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "angry_pst")
			OverrideFeeling(inst, "neutral")
		end,

		timeline =
		{
			FrameEvent(9, OverrideFeeling),
			FrameEvent(14, function(inst)
				inst.sg:RemoveStateTag("busy")
				SGCommon.Fns.TryEmote(inst, ChooseEmote)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = OverrideFeeling,
	}),

	State({
		name = "point_pre",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "point_pre")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("point_loop")
			end),
		},
	}),

	State({
		name = "point_loop",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "point_loop", true)
			SGCommon.Fns.TryEndEmote(inst, "point_pst")
		end,
	}),

	State({
		name = "point_pst",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "point_pst")
		end,

		timeline =
		{
			FrameEvent(11, function(inst)
				inst.sg:RemoveStateTag("busy")
				SGCommon.Fns.TryEmote(inst, ChooseEmote)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "think_pre",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "think_pre")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("think_loop")
			end),
		},
	}),

	State({
		name = "think_loop",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "think_loop", true)
			SGCommon.Fns.TryEndEmote(inst, "think_pst")
		end,
	}),

	State({
		name = "think_pst",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "think_pst")
		end,

		timeline =
		{
			FrameEvent(14, function(inst)
				inst.sg:RemoveStateTag("busy")
				SGCommon.Fns.TryEmote(inst, ChooseEmote)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "dubious",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "dubious")
		end,

		timeline =
		{
			FrameEvent(45, function(inst)
				inst.sg:RemoveStateTag("busy")
				SGCommon.Fns.TryEmote(inst, ChooseEmote)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "clap",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "clap")
			OverrideFeeling(inst, "happy")
		end,

		timeline =
		{
			FrameEvent(53, OverrideFeeling),
			FrameEvent(56, function(inst)
				inst.sg:RemoveStateTag("busy")
				SGCommon.Fns.TryEmote(inst, ChooseEmote)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = OverrideFeeling,
	}),

	State({
		name = "gesture_pre",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "gesture_pre")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("gesture_loop")
			end),
		},
	}),

	State({
		name = "gesture_loop",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "gesture_loop", true)
			SGCommon.Fns.TryEndEmote(inst, "gesture_pst")
		end,
	}),

	State({
		name = "gesture_pst",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "gesture_pst")
		end,

		timeline =
		{
			FrameEvent(12, function(inst)
				inst.sg:RemoveStateTag("busy")
				SGCommon.Fns.TryEmote(inst, ChooseEmote)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "dejected_pre",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "dejected_pre")
			OverrideFeeling(inst, "neutral")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.dejected = true
				inst.sg:GoToState("dejected_loop")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.dejected then
				OverrideFeeling(inst, nil)
			end
		end,
	}),

	State({
		name = "dejected_loop",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "dejected_loop", true)
			OverrideFeeling(inst, "neutral")
			SGCommon.Fns.TryEndEmote(inst, "dejected_pst")
		end,

		onexit = function(inst)
			if not inst.sg.statemem.endingemote then
				OverrideFeeling(inst, nil)
			end
		end,
	}),

	State({
		name = "dejected_pst",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "dejected_pst")
			OverrideFeeling(inst, "neutral")
		end,

		timeline =
		{
			FrameEvent(14, function(inst)
				OverrideFeeling(inst, nil)
				inst.sg:RemoveStateTag("busy")
				SGCommon.Fns.TryEmote(inst, ChooseEmote)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = OverrideFeeling,
	}),

	State({
		name = "shrug",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "shrug")
		end,

		timeline =
		{
			FrameEvent(43, function(inst)
				inst.sg:RemoveStateTag("busy")
				SGCommon.Fns.TryEmote(inst, ChooseEmote)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "takeitem",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "receive")
			-- PushAnimation(inst, "hold_loop")
			PushAnimation(inst, "put_away")
		end,

		events =
		{
			EventHandler("animqueueover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "eat",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "receive")
			-- PushAnimation(inst, "hold_loop")
			PushAnimation(inst, "hold_eat")
		end,

		events =
		{
			EventHandler("animqueueover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "receive",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "receive")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("hold_loop")
			end),
		},
	}),

	State({
		name = "hold_loop",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "hold_loop", true)
		end,
	}),

	State({
		name = "put_away",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "put_away")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "hold_eat",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "hold_eat")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "laugh",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "laugh")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "shock",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "shock")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "nervous",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "nervous")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "roll_eyes",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "roll_eyes")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "gruff_nod",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "gruff_nod")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "bliss",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "bliss")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "scared",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "scared")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "write_pre",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "write_pre")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("write_loop")
			end),
		},
	}),

	State({
		name = "write_loop",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "write_loop", true)
		end,
	}),

	State({
		name = "write_pst",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "write_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "notebook",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "write_pre")
			PushAnimation(inst, "write_loop")
			PushAnimation(inst, "write_pst")
		end,

		events =
		{
			EventHandler("animqueueover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},	
	}),

	State({
		name = "closedeyes",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "close_eyes_pre")
			PushAnimation(inst, "close_eyes_loop")
			PushAnimation(inst, "close_eyes_pst")
		end,

		events =
		{
			EventHandler("animqueueover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "wavelunn",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "display_held_item_pre")
			PushAnimation(inst, "display_held_item_loop")
			PushAnimation(inst, "display_held_item_pst")
		end,

		events =
		{
			EventHandler("animqueueover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "close_eyes_pre",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "close_eyes_pre")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("close_eyes_loop")
			end),
		},
	}),

	State({
		name = "close_eyes_loop",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "close_eyes_loop", true)
		end,
	}),

	State({
		name = "close_eyes_pst",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "close_eyes_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "nod",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "nod")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "shake_head",
		tags = { "busy" },

		onenter = function(inst)
			PlayAnimation(inst, "shake_head")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),
}

SGCommon.States.AddWalkStates(states,
{
	onenterpre = function(inst) inst.Physics:Stop() end,
	pretimeline =
	{
		FrameEvent(1, function(inst) inst.Physics:SetMotorVel(inst.components.locomotor:GetWalkSpeed()) end),
	},

	--sounds
	-- onenterpst = function(inst) PlayFootstepStop(inst, 0.5) end,

	onenterturnpre = function(inst) inst.Physics:Stop() end,
	onenterturnpst = function(inst) inst.Physics:Stop() end,
	turnpsttimeline =
	{
		FrameEvent(3, function(inst) inst.Physics:SetMotorVel(inst.components.locomotor:GetWalkSpeed()) end),
		FrameEvent(4, function(inst)
			inst.sg:RemoveStateTag("busy")
		end),
	},

	looptimeline = 
	{
		-- --sounds
		-- FrameEvent(2, function(inst) PlayFootstep(inst, 0.6) end),
		-- FrameEvent(14, function(inst) PlayFootstep(inst, 0.45) end),
	},
})

SGCommon.States.AddTurnStates(states,
{
	psttimeline =
	{
		FrameEvent(6, function(inst)
			if inst.sg.statemem.nextstate ~= nil then
				inst.sg:GoToState(table.unpack(inst.sg.statemem.nextstate))
			else
				inst.sg:RemoveStateTag("busy")
				inst.sg:AddStateTag("idle")
			end
		end),
	},
})

return StateGraph("sg_npc", states, events, "idle")
