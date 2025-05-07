-- THIS ENTITY SHOULD ALWAYS BE SPAWNED ON ALL LOCAL MACHINES, OTHERWISE IT WILL FAIL ADDING POWER

local Power = require "defs.powers"

local function OnProximityHitBoxTriggered(inst, data)
	local triggered = false
	local def = Power.FindPowerByName("player_wind_gust")
	assert(inst.powerlevel ~= nil, "Player Wind Gust not configured: missing power level.")

	for i = 1, #data.targets do
		local v = data.targets[i]
		if v:IsLocal() and v.components.powermanager and not inst.sg.mem.touched[v] then
			local rarity
			if inst.powerlevel == 2 then
				rarity = Power.Rarity.EPIC
			elseif inst.powerlevel == 3 then
				rarity = Power.Rarity.LEGENDARY
			else
				rarity = Power.Rarity.COMMON
			end

			local power = v.components.powermanager:CreatePower(def, rarity)
			v.components.powermanager:AddPower(power)
			
			local powerinst = v.components.powermanager:GetPower(def)
			if powerinst then
				-- It's possible that the powermanager failed to add the power. Make sure the power is there before accessing it.
				powerinst.mem.sources = {}
				powerinst.mem.sources[inst.GUID] = inst
			end

			inst.sg.mem.touched[v] = true
		end
	end
end

local events =
{
}

local states =
{
	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			inst.sg.mem.touched = {}
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("destroying")
		end,

		onupdate = function(inst)
			-- Because of some ordering stuff with this prefab, hitbox data may not be set up yet. Check first.
			if inst.sg.mem.hitbox_data ~= nil then
				inst.components.hitbox:PushOffsetBeam(inst.sg.mem.hitbox_data[1], inst.sg.mem.hitbox_data[2], inst.sg.mem.hitbox_data[3], inst.sg.mem.hitbox_data[4], HitPriority.MOB_DEFAULT)

				if not inst.sg.mem.active then
					-- Wait until we have hitbox data to actually start the timeout, so that the attack always lasts the correct amount of frames.
					-- Doing this in onenter means -sometimes- the attack lasts slightly less long.
					inst.sg:SetTimeoutAnimFrames(5)
					inst.sg.mem.active = true
				end
			end
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnProximityHitBoxTriggered),
		},
	}),

	State({
		name = "destroying",
		tags = { },

		onenter = function(inst)
			inst:DelayedRemove()
		end,
	}),
}

return StateGraph("sg_windguster", states, events, "idle")
