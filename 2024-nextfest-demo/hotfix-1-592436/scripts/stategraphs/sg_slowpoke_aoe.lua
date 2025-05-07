local krandom = require "util.krandom"


local function SpawnBubble(inst)
	local bubble = SpawnPrefab("fx_battoad_bubbles", inst)
	local dist_mod = math.random() * 2.2
	local target_pos = inst:GetPosition()
	target_pos.y = 0
	target_pos = target_pos + krandom.Vec3_FlatOffset(dist_mod)
	bubble.Transform:SetPosition(target_pos:unpack())
end

local states =
{
	State({
		name = "spawn",

		onenter = function(inst)
			inst.sg.statemem.fx = SpawnPrefab("fx_battoad_acid_ground_land", inst)
			inst.sg.statemem.fx.entity:SetParent(inst.entity)
			inst.sg:SetTimeoutTicks(24)
		end,

		onexit = function(inst)
			inst.sg.statemem.fx:Remove()
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("aoe")
		end,
	}),

	State({
		name = "aoe",

		onenter = function(inst, pos)
			inst.sg.statemem.fx = SpawnPrefab("fx_battoad_acid_ground_loop", inst)
			inst.sg.statemem.fx.entity:SetParent(inst.entity)
			inst.sg:SetTimeout(10)

			SpawnBubble(inst)
		end,

		onupdate = function(inst)
			if math.random() < 0.02 and inst.sg:GetTimeInState() <= 7.75 then
				SpawnBubble(inst)
			end
			inst.components.jointaoechild:PushHitBox()
		end,

		events =
		{
			EventHandler("despawn", function(inst) inst.sg:GoToState("despawn") end)
		},

		ontimeout = function(inst)
			inst.sg:GoToState("despawn")
		end,

		onexit = function(inst)
			inst.sg.statemem.fx:Remove()
		end,
	}),

	State({
		name = "despawn",

		onenter = function(inst, pos)
			inst.sg.statemem.fx = SpawnPrefab("fx_battoad_acid_ground_pst", inst)
			inst.sg.statemem.fx.entity:SetParent(inst.entity)
			inst.sg:SetTimeoutTicks(52)
		end,

		ontimeout = function(inst)
			inst:Remove()
		end,
	}),
}

return StateGraph("sg_slowpoke_aoe", states, nil, "spawn")
