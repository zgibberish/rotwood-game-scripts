local function CreateRootDebris()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	inst.persists = false

	inst.Transform:SetTwoFaced()

	inst.AnimState:SetBank("treemon_bank")
	inst.AnimState:SetBuild("treemon_build")
	inst.AnimState:PlayAnimation("debris")
	inst.AnimState:SetShadowEnabled(true)

	inst:ListenForEvent("animover", inst.Remove)
	return inst
end

local EXTRUDE_TIMEOUT_FRAMES = 60

local states =
{
	State({
		name = "extrude_pre",

		onenter = function(inst)
			inst.AnimState:PlayAnimation("root_pre")
		end,

		events =
		{
			EventHandler("interrupted", function(inst)
				inst.sg:GoToState("extrude_cancel")
			end),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("extrude_pre_loop")
			end),
		},

		timeline =
		{
			-- Delay a frame to spawn FX, since this object needs to position itself on enter
			FrameEvent(1, function(inst)
				local fx = CreateRootDebris()
				inst.components.hitstopper:AttachChild(fx)
				fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
				fx.Transform:SetRotation(inst.Transform:GetFacingRotation())
				inst.sg.statemem.fx = fx
			end),
		}
	}),

	State({
		name = "extrude_pre_loop",

		onenter = function(inst)
			inst.AnimState:PlayAnimation("root_pre_loop")
			inst.sg:SetTimeoutAnimFrames(EXTRUDE_TIMEOUT_FRAMES)
		end,

		ontimeout = function(inst)
			-- Failsafe for roots that linger in the world after rapid network ownership transfer
			TheLog.ch.Treemon:printf("Warning: Treemon growth root %s timed out in extrude_pre_loop after %d frames",
				inst, EXTRUDE_TIMEOUT_FRAMES)
			inst.sg:GoToState("extrude_cancel")
		end,

		events =
		{
			EventHandler("interrupted", function(inst)
				inst.sg:GoToState("extrude_cancel")
			end),

			-- Needs this event in order to go to the extrude state
			EventHandler("extrude", function(inst)
				inst.sg:GoToState("extrude")
			end),
		},
	}),

	State({
		name = "extrude",

		onenter = function(inst)
			inst.AnimState:PlayAnimation("root")
			inst.sg.statemem.cancelstate = "extrude_cancel"
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				inst.sg.statemem.cancelstate = "extrude_low_pst"
			end),
			FrameEvent(2, function(inst)
				inst.sg.statemem.cancelstate = "extrude_mid_pst"
				inst.owner.components.hitbox:PushOffsetCircleFromChild(0, 0, 0.5, 0, inst, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				inst.owner.components.hitbox:PushOffsetCircleFromChild(0, 0, 0.5, 0, inst, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitstopper:DetachChild(inst.sg.statemem.fx)
				inst.sg.statemem.fx = nil
			end),
		},

		events =
		{
			EventHandler("interrupted", function(inst)
				inst.sg:GoToState(inst.sg.statemem.cancelstate)
			end),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("extrude_mid_pst")
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.fx ~= nil then
				inst.components.hitstopper:DetachChild(inst.sg.statemem.fx)
			end
		end,
	}),

	State({
		name = "extrude_mid_pst",

		onenter = function(inst)
			inst.AnimState:PlayAnimation("root_mid_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("extrude_low_pst")
			end),
		},
	}),

	State({
		name = "extrude_low_pst",

		onenter = function(inst)
			inst.AnimState:PlayAnimation("root_low_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst:Remove()
			end),
		},
	}),

	State({
		name = "extrude_cancel",

		onenter = function(inst)
			inst.AnimState:PlayAnimation("root_cancel")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst:Remove()
			end),
		},
	}),
}

return StateGraph("sg_treemon_growth_root", states, nil, "extrude_pre")
