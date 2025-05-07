local easing = require("util/easing")
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"

local function StartLoopingSound(inst)
	local params = {}
	params.fmodevent = fmodtable.Event.mothball_teen_atk_LP

	inst.sg.mem.looping_sound = soundutil.PlaySoundData(inst, params, "looping_sound", inst)
end

local events =
{
	EventHandler("thrown", function(inst, targetpos) inst.sg:GoToState("thrown", targetpos) end),
}

local states =
{
	State({
		name = "idle",
	}),

	State({
		name = "thrown",
		tags = { "airborne" },
		onenter = function(inst, targetpos)
			inst.AnimState:PlayAnimation("spin", true)
			local x, y, z = inst.Transform:GetWorldPosition()
		    local dx = targetpos.x - x
		    local dz = targetpos.z - z
		    local rangesq = dx * dx + dz * dz
		    local maxrange = 20
		    local speed = easing.linear(rangesq, 20, 3, maxrange * maxrange)
		    inst.components.complexprojectile:SetHorizontalSpeed(speed)
		    inst.components.complexprojectile:SetGravity(-40)
		    inst.components.complexprojectile:Launch(targetpos)
		    inst.components.complexprojectile.onhitfn = function()
				if inst.sg.mem.explodeonland then
					inst.sg:GoToState("explode_on_land", targetpos)
				else
					inst.sg:GoToState("land", targetpos)
				end
			end

			local circle
			if inst.sg.mem.explodeonland then
				circle = SpawnPrefab("bomb_explosion_warning_clear", inst)
				inst:DoTaskInTime(0.66, function() circle:Remove() end)
			else
				circle = SpawnPrefab("fx_ground_target_purple", inst)
			end

			circle.Transform:SetPosition( targetpos.x, 0, targetpos.z )

			inst.sg.statemem.landing_pos = circle
		end,

		onexit = function(inst)
			if inst.sg.statemem.landing_pos then
				inst.sg.statemem.landing_pos:Remove()
			end
		end,
	}),

	State({
		name = "land",
		onenter = function(inst, pos)
			inst.Transform:SetPosition(pos.x, 0, pos.z)
			inst.AnimState:PlayAnimation("open")
			
			--sound
			local params = {}
			params.fmodevent = fmodtable.Event.pinecone_bomb_traps_land
			params.sound_max_count = 3
			inst.sg.mem.handle = soundutil.PlaySoundData(inst, params)

		end,

		events = {
			EventHandler("animover", function(inst)
				-- spawn bomb prop
				local x, y, z = inst.Transform:GetWorldPosition()
				local bomb = SpawnPrefab("trap_bomb_pinecone", inst)
				bomb.Transform:SetPosition(x, 0, z)

				-- remove self
				inst:Remove()
			end),
		}
	}),

	State({
		name = "explode_on_land",
		onenter = function(inst, pos)
			inst.Transform:SetPosition(pos.x, 0, pos.z)
			-- spawn bomb prop
			local x, y, z = inst.Transform:GetWorldPosition()
			local bomb = SpawnPrefab("trap_bomb_pinecone", inst)
			bomb.Transform:SetPosition(x, 0, z)
			bomb.sg:GoToState("explode")
			bomb.sg.statemem.explodeonland = true

			-- remove self
			inst:Remove()
		end,
		
		onupdate = function(inst)
			UpdateWarningSound(inst)
		end,

		events = {
			EventHandler("animover", function(inst)

			end),
		}
	})
}

return StateGraph("sg_megatreemon_bomb_projectile", states, events, "idle")
