local SGCommon = require "stategraphs.sg_common"
local SGPlayerCommon = require "stategraphs.sg_player_common"
local fmodtable = require "defs.sound.fmodtable"
local combatutil = require "util.combatutil"
local DebugDraw = require "util.debugdraw"
local soundutil = require "util.soundutil"
local Weight = require "components.weight"

local ATTACKS =
{
	LIGHT_ATTACK_WEAK =
	{
		DAMAGE = 0.5,
		HITSTUN = 0,
		PUSHBACK = 0,
		SPEED = 30,
		RANGE = 100,
		HITSTOP = HitStopLevel.MINOR,
		FOCUS = false,
	},

	LIGHT_ATTACK_MEDIUM =
	{
		DAMAGE = 1,
		HITSTUN = 6,
		PUSHBACK = 0.75,
		SPEED = 50,
		RANGE = 100,
		HITSTOP = HitStopLevel.HEAVY,
		FOCUS = false,
	},

	LIGHT_ATTACK_FOCUS =
	{
		DAMAGE = 2,
		HITSTUN = 12,
		PUSHBACK = 1,
		SPEED = 60,
		RANGE = 100,
		HITSTOP = HitStopLevel.MAJOR,
		FOCUS = true,
	},

	LIGHT_ATTACK_STRONG =
	{
		DAMAGE = 1.5,
		HITSTUN = 8,
		PUSHBACK = 1,
		SPEED = 60,
		RANGE = 100,
		HITSTOP = HitStopLevel.HEAVIER,
		FOCUS = false,
	},
}

local function CreateArrow(inst)
	local ATTACK_DATA = ATTACKS[inst.sg.mem.attack_id]

	-- TheDungeon.HUD:MakePopText({ target = inst, button = inst.sg.mem.attack_id, color = UICOLORS.KONJUR, size = 50, fade_time = 1 })

	local arrow = SGCommon.Fns.SpawnAtDist(inst, "player_bow_projectile", 2)
	-- owner, damage_mod, hitstun_animframes, pushback, speed, range, focus, attacktype, attackid
	arrow:Setup(inst, ATTACK_DATA.DAMAGE, ATTACK_DATA.HITSTUN, ATTACK_DATA.PUSHBACK, ATTACK_DATA.SPEED, ATTACK_DATA.RANGE, ATTACK_DATA.FOCUS, inst.sg.mem.attack_type, inst.sg.mem.attack_id)

	local arrowpos = arrow:GetPosition()
	local y_offset = inst.sg.statemem.projectile_y_offset ~= nil and inst.sg.statemem.projectile_y_offset or 1.5
	arrow.Transform:SetPosition(arrowpos.x, arrowpos.y + y_offset, arrowpos.z)

	-- Send an event for power purposes.
	inst:PushEvent("projectile_launched", { arrow })

	return arrow
end

local events = {}

SGPlayerCommon.Events.AddAllBasicEvents(events)

local roll_states =
{
	[Weight.Status.s.Light] = "roll_light",
	[Weight.Status.s.Normal] = "roll_pre",
	[Weight.Status.s.Heavy] = "roll_heavy",
}

