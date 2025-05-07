local function ValidateSGMemTarget(inst)
	if not inst then
		return false
	elseif not inst.sg.mem.target or not inst.sg.mem.target:IsValid() then
		-- remove drops for invalid targets as they can not be collected by anyone else
		inst:Remove()
		return false
	end
	return true
end

local states =
{
	State({
		name = "blank",
	}),

	State({
		name = "loaded",

		onenter = function(inst)
			inst.AnimState:SetFrame(inst.AnimState:GetCurrentAnimationNumFrames() - 1)
			inst.Physics:Stop()
		end,
	}),

	State({
		name = "solid_low",
		tags = { "airborne" },

		onenter = function(inst, speed)
			inst.AnimState:PlayAnimation("solid_low")
			inst.sg.statemem.speed = speed or 1
			inst.Physics:SetMotorVel(6 * inst.sg.statemem.speed)
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst:OnLand()
				inst.Physics:SetMotorVel(4 * inst.sg.statemem.speed)
			end),
			FrameEvent(7, function(inst) inst.Physics:SetMotorVel(3.5 * inst.sg.statemem.speed) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVel(2 * inst.sg.statemem.speed) end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVel(1 * inst.sg.statemem.speed) end),
			FrameEvent(13, function(inst) inst.Physics:SetMotorVel(.5 * inst.sg.statemem.speed) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(.25 * inst.sg.statemem.speed) end),
			FrameEvent(15, function(inst)
				inst.Physics:Stop()
				inst:MakePickupable()
			end),
		},
	}),

	State({
		name = "solid_low2",
		tags = { "airborne" },

		onenter = function(inst, speed)
			inst.AnimState:PlayAnimation("solid_low2")
			inst.sg.statemem.speed = speed or 1
			inst.Physics:SetMotorVel(4.8 * inst.sg.statemem.speed)
		end,

		timeline =
		{
			FrameEvent(9, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst:OnLand()
				inst.Physics:SetMotorVel(2.4 * inst.sg.statemem.speed)
			end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVel(1.2 * inst.sg.statemem.speed) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(.6 * inst.sg.statemem.speed) end),
			FrameEvent(16, function(inst) inst.Physics:SetMotorVel(.3 * inst.sg.statemem.speed) end),
			FrameEvent(17, function(inst) inst.Physics:SetMotorVel(.2 * inst.sg.statemem.speed) end),
			FrameEvent(18, function(inst) inst.Physics:SetMotorVel(.1 * inst.sg.statemem.speed) end),
			FrameEvent(19, function(inst)
				inst.Physics:Stop()
				inst:MakePickupable()
			end),
		},
	}),

	State({
		name = "solid_med",
		tags = { "airborne" },

		onenter = function(inst, speed)
			inst.AnimState:PlayAnimation("solid_med")
			inst.sg.statemem.speed = speed or 1
			inst.Physics:SetMotorVel(3.8 * inst.sg.statemem.speed)
		end,

		timeline =
		{
			FrameEvent(11, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst:OnLand()
				inst.Physics:SetMotorVel(2 * inst.sg.statemem.speed)
			end),
			FrameEvent(13, function(inst) inst.Physics:SetMotorVel(1 * inst.sg.statemem.speed) end),
			FrameEvent(15, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
			FrameEvent(18, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst:OnLand()
				inst.Physics:SetMotorVel(.5 * inst.sg.statemem.speed)
			end),
			FrameEvent(21, function(inst) inst.Physics:SetMotorVel(.25 * inst.sg.statemem.speed) end),
			FrameEvent(23, function(inst)
				inst.Physics:Stop()
				inst:MakePickupable()
			end),
		},
	}),

	State({
		name = "solid_high",
		tags = { "airborne" },

		onenter = function(inst, speed)
			inst.AnimState:PlayAnimation("solid_high")
			inst.sg.statemem.speed = speed or 1
			inst.Physics:SetMotorVel(2 * inst.sg.statemem.speed)
		end,

		timeline =
		{
			FrameEvent(16, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst:OnLand()
				inst.Physics:SetMotorVel(1.2 * inst.sg.statemem.speed)
			end),
			FrameEvent(18, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
			FrameEvent(28, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst:OnLand()
				inst.Physics:SetMotorVel(.8 * inst.sg.statemem.speed)
			end),
			FrameEvent(30, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
			FrameEvent(35, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst:OnLand()
				inst.Physics:SetMotorVel(.4 * inst.sg.statemem.speed)
			end),
			FrameEvent(37, function(inst) inst.Physics:SetMotorVel(.2 * inst.sg.statemem.speed) end),
			FrameEvent(39, function(inst) inst.Physics:SetMotorVel(.1 * inst.sg.statemem.speed) end),
			FrameEvent(42, function(inst)
				inst.Physics:Stop()
				inst:MakePickupable()
			end),
		},
	}),

	State({
		name = "solid_fall_high",
		tags = { "airborne" },

		onenter = function(inst, speed)
			inst.AnimState:PlayAnimation("solid_fall_high")
			inst.sg.statemem.speed = speed or 1
			inst.Physics:SetMotorVel(2 * inst.sg.statemem.speed)
		end,

		timeline =
		{
			FrameEvent(17, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst:OnLand()
				inst.Physics:SetMotorVel(2 * inst.sg.statemem.speed)
			end),
			FrameEvent(19, function(inst) inst.Physics:SetMotorVel(1 * inst.sg.statemem.speed) end),
			FrameEvent(21, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
			FrameEvent(25, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst:OnLand()
				inst.Physics:SetMotorVel(.5 * inst.sg.statemem.speed)
			end),
			FrameEvent(27, function(inst) inst.Physics:SetMotorVel(.25 * inst.sg.statemem.speed) end),
			FrameEvent(29, function(inst)
				inst.Physics:Stop()
				inst:MakePickupable()
			end),
		},
	}),

	State({
		name = "curve_low",
		tags = { "airborne", "curve" },

		onenter = function(inst, speed)
			inst.AnimState:PlayAnimation("curve_low")
			inst.sg.statemem.speed = speed or 1
			inst.Physics:SetMotorVel(6 * inst.sg.statemem.speed)
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst:OnLand()
				inst.Physics:SetMotorVel(4 * inst.sg.statemem.speed)
			end),
			FrameEvent(9, function(inst) inst.Physics:SetMotorVel(2 * inst.sg.statemem.speed) end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVel(1 * inst.sg.statemem.speed) end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(.5 * inst.sg.statemem.speed) end),
			FrameEvent(13, function(inst)
				inst.Physics:Stop()
				inst:MakePickupable()
			end),
		},
	}),

	State({
		name = "curve_low2",
		tags = { "airborne", "curve" },

		onenter = function(inst, speed)
			inst.AnimState:PlayAnimation("curve_low2")
			inst.sg.statemem.speed = speed or 1
			inst.Physics:SetMotorVel(4.1 * inst.sg.statemem.speed)
		end,

		timeline =
		{
			FrameEvent(11, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst:OnLand()
				inst.Physics:SetMotorVel(2 * inst.sg.statemem.speed)
			end),
			FrameEvent(13, function(inst) inst.Physics:SetMotorVel(1 * inst.sg.statemem.speed) end),
			FrameEvent(15, function(inst) inst.Physics:SetMotorVel(.5 * inst.sg.statemem.speed) end),
			FrameEvent(18, function(inst)
				inst.Physics:Stop()
				inst:MakePickupable()
			end),
		},
	}),

	State({
		name = "curve_high",
		tags = { "airborne", "curve" },

		onenter = function(inst, speed)
			inst.AnimState:PlayAnimation("curve_high")
			inst.sg.statemem.speed = speed or 1
			inst.Physics:SetMotorVel(3.9 * inst.sg.statemem.speed)
		end,

		timeline =
		{
			FrameEvent(11, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst:OnLand()
				inst.Physics:SetMotorVel(2 * inst.sg.statemem.speed)
			end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(1 * inst.sg.statemem.speed) end),
			FrameEvent(17, function(inst) inst.Physics:SetMotorVel(.5 * inst.sg.statemem.speed) end),
			FrameEvent(19, function(inst) inst.Physics:SetMotorVel(.25 * inst.sg.statemem.speed) end),
			FrameEvent(21, function(inst)
				inst.Physics:Stop()
				inst:MakePickupable()
			end),
		},
	}),

	State({
		name = "soft_low",
		tags = { "airborne" },

		onenter = function(inst, speed)
			inst.AnimState:PlayAnimation("soft_low")
			inst.sg.statemem.speed = speed or 1
			inst.Physics:SetMotorVel(5.5 * inst.sg.statemem.speed)
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst:OnLand()
				inst.Physics:SetMotorVel(3.2 * inst.sg.statemem.speed)
			end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(1.6 * inst.sg.statemem.speed) end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVel(.8 * inst.sg.statemem.speed) end),
			FrameEvent(12, function(inst)
				inst.Physics:Stop()
				inst:MakePickupable()
			end),
		},
	}),

	State({
		name = "soft_med",
		tags = { "airborne" },

		onenter = function(inst, speed)
			inst.AnimState:PlayAnimation("soft_med")
			inst.sg.statemem.speed = speed or 1
			inst.Physics:SetMotorVel(4 * inst.sg.statemem.speed)
		end,

		timeline =
		{
			FrameEvent(11, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst:OnLand()
				inst.Physics:SetMotorVel(3.2 * inst.sg.statemem.speed)
			end),
			FrameEvent(13, function(inst) inst.Physics:SetMotorVel(1.6 * inst.sg.statemem.speed) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(.8 * inst.sg.statemem.speed) end),
			FrameEvent(15, function(inst)
				inst.Physics:Stop()
				inst:MakePickupable()
			end),
		},
	}),

	State({
		name = "soft_high",
		tags = { "airborne" },

		onenter = function(inst, speed)
			inst.AnimState:PlayAnimation("soft_high")
			inst.sg.statemem.speed = speed or 1
			inst.Physics:SetMotorVel(3.2 * inst.sg.statemem.speed)
		end,

		timeline =
		{
			FrameEvent(15, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst:OnLand()
				inst.Physics:SetMotorVel(2 * inst.sg.statemem.speed)
			end),
			FrameEvent(17, function(inst) inst.Physics:SetMotorVel(1 * inst.sg.statemem.speed) end),
			FrameEvent(18, function(inst) inst.Physics:SetMotorVel(.5 * inst.sg.statemem.speed) end),
			FrameEvent(19, function(inst)
				inst.Physics:Stop()
				inst:MakePickupable()
			end),
		},
	}),

	State({
		name = "jiggle_low",
		tags = { "airborne" },

		onenter = function(inst, speed)
			inst.AnimState:PlayAnimation("jiggle_low")
			inst.sg.statemem.speed = speed or 1
			inst.Physics:SetMotorVel(8 * inst.sg.statemem.speed)
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst:OnLand()
				inst.Physics:SetMotorVel(3 * inst.sg.statemem.speed)
			end),
			FrameEvent(7, function(inst) inst.Physics:SetMotorVel(1 * inst.sg.statemem.speed) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVel(.5 * inst.sg.statemem.speed) end),
			FrameEvent(9, function(inst)
				inst.Physics:Stop()
				inst:MakePickupable()
			end),
		},
	}),

	State({
		name = "jiggle_med",
		tags = { "airborne" },

		onenter = function(inst, speed)
			inst.AnimState:PlayAnimation("jiggle_med")
			inst.sg.statemem.speed = speed or 1
			inst.Physics:SetMotorVel(5 * inst.sg.statemem.speed)
		end,

		timeline =
		{
			FrameEvent(10, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst:OnLand()
				inst.Physics:SetMotorVel(2 * inst.sg.statemem.speed)
			end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVel(1 * inst.sg.statemem.speed) end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(.5 * inst.sg.statemem.speed) end),
			FrameEvent(13, function(inst)
				inst.Physics:Stop()
				inst:MakePickupable()
			end),
		},
	}),

	State({
		name = "jiggle_high",
		tags = { "airborne" },

		onenter = function(inst, speed)
			inst.AnimState:PlayAnimation("jiggle_high")
			inst.sg.statemem.speed = speed or 1
			inst.Physics:SetMotorVel(4 * inst.sg.statemem.speed)
		end,

		timeline =
		{
			FrameEvent(13, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst:OnLand()
				inst.Physics:SetMotorVel(1 * inst.sg.statemem.speed)
			end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(.5 * inst.sg.statemem.speed) end),
			FrameEvent(15, function(inst)
				inst.Physics:Stop()
				inst:MakePickupable()
			end),
		},
	}),

	State({
		name = "vacuum_pre",
		tags = { "moving", "busy" },
		onenter = function(inst)
			if not ValidateSGMemTarget(inst) then
				return
			end

			inst:OnMove()
			local x = inst.Transform:GetWorldXZ()
			local x1 = inst.sg.mem.target.Transform:GetWorldXZ()
			inst.sg.mem.moving_east = x1 > x

			if (inst.sg.mem.moving_east and not inst.sg.mem.is_flipped) or (not inst.sg.mem.moving_east and inst.sg.mem.is_flipped) then
				local anim_name = ("%smove_east%s"):format(inst.sg.mem.is_curved and "curve_" or "", inst.sg.mem.move_type)
				inst.AnimState:PlayAnimation(anim_name)
			elseif (not inst.sg.mem.moving_east and not inst.sg.mem.is_flipped) or (inst.sg.mem.moving_east and inst.sg.mem.is_flipped) then
				local anim_name = ("%smove_west%s"):format(inst.sg.mem.is_curved and "curve_" or "", inst.sg.mem.move_type)
				inst.AnimState:PlayAnimation(anim_name)
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("vacuum")
			end),
		}
	}),

	State({
		name = "vacuum",
		tags = { "moving", "busy" },
		onenter = function(inst)
			if not ValidateSGMemTarget(inst) then
				return
			end
			local x = inst.Transform:GetWorldXZ()
			local x1 = inst.sg.mem.target.Transform:GetWorldXZ()
			local moving_east = x1 > x

			if moving_east ~= inst.sg.mem.moving_east then
				inst.sg:GoToState("vacuum_change_dir", moving_east)
			else
				if (inst.sg.mem.moving_east and not inst.sg.mem.is_flipped) or (not inst.sg.mem.moving_east and inst.sg.mem.is_flipped) then
					local anim_name = ("%smove_east_hold"):format(inst.sg.mem.is_curved and "curve_" or "")
					inst.AnimState:PlayAnimation(anim_name)
				elseif (not inst.sg.mem.moving_east and not inst.sg.mem.is_flipped) or (inst.sg.mem.moving_east and inst.sg.mem.is_flipped) then
					local anim_name = ("%smove_west_hold"):format(inst.sg.mem.is_curved and "curve_" or "")
					inst.AnimState:PlayAnimation(anim_name)
				end
			end
		end,

		onupdate = function(inst)
			if not ValidateSGMemTarget(inst) then
				return
			end
			local x = inst.Transform:GetWorldXZ()
			local x1 = inst.sg.mem.target.Transform:GetWorldXZ()
			local moving_east = x1 > x
			if moving_east ~= inst.sg.mem.moving_east then
				-- go to flip anim state
				inst.sg:GoToState("vacuum_change_dir", moving_east)
			end
		end,
	}),

	State({
		name = "vacuum_change_dir",
		tags = { "moving", "busy" },
		onenter = function(inst, moving_east)
			if (inst.sg.mem.moving_east and not inst.sg.mem.is_flipped) or (not inst.sg.mem.moving_east and inst.sg.mem.is_flipped) then
				local anim_name = ("%smove_east_west_change"):format(inst.sg.mem.is_curved and "curve_" or "")
				inst.AnimState:PlayAnimation(anim_name)
				inst.sg.mem.moving_east = moving_east
			elseif (not inst.sg.mem.moving_east and not inst.sg.mem.is_flipped) or (inst.sg.mem.moving_east and inst.sg.mem.is_flipped) then
				local anim_name = ("%smove_west_east_change"):format(inst.sg.mem.is_curved and "curve_" or "")
				inst.AnimState:PlayAnimation(anim_name)
				inst.sg.mem.moving_east = moving_east
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("vacuum")
			end),
		}
	})
}

local function OnVacuumStarted(inst, target)
	if not inst.sg:HasStateTag("busy") then
		local move_type = math.random(1, 3)
		local x_scale = inst.AnimState:GetScale()
		inst.sg.mem.move_type = move_type
		inst.sg.mem.is_flipped = x_scale < 0 or (inst.Transform:GetFacing() == FACING_LEFT)
		inst.sg.mem.is_curved = inst.sg:HasStateTag("curve")
		inst.sg.mem.target = target

		inst.sg:GoToState("vacuum_pre")
	end
end

local events =
{
	EventHandler("vacuum_started", OnVacuumStarted),
}

return StateGraph("sg_drops", states, events, "blank")
