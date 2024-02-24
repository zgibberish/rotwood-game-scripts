local krandom = require "util.krandom"

local anims = {
	states = {
		idle = { "idle_1", "idle_2", },
	},
}
local hidden = anims.states.idle[1]

local function HideIndicator(inst)
	inst.AnimState:PlayAnimation(hidden)
	inst.AnimState:HideSymbol("sweat_untex")
	inst.AnimState:Pause()
end

local function ShowIndicator(inst)
	inst.AnimState:ShowSymbol("sweat_untex")
	inst.AnimState:Resume()
end

-- We have two effects:
-- * sweat on face (AnimState) that only plays when idle.
-- * flying sweat drops (particlesystem) that only plays when moving.
local states =
{
	State({
			name = "hidden",
			onenter = function(inst)
				HideIndicator(inst)
				if inst.sg.mem.target then -- might not be hooked up yet
					inst.sg.mem.target:PushEvent("sweat_stop")
				end
			end,
			onexit = function(inst)
				ShowIndicator(inst)
			end,
		}),

	State({
			name = "choose",

			-- Hold first frame to reduce visibility while we wait for a good
			-- state.
			onenter = HideIndicator,
			onexit = ShowIndicator,

			onupdate = function(inst)
				assert(inst.sg.mem.target, "Forgot to call WatchHealth.")
				local sg = inst.sg.mem.target.sg
				if sg:HasStateTag("norotatecombo") then
					-- stay in this state
				elseif sg:HasStateTag("idle") then
					inst.sg:GoToState("idle")
				elseif sg:HasStateTag("running") then
					inst.sg:GoToState("move")
				elseif sg:HasStateTag("attack") then
					inst.sg:GoToState("move")
				end
			end,
		}),

	State({
			name = "wait",
			onenter = function(inst, delay)
				delay = delay or 1
				inst.sg:SetTimeout(delay)
				HideIndicator(inst)
				inst.sg.mem.target:PushEvent("sweat_stop")
			end,

			ontimeout = function(inst)
				inst.sg:GoToState("choose")
			end,
		}),

	State({
			name = "move",

			onenter = function(inst)
				HideIndicator(inst)
				inst.sg.mem.target:PushEvent("sweat_start")
				-- Spawn fx at current position and let them hang in the air.
				--~ local vfx = SpawnPrefab(inst.sg.mem.vfx_prefab, inst)
				--~ inst.sg.mem.vfx = vfx
				--~ vfx.Transform:SetPosition(inst.Transform:GetWorldPosition())
				--~ vfx.Transform:SetRotation(inst.sg.mem.target.Transform:GetRotation())
				--~ inst.sg:SetTimeoutAnimFrames(vfx.AnimState:GetCurrentAnimationNumFrames())
				inst.sg:SetTimeoutTicks(1 * SECONDS)
			end,

			ontimeout = function(inst)
				inst.sg:GoToState("choose")
			end,

			onexit = function(inst)
				inst.sg.mem.vfx = nil
			end,
		})
}

for name,anim_choices in pairs(anims.states) do
	local s = State({
			name = name,

			onenter = function(inst)
				inst.sg.mem.target:PushEvent("sweat_stop")
				inst.AnimState:PlayAnimation(krandom.PickValue(anim_choices))
			end,

			onupdate = function(inst)
				local sg = inst.sg.mem.target.sg
				if sg:HasStateTag("norotatecombo") then
					-- Rolls make sweat spin wildly and looks absurd. Abort.
					inst.sg:GoToState("choose")
				elseif inst.sg.mem.target.AnimState:GetCurrentFacing() ~= inst.AnimState:GetCurrentFacing() then
					-- Rarely, our facing doesn't update until the animation
					-- restarts. Ensure it always matches.
					inst.Transform:FlipFacingAndRotation()
				end
			end,

			events =
			{
				EventHandler("animover", function(inst)
					inst.sg:GoToState("choose")
				end),
			},
		})
	table.insert(states, s)
end

local events =
{
}

return StateGraph("sg_health_indicator", states, events, "hidden")