local states =
{
	State({
		name = "default_light_attack",
		onenter = function(inst) inst.sg:GoToState("light_draw") end,
	}),

	State({
		name = "default_heavy_attack",
		onenter = function(inst) inst.sg:GoToState("heavy_attack_pre") end,
	}),

	State({
		name = "default_dodge",
		onenter = function(inst)
			local weight = inst.components.weight:GetStatus()
			inst.sg:GoToState(roll_states[weight])
		end,
	}),

	State({
		name = "light_draw",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("draw_pre")
			inst.AnimState:PushAnimation("draw")
			inst.AnimState:SetDeltaTimeMultiplier(3)
		end,

		timeline =
		{
			FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("light_draw_hold")
			end),
		},

		onexit = function(inst)
			inst.sg.statemem.enemynearby = false
			inst.AnimState:SetDeltaTimeMultiplier(1)
		end,
	}),

	State({
		name = "light_draw_hold",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("draw_loop", true)
		end,

		onupdate = function(inst)
			if not inst.components.playercontroller:IsControlHeld("lightattack") then
				inst.sg:GoToState("light_shoot", inst.sg.statemem.shot_strength)
			end
			-- If they've released the light attack button, shoot!
		end,

		timeline =
		{
			-- FOCUS FX:
			FrameEvent(11, function(inst)
				SGCommon.Fns.SpawnAtDist(inst, "fx_hammer_charge_glint", 2)
			end),

			FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),

			-- SHOT STRENGTHS
			FrameEvent(0, function(inst) inst.sg.statemem.shot_strength = "WEAK" end),
			FrameEvent(6, function(inst) inst.sg.statemem.shot_strength = "MEDIUM" end),
			FrameEvent(11, function(inst) inst.sg.statemem.shot_strength = "FOCUS" end),
			FrameEvent(16, function(inst) inst.sg.statemem.shot_strength = "STRONG" end),
		},

		events =
		{
			EventHandler("animover", function(inst)
			end),
		},

		onexit = function(inst)
		end,
	}),

	State({
		name = "light_shoot",
		tags = { "attack", "busy" },

		onenter = function(inst, shot_strength)
			inst.AnimState:PlayAnimation("loose")
			inst.sg.mem.attack_type = "lightattack"
			inst.sg.mem.attack_id = "LIGHT_ATTACK_"..shot_strength
			CreateArrow(inst)
		end,

		onupdate = function(inst)
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				inst.sg.statemem.lightcombostate = "light_shoot_redraw"
				SGPlayerCommon.Fns.TryQueuedAction(inst, "lightattack")
			end),

			FrameEvent(3, SGPlayerCommon.Fns.SetCanDodge),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("light_shoot_pst")
			end),
		},

		onexit = function(inst)
		end,
	}),

	State({
		name = "light_shoot_redraw",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("draw_pre")
			inst.AnimState:SetFrame(14)
		end,

		onupdate = function(inst)
		end,

		timeline =
		{
			FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("light_draw_hold")
			end),
		},

		onexit = function(inst)
		end,
	}),

	State({
		name = "light_shoot_pst",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("draw_pst")
			inst.AnimState:SetDeltaTimeMultiplier(3)
		end,

		onupdate = function(inst)
		end,

		timeline =
		{
			FrameEvent(7, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(7, SGPlayerCommon.Fns.SetCanSkill),
			FrameEvent(9, SGPlayerCommon.Fns.RemoveBusyState)
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.AnimState:SetDeltaTimeMultiplier(1)
		end,
	}),
}

SGPlayerCommon.States.AddAllBasicStates(states)
SGPlayerCommon.States.AddRollStates(states)

-- TODO: add this as a SGPlayerCommon helper function after moving the other weapons over, too.
-- TODO: should roll_pre have combo states too, to allow 1-or-2 frame immediate cancels? I think yes?
-- for i,state in ipairs(states) do
-- 	if state.name == "roll_loop" then
-- 		local id = #state.timeline
-- 		state.timeline[id + 1] = FrameEvent(0, function(inst)
-- 				inst.sg.statemem.lightcombostate = "rolling_drill_attack"
-- 				inst.sg.statemem.heavycombostate = "rolling_heavy_attack_far"
-- 				inst.sg.statemem.reverselightstate = "fading_light_attack_far"
-- 				inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back_far"
-- 			end)
-- 		state.timeline[id + 1].idx = id + 1

-- 		state.timeline[id + 2] = FrameEvent(2, function(inst)
-- 				inst.sg.statemem.reverselightstate = "fading_light_attack_med"
-- 				inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back_med"
-- 			end)
-- 		state.timeline[id + 2].idx = id + 2

-- 		state.timeline[id + 3] = FrameEvent(9, function(inst)
-- 				inst.sg.statemem.reverselightstate = "fading_light_attack_short"
-- 				inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back_short"
-- 			end)
-- 		state.timeline[id + 3].idx = id + 3

-- 		state.timeline[id + 4] = FrameEvent(10, function(inst)
-- 				inst.sg.statemem.lightcombostate = "rolling_drill_attack_med"
-- 				inst.sg.statemem.heavycombostate = "rolling_heavy_attack_med"
-- 			end)
-- 		state.timeline[id + 4].idx = id + 4

-- 		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
-- 	end

-- 	if state.name == "roll_pst" then
-- 		local id = #state.timeline
-- 		state.timeline[id + 1] = FrameEvent(0, function(inst)
-- 			inst.sg.statemem.lightcombostate = "rolling_drill_attack_med"
-- 			inst.sg.statemem.heavycombostate = "rolling_heavy_attack_med"
-- 			inst.sg.statemem.reverselightstate = "fading_light_attack_very_short"
-- 			inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back_very_short"
-- 			end)
-- 		state.timeline[id + 1].idx = id + 1

-- 		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
-- 	end

-- 	-- LIGHT ROLL
-- 	if state.name == "roll_light" then
-- 		local id = #state.timeline
-- 		state.timeline[id + 1] = FrameEvent(0, function(inst)
-- 				inst.sg.statemem.lightcombostate = "rolling_drill_attack_far"
-- 				inst.sg.statemem.heavycombostate = "rolling_heavy_attack_med"
-- 				inst.sg.statemem.reverselightstate = "fading_light_attack"
-- 				inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back"
-- 			end)
-- 		state.timeline[id + 1].idx = id + 1

-- 		state.timeline[id + 2] = FrameEvent(2, function(inst)
-- 				inst.sg.statemem.lightcombostate = "rolling_drill_attack_very_far"
-- 				inst.sg.statemem.heavycombostate = "rolling_heavy_attack_very_far"
-- 				inst.sg.statemem.reverselightstate = "fading_light_attack_far"
-- 				inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back_very_far"
-- 			end)
-- 		state.timeline[id + 2].idx = id + 2

-- 		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
-- 	end

-- 	if state.name == "roll_light_pst" then
-- 		local id = #state.timeline
-- 		state.timeline[id + 1] = FrameEvent(0, function(inst)
-- 			inst.sg.statemem.lightcombostate = "rolling_drill_attack_far"
-- 			inst.sg.statemem.heavycombostate = "rolling_heavy_attack_very_far"
-- 			inst.sg.statemem.reverselightstate = "fading_light_attack_far"
-- 			inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back_very_far"
-- 			end)
-- 		state.timeline[id + 1].idx = id + 1

-- 		state.timeline[id + 2] = FrameEvent(2, function(inst)
-- 			inst.sg.statemem.lightcombostate = "rolling_drill_attack_med"
-- 			inst.sg.statemem.heavycombostate = "rolling_heavy_attack_med"
-- 			inst.sg.statemem.reverselightstate = "fading_light_attack_very_short"
-- 			inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back_very_short"
-- 			end)
-- 		state.timeline[id + 2].idx = id + 2

-- 		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
-- 	end

-- 	-- HEAVY ROLL
-- 	if state.name == "roll_heavy" then
-- 		local id = #state.timeline
-- 		state.timeline[id + 1] = FrameEvent(2, function(inst)
-- 			inst.sg.statemem.lightcombostate = "rolling_drill_attack_very_short"
-- 			inst.sg.statemem.heavycombostate = "rolling_heavy_attack_very_short"
-- 			inst.sg.statemem.reverselightstate = "fading_light_attack_very_short"
-- 			inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back_very_short"
-- 			-- DO NOT TRY to actually execute these states. This just lets the attack get queued up for the next state.
-- 		end)
-- 		state.timeline[id + 1].idx = id + 1

-- 		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
-- 	end


-- 	if state.name == "roll_heavy_pst" then
-- 		local id = #state.timeline
-- 		state.timeline[id + 1] = FrameEvent(4, function(inst)
-- 			-- First, try any queued attacks we've tried to do in the previous state.
-- 			if inst.sg.statemem.queued_lightcombodata then
-- 				inst.sg.statemem.lightcombostate = inst.sg.statemem.queued_lightcombodata.state
--  				if SGPlayerCommon.Fns.DoAction(inst, inst.sg.statemem.queued_lightcombodata.data) then
--  					inst.components.playercontroller:FlushControlQueue()
--  				else
--  					inst.sg.statemem.queued_lightcombodata = nil
--  				end
-- 			elseif inst.sg.statemem.queued_heavycombodata then
-- 				inst.sg.statemem.heavycombostate = inst.sg.statemem.queued_heavycombodata.state
--  				if SGPlayerCommon.Fns.DoAction(inst, inst.sg.statemem.queued_heavycombodata.data) then
--  					inst.components.playercontroller:FlushControlQueue()
--  				else
--  					inst.sg.statemem.queued_heavycombodata = nil
--  				end
--  			else
-- 				-- If we didn't queue anything before, go to these instead:
-- 				inst.sg.statemem.lightcombostate = "rolling_drill_attack_very_short"
-- 				inst.sg.statemem.heavycombostate = "rolling_heavy_attack_very_short"
-- 				inst.sg.statemem.reverselightstate = "fading_light_attack_very_short"
-- 				inst.sg.statemem.reverseheavystate = "rolling_heavy_attack_back_very_short"
-- 				SGPlayerCommon.Fns.TryQueuedLightOrHeavy(inst)
-- 			end
-- 		end)
-- 		state.timeline[id + 1].idx = id + 1

-- 		state.timeline[id + 2] = FrameEvent(3, function(inst)
-- 			inst.sg.statemem.reverseheavystate = "reverse_heavy_attack_pre" --non-sliding version
-- 			inst.sg.statemem.reverselightstate = "fading_light_attack"
-- 		end)
-- 		state.timeline[id + 2].idx = id + 2

-- 		table.sort(state.timeline, function(a,b) return a.frame < b.frame end)
-- 	end
-- end

return StateGraph("sg_player_bow", states, events, "idle")
