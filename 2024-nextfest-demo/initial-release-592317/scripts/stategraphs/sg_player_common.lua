local EffectEvents = require "effectevents"
local Equipment = require "defs.equipment"
local PlayerSkillState = require "playerskillstate"
local SGCommon = require "stategraphs.sg_common"
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"
local playerutil = require "util.playerutil"
local spawnutil = require "util.spawnutil"
local monsterutil = require "util.monsterutil"
local powerutil = require "util.powerutil"
local strict = require "util.strict"
local lume = require "util.lume"
local Weight = require "components.weight"
local Cosmetics = require "defs.cosmetics.cosmetics"
local color = require "math.modules.color"

local SGPlayerCommon =
{
	States = {},
	Events = {},
	Fns = {},
}

-- Some tuning stuff for various states below
local weight_to_hitstunframes =
{
		[Weight.Status.s.Light] = 2,
		[Weight.Status.s.Normal] = 0,
		[Weight.Status.s.Heavy] = -2,
}

local function CalculatePlayerIncomingHitstun(inst, attack)
	local frames = attack:GetHitstunAnimFrames() or 6
	local weight = inst.components.weight:GetStatus()

	-- Minimum # of frames should be 1
	frames = math.max(1, frames + weight_to_hitstunframes[weight])

	-- TheDungeon.HUD:MakePopText({ target = inst, button = "[HitStun] "..weight..": "..frames, color = UICOLORS.RED, size = 50, fade_time = 3 })
	return frames
end

local weight_to_knockdistmult =
{
	knockdown =
	{
		[Weight.Status.s.Light] = 2,
		[Weight.Status.s.Normal] = 1,
		[Weight.Status.s.Heavy] = 0.5,
	},

	knockdown_high =
	{
		[Weight.Status.s.Light] = 2,
		[Weight.Status.s.Normal] = 1,
		[Weight.Status.s.Heavy] = 0.5,
	},

	knockback =
	{
		[Weight.Status.s.Light] = 1.25,
		[Weight.Status.s.Normal] = 1,
		[Weight.Status.s.Heavy] = 0.5,
	},
}

local weight_to_hitshudder =
{
		[Weight.Status.s.Light] = 2,
		[Weight.Status.s.Normal] = 0,
		[Weight.Status.s.Heavy] = -2,
}

--


local function OnTalk(inst)
	if not inst.sg.mem.talking then
		inst.sg.mem.talking = true
		-- RefreshMouthAnim(inst)
		inst.AnimState:HideSymbol("mouth01")
		inst.AnimState:HideSymbol("mouth_inner01")
		inst.mouth:Show()
	end
end

local function OnShutUp(inst)
	if inst.sg.mem.talking then
		inst.sg.mem.talking = false
		-- RefreshMouthAnim(inst)
		inst.AnimState:ShowSymbol("mouth01")
		inst.AnimState:ShowSymbol("mouth_inner01")
		inst.mouth:Hide()
	end
end

function SGPlayerCommon.Events.AddMouthEvents(events)
	events[#events + 1] = EventHandler("talk", OnTalk)
	events[#events + 1] = EventHandler("shutup", OnShutUp)
end

--------------------------------------------------------------------------
local function OnDeafen(inst, source)
	if not (inst.sg.mem.earplugs or inst.sg:HasStateTag("nodeafen") or inst.sg:HasStateTag("deafen")) then
		if inst.sg:HasStateTag("airborne") then
			local facingrot = inst.Transform:GetFacingRotation()
			local reverse = source ~= nil and DiffAngle(inst:GetAngleTo(source), facingrot) <= 90
			inst.Transform:SetRotation(facingrot)
			inst.sg:GoToState("deafen_air_pre", reverse)
		else
			inst.sg:GoToState("deafen_pre")
		end
	end
end

function SGPlayerCommon.Events.OnDeafen()
	return EventHandler("deafen", OnDeafen)
end

--------------------------------------------------------------------------
local function OnInputDisabled(inst)
	if not inst:IsLocal() then
		return
	end

	if not inst:IsSpectating() then
		inst.sg:GoToState("inputs_disabled")
	else
		TheLog.ch.StateGraph:printf("Ignoring inputs_disabled: Already in spectating mode which disables inputs")
	end
end

function SGPlayerCommon.Events.OnInputDisabled()
	return EventHandler("inputs_disabled", OnInputDisabled)
end

--------------------------------------------------------------------------
local function OnConversation(inst, data)
	if data.action == "end"
		-- Only change state if we're still in an interact state. The
		-- conversation may have put us into a different state.
		and inst.sg:HasStateTag("interact")
	then
		if SGPlayerCommon.Fns.ShouldSheatheWeapon(inst) then
			inst.sg:GoToState("idle")
		else
			inst.sg:GoToState("unsheathe_fast")
		end
	end
end

function SGPlayerCommon.Events.OnConversation()
	return EventHandler("conversation", OnConversation)
end
--------------------------------------------------------------------------
local function PotionHoldCheck(inst)
	local canceltask = false
	if inst.components.playercontroller:IsControlHeld("potion") then
		inst.sg.mem.potionticksheld = inst.sg.mem.potionticksheld + 1
		if inst.sg.mem.potionticksheld >= TUNING.POTION_HOLD_TICKS then
			inst.sg:GoToState("potion_pre")
			canceltask = true
		end
	else
		canceltask = true
	end

	if canceltask then
		if inst.sg.mem.potionholdtask then
			inst.sg.mem.potionholdtask:Cancel()
			inst.sg.mem.potionholdtask = nil
		else
			TheLog.ch.Player:printf("Warning: Tried to cancel potion hold task when it doesn't exist.")
		end
	end
end
--------------------------------------------------------------------------
local DoControlFn =
{
	["lightattack"] = function(inst, data)
		if inst.emote_ring and inst.emote_ring:IsRingShowing() then

			-- If the emote ring is open, feed inputs to that instead

			inst.components.playercontroller:FlushControlQueueAt(data)
			inst.emote_ring:DoEmoteShortcut(Controls.Digital.ATTACK_LIGHT)
		else

			-- Emote ring is not up -- do normal gameplay stuff.

			local state = inst.sg.statemem.lightcombostate or "default_light_attack"
			if not inst.sg.statemem.queued_lightcombodata then
				inst.sg.mem.executingqueuedattack = true
				inst.components.playercontroller:FlushControlQueueAt(data)
			end
			if inst.sg:HasStateTag("norotatecombo") or inst.sg.statemem.norotatelightcombo then
				inst.sg.mem.attack_type = "light_attack"
				inst.sg:GoToState(state)
			elseif inst.sg:HasStateTag("busy") or (inst.sg:HasStateTag("turning") and inst.sg:GetTicksInState() > 0) then
				inst.sg.mem.attack_type = "light_attack"
				SGCommon.Fns.FaceActionTarget(inst, data, true, true)
				inst.sg:GoToState(state)
			else
				inst.sg.mem.attack_type = "light_attack"
				SGCommon.Fns.TurnAndActOnTarget(inst, data, true, state, nil, true)
			end
			SGPlayerCommon.Fns.SetWeaponSheathed(inst, false)
		end
		return true
	end,

	["heavyattack"] = function(inst, data)
		if inst.emote_ring and inst.emote_ring:IsRingShowing() then

			-- If the emote ring is open, feed inputs to that instead

			inst.components.playercontroller:FlushControlQueueAt(data)
			inst.emote_ring:DoEmoteShortcut(Controls.Digital.ATTACK_HEAVY)
		else
			local state = inst.sg.statemem.heavycombostate or "default_heavy_attack"
			if not inst.sg.statemem.queued_heavycombodata then
				inst.sg.mem.executingqueuedattack = true
				inst.components.playercontroller:FlushControlQueueAt(data)
			end
			if inst.sg:HasStateTag("norotatecombo") or inst.sg.statemem.norotateheavycombo then
				inst.sg.mem.attack_type = "heavy_attack"
				inst.sg:GoToState(state)
			elseif inst.sg:HasStateTag("busy") or (inst.sg:HasStateTag("turning") and inst.sg:GetTicksInState() > 0) then
				inst.sg.mem.attack_type = "heavy_attack"
				SGCommon.Fns.FaceActionTarget(inst, data, true, true)
				inst.sg:GoToState(state)
			else
				inst.sg.mem.attack_type = "heavy_attack"
				SGCommon.Fns.TurnAndActOnTarget(inst, data, true, state, nil, true)
			end
			SGPlayerCommon.Fns.SetWeaponSheathed(inst, false)
		end
		return true
	end,

	["skill"] = function(inst, data)
		if inst.emote_ring and inst.emote_ring:IsRingShowing() then

			-- If the emote ring is open, feed inputs to that instead

			inst.components.playercontroller:FlushControlQueueAt(data)
			inst.emote_ring:DoEmoteShortcut(Controls.Digital.SKILL)
		else
			local skillstate = inst.sg.statemem.skillcombostate or inst.sg.mem.skillstate or nil
			if skillstate then
				local state = skillstate
				inst.components.playercontroller:FlushControlQueueAt(data)
				if inst.sg:HasStateTag("norotatecombo") or inst.sg.statemem.norotateskillcombo then
					inst.sg.mem.attack_type = "skill"
					inst.sg:GoToState(state)
				elseif inst.sg:HasStateTag("busy") or (inst.sg:HasStateTag("turning") and inst.sg:GetTicksInState() > 0) then
					inst.sg.mem.attack_type = "skill"
					SGCommon.Fns.FaceActionTarget(inst, data, true, true)
					inst.sg:GoToState(state)
				else
					inst.sg.mem.attack_type = "skill"
					SGCommon.Fns.TurnAndActOnTarget(inst, data, true, state, nil, true)
				end
				SGPlayerCommon.Fns.SetWeaponSheathed(inst, false)
				return true
			else
				return false
			end
		end
	end,

	["dodge"] = function(inst, data)
		if inst.emote_ring and inst.emote_ring:IsRingShowing() then

			-- If the emote ring is open, feed inputs to that instead

			inst.components.playercontroller:FlushControlQueueAt(data)
			inst.emote_ring:DoEmoteShortcut(Controls.Digital.DODGE)
		else
		local state = inst.sg.statemem.dodgecombostate or "default_dodge"
			inst.components.playercontroller:FlushControlQueueAt(data)

			if inst.sg.statemem.candodgespecial then
				inst:PushEvent("quick_rise")
				SGPlayerCommon.Fns.DoQuickRise(inst)
			end

			if inst.sg:HasStateTag("interact") and not inst.sg.statemem.allow_dodge then
				-- Cannot dodge out of an interaction.
				return false
			elseif inst.sg:HasStateTag("busy") or (inst.sg:HasStateTag("turning") and inst.sg:GetTicksInState() > 0) then
				SGCommon.Fns.FaceActionTarget(inst, data, data.dir == nil)
				inst.sg:GoToState(state)
			else
				SGCommon.Fns.TurnAndActOnTarget(inst, data, data.dir == nil, state)
			end
		end
		return true
	end,

	["potion"] = function(inst, data)
		if inst.components.potiondrinker:CanDrinkPotion() then
			inst.components.playercontroller:FlushControlQueueAt(data)
			if inst.sg:HasStateTag("potion_refill") then --JAMBELL TODO: once figured out potion buffering, fix drinking potion from a refill
				inst.sg:GoToState("potion_pre")
			else
				if inst.sg.mem.potionholdtask then
					TheLog.ch.Player:printf("Warning: Tried to start new potion hold task before canceling previous one.")
					inst.sg.mem.potionholdtask:Cancel()
					inst.sg.mem.potionholdtask = nil
				end
				inst.sg.mem.potionticksheld = 0
				inst.sg.mem.potionholdtask = inst:DoPeriodicTicksTask(0, PotionHoldCheck)
			end
			return true
		elseif inst.PeekFollowStatus then
			inst:PeekFollowStatus({showHealth = true, showPotionStatus = true})
		end
		return false
	end,

	["interact"] = function(inst, data)
		if data.target == nil then
			return false
		end
		local interactable = data.target.components.interactable
		if not interactable then
			return false
		end
		if not interactable:CanPlayerInteract(inst, true) then
			return false
		end
		
		interactable:StartInteract(inst)

		local nextstate = interactable:GetInteractStateName()
		dbassert(nextstate, "Without a destination state, we'll be stuck in this interact.")
		if not nextstate then
			return false
		end

		inst.components.playercontroller:FlushControlQueueAt(data)
		local target_pos = interactable:GetInteractionWorldPosition(inst)
		if target_pos then
			-- With a pos, we'll walk there immediately after next state.
			-- TODO(interact): Would be better if we could
			-- TurnAndActOnTarget towards target_pos? Or have a GoToPosition?
			inst.sg:GoToState(nextstate, data.target)
		else
			SGCommon.Fns.TurnAndActOnTarget(inst, data, false, nextstate, data.target)
		end

		-- Immediately add state tag to block further interactions (we
		-- might be in turn_pre or other antic).
		inst.sg:AddStateTag("interact")
		if TheWorld:HasTag("town") then
			-- Don't allow spamming interact button to cancel out of
			-- interactions in town. We probably want to allow
			-- cancelling in dungeons?
			inst.sg:AddStateTag("busy")
		end
		return true
	end,
}

function SGPlayerCommon.Fns.ForceControlAction(id)
	return
end

local function DoControlAction(inst, data)
	local fn = DoControlFn[data.control]
	if fn ~= nil then
		-- verbose control detail
		-- TheLog.ch.Player:printf("DoControlAction %s CurrentTick=%d, ControlOriginTick=%d Lifetime=%d",
		-- 	data.control, TheSim:GetTick(), data.simtick, data.ticks)
		return fn(inst, data)
	end
	dbassert(false, "Unsupported control: "..tostring(data.control))
	return false
end

local function OnControl(inst, data)
	if not inst.sg:HasStateTag("busy") then
		DoControlAction(inst, data)
	elseif data.control == "lightattack" then
		if inst.sg.statemem.canattackorability or inst.sg.statemem.lightcombostate ~= nil then
			DoControlFn.lightattack(inst, data)
		end
	elseif data.control == "heavyattack" then
		if inst.sg.statemem.canattackorability or inst.sg.statemem.heavycombostate ~= nil then
			DoControlFn.heavyattack(inst, data)
		end
	elseif data.control == "dodge" then
		if inst.sg.statemem.candodge or inst.sg.statemem.dodgecombostate ~= nil then
			DoControlFn.dodge(inst, data)
		end
	elseif data.control == "skill" then
		if inst.sg.statemem.canskill or inst.sg.statemem.canattackorability or inst.sg.statemem.skillcombostate ~= nil then
			DoControlFn.skill(inst, data)
		end
	elseif data.control == "potion" then
		if inst.sg.statemem.canattackorability then
			DoControlFn.potion(inst, data)
		end
	end
end

-- Enabled movement control while state has "busy" tag.
function SGPlayerCommon.Fns.SetCanMove(inst)
	dbassert(inst.sg:HasStateTag("busy")) --just to make sure we're using this correctly
	inst.sg:AddStateTag("canmovewhilebusy")
end

function SGPlayerCommon.Fns.UnsetCanMove(inst)
	dbassert(inst.sg:HasStateTag("busy")) --just to make sure we're using this correctly
	inst.sg:RemoveStateTag("canmovewhilebusy")
end

--Enables "dodge" control while state has "busy" tag.
function SGPlayerCommon.Fns.SetCanDodge(inst)
	dbassert(inst.sg:HasStateTag("busy")) --just to make sure we're using this correctly
	inst.sg.statemem.candodge = true
	return SGPlayerCommon.Fns.TryQueuedAction(inst, "dodge")
end
function SGPlayerCommon.Fns.SetCannotDodge(inst)
	inst.sg.statemem.candodge = false
	return true
end

local function CheckForHeavyQuickRise(inst, data)
	if data.control == "heavyattack" then
		inst:PushEvent("quick_rise")
		return true
	end

	return false
end

function SGPlayerCommon.Fns.SetCanDodgeSpecial(inst)
	dbassert(inst.sg:HasStateTag("busy")) --just to make sure we're using this correctly

	inst.sg.statemem.candodge = true
	inst.sg.statemem.candodgespecial = true

	return SGPlayerCommon.Fns.TryQueuedAction(inst, "dodge")
end

function SGPlayerCommon.Fns.SetCanHeavyDodgeSpecial(inst)
	-- For cannon, which uses Heavy Attack for quickrise.
	dbassert(inst.sg:HasStateTag("busy")) --just to make sure we're using this correctly

	inst.sg.statemem.canheavydodgespecial = true
	return SGPlayerCommon.Fns.TryQueuedAction(inst, "heavyattack")
end

function SGPlayerCommon.Fns.UnsetCanDodge(inst)
	dbassert(inst.sg:HasStateTag("busy")) --just to make sure we're using this correctly
	inst.sg.statemem.candodge = nil
	inst.sg.statemem.candodgespecial = nil
end

function SGPlayerCommon.Fns.UnsetCanDodgeSpecial(inst)
	dbassert(inst.sg:HasStateTag("busy")) --just to make sure we're using this correctly
	inst.sg.statemem.candodgespecial = nil
end

function SGPlayerCommon.Fns.UnsetCanHeavyDodgeSpecial(inst)
	-- For cannon, which uses Heavy Attack for quickrise.
	dbassert(inst.sg:HasStateTag("busy")) --just to make sure we're using this correctly
	inst.sg.statemem.canheavydodgespecial = nil
end

--Enables "skill" control while state has "busy" tag.
function SGPlayerCommon.Fns.SetCanSkill(inst)
	dbassert(inst.sg:HasStateTag("busy")) --just to make sure we're using this correctly
	inst.sg.statemem.canskill = true
	return SGPlayerCommon.Fns.TryQueuedAction(inst, "skill")
end

--Enables "lightattack", "heavyattack", "skill", and "potion" controls while state has "busy" tag.
function SGPlayerCommon.Fns.SetCanAttackOrAbility(inst)
	dbassert(inst.sg:HasStateTag("busy")) --just to make sure we're using this correctly
	inst.sg.statemem.canattackorability = true
	return SGPlayerCommon.Fns.TryQueuedAction(inst, "lightattack", "heavyattack", "potion", "skill")
end

--Enables all controls
function SGPlayerCommon.Fns.RemoveBusyState(inst)
	dbassert(inst.sg:HasStateTag("busy")) --just to make sure we're using this correctly
	inst.sg:RemoveStateTag("busy")
	return SGPlayerCommon.Fns.TryNextQueuedAction(inst)
end

function SGPlayerCommon.Events.OnControl()
	return EventHandler("controlevent", OnControl)
end

-- Adjusts character size during a roll
function SGPlayerCommon.Fns.SetRollPhysicsSize(inst)
	inst.sg.mem.preroll_physicssize = inst.Physics:GetSize()
	local new_physics_size = math.max(0.1, inst.sg.mem.preroll_physicssize * 0.2) -- if we go smaller than this, the game hard-crashes
	inst.Physics:SetSize(new_physics_size)
end

function SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)
	inst.Physics:SetSize(inst.sg.mem.preroll_physicssize)
end

-- Adjusts character hitbox size during a roll's recovery
-- Don't adjust it for the actual roll, because all you're doing is adjusting ability to do iFrame Dodges
function SGPlayerCommon.Fns.SetRollRecoveryHitBoxSize(inst)
	inst.sg.mem.preroll_hitboxsize = inst.HitBox:GetSize()
	local new_hitbox_size = math.max(0.1, inst.sg.mem.preroll_hitboxsize * 0.5)
	inst.HitBox:SetNonPhysicsRect(new_hitbox_size)
end

function SGPlayerCommon.Fns.UndoRollRecoveryHitBoxSize(inst)
	inst.HitBox:SetNonPhysicsRect(inst.sg.mem.preroll_hitboxsize)
end

-- Post-hit invincibility, to reduce incidences of getting hit multiple times in a row
-- Ideally, should be unnoticeable to the player, a hidden helper
function SGPlayerCommon.Fns.StartPostHitInvincibility(inst)
	inst.HitBox:SetInvincible(true)
	inst:DoTaskInAnimFrames(TUNING.PLAYER_POSTHIT_IFRAMES, function(inst)
		inst.HitBox:SetInvincible(false)
	end)
end

function SGPlayerCommon.Fns.TryQueuedLightOrHeavy(inst)
	local data = inst.components.playercontroller:GetQueuedControl("lightattack", "heavyattack")
	local retry = true
	while data ~= nil do
		if data.control == "lightattack" then
			if SGPlayerCommon.Fns.IsReverseControl(inst, data) then
				local temp = inst.sg.statemem.lightcombostate
				inst.sg.statemem.lightcombostate = inst.sg.statemem.reverselightstate
				if SGPlayerCommon.Fns.DoAction(inst, data) then
					return
				end
				inst.sg.statemem.lightcombostate = temp
			elseif inst.sg.statemem.lightcombostate ~= nil then
				if SGPlayerCommon.Fns.DoAction(inst, data) then
					return
				end
			end
			--control to try for next pass
			data = "heavyattack"
		elseif data.control == "heavyattack" then
			if SGPlayerCommon.Fns.IsReverseControl(inst, data) then
				local temp = inst.sg.statemem.heavycombostate
				inst.sg.statemem.heavycombostate = inst.sg.statemem.reverseheavystate
				if SGPlayerCommon.Fns.DoAction(inst, data) then
					return
				end
				inst.sg.statemem.heavycombostate = temp
			elseif SGPlayerCommon.Fns.DoAction(inst, data) then
				return
			end
			--control to try for next pass
			data = "lightattack"
		end
		if not retry then
			break
		end
		dbassert(type(data) == "string")
		data = inst.components.playercontroller:GetQueuedControl(data)
		retry = false
	end
end
--------------------------------------------------------------------------

local function TurnBodyToFaceMouse(inst)

	if not inst.components.playercontroller:IsEnabled() then return end
	if inst.emote_ring and inst.emote_ring.active then return end

	local left = inst.Transform:GetFacing() == FACING_LEFT
	local dir = inst.components.playercontroller:GetMouseActionDirection()
	if left and math.abs(dir) <= 90 or
		not left and math.abs(dir) >= 90 then
		-- inst:FlipFacingAndRotation() -- IMMEDIATE TURN, NO ANIM
		inst.components.locomotor:TurnToDirection(dir) -- TRANSITION TURN WITH ANIM
	end
end

function SGPlayerCommon.States.AddIdleState(states)
	states[#states + 1] = State({
		name = "idle",
		tags = { "idle" },

		default_data_for_tools = 4,

		onenter = function(inst, loops)
			if SGPlayerCommon.Fns.TryNextQueuedAction(inst) then
				return
			end

			inst.sg.statemem.loops = loops or math.random(2, 4)

			local should_fatigue = inst.components.health ~= nil and inst.components.health:IsLow()
			if should_fatigue then
				inst.sg:GoToState("idle_fatigue_pre")
			else
				if inst.sg.statemem.loops > 0 then
					local animname = "idle"
					animname = SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, animname)
					inst.AnimState:PlayAnimation(animname, true)
				else
					inst.sg:GoToState("idle_blink")
				end
			end
		end,

		onupdate = function(inst)
			if inst.components.playercontroller:GetLastInputDeviceType() == "keyboard" then
				TurnBodyToFaceMouse(inst)
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.statemem.loops > 1 then
					inst.sg.statemem.loops = inst.sg.statemem.loops - 1
				else
					if SGPlayerCommon.Fns.ShouldSheatheWeapon(inst) and not SGPlayerCommon.Fns.IsWeaponSheathed(inst) then
						inst.sg:GoToState("sheathe_fast")
					else
						inst.sg:GoToState("idle_blink")
					end
				end
			end),
		},
	})

	states[#states + 1] = State({
		name = "idle_blink",
		tags = { "idle" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "idle_blink"))
		end,

		onupdate = function(inst)
			if inst.components.playercontroller:GetLastInputDeviceType() == "keyboard"then
				TurnBodyToFaceMouse(inst)
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle", math.random(2, 3))
			end),
		},
	})

	states[#states + 1] = State({
		name = "idle_blink_alert",
		tags = { "idle" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "idle_blink_alert"))
		end,

		onupdate = function(inst)
			if inst.components.playercontroller:GetLastInputDeviceType() == "keyboard"then
				TurnBodyToFaceMouse(inst)
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle", math.random(2, 3))
			end),
		},
	})

	states[#states + 1] = State({
		name = "idle_fatigue_pre",
		tags = { "idle" },

		onenter = function(inst, loops)
			if SGPlayerCommon.Fns.TryNextQueuedAction(inst) then
				return
			end

			local animname = "fatigue_idle_pre"
			animname = SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, animname)
			inst.AnimState:PlayAnimation(animname, true)
		end,

		onupdate = function(inst)
			if inst.components.playercontroller:GetLastInputDeviceType() == "keyboard"then
				TurnBodyToFaceMouse(inst)
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle_fatigue")
			end),
		},
	})

	states[#states + 1] = State({
		name = "idle_fatigue",
		tags = { "idle" },

		onenter = function(inst, loops)
			if SGPlayerCommon.Fns.TryNextQueuedAction(inst) then
				return
			end

			local animname = "fatigue_idle"
			animname = SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, animname)
			inst.AnimState:PlayAnimation(animname, true)
		end,

		onupdate = function(inst)
			if inst.components.playercontroller:GetLastInputDeviceType() == "keyboard"then
				TurnBodyToFaceMouse(inst)
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				local should_fatigue = inst.components.health ~= nil and inst.components.health:IsLow()
				if not should_fatigue then
					inst.sg:GoToState("idle", math.random(2, 3))
				end
			end),
		},
	})
end

-- Generic states are for prototyping a weapon without all the idle anims
function SGPlayerCommon.States.AddIdleStateGeneric(states)
	states[#states + 1] = State({
		name = "idle",
		tags = { "idle" },

		default_data_for_tools = 4,

		onenter = function(inst, loops)
			if SGPlayerCommon.Fns.TryNextQueuedAction(inst) then
				return
			end

			inst.sg.statemem.loops = loops or math.random(0, 4)

			local should_fatigue = inst.components.health ~= nil and inst.components.health:IsLow()
			if should_fatigue then
				inst.sg:GoToState("idle_fatigue_pre")
			else
				if inst.sg.statemem.loops > 0 then
					local animname = "idle"
					-- animname = SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, animname)
					inst.AnimState:PlayAnimation(animname, true)
				else
					inst.sg:GoToState("idle_blink")
				end
			end
		end,

		onupdate = function(inst)
			if inst.components.playercontroller:GetLastInputDeviceType() == "keyboard"then
				TurnBodyToFaceMouse(inst)
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.statemem.loops > 1 then
					inst.sg.statemem.loops = inst.sg.statemem.loops - 1
				else
					inst.sg:GoToState(math.random() < .3 and "idle_blink_alert" or "idle_blink")
				end
			end),
		},
	})

	states[#states + 1] = State({
		name = "idle_blink",
		tags = { "idle" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("idle_blink")
		end,

		onupdate = function(inst)
			if inst.components.playercontroller:GetLastInputDeviceType() == "keyboard"then
				TurnBodyToFaceMouse(inst)
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle", math.random(2, 3))
			end),
		},
	})

	states[#states + 1] = State({
		name = "idle_blink_alert",
		tags = { "idle" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("idle_blink_alert")
		end,

		onupdate = function(inst)
			if inst.components.playercontroller:GetLastInputDeviceType() == "keyboard"then
				TurnBodyToFaceMouse(inst)
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle", math.random(2, 3))
			end),
		},
	})

	states[#states + 1] = State({
		name = "idle_fatigue_pre",
		tags = { "idle" },

		onenter = function(inst, loops)
			if SGPlayerCommon.Fns.TryNextQueuedAction(inst) then
				return
			end

			local animname = "fatigue_idle_pre"
			-- animname = SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, animname)
			inst.AnimState:PlayAnimation(animname, true)
		end,

		onupdate = function(inst)
			if inst.components.playercontroller:GetLastInputDeviceType() == "keyboard"then
				TurnBodyToFaceMouse(inst)
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle_fatigue")
			end),
		},
	})

	states[#states + 1] = State({
		name = "idle_fatigue",
		tags = { "idle" },

		onenter = function(inst, loops)
			if SGPlayerCommon.Fns.TryNextQueuedAction(inst) then
				return
			end

			local animname = "fatigue_idle"
			-- animname = SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, animname)
			inst.AnimState:PlayAnimation(animname, true)
		end,

		onupdate = function(inst)
			if inst.components.playercontroller:GetLastInputDeviceType() == "keyboard"then
				TurnBodyToFaceMouse(inst)
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				local should_fatigue = inst.components.health ~= nil and inst.components.health:IsLow()
				if not should_fatigue then
					inst.sg:GoToState("idle", math.random(2, 3))
				end
			end),
		},
	})
end

--------------------------------------------------------------------------

function SGPlayerCommon.Fns.ShouldSheatheWeapon(inst)
	-- should also sheath weapon in non-combat dungeon rooms
	return TheWorld:HasTag("town")
end

function SGPlayerCommon.Fns.IsWeaponSheathed(inst)
	return inst.sg.mem.sheathed
end

function SGPlayerCommon.Fns.SetWeaponSheathed(inst, bool)
	if not inst:IsLocal() then
		return
	end

	if TheWorld:HasTag('town') and bool then
		inst.components.locomotor:AddSpeedMult('sheathed_weapon', 0.33)
	else
		inst.components.locomotor:RemoveSpeedMult('sheathed_weapon')
	end

	if inst.sg.mem.sheathed ~= bool then
		inst:PushEvent("sheathe_weapon", bool)
	end

	inst.sg.mem.sheathed = bool
end

function SGPlayerCommon.Fns.SheatheWeapon(inst, data)
	if not inst:IsLocal() then
		return
	end

	if SGPlayerCommon.Fns.IsWeaponSheathed(inst) then
		return true
	else
		inst.sg:GoToState("sheathe_transition", { inst.sg.currentstate.name, data })
		return false
	end
end

function SGPlayerCommon.States.AddSheathedStates(states)
	states[#states + 1] = State({
		name = "sheathe_transition",
		tags = { "idle", "busy" },

		onenter = function(inst, data)
			inst.sg.statemem.nextstate = data[1]
			inst.sg.statemem.data = data[2]

			-- printf("Do Sheathe Transition %s", inst.sg.statemem.nextstate)

			local animname = "sheathe_fast"
			animname = SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, animname)
			inst.AnimState:PlayAnimation(animname, true)

			SGPlayerCommon.Fns.SetWeaponSheathed(inst, true)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState(inst.sg.statemem.nextstate, inst.sg.statemem.data)
			end),
		},
	})

	states[#states + 1] = State({
		name = "sheathe_fast",
		tags = { "idle", "busy" },

		onenter = function(inst, loops)
			local animname = "sheathe_fast"
			animname = SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, animname)
			inst.AnimState:PlayAnimation(animname, true)
			SGPlayerCommon.Fns.SetWeaponSheathed(inst, true)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	})

	states[#states + 1] = State({
		name = "sheathed_waiting",
		tags = { "idle", "busy" },

		onenter = function(inst, loops)
			local animname = "idle"
			inst.AnimState:PlayAnimation(animname, true)
		end,

		events =
		{
			EventHandler("unsheathe_stop_waiting", function(inst)
				inst.sg:GoToState("unsheathe_fast")
			end),
		},
	})

	states[#states + 1] = State({
		name = "unsheathe_fast",
		tags = { "idle", "busy" },

		onenter = function(inst, loops)
			SGPlayerCommon.Fns.SetWeaponSheathed(inst, false)
			local animname = "unsheathe_fast"
			animname = SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, animname)
			inst.AnimState:PlayAnimation(animname, true)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	})
end
--------------------------------------------------------------------------
local function DoFootstep(inst)
	inst.sg.mem.lastfootstep = GetTime()
	inst.sg.mem.numfootsteps = inst.sg.mem.numfootsteps + 1
	PlayFootstep(inst, inst.sg.mem.numfootsteps > 3 and .6 or 1)
end

-- local speed_to_anim_mult =
-- {
-- 	{0.7, 0.5},
-- 	{1.0, 1.0},
-- 	{1.2, 1.5},
-- }

function SGPlayerCommon.States.AddRunStates(states)
	SGCommon.States.AddRunStates(states,
	{
		onenterpre = function(inst)
			-- local mult = PiecewiseFn(inst.components.locomotor:GetTotalSpeedMult(), speed_to_anim_mult)
			-- inst.AnimState:SetDeltaTimeMultiplier(mult)
			inst.sg.mem.lastfootstep = 0
			inst.sg.mem.numfootsteps = 0
		end,
		onenterpst = function(inst)
			if inst.sg.mem.lastfootstep + .13 < GetTime() then
				PlayFootstepStop(inst, 1)
			end
		end,
		onexitpst = function(inst, currentstate, nextstate)
			local should_fatigue = inst.components.health ~= nil and inst.components.health:IsLow()
			if should_fatigue and nextstate.name == "idle" then
				inst.sg:GoToState("idle_fatigue")
			end
			inst.AnimState:SetDeltaTimeMultiplier(1)
		end,

		onenterturnpre = function(inst)
			-- local mult = PiecewiseFn(inst.components.locomotor:GetTotalSpeedMult(), speed_to_anim_mult)
			-- inst.AnimState:SetDeltaTimeMultiplier(mult)
			inst.sg.mem.lastfootstep = 0
			inst.sg.mem.numfootsteps = 0
			SGPlayerCommon.Fns.RemoveBusyState(inst)
		end,

		-- loopevents =
		-- {
		-- 	EventHandler("speed_mult_changed", function(inst)
		-- 		local mult = PiecewiseFn(inst.components.locomotor:GetTotalSpeedMult(), speed_to_anim_mult)
		-- 		inst.AnimState:SetDeltaTimeMultiplier(mult)
		-- 	end),
		-- },

		onenterturnpst = SGPlayerCommon.Fns.RemoveBusyState,

		modifyanim = function(inst, name)
			local animname = name
			animname = SGPlayerCommon.Fns.ApplyFatiguePrefix(inst, animname)
			animname = SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, animname)
			animname = SGPlayerCommon.Fns.ApplyUpPrefixSimple(inst, animname, inst.sg.statemem.invertrotationforanim)
			return animname
		end,

		modifyanim_onupdate = function(inst, name)
			local animname = name
			local cur_frame = inst.AnimState:GetCurrentAnimationFrame()
			inst.sg.statemem.currentframe_runanim = cur_frame
			animname = SGPlayerCommon.Fns.ApplyFatiguePrefix(inst, animname)
			animname = SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, animname)
			animname = SGPlayerCommon.Fns.ApplyUpPrefixOnUpdate(inst, animname)
			animname = SGPlayerCommon.Fns.ApplyBackPrefixOnUpdate(inst, animname)
			return animname
		end,
	})
end

-- A generic version of the states for any weapons which don't have the full weapon-specific runs, ups/sides, and fatigued states.
function SGPlayerCommon.States.AddRunStatesGeneric(states)
	SGCommon.States.AddRunStates(states,
	{
		onenterpre = function(inst)
			inst.sg.mem.lastfootstep = 0
			inst.sg.mem.numfootsteps = 0
		end,
		onenterpst = function(inst)
			if inst.sg.mem.lastfootstep + .13 < GetTime() then
				PlayFootstepStop(inst, 1)
			end
		end,
		onexitpst = function(inst, currentstate, nextstate)
			local should_fatigue = inst.components.health ~= nil and inst.components.health:IsLow()
			if should_fatigue and nextstate.name == "idle" then
				inst.sg:GoToState("idle_fatigue")
			end
		end,
		onenterturnpre = function(inst)
			inst.sg.mem.lastfootstep = 0
			inst.sg.mem.numfootsteps = 0
			SGPlayerCommon.Fns.RemoveBusyState(inst)
		end,

		onenterturnpst = SGPlayerCommon.Fns.RemoveBusyState,

		modifyanim = function(inst, name)
			local animname = name
			-- animname = SGPlayerCommon.Fns.ApplyFatiguePrefix(inst, animname)
			-- animname = SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, animname)
			-- animname = SGPlayerCommon.Fns.ApplyUpPrefixSimple(inst, animname, inst.sg.statemem.invertrotationforanim)
			return animname
		end,

		modifyanim_onupdate = function(inst, name)
			local animname = name
			local cur_frame = inst.AnimState:GetCurrentAnimationFrame()
			inst.sg.statemem.currentframe_runanim = cur_frame
			-- animname = SGPlayerCommon.Fns.ApplyFatiguePrefix(inst, animname)
			-- animname = SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, animname)
			-- animname = SGPlayerCommon.Fns.ApplyUpPrefixOnUpdate(inst, animname)
			return animname
		end,
	})
end

--------------------------------------------------------------------------
function SGPlayerCommon.States.AddTurnStates(states)
	SGCommon.States.AddTurnStates(states,
	{
		onenterpst = function(inst)
			if inst.sg.statemem.nextstate ~= nil then
				inst.sg:GoToState(table.unpack(inst.sg.statemem.nextstate))
			else
				inst.sg:AddStateTag("idle")
				SGPlayerCommon.Fns.RemoveBusyState(inst)
			end
		end,

		onupdatepst = function(inst)
			if inst.sg:GetAnimFramesInState() > 2 then
				TurnBodyToFaceMouse(inst)
			end
		end,

		modifyanim = function(inst, name)
			return SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, name)
		end,
	})
end

--------------------------------------------------------------------------
function ValidateHitPlayerState(inst, data)
	-- Check if the player is alive during a hit state; if not go to the relevant state instead.
	if inst:IsDying() or inst:IsDead() then
		TheLog.ch.Health:printf("Dying, but entering hit state. Transitioning to death_hit. Entity GUID %d, EntityID %d", inst.GUID, inst.Network:GetEntityID())
		inst.sg:GoToState("death_hit")
		return false
	elseif inst:IsRevivable() then
		TheLog.ch.Health:printf("In revivable state, but entering hit state. Transitioning to revivable_hit. Entity GUID %d, EntityID %d", inst.GUID, inst.Network:GetEntityID())
		inst.sg:GoToState("revivable_hit", data)
		return false
	end

	return true
end

--------------------------------------------------------------------------
function SGPlayerCommon.States.AddHitState(states)
	states[#states + 1] = State({
		name = "hit",
		tags = { "hit", "busy" },
		default_data_for_tools = {
			attack = {
				GetHitstun = function() return 8 end,
				GetPushback = function() return 1 end,
			}
		},

		onenter = function(inst, data)
			if not ValidateHitPlayerState(inst, data) then
				return
			end

			inst.sg.statemem.data = data

			-- First face the attacker, then flip afterwards to make sure animation looks right
			if data.attack:GetAttacker() ~= nil and data.attack:GetAttacker():IsValid() then
				inst:Face(data.attack:GetAttacker())
			end

			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "knockback_hold"))
			inst.components.playercontroller:FlushControlQueue()

			inst.sg.statemem.bypassposthitinvincibility = data.attack:BypassesPosthitInvincibility()
			if not inst.sg.statemem.bypassposthitinvincibility then
				inst.HitBox:SetInvincible(true)
			end
			inst.Physics:Stop()

			local frames = CalculatePlayerIncomingHitstun(inst, data.attack)
			inst.sg:SetTimeoutAnimFrames(frames)

			if inst.components.hitshudder then
				inst.components.hitshudder:DoShudder(TUNING.HITSHUDDER_AMOUNT_MEDIUM, frames)
			end

			SGPlayerCommon.Fns.SetCanAttackOrAbility(inst)
			SGPlayerCommon.Fns.SetCanDodge(inst)
		end,

		onexit = function(inst)
			if not inst.sg.statemem.bypassposthitinvincibility then
				SGPlayerCommon.Fns.StartPostHitInvincibility(inst)
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("hit_pst", inst.sg.statemem.data)
		end,

		timeline =
		{
		},

		events =
		{
		},
	})

	states[#states + 1] = State({
		name = "hit_pst",
		tags = { "hit", "busy" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "hit"))
			inst.components.playercontroller:FlushControlQueue()

			local anim_length = inst.AnimState:GetCurrentAnimationNumFrames()
			inst.components.playercontroller:OverrideControlQueueTicks("lightattack", anim_length * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", anim_length * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", anim_length * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("skill", anim_length * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("potion", anim_length * ANIM_FRAMES)
		end,

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.playercontroller:OverrideControlQueueTicks("lightattack", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("skill", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("potion", nil)
		end,

		timeline =
		{
			FrameEvent(0, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	})
end

--------------------------------------------------------------------------
function SGPlayerCommon.States.AddRollStates(states)
	states[#states + 1] = State({
		name = "roll_pre",
		tags = { "busy", "dodge",  "dodge_pre" },

		onenter = function(inst)
			if inst.sg.mem.weapontype == nil then
				inst.sg.mem.weapontype = SGPlayerCommon.Fns.GetWeaponType(inst)
			end

			local animname = SGPlayerCommon.Fns.ApplyUpPrefixSimple(inst, inst.sg.mem.weapontype.."_roll").."_pre"
			inst.AnimState:PlayAnimation(animname)

			-- local stategraphspeedmult = SGCommon.Fns.GetSGSpeedmult(inst, SGCommon.SGSpeedScale.TINY)

			local distance = inst.components.playerroller:GetTotalDistance()
			local ticks = inst.components.playerroller:GetTotalTicks()

			local secs = ticks/60
			local velocity = distance / secs

			inst.sg.statemem.maxspeed = velocity --* stategraphspeedmult
			inst.sg.statemem.speed = inst.sg.statemem.maxspeed

			inst.Physics:SetMotorVel(inst.sg.statemem.speed)
			SGPlayerCommon.Fns.SetRollPhysicsSize(inst)

			inst.components.playerroller:StartIFrames()
			inst:PushEvent("dodge")
		end,

		timeline =
		{
			FrameEvent(0, function() end) -- jambell: adding this because otherwise timeline{} does not exist when we try to add things to it later
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.rolling = true
				inst.sg:GoToState("roll_loop", { maxspeed = inst.sg.statemem.maxspeed })
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.rolling then
				inst.Physics:Stop()
				inst.components.playerroller:StopIframes()
				SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)
			end
		end,
	})

	states[#states + 1] = State({
		name = "roll_loop",
		tags = { "busy", "norotatecombo", "dodge" },

		default_data_for_tools = { maxspeed = 11 },

		onenter = function(inst, data)
			local animname = SGPlayerCommon.Fns.ApplyUpPrefixSimple(inst, inst.sg.mem.weapontype.."_roll").."_loop"
			inst.AnimState:PlayAnimation(animname)

			inst.components.playercontroller:OverrideControlQueueTicks("lightattack", 8 * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", 8 * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", 6 * ANIM_FRAMES)

			-- Distance modifiers have already been applied in roll_pre
			inst.sg.statemem.maxspeed = data.maxspeed or 11

			inst.sg.statemem.speed = inst.sg.statemem.maxspeed
		end,

		timeline =
		{
			-- Physics (setting a value which is read above in onupdate)
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speed) end),
		},

		events =
		{
			EventHandler("controlevent", function(inst, data)
				if not inst.sg:HasStateTag("busy") then
					SGPlayerCommon.Fns.DoAction(inst, data)
				-- Roll-chaining
				elseif data.control == "dodge" and inst.sg.mem.chainrolls then
					inst.sg.statemem.chainrolldata = data
				-- Light Attack
				elseif data.control == "lightattack" then
					if inst.sg.statemem.lightcombostate ~= nil then
						if SGPlayerCommon.Fns.IsReverseControl(inst, data) then
							local temp = inst.sg.statemem.lightcombostate
							inst.sg.statemem.lightcombostate = inst.sg.statemem.reverselightstate
							if SGPlayerCommon.Fns.DoAction(inst, data) then
								return
							end
						elseif SGPlayerCommon.Fns.DoAction(inst, data) then
							return
						end
					end
				elseif data.control == "heavyattack" then
					if inst.sg.statemem.heavycombostate ~= nil then
						if SGPlayerCommon.Fns.IsReverseControl(inst, data) then
							local temp = inst.sg.statemem.heavycombostate
							inst.sg.statemem.heavycombostate = inst.sg.statemem.reverseheavystate
							if SGPlayerCommon.Fns.DoAction(inst, data) then
								return
							end
							inst.sg.statemem.heavycombostate = temp
						elseif SGPlayerCommon.Fns.DoAction(inst, data) then
							return
						end
					end
				end
			end),

			EventHandler("animover", function(inst)
				inst.sg.statemem.rolling = true

				if inst.sg.mem.chainrolls and inst.sg.statemem.chainrolldata ~= nil then
					local data = inst.sg.statemem.chainrolldata
					if data ~= nil then
						local rot = inst.Transform:GetRotation()
						data.dir = inst.components.playercontroller:GetAnalogDir() or data.dir or rot
						if DiffAngle(data.dir, rot) <= 90 then-- inst.sg:GoToState("roll_loop", { iframes = TUNING.PLAYER_ROLL_IFRAMES, maxspeed = inst.sg.statemem.maxspeed })
							if SGPlayerCommon.Fns.DoAction(inst, data) then
								return
							end
						end
					end
				end

				-- local numrolls = (inst.sg.mem.numrolls or 0) + 1
				-- local canmultiroll = numrolls > 1
				-- print("numrolls:", numrolls)
				-- if canmultiroll and inst.sg.statemem.chainrolldata ~= nil then
				-- 	local data = inst.sg.statemem.chainrolldata
				-- 	print(data)
				-- 	if data ~= nil then
				-- 		local rot = inst.Transform:GetRotation()
				-- 		data.dir = inst.components.playercontroller:GetAnalogDir() or data.dir or rot
				-- 		inst.sg:GoToState("roll_loop", { iframes = TUNING.PLAYER_ROLL_IFRAMES, maxspeed = inst.sg.statemem.maxspeed })
				-- 		if SGPlayerCommon.Fns.DoAction(inst, data) then
				-- 			if inst.sg:GetCurrentState() == "roll_loop" then
				-- 				inst.sg.mem.numrolls = numrolls
				-- 			end
				-- 			return
				-- 		end
				-- 	end
				-- end

				inst.sg.statemem.pst = true
				inst.sg:GoToState("roll_pst", inst.sg.statemem.speed)
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.rolling then
				inst.components.playerroller:StopIframes()
				inst.Physics:Stop()
				SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)
				inst.components.playercontroller:OverrideControlQueueTicks("lightattack", nil)
				inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", nil)
				inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
			elseif inst.sg.statemem.pst then
				inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
			end
		end,
	})

	states[#states + 1] = State({
		name = "roll_pst",
		tags = { "busy", "norotatecombo", "dodge", "dodge_pst" },

		onenter = function(inst, maxspeed)
			local MAXSPEED_DEFAULT <const> = 10 -- move to tuning?
			maxspeed = maxspeed or MAXSPEED_DEFAULT
			local animname = SGPlayerCommon.Fns.ApplyUpPrefixSimple(inst, inst.sg.mem.weapontype.."_roll").."_pst"

			inst.AnimState:PlayAnimation(animname)

			SGPlayerCommon.Fns.SetRollRecoveryHitBoxSize(inst)

			inst.components.playercontroller:OverrideControlQueueTicks("dodge", 9 * ANIM_FRAMES) -- Basically the whole state, if they press dodge again, queue one up.

			inst.sg.statemem.speed = math.min(maxspeed, MAXSPEED_DEFAULT) -- Clamp speed to 10 for this roll, in case our velocity is much higher. Possibly temp solution.

			inst:PushEvent("dodge_pst")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst)
				local controller_dir = inst.components.playercontroller:GetAnalogDir()
				-- If the player is still holding the direction down, then maintain some momentum. Otherwise, decay speed.
				local speed_reduction = controller_dir and 0.25 or 0.35
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.speed * ( 1 - speed_reduction))
			end),
			FrameEvent(2, function(inst)
				local controller_dir = inst.components.playercontroller:GetAnalogDir()
				local speed_reduction = controller_dir and 0.35 or 0.45
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.speed * ( 1 - speed_reduction))
			end),
			FrameEvent(3, function(inst)
				local controller_dir = inst.components.playercontroller:GetAnalogDir()
				local speed_reduction = controller_dir and 0.45 or 0.55
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.speed * ( 1 - speed_reduction))
			end),
			FrameEvent(4, function(inst)
				local controller_dir = inst.components.playercontroller:GetAnalogDir()
				local speed_reduction = controller_dir and 0.55 or 0.65
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.speed * ( 1 - speed_reduction))
			end),
			FrameEvent(5, function(inst)
				local controller_dir = inst.components.playercontroller:GetAnalogDir()
				local speed_reduction = controller_dir and 0.65 or 0.75
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.speed * ( 1 - speed_reduction))
			end),
			FrameEvent(6, function(inst) inst.Physics:Stop() end),

			FrameEvent(0, function(inst)
				SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)
			end),

			-- Cancels
			FrameEvent(3, SGPlayerCommon.Fns.SetCanSkill),
			FrameEvent(6, SGPlayerCommon.Fns.SetCanMove),
			FrameEvent(9, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("controlevent", function(inst, data)
				if not inst.sg:HasStateTag("busy") then
					SGPlayerCommon.Fns.DoAction(inst, data)
				elseif data.control == "lightattack" then
					if inst.sg.statemem.lightcombostate ~= nil then
						if SGPlayerCommon.Fns.IsReverseControl(inst, data) then
							local temp = inst.sg.statemem.lightcombostate
							inst.sg.statemem.lightcombostate = inst.sg.statemem.reverselightstate
							if SGPlayerCommon.Fns.DoAction(inst, data) then
								return
							end
							inst.sg.statemem.lightcombostate = temp
						elseif SGPlayerCommon.Fns.IsUpwardControl(inst, data) then
							if SGPlayerCommon.Fns.DoAction(inst, data) then
								return
							end
						elseif SGPlayerCommon.Fns.IsForwardControl(inst, data) then
							SGPlayerCommon.Fns.DoAction(inst, data)
						end
					end
				elseif data.control == "heavyattack" then
					if inst.sg.statemem.heavycombostate ~= nil then
						if SGPlayerCommon.Fns.IsReverseControl(inst, data) then
							local temp = inst.sg.statemem.heavycombostate
							inst.sg.statemem.heavycombostate = inst.sg.statemem.reverseheavystate
							if SGPlayerCommon.Fns.DoAction(inst, data) then
								return
							end
							inst.sg.statemem.heavycombostate = temp
						elseif SGPlayerCommon.Fns.IsUpwardControl(inst, data) then
							if SGPlayerCommon.Fns.DoAction(inst, data) then
								return
							end
						elseif SGPlayerCommon.Fns.IsForwardControl(inst, data) then
							SGPlayerCommon.Fns.DoAction(inst, data)
						end
					end
				end
			end),

			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)
			SGPlayerCommon.Fns.UndoRollRecoveryHitBoxSize(inst)
			inst.components.playercontroller:OverrideControlQueueTicks("lightattack", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
		end,
	})

	-- Roll Light
	states[#states + 1] = State({
		name = "roll_light",
		tags = { "busy", "norotatecombo", "dodge" },

		onenter = function(inst)
			if inst.sg.mem.weapontype == nil then
				inst.sg.mem.weapontype = SGPlayerCommon.Fns.GetWeaponType(inst)
			end

			inst.AnimState:PlayAnimation(inst.sg.mem.weapontype.."_dash_pre")--SGPlayerCommon.Fns.ApplyUpPrefixSimple(inst, inst.sg.mem.weapontype.."_dash_pre"))
			inst.AnimState:PushAnimation(inst.sg.mem.weapontype.."_dash_loop")--SGPlayerCommon.Fns.ApplyUpPrefixSimple(inst, inst.sg.mem.weapontype.."_dash_loop"))

			inst.components.playercontroller:OverrideControlQueueTicks("lightattack", 8 * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", 8 * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", 6 * ANIM_FRAMES)

			local distance = inst.components.playerroller:GetTotalDistance()
			local ticks = inst.components.playerroller:GetTotalTicks()

			local secs = ticks/60
			local velocity = distance / secs

			SGPlayerCommon.Fns.SetRollPhysicsSize(inst)

			inst.sg:SetTimeoutTicks(ticks)
			inst.sg.statemem.velocity = velocity

			inst.components.playerroller:StartIFrames()
			inst:PushEvent("dodge")

			inst.components.ghosttrail:SetFacing(inst.Transform:GetFacing())
			inst.components.ghosttrail:Activate({ ticks_between_ghosts = 2, max_count = 2, multcolor = color.new(1, 1, 1, .5), addcolor = color.new(0.0/255.0, 0.0/255.0, 0.0/255.0, 0.0/255.0)})
		end,

		timeline =
		{
			FrameEvent(0, function(inst) -- @jambell #roll consider setting this to be f1
										 -- how many frames of startup before the motion begins?
				inst.Physics:SetMotorVel(inst.sg.statemem.velocity)
			end)
		},

		ontimeout = function(inst)
			inst.sg.statemem.rolling = true
			inst.sg.statemem.pst = true
			inst.sg:GoToState("roll_light_pst", inst.sg.statemem.velocity)
		end,

		events =
		{
			EventHandler("controlevent", function(inst, data)
				if not inst.sg:HasStateTag("busy") then
					SGPlayerCommon.Fns.DoAction(inst, data)
				-- Roll-chaining
				elseif data.control == "dodge" and inst.sg.mem.chainrolls then
					inst.sg.statemem.chainrolldata = data
				-- Light Attack
				elseif data.control == "lightattack" then
					if inst.sg.statemem.lightcombostate ~= nil then
						if SGPlayerCommon.Fns.IsReverseControl(inst, data) then
							local temp = inst.sg.statemem.lightcombostate
							inst.sg.statemem.lightcombostate = inst.sg.statemem.reverselightstate
							if SGPlayerCommon.Fns.DoAction(inst, data) then
								return
							end
						elseif SGPlayerCommon.Fns.DoAction(inst, data) then
							return
						end
					end
				elseif data.control == "heavyattack" then
					if inst.sg.statemem.heavycombostate ~= nil then
						if SGPlayerCommon.Fns.IsReverseControl(inst, data) then
							local temp = inst.sg.statemem.heavycombostate
							inst.sg.statemem.heavycombostate = inst.sg.statemem.reverseheavystate
							if SGPlayerCommon.Fns.DoAction(inst, data) then
								return
							end
							inst.sg.statemem.heavycombostate = temp
						elseif SGPlayerCommon.Fns.DoAction(inst, data) then
							return
						end
					end
				end
			end),
		},

		onexit = function(inst)
			inst.AnimState:Resume()
			inst.components.ghosttrail:Deactivate()
			if not inst.sg.statemem.rolling then
				inst.components.playerroller:StopIframes()
				inst.Physics:Stop()
				SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)

				inst.components.playercontroller:OverrideControlQueueTicks("lightattack", nil)
				inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", nil)
				inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
			elseif inst.sg.statemem.pst then
				inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
			end
		end,
	})

	states[#states + 1] = State({
		name = "roll_light_pst",
		tags = { "busy", "norotatecombo", "dodge", "dodge_pst" },

		onenter = function(inst, velocity)
			inst.AnimState:PlayAnimation(inst.sg.mem.weapontype.."_dash_pst")--SGPlayerCommon.Fns.ApplyUpPrefixSimple(inst, inst.sg.mem.weapontype.."_dash_pst"))

			SGPlayerCommon.Fns.SetRollRecoveryHitBoxSize(inst)

			inst.sg.statemem.velocity = velocity or 10

			inst:PushEvent("dodge_pst")
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				local controller_dir = inst.components.playercontroller:GetAnalogDir()
				local speed_reduction = controller_dir and 0.65 or 0.75
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.velocity * (1 - speed_reduction)) --0.25)
			end),
			FrameEvent(2, function(inst)
				local controller_dir = inst.components.playercontroller:GetAnalogDir()
				local speed_reduction = controller_dir and 0.725 or 0.825
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.velocity * (1 - speed_reduction)) --0.175)
			end),
			FrameEvent(4, function(inst)
				local controller_dir = inst.components.playercontroller:GetAnalogDir()
				local speed_reduction = controller_dir and 0.8 or 0.9
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.velocity * (1 - speed_reduction)) --0.1)
			end),
			FrameEvent(6, function(inst)
				local controller_dir = inst.components.playercontroller:GetAnalogDir()
				local speed_reduction = controller_dir and 0.85 or 0.95
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.velocity * (1 - speed_reduction)) --0.05)
			end),
			FrameEvent(8, function(inst) inst.Physics:Stop() end),

			FrameEvent(0, function(inst)
				SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)
			end),

			-- Cancels
			-- FrameEvent(0, SGPlayerCommon.Fns.RemoveBusyState),
			FrameEvent(6, function(inst)
				SGPlayerCommon.Fns.SetCanMove(inst)
			end),
			FrameEvent(6, SGPlayerCommon.Fns.SetCanSkill),
		},

		events =
		{
			EventHandler("controlevent", function(inst, data)
				if not inst.sg:HasStateTag("busy") then
					SGPlayerCommon.Fns.DoAction(inst, data)
				elseif data.control == "lightattack" then
					if inst.sg.statemem.lightcombostate ~= nil then
						if SGPlayerCommon.Fns.IsReverseControl(inst, data) then
							local temp = inst.sg.statemem.lightcombostate
							inst.sg.statemem.lightcombostate = inst.sg.statemem.reverselightstate
							if SGPlayerCommon.Fns.DoAction(inst, data) then
								return
							end
							inst.sg.statemem.lightcombostate = temp
						elseif SGPlayerCommon.Fns.IsUpwardControl(inst, data) then
							if SGPlayerCommon.Fns.DoAction(inst, data) then
								return
							end
						elseif SGPlayerCommon.Fns.IsForwardControl(inst, data) then
							SGPlayerCommon.Fns.DoAction(inst, data)
						end
					end
				elseif data.control == "heavyattack" then
					if inst.sg.statemem.heavycombostate ~= nil then
						if SGPlayerCommon.Fns.IsReverseControl(inst, data) then
							local temp = inst.sg.statemem.heavycombostate
							inst.sg.statemem.heavycombostate = inst.sg.statemem.reverseheavystate
							if SGPlayerCommon.Fns.DoAction(inst, data) then
								return
							end
							inst.sg.statemem.heavycombostate = temp
						elseif SGPlayerCommon.Fns.IsUpwardControl(inst, data) then
							if SGPlayerCommon.Fns.DoAction(inst, data) then
								return
							end
						elseif SGPlayerCommon.Fns.IsForwardControl(inst, data) then
							SGPlayerCommon.Fns.DoAction(inst, data)
						end
					end
				end
			end),

			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)
			SGPlayerCommon.Fns.UndoRollRecoveryHitBoxSize(inst)
			inst.components.playercontroller:OverrideControlQueueTicks("lightattack", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
		end,
	})

	-- Roll Heavy
	states[#states + 1] = State({
		name = "roll_heavy",
		tags = { "busy", "norotatecombo", "dodge" },

		onenter = function(inst)
			if inst.sg.mem.weapontype == nil then
				inst.sg.mem.weapontype = SGPlayerCommon.Fns.GetWeaponType(inst)
			end

			local animname = inst.sg.mem.weapontype.."_hop"
			inst.AnimState:PlayAnimation(animname.."_pre")
			inst.AnimState:PushAnimation(animname.."_loop")

			inst.components.playercontroller:OverrideControlQueueTicks("lightattack", 40 * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", 40 * ANIM_FRAMES)

			local distance = inst.components.playerroller:GetTotalDistance()
			local ticks = inst.components.playerroller:GetTotalTicks()

			local secs = ticks/60
			local velocity = distance / secs

			SGPlayerCommon.Fns.SetRollPhysicsSize(inst)

			inst.sg:SetTimeoutTicks(ticks)
			inst.Physics:SetMotorVel(velocity * 2) -- Start a bit faster for better feel, then slow down to correct velocity after a frame or two.
			inst.sg.statemem.velocity = velocity

			inst.components.playerroller:StartIFrames()
			inst:PushEvent("dodge")
		end,

		timeline =
		{
			FrameEvent(0, function() end),
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.velocity) end), -- Start a bit faster for better feel, then slow down to correct velocity after a frame or two. end),
		},

		ontimeout = function(inst)
			inst.sg.statemem.rolling = true
			inst.sg.statemem.pst = true
			inst.sg:GoToState("roll_heavy_pst", { velocity = inst.sg.statemem.velocity, queued_lightcombodata = inst.sg.statemem.queued_lightcombodata, queued_heavycombodata = inst.sg.statemem.queued_heavycombodata })
		end,

		events =
		{
			EventHandler("controlevent", function(inst, data)
				if not inst.sg:HasStateTag("busy") then
					SGPlayerCommon.Fns.DoAction(inst, data)
				-- Roll-chaining
				elseif data.control == "dodge" and inst.sg.mem.chainrolls then
					inst.sg.statemem.chainrolldata = data
				-- Light Attack
				elseif data.control == "lightattack" then
					-- This is a bit particular
					-- We don't want any attacks to be cancelable during this hop -- they should all be queued up to be executed in the PST state.
					-- So here we are NOT trying to execute any of these moves, just storing them as transition data.
					-- Below, in the _pst we will actually try executing.

					if inst.sg.statemem.lightcombostate ~= nil then
						if SGPlayerCommon.Fns.IsReverseControl(inst, data) and inst.sg.statemem.reverselightstate then
							inst.sg.statemem.queued_lightcombodata = { state = inst.sg.statemem.reverselightstate, data = data }
						else
							inst.sg.statemem.queued_lightcombodata = { state = inst.sg.statemem.lightcombostate, data = data }
						end
					end
				elseif data.control == "heavyattack" then
					if inst.sg.statemem.heavycombostate ~= nil then
						if SGPlayerCommon.Fns.IsReverseControl(inst, data) and inst.sg.statemem.reverseheavystate then
							inst.sg.statemem.queued_heavycombodata = { state = inst.sg.statemem.reverseheavystate, data = data }
						else
							inst.sg.statemem.queued_heavycombodata = { state = inst.sg.statemem.heavycombostate, data = data }
						end
					end
				end
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.rolling then
				inst.components.playerroller:StopIframes()
				inst.Physics:Stop()
				SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)
				inst.components.playercontroller:OverrideControlQueueTicks("lightattack", nil)
				inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", nil)
				inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
			elseif inst.sg.statemem.pst then
				inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
			end
		end,
	})

	states[#states + 1] = State({
		name = "roll_heavy_pst",
		tags = { "busy", "norotatecombo", "dodge", "dodge_pst" },

		onenter = function(inst, data)
			-- data =
			-- 		velocity = what speed we were moving at
			--		queued_lightcombodata = if we have queued up Light Attack to be executed now
			--			state = the state we should go to
			--			data = the control queue data
			--		queued_heavycombodata = if we have queued up a Heavy Attack to be executed now
			--			state = the state we should go to
			--			data = the control queue data

			local animname = inst.sg.mem.weapontype.."_hop_pst"

			inst.AnimState:PlayAnimation(animname)

			SGPlayerCommon.Fns.SetRollRecoveryHitBoxSize(inst)

			inst.sg.statemem.velocity = data.velocity or 10
			inst.sg.statemem.queued_lightcombodata = data.queued_lightcombodata or nil
			inst.sg.statemem.queued_heavycombodata = data.queued_heavycombodata or nil

			inst:PushEvent("dodge_pst")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.velocity * 0.25) end),
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.velocity * 0.125) end),
			FrameEvent(4, function(inst) inst.Physics:Stop() end),

			FrameEvent(3, function(inst)
				SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)
			end),

			-- Cancels
			FrameEvent(6, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(6, SGPlayerCommon.Fns.SetCanSkill),
			FrameEvent(8, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("controlevent", function(inst, data)
				if not inst.sg:HasStateTag("busy") then
					SGPlayerCommon.Fns.DoAction(inst, data)
				elseif data.control == "lightattack" then
					if inst.sg.statemem.lightcombostate ~= nil then
						if SGPlayerCommon.Fns.IsReverseControl(inst, data) then
							local temp = inst.sg.statemem.lightcombostate
							inst.sg.statemem.lightcombostate = inst.sg.statemem.reverselightstate
							if SGPlayerCommon.Fns.DoAction(inst, data) then
								return
							end
							inst.sg.statemem.lightcombostate = temp
						elseif SGPlayerCommon.Fns.IsUpwardControl(inst, data) then
							if SGPlayerCommon.Fns.DoAction(inst, data) then
								return
							end
						elseif SGPlayerCommon.Fns.IsForwardControl(inst, data) then
							SGPlayerCommon.Fns.DoAction(inst, data)
						end
					end
				elseif data.control == "heavyattack" then
					if inst.sg.statemem.heavycombostate ~= nil then
						if SGPlayerCommon.Fns.IsReverseControl(inst, data) then
							local temp = inst.sg.statemem.heavycombostate
							inst.sg.statemem.heavycombostate = inst.sg.statemem.reverseheavystate
							if SGPlayerCommon.Fns.DoAction(inst, data) then
								return
							end
							inst.sg.statemem.heavycombostate = temp
						elseif SGPlayerCommon.Fns.IsUpwardControl(inst, data) then
							if SGPlayerCommon.Fns.DoAction(inst, data) then
								return
							end
						elseif SGPlayerCommon.Fns.IsForwardControl(inst, data) then
							SGPlayerCommon.Fns.DoAction(inst, data)
						end
					end
				end
			end),

			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			if inst.sg.mem.executingqueuedattack then
				inst.components.playerroller:StopIframes()
			end

			inst.sg.mem.executingqueuedattack = nil

			inst.Physics:Stop()
			SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)
			SGPlayerCommon.Fns.UndoRollRecoveryHitBoxSize(inst)
			inst.components.playercontroller:OverrideControlQueueTicks("lightattack", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", nil)
		end,
	})
end

--------------------------------------------------------------------------

-- Knockback i-frames:
-- "knockback": hit hold state -- includes hitstop and hitstun. Invincible the entire time
-- "knockback_pst": released from hitstop/hitstun, knocking back away from enemy. Invincible for PLAYER_POSTHIT_IFRAMES frames.

function SGPlayerCommon.States.AddKnockbackState(states)
	states[#states + 1] = State({
		name = "knockback",
		tags = { "hit", "knockback", "busy" },
		default_data_for_tools = {
			attack = {
				GetHitstun = function() return 8 end,
				GetPushback = function() return 1 end,
			}
		},

		onenter = function(inst, data)
			if not ValidateHitPlayerState(inst, data) then
				return
			end

			inst.sg.statemem.data = data

			-- First face the attacker, then flip afterwards to make sure animation looks right
			if data.attack:GetAttacker() ~= nil and data.attack:GetAttacker():IsValid() then
				inst:Face(data.attack:GetAttacker())
			end

			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "knockback_hold"))
			inst.components.playercontroller:FlushControlQueue()

			inst.sg.statemem.bypassposthitinvincibility = data.attack:BypassesPosthitInvincibility()
			if not inst.sg.statemem.bypassposthitinvincibility then
				inst.HitBox:SetInvincible(true)
			end
			inst.Physics:Stop()

			local frames = CalculatePlayerIncomingHitstun(inst, data.attack)

			inst.sg:SetTimeoutAnimFrames(frames)
			if inst.components.hitshudder then
				inst.components.hitshudder:DoShudder(TUNING.HITSHUDDER_AMOUNT_MEDIUM, frames)
			end
		end,

		onexit = function(inst)
			if not inst.sg.statemem.bypassposthitinvincibility then
				SGPlayerCommon.Fns.StartPostHitInvincibility(inst)
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("knockback_pst", inst.sg.statemem.data)
		end,

		timeline =
		{
		},

		events =
		{
			-- EventHandler("controlevent", function(inst, data)
			-- 	inst.components.playercontroller:FlushControlQueueAt(data)
			-- 	if data.control == "dodge" then
			-- 		inst.sg.statemem.dodge_on_exit = true
			-- 	elseif data.control == "heavyattack" and inst.sg.mem.heavydodge then
			-- 		inst.sg.statemem.heavydodge_on_exit = true
			-- 	end
			-- end),
		},
	})

	states[#states + 1] = State({
		name = "knockback_pst",
		tags = { "hit", "knockback", "busy", "nointerrupt" },
		default_data_for_tools = {
			attack = {
				GetHitstun = function() return 8 end,
				GetPushback = function() return 1 end,
			}
		},

		onenter = function(inst, data)
			local attack = data.attack

			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "knockback_pst"))

			local pushbackmult = attack and attack:GetPushback() or 1
			local weightmult = weight_to_knockdistmult.knockback[inst.components.weight:GetStatus()]
			inst.sg.statemem.speedmult = pushbackmult * weightmult

			local anim_length = inst.AnimState:GetCurrentAnimationNumFrames()
			inst.components.playercontroller:OverrideControlQueueTicks("lightattack", anim_length * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", anim_length * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", anim_length * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("skill", anim_length * ANIM_FRAMES)
			inst.components.playercontroller:OverrideControlQueueTicks("potion", anim_length * ANIM_FRAMES)
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(-12 * inst.sg.statemem.speedmult) end),
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(-10 * inst.sg.statemem.speedmult) end),
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(-8 * inst.sg.statemem.speedmult) end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(-6 * inst.sg.statemem.speedmult) end),
			FrameEvent(5, function(inst) inst.Physics:SetMotorVel(-4 * inst.sg.statemem.speedmult) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(-2 * inst.sg.statemem.speedmult) end),
			FrameEvent(7, function(inst) inst.Physics:SetMotorVel(-1 * inst.sg.statemem.speedmult) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVel(-.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(9, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(4, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(2, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
			FrameEvent(7, function(inst)
				if inst.sg.statemem.deafen then
					inst.sg:GoToState("deafen_pre")
					return
				end
				inst.sg:RemoveStateTag("airborne")
				SGPlayerCommon.Fns.RemoveBusyState(inst)
				inst.sg.statemem.candeafen = true
			end),
			FrameEvent(8, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("deafen", function(inst)
				if not inst.sg.mem.earplugs then
					if inst.sg.statemem.candeafen then
						inst.sg:GoToState("deafen_pre")
					else
						inst.sg.statemem.deafen = true
					end
				end
			end),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.playercontroller:OverrideControlQueueTicks("lightattack", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("skill", nil)
			inst.components.playercontroller:OverrideControlQueueTicks("potion", nil)
		end,
	})
end

--------------------------------------------------------------------------

-- Knockdown i-frames:
-- "knockdown": hit hold state -- includes hitstop and hitstun. Invincible the entire time
-- "knockdown_pst": released from hitstop/hitstun, flying through the air. Invincible the entire time, [[except to JUGGLE attacks]].
-- upon landing, begin post-hit invincibility frames

-- Same sequence for knockdown_high

function SGPlayerCommon.States.AddKnockdownStates(states)
	states[#states + 1] = State({
		name = "knockdown",
		tags = { "hit", "knockdown", "busy", "nointerrupt", "knockback_becomes_hit" },
		default_data_for_tools = {
			attack = {
				GetHitstun = function() return 8 end,
				GetPushback = function() return 1 end,
			}
		},

		onenter = function(inst, data)
			if not ValidateHitPlayerState(inst, data) then
				return
			end

			inst.sg.statemem.data = data

			-- First face the attacker, then flip afterwards to make sure animation looks right
			if not data.ignore_face_attacker and data.attack:GetAttacker() ~= nil and data.attack:GetAttacker():IsValid() then
				inst:Face(data.attack:GetAttacker())
			end
			inst:FlipFacingAndRotation()

			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "knockdown_hold"))
			inst.components.playercontroller:FlushControlQueue()

			inst.sg.statemem.bypassposthitinvincibility = data.attack:BypassesPosthitInvincibility()
			if not inst.sg.statemem.bypassposthitinvincibility then
				inst.HitBox:SetInvincible(true)
			end
			inst.Physics:Stop()

			local frames = CalculatePlayerIncomingHitstun(inst, data.attack)

			inst.sg:SetTimeoutAnimFrames(frames)
			if inst.components.hitshudder then
				inst.components.hitshudder:DoShudder(TUNING.HITSHUDDER_AMOUNT_MEDIUM, frames)
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("knockdown_pst", inst.sg.statemem.data)
		end,

		timeline =
		{
		},

		events =
		{
		},
	})

	states[#states + 1] = State({
		name = "knockdown_pst",
		tags = { "hit", "knockdown", "busy", "airborne", "knockback_becomes_hit" },

		onenter = function(inst, data)
			local attack = data and data.attack or nil

			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "knockdown_pst"))
			inst.components.playercontroller:FlushControlQueue()
			inst.Physics:StartPassingThroughObjects()
			inst.HitBox:SetInvincible(true)

			local pushbackmult = attack and attack:GetPushback() or 1
			local weightmult = weight_to_knockdistmult.knockdown[inst.components.weight:GetStatus()]
			inst.sg.statemem.speedmult = pushbackmult * weightmult
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(8 * inst.sg.statemem.speedmult) end),
			FrameEvent(12, function(inst)
				inst.Physics:SetMotorVel(6 * inst.sg.statemem.speedmult)
				inst.Physics:StopPassingThroughObjects()
			end),
			FrameEvent(13, function(inst) inst.Physics:SetMotorVel(5 * inst.sg.statemem.speedmult) end),
			--

			-- victorc: 60Hz, open this up by one extra 60Hz frame
			-- FrameEvent(10, function(inst)
			FrameEvent60(19, function(inst) --FrameEvent9/10
					inst.sg:RemoveStateTag("airborne")
					SGPlayerCommon.Fns.SetCanDodgeSpecial(inst) -- quick rise window
					SGPlayerCommon.Fns.SetCanHeavyDodgeSpecial(inst) -- quick rise window for cannon
				end,
				nil, --optname
				FrameEvent60.LEGACY_TIMING_CEIL),
			FrameEvent(12, function(inst)
				if not inst.sg.statemem.noshake then
					inst:ShakeCamera(CAMERASHAKE.VERTICAL, .4, .01, .08)
				end
				inst.HitBox:SetEnabled(true)
				inst.sg:AddStateTag("prone")
			end),
			FrameEvent(15, SGPlayerCommon.Fns.UnsetCanDodgeSpecial), -- Let player roll as normal, but after this point it is no longer a QuickRise.
			FrameEvent(15, SGPlayerCommon.Fns.UnsetCanHeavyDodgeSpecial),
		},

		events =
		{
			EventHandler("deafen", function(inst)
				inst.sg.statemem.noshake = true
			end),
			EventHandler("animover", function(inst)
				inst.sg.statemem.knockdown = true
				inst.sg:GoToState("knockdown_idle", inst.sg.statemem.speedmult)
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.knockdown then
				inst.Physics:Stop()
			end
			inst.Physics:StopPassingThroughObjects()
			SGPlayerCommon.Fns.StartPostHitInvincibility(inst)
			SGPlayerCommon.Fns.UnsetCanDodgeSpecial(inst)
		end,
	})

	states[#states + 1] = State({
		name = "knockdown_high",
		tags = { "hit", "knockdown", "busy", "airborne" },
		default_data_for_tools = {
			attack = {
				GetHitstun = function() return 8 end,
				GetPushback = function() return 1 end,
			}
		},

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "knockhigh_hold"))

			if data.attack:GetAttacker() ~= nil and data.attack:GetAttacker():IsValid() then
				inst:Face(data.attack:GetAttacker())
			end
			-- inst:FlipFacingAndRotation()

			inst.components.playercontroller:FlushControlQueue()

			inst.sg.statemem.bypassposthitinvincibility = data.attack:BypassesPosthitInvincibility()
			if not inst.sg.statemem.bypassposthitinvincibility then
				inst.HitBox:SetInvincible(true)
			end

			inst.Physics:Stop()

			local frames = CalculatePlayerIncomingHitstun(inst, data.attack)
			inst.sg:SetTimeoutAnimFrames(frames)

			if inst.components.hitshudder then
				inst.components.hitshudder:DoShudder(TUNING.HITSHUDDER_AMOUNT_MEDIUM, frames)
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("knockdown_high_pst", inst.sg.statemem.data)
		end,

		timeline =
		{
		},

		events =
		{
		},
	})

	states[#states + 1] = State({
		name = "knockdown_high_pst",
		tags = { "hit", "knockdown", "busy", "airborne" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "knockhigh_pst"))
			inst.components.playercontroller:FlushControlQueue()
			inst.HitBox:SetInvincible(true)

			local pushbackmult = data and data.attack and data.attack:GetPushback() or 1
			local weightmult = weight_to_knockdistmult.knockdown_high[inst.components.weight:GetStatus()]
			inst.sg.statemem.speedmult = pushbackmult * weightmult
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst:FlipFacingAndRotation() end),
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(6 * inst.sg.statemem.speedmult) end),
			FrameEvent(2, function(inst) inst.Physics:StartPassingThroughObjects() end),
			FrameEvent(20, function(inst) inst.Physics:StopPassingThroughObjects() end),
			FrameEvent(22, function(inst) inst.Physics:SetMotorVel(4 * inst.sg.statemem.speedmult) end),
			FrameEvent(23, function(inst) inst.Physics:SetMotorVel(3 * inst.sg.statemem.speedmult) end),
			FrameEvent(26, function(inst) inst.Physics:SetMotorVel(2.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(27, function(inst) inst.Physics:SetMotorVel(2 * inst.sg.statemem.speedmult) end),
			FrameEvent(28, function(inst) inst.Physics:SetMotorVel(1.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(29, function(inst) inst.Physics:SetMotorVel(1.125 * inst.sg.statemem.speedmult) end),
			FrameEvent(30, function(inst) inst.Physics:SetMotorVel(1 * inst.sg.statemem.speedmult) end),
			FrameEvent(31, function(inst) inst.Physics:SetMotorVel(.875 * inst.sg.statemem.speedmult) end),
			--

			FrameEvent(2, function(inst)
				inst.sg:AddStateTag("nointerrupt")
				inst.HitBox:SetEnabled(false)
			end),
			FrameEvent(18, function(inst)
				inst.HitBox:SetEnabled(true)
			end),
			FrameEvent(20, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:RemoveStateTag("airborne")
			end),
			FrameEvent(22, function(inst)
				if not inst.sg.statemem.noshake then
					inst:ShakeCamera(CAMERASHAKE.VERTICAL, .4, .01, .08)
				end
				inst.sg:AddStateTag("prone")
			end),
			FrameEvent(20, SGPlayerCommon.Fns.SetCanDodgeSpecial), -- quick rise window
			FrameEvent(20, SGPlayerCommon.Fns.SetCanHeavyDodgeSpecial), -- quick rise window
			FrameEvent(25, SGPlayerCommon.Fns.UnsetCanDodgeSpecial), -- Still let them dodge as normal, but after here it is not quickrise.
		},

		events =
		{
			EventHandler("deafen", function(inst)
				inst.sg.statemem.noshake = true
			end),
			EventHandler("animover", function(inst)
				inst.sg.statemem.knockdown = true
				inst.sg:GoToState("knockdown_idle", inst.sg.statemem.speedmult * .25)
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.knockdown then
				inst.Physics:Stop()
			end

			if not inst.sg.statemem.bypassposthitinvincibility then
				SGPlayerCommon.Fns.StartPostHitInvincibility(inst)
			end

			SGPlayerCommon.Fns.UnsetCanHeavyDodgeSpecial(inst)

			inst.Physics:StopPassingThroughObjects()
		end,
	})

	states[#states + 1] = State({
		name = "knockdown_idle",
		tags = { "knockdown", "busy", "nodeafen" },

		onenter = function(inst, speedmult)
			local data = inst.components.playercontroller:GetNextQueuedControl()
			if data ~= nil then
				inst.components.playercontroller:FlushControlQueueAt(data)
				inst.sg:GoToState("knockdown_getup")
				return
			end
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "knockdown_idle", true))
			inst.sg.statemem.speedmult = speedmult or 0
			inst.sg:AddStateTag("prone")
		end,

		onupdate = function(inst)
			if inst.components.playercontroller:IsEnabled() and inst.components.playercontroller:GetAnalogDir() ~= nil then
				inst.components.playercontroller:FlushControlQueue()
				inst.sg:GoToState("knockdown_getup")
			end
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(3 * inst.sg.statemem.speedmult) end),
			FrameEvent(1, function(inst) inst.Physics:SetMotorVel(2.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(2 * inst.sg.statemem.speedmult) end),
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(1.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.speedmult) end),
			FrameEvent(5, function(inst) inst.Physics:SetMotorVel(.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(6, function(inst) inst.Physics:Stop() end),
			--
		},

		events =
		{
			EventHandler("controlevent", function(inst, data)
				inst.components.playercontroller:FlushControlQueueAt(data)
				if data.control == "dodge" then
					inst.sg:GoToState("default_dodge")
				else
					inst.sg:GoToState("knockdown_getup")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
		end,
	})

	states[#states + 1] = State({
		name = "knockdown_getup",
		tags = { "knockdown", "busy", "nodeafen" },

		onenter = function(inst)
			inst.sg:AddStateTag("prone")
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "getup_pre"))
			SGPlayerCommon.Fns.SetCanDodge(inst)
		end,

		timeline =
		{
			--sounds
			--
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState(inst.sg.mem.quickgetup and "knockdown_getup_pst" or "knockdown_getup_struggle")
			end),
		},
	})

	states[#states + 1] = State({
		name = "knockdown_getup_struggle",
		tags = { "knockdown", "busy", "nodeafen" },

		onenter = function(inst)
			inst.sg:AddStateTag("prone")
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "getup_struggle"))
			SGPlayerCommon.Fns.SetCanDodge(inst)
		end,

		timeline =
		{
			FrameEvent(7, function(inst)
				inst.sg:RemoveStateTag("nodeafen")
				inst.sg:RemoveStateTag("prone")
			end),
			FrameEvent(13, function(inst) inst.sg:RemoveStateTag("knockdown") end),

		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("knockdown_getup_pst")
			end),
		},
	})

	states[#states + 1] = State({
		name = "knockdown_getup_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "getup_pst"))
		end,

		timeline =
		{
			FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(4, function(inst) inst.sg:RemoveStateTag("prone") end),
			FrameEvent(6, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	})
end

--------------------------------------------------------------------------
function SGPlayerCommon.States.AddDeafenStates(states)
	states[#states + 1] = State({
		name = "deafen_air_pre",
		tags = { "deafen", "busy", "airborne" },

		onenter = function(inst, reverse)
			inst.AnimState:PlayAnimation("deafen_air_pre")
			inst.sg.statemem.reverse = reverse
			inst.components.playercontroller:FlushControlQueue()
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.reverse and -2 or 2) end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.reverse and -1 or 1) end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVel(inst.sg.statemem.reverse and -.5 or .5) end),
			--

			FrameEvent(10, function(inst)
				inst.sg:RemoveStateTag("airborne")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("deafen_loop")
			end),
		},

		onexit = function(inst) inst.Physics:Stop() end,
	})

	states[#states + 1] = State({
		name = "deafen_pre",
		tags = { "deafen", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("deafen_pre")
			inst.components.playercontroller:FlushControlQueue()
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("deafen_loop")
			end),
		},
	})

	states[#states + 1] = State({
		name = "deafen_loop",
		tags = { "deafen", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("deafen_loop", true)
			inst.sg.statemem.maxticks = 20
			inst.sg.statemem.ticks = inst.sg.statemem.maxticks
		end,

		onupdate = function(inst)
			if inst.sg.statemem.ticks > 1 then
				inst.sg.statemem.ticks = inst.sg.statemem.ticks - 1
			else
				inst.sg:GoToState("deafen_pst")
			end
		end,

		events =
		{
			EventHandler("deafen", function(inst)
				inst.sg.statemem.ticks = inst.sg.statemem.maxticks
			end),
		},
	})

	states[#states + 1] = State({
		name = "deafen_pst",
		tags = { "deafen", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("deafen_pst")
		end,

		timeline =
		{
			FrameEvent(12, function(inst)
				inst.sg:RemoveStateTag("deafen")
				SGPlayerCommon.Fns.RemoveBusyState(inst)
			end),
		},

		events =
		{
			EventHandler("deafen", function(inst)
				inst.sg:GoToState(inst.sg:HasStateTag("deafen") and "deafen_loop" or "deafen_pre")
			end),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	})
end

function SGPlayerCommon.States.AddDisabledInputState(states)
	states[#states + 1] = State({
		name = "inputs_disabled",
		tags = { "busy" },

		onenter = function(inst)
			local animname = "idle"
			animname = SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, animname)
			inst.AnimState:PlayAnimation(animname, true)
			inst.components.playercontroller:FlushControlQueue()
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("inputs_enabled", function(inst)
				if inst:IsLocal() then
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst) inst.Physics:Stop() end,
	})

	states[#states + 1] = State({
		name = "deafen_pre",
		tags = { "deafen", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("deafen_pre")
			inst.components.playercontroller:FlushControlQueue()
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("deafen_loop")
			end),
		},
	})

	states[#states + 1] = State({
		name = "deafen_loop",
		tags = { "deafen", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("deafen_loop", true)
			inst.sg.statemem.maxticks = 20
			inst.sg.statemem.ticks = inst.sg.statemem.maxticks
		end,

		onupdate = function(inst)
			if inst.sg.statemem.ticks > 1 then
				inst.sg.statemem.ticks = inst.sg.statemem.ticks - 1
			else
				inst.sg:GoToState("deafen_pst")
			end
		end,

		events =
		{
			EventHandler("deafen", function(inst)
				inst.sg.statemem.ticks = inst.sg.statemem.maxticks
			end),
		},
	})

	states[#states + 1] = State({
		name = "deafen_pst",
		tags = { "deafen", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("deafen_pst")
		end,

		timeline =
		{
			FrameEvent(12, function(inst)
				inst.sg:RemoveStateTag("deafen")
				SGPlayerCommon.Fns.RemoveBusyState(inst)
			end),
		},

		events =
		{
			EventHandler("deafen", function(inst)
				inst.sg:GoToState(inst.sg:HasStateTag("deafen") and "deafen_loop" or "deafen_pre")
			end),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	})
end

---------
-- Networking spectate states:
-- In limbo, no inputs are respected. Once the room has unlocked, the player will receive an event and be freed from this state and brought into the game.
function SGPlayerCommon.States.AddSpectateStates(states)
	states[#states + 1] = State({
		name = "spectating",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("claw_drop") -- HACK: for networking, play an animation that leaves a blank visual
			inst.Network:FlushAllHistory()	-- Make sure this anim 'skips' the network buffered anim history
		end,

		onupdate = function(inst)
			inst:TryStopSpectating()
		end,

		onexit = function(inst, _currentstate, newstate)
			if inst:IsSpectating() then
				TheLog.ch.StateGraph:printf("Player %d GUID %d attempting to exit spectating state to %s -- returning next tick",
					inst.Network:GetPlayerID(), inst.GUID, newstate.name)
				inst:DoTaskInTicks(0, function(_inst)
					if inst:IsSpectating() then
						TheLog.ch.StateGraph:printf("Player %d GUID %d returning to spectating state.", inst.Network:GetPlayerID(), inst.GUID)
						inst.sg:GoToState("spectating")
					else
						TheLog.ch.StateGraph:printf("Player %d GUID %d didn't need to return to spectating state.", inst.Network:GetPlayerID(), inst.GUID)
					end
				end)
			end
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("spectatingstop", function(inst)
				inst.sg:GoToState("spectating_pst")
			end),
		},
	})

	states[#states + 1] = State({
		name = "spectating_pst",
		tags = { "busy" },

		onenter = function(inst)
			TheLog.ch.Player:printf("Player %d GUID %d entering spectating_pst...",
				inst.Network:GetPlayerID(), inst.GUID)

			-- TODO: this needs to be offset by playerID when multiple players enter at once
			local x,z = monsterutil.BruteForceFindWalkableTileFromXZ(0, 0, 100, 1)
			inst.Transform:SetPosition(x, 0, z)

			SGPlayerCommon.Fns.SetWeaponSheathed(inst, true)
			inst.AnimState:PlayAnimation("claw_abandon_drop")
			inst.AnimState:PushAnimation("claw_abandon_drop_pst")
			inst.Network:FlushAllHistory()	-- Make sure this anim 'skips' the network buffered anim history
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animqueueover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst) inst.Physics:Stop() end,
	})
end

---------
function SGPlayerCommon.States.AddPlayerSkillStates(states)
	states[#states + 1] = State({
		-- A universal skill_pst state that many states can return to if they choose. A very quick unsheathing of the weapon.
		name = "skill_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "skill_unsheathe"))
			SGPlayerCommon.Fns.SetCanDodge(inst)
			SGPlayerCommon.Fns.SetCanAttackOrAbility(inst)
		end,

		timeline =
		{
		},

		onexit = function(inst)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	})

	require "playerskillstates" -- initialize all the skill states
	local playerskillstates = PlayerSkillState.GetPlayerSkillStates()

	for _,skillstate in pairs(playerskillstates) do
		states[#states + 1] = skillstate
	end
end

-- Special states played on interactions with certain monsters.
function SGPlayerCommon.States.AddMonsterInteractionStates(states)
	states[#states + 1] = State({
		-- Used with groak's swallow attack.
		name = "vacuum_pre",
		tags = { "busy", "pre_swallowed", "nointerrupt", "airborne", "revivablestate" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("vacuum_pre")
			inst.Physics:StartPassingThroughObjects()
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("vacuum_pst")
			end),

			-- Swallowed event handlers added in SGCommon.Events.OnSwallowed.
		},

		onexit = function(inst)
			inst.Physics:StopPassingThroughObjects()
		end,
	})

	states[#states + 1] = State({
		-- Used with groak's swallow attack.
		name = "vacuum_pst",
		tags = { "busy", "pre_swallowed", "nointerrupt", "airborne", "revivablestate" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("vacuum_pst")
			inst.Physics:StartPassingThroughObjects()

			-- Set timeout fallback if the player never gets swallowed
			inst.sg:SetTimeout(3)
		end,

		events =
		{
			--[[EventHandler("animover", function(inst)
				inst.sg:GoToState("knockdown")
			end),]]

			-- Swallowed event handlers added in SGCommon.Events.OnSwallowed.
		},

		ontimeout = function(inst)
			SGCommon.Fns.ExitSwallowed(inst, { swallower = inst.sg.mem.swallower })
		end,

		onexit = function(inst)
			inst.Physics:StopPassingThroughObjects()
		end,
	})
end

--------------------------------------------------------------------------
-- Death flow upon receiving the 'dying' event:
--	OnDying(): Listen for hitstop 'paused' event, otherwise OnDeathTask() -> DoDeathState() on next frame if no hitstop.
-- 	(Received avoided_dying event): go to OnAvoidedDying()
--	OnDeathPaused()/OnDeathResumed(): After hitstop completes, go to DoDeathState().
-- 	DoDeathState(): Transition to death/death_hit state.
-- 	death/death_hit states: OnDeathJuggle() if hit during these states.
--	(During death state) on landing, send lucky revive event, then done_dying event.
--	DoDeathRevive() called in OnAvoidedDying(), OnAvoidedDeath().
--	(Received death event) go to OnDeath().
-- 	(Received avoided_death event): go to OnAvoidedDeath().
-- 	(Received revived event): go to OnRevived().
--	death_pst states. Push becomecorpse event; player is truly dead.

local function DoDeathState(inst)
	if inst.sg:HasStateTag("hit") then
		if inst.sg:HasStateTag("knockdown") then
			inst:FlipFacingAndRotation()
		elseif not inst.sg:HasStateTag("knockback") then
			inst:SnapToFacingRotation()
		end
		inst.sg:GoToState("death", inst.sg.statemem.speedmult)
	else
		inst:SnapToFacingRotation()
		inst.sg:GoToState("death_hit")
	end
end

-- These functions get called via hitstop pause/resume.
local function OnDeathResumed(inst)
	inst:RemoveEventCallback("resumed", OnDeathResumed)
	DoDeathState(inst)
end

local function OnDeathPaused(inst)
	inst.sg.mem.deathtask:Cancel()
	inst.sg.mem.deathtask = nil
	inst:RemoveEventCallback("paused", OnDeathPaused)
	inst:ListenForEvent("resumed", OnDeathResumed)
end

-- If not hitstop, this gets called instead.
local function OnDeathTask(inst)
	inst.sg.mem.deathtask = nil
	inst:RemoveEventCallback("paused", OnDeathPaused)
	DoDeathState(inst)
end

local function DoDeathRevive(inst)
	-- Death-related audio snapshot cleanup
	TheAudio:StopFMODSnapshot(fmodtable.Snapshot.Mute_Music_NonMenuMusic)
	TheAudio:StopFMODSnapshot(fmodtable.Snapshot.Mute_Ambience_Bed)
	TheAudio:StopFMODSnapshot(fmodtable.Snapshot.Mute_Ambience_Birds)

	if inst.sg.mem.deathtask ~= nil then
		inst.sg.mem.deathtask:Cancel()
		inst.sg.mem.deathtask = nil
	end

	inst:RemoveEventCallback("paused", OnDeathPaused)
	inst:RemoveEventCallback("resumed", OnDeathResumed)
end

local function OnAvoidedDying(inst)
	-- Avoided dying; transition back to a normal state.
	DoDeathRevive(inst)
end

function SGPlayerCommon.Events.OnAvoidedDying(inst)
	return EventHandler("avoided_dying", OnAvoidedDying)
end

local function OnAvoidedDeath(inst)
	DoDeathRevive(inst)

	-- Avoided death; transition back to a normal state.
	if inst.sg.mem.weapontype == nil then
		inst.sg.mem.weapontype = SGPlayerCommon.Fns.GetWeaponType(inst)
	end
	local rot = inst.Transform:GetRotation()
	inst.Transform:SetRotation(rot + 180)
	SGPlayerCommon.Fns.SetRollPhysicsSize(inst) -- This should get undone when exiting roll_loop, but it's possible not.

	inst.sg:ForceGoToState("roll_loop", { iframes = 10, maxspeed = 11 })
	inst.components.hitstopper:PushHitStop(1)

	TheWorld:PushEvent("playerdeathrevived")
end

function SGPlayerCommon.Events.OnAvoidedDeath(inst)
	return EventHandler("avoided_death", OnAvoidedDeath)
end

local function OnDying(inst, data)
	--Prepare for death anim after hitstop
	inst.sg.mem.deathtask = inst:DoTaskInTicks(0, OnDeathTask)
	inst:ListenForEvent("paused", OnDeathPaused)

	inst.components.playercontroller:FlushControlQueue()
end

function SGPlayerCommon.Events.OnDying(inst)
	return EventHandler("dying", OnDying)
end

local function OnLastPlayerDead(inst)
	inst.sg:ForceGoToState("death_pst")
end

local function IsAnotherPlayerParticipating(inst)
	for _, player in ipairs(AllPlayers) do
		if player ~= inst and not player:IsInLimbo() then
			return true
		end
	end
	return false
end

local function OnDeath(inst)
	inst.components.playercontroller:FlushControlQueue()

	if IsAnotherPlayerParticipating() and not playerutil.AreAllMultiplayerPlayersDead() then
		-- Multiplayer game & other players are still alive; set dead player to be revivable
		inst.components.health:SetRevivable()

		-- Listen for when the last player dies
		inst:ListenForEvent("lastplayerdead", function()
			OnLastPlayerDead(inst)
		end, TheWorld)
	else
		OnLastPlayerDead(inst)
	end
end

function SGPlayerCommon.Events.OnDeath(inst)
	return EventHandler("death", OnDeath)
end

local function OnDeathJuggle(inst, data)
	if data ~= nil and data.attack:GetDir() ~= nil then
		data.dir = data.attack:GetDir()
		SGCommon.Fns.FaceAwayActionTarget(inst, data, true)
	end
	inst.sg.statemem.death = true
	inst.sg:ForceGoToState("death_hit", data ~= nil and data.attack ~= nil and data.attack:GetPushback() or nil)
end

-- Logging data to help discover cases where a player dies, but revives with 0 HP.
--[[local function DoDeathCancelLogging(inst, currentstate, nextstate)
	if nextstate and not (nextstate.tags and table.contains(nextstate.tags, "death")) then
		TheLog.ch.Player:printf("Exited death state! CurrentState: %s, NextState: %s", currentstate.name, nextstate.name)
	end
end]]

function SGPlayerCommon.States.AddDeathStates(states)
	states[#states + 1] = State({
		name = "death",
		tags = { "death", "busy", "airborne" },

		onenter = function(inst, speedmult)
			--inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "death"))
			inst.AnimState:PlayAnimation("death")
			inst.sg.statemem.speedmult = speedmult or 1
			inst.HitBox:SetEnabled(false)

			inst.components.playercontroller:FlushControlQueue()
			inst:AddTag("no_state_transition")
		end,

		timeline =
		{
			-- death save
			FrameEvent(12, function(inst)
				inst:RemoveTag("no_state_transition")
				inst:PushEvent("process_lucky_revive")
			end),

			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(-10 * inst.sg.statemem.speedmult) end),
			FrameEvent(13, function(inst) inst.Physics:SetMotorVel(-5 * inst.sg.statemem.speedmult) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(-4 * inst.sg.statemem.speedmult) end),
			FrameEvent(18, function(inst) inst.Physics:SetMotorVel(-2 * inst.sg.statemem.speedmult) end),
			FrameEvent(20, function(inst) inst.Physics:SetMotorVel(-1 * inst.sg.statemem.speedmult) end),
			FrameEvent(22, function(inst) inst.Physics:SetMotorVel(-.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(25, function(inst) inst.Physics:SetMotorVel(-.25 * inst.sg.statemem.speedmult) end),
			--

			FrameEvent(13, function(inst)
				inst:AddTag("no_state_transition")
				inst.sg:RemoveStateTag("airborne")
				inst:PushEvent("death_landed") -- Push this before done_dying so that certain callbacks get handled before dying -> death processing.

				-- If we lucky revive/mulligan'ed, push the done_dying event to kick out of this state (via _on_done_dying in the health component.)
				if inst.components.health:GetCurrent() > 0 then
					inst:PushEvent("done_dying")
				end
			end),

			FrameEvent(18, function(inst)
				inst:PushEvent("death_bounce")
			end),

			FrameEvent(20, function(inst)
				inst.sg:AddStateTag("nointerrupt")
			end),
		},

		events =
		{
			EventHandler("knockdown", OnDeathJuggle),
			EventHandler("knockback", OnDeathJuggle),
			EventHandler("animover", function(inst)
				inst.Physics:Stop()

				inst:PushEvent("done_dying")

				-- In multiplayer, done_dying will set the player's status to revivable & transition to the proper revivable state. See OnRevivable() in sg_player_common
				if inst:IsRevivable() then
					return
				end

				-- Do not go into death_pst if held, since exiting from that state via transitions during hold will revive the player!
				if not inst.sg.mem.isheld then
					inst.sg.statemem.death = true
					inst.sg:ForceGoToState("death_pst")
				end
			end),
		},

		onexit = function(inst, currentstate, nextstate)
			if not inst.sg.statemem.death then
				inst.Physics:Stop()
				inst.HitBox:SetEnabled(true)
			end

			--DoDeathCancelLogging(inst, currentstate, nextstate)
		end,
	})

	states[#states + 1] = State({
		name = "death_hit",
		tags = { "hit", "death", "busy", "airborne" },

		onenter = function(inst, speedmult)
			--inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "death_hit"))
			inst.AnimState:PlayAnimation("death_hit")
			inst.sg.statemem.speedmult = speedmult or .35
			inst.HitBox:SetEnabled(false)

			inst.components.playercontroller:FlushControlQueue()
			inst:AddTag("no_state_transition")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(-7 * inst.sg.statemem.speedmult) end),
			--
		},

		events =
		{
			EventHandler("knockdown", OnDeathJuggle),
			EventHandler("knockback", OnDeathJuggle),
			EventHandler("animover", function(inst)
				inst.sg.statemem.death = true
				if not inst.sg.mem.isheld then -- If held, the transition to death is handled in a reset function upon release (e.g. SGCommon.Fns.ExitSwallowed())
					inst.sg:ForceGoToState("death", inst.sg.statemem.speedmult)
				end
			end),
		},

		onexit = function(inst, currentstate, nextstate)
			if not inst.sg.statemem.death then
				inst.Physics:Stop()
				inst.HitBox:SetEnabled(true)
			end

			--DoDeathCancelLogging(inst, currentstate, nextstate)
		end,
	})

	states[#states + 1] = State({
		name = "death_pst",
		tags = { "death", "busy", "nointerrupt", "notarget" },

		onenter = function(inst)
			--inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "death_idle"))
			inst.AnimState:PlayAnimation("death_idle", true)
			inst.Physics:SetEnabled(false)
			inst.HitBox:SetEnabled(false)
			inst:PushEvent("becomecorpse")

			inst.components.playercontroller:FlushControlQueue()
			inst:AddTag("no_state_transition")
		end,

		onexit = function(inst, currentstate, nextstate)
			inst.Physics:SetEnabled(true)
			inst.HitBox:SetEnabled(true)

			--DoDeathCancelLogging(inst, currentstate, nextstate)
		end,
	})
end

--------------------------------------------------------------------------

local function _RevivableCommonEvents()
	return {
		EventHandler("lastplayerdead", OnLastPlayerDead),
	}
end


local function _SetRevivableControlQueueTicks(inst)
	inst.components.playercontroller:OverrideControlQueueTicks("dodge", 4 * ANIM_FRAMES)
	inst.components.playercontroller:OverrideControlQueueTicks("lightattack", 6 * ANIM_FRAMES)
	inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", 6 * ANIM_FRAMES)
	inst.components.playercontroller:OverrideControlQueueTicks("skill", 6 * ANIM_FRAMES)
end

local function _UnsetRevivableControlQueueTicks(inst)
	inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
	inst.components.playercontroller:OverrideControlQueueTicks("lightattack", nil)
	inst.components.playercontroller:OverrideControlQueueTicks("heavyattack", nil)
	inst.components.playercontroller:OverrideControlQueueTicks("skill", nil)
end

local function _AddRevivableStatememStates(inst)
	inst.sg.statemem.dodgecombostate = "death_flop"
	inst.sg.statemem.lightcombostate = "death_wave"
	inst.sg.statemem.heavycombostate = "death_ground_smack"
	inst.sg.statemem.skillcombostate = "death_kick"

	if SGPlayerCommon.Fns.TryQueuedAction(inst, "dodge") then return end
	if SGPlayerCommon.Fns.TryQueuedAction(inst, "lightattack") then	return end
	if SGPlayerCommon.Fns.TryQueuedAction(inst, "heavyattack") then	return end
	if SGPlayerCommon.Fns.TryQueuedAction(inst, "skill") then return end
end

local function _AddRevivableStatememStatesWithoutDodge(inst)
	inst.sg.statemem.lightcombostate = "death_wave"
	inst.sg.statemem.heavycombostate = "death_ground_smack"
	inst.sg.statemem.skillcombostate = "death_kick"

	if SGPlayerCommon.Fns.TryQueuedAction(inst, "lightattack") then	return end
	if SGPlayerCommon.Fns.TryQueuedAction(inst, "heavyattack") then	return end
	if SGPlayerCommon.Fns.TryQueuedAction(inst, "skill") then return end
end

local REVIVABLE_HIT_STUN_TIME = 3
function SGPlayerCommon.States.AddReviveStates(states)
	states[#states + 1] = State({
		name = "revivable_idle",
		tags = { "busy", "revivable", "revivablestate" },

		onenter = function(inst, speedmult)
			--inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "death_idle"), true)
			inst.AnimState:PlayAnimation("death_idle", true)
			inst.HitBox:SetInvincible(false)
			_AddRevivableStatememStates(inst)
			_SetRevivableControlQueueTicks(inst)
		end,

		events = lume.concat(_RevivableCommonEvents(),
		{
		}),

		onexit = function(inst)
			_UnsetRevivableControlQueueTicks(inst)
			SGPlayerCommon.Fns.UnsetCanMove(inst)
		end,
	})

	states[#states + 1] = State({
		name = "revivable_stunned",
		tags = { "busy", "revivable", "revivablestate" },

		onenter = function(inst, speedmult)
			--inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "death_idle"), true)
			inst.AnimState:PlayAnimation("death_idle", true)
			inst.HitBox:SetInvincible(false)
			inst.sg:SetTimeout(REVIVABLE_HIT_STUN_TIME)

			-- Spawn stunned FX
			local distance = -0.85
			local facingrot = inst.Transform:GetFacingRotation()
			local ox, oz = SGCommon.Fns.CalculateFacingXZOffsets(inst, distance, facingrot)

			local flip = inst.Transform:GetFacingRotation() == 0
			local params =
			{
				fxname = "fx_stunned_headstars",
				scalex = flip and -1.0 or 1.0,
				offx = ox,
				offy = 1.5,
				offz = oz,
				stopatexitstate = true,
			}
			inst.sg.statemem.stunned_fx = EffectEvents.MakeEventSpawnEffect(inst, params)
		end,

		events =
		{
			EventHandler("lastplayerdead", OnLastPlayerDead),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("revivable_idle") -- Re-enter revivable idle to re-enable controls.
		end,

		onexit = function(inst)
			inst.HitBox:SetEnabled(true)
		end,
	})

	states[#states + 1] = State({
		name = "death_flop",
		tags = { "moving", "busy", "revivable", "revivablestate", "airborne" },

		onenter = function(inst, perfectwindow)
			inst.AnimState:PlayAnimation("death_flop")
			inst.Physics:Stop()
			if inst.components.playercontroller:GetAnalogDir() ~= nil then
				inst.sg.statemem.speedmult_start = perfectwindow and 0.8 or 0.25
				inst.sg.statemem.speedmult_mid = perfectwindow and 0.01 or 0.05
				inst.sg.statemem.moving = true

				SGCommon.Fns.SetMotorVelScaled(inst, inst.components.locomotor:GetBaseRunSpeed() * inst.sg.statemem.speedmult_start)
			end

			if perfectwindow then
				inst.components.hitstopper:PushHitStop(2)
			end

			_SetRevivableControlQueueTicks(inst)
		end,

		timeline =
		{
			FrameEvent(9, function(inst)
				if inst.sg.statemem.moving then
					inst.Physics:SetMotorVel(inst.components.locomotor:GetBaseRunSpeed() * inst.sg.statemem.speedmult_mid)
				end
				inst.sg:RemoveStateTag("airborne")
			end),
			FrameEvent(11, function(inst) inst.Physics:Stop() end),
			FrameEvent(11, function(inst) _AddRevivableStatememStatesWithoutDodge(inst) end), -- We are manually managing Dodge in this state.

			-- Perfect Window: If the player presses Dodge during this window, then we will re-enter this dodge state faster.
			FrameEvent(8, function(inst) inst.sg.statemem.perfectwindow = true end),
			FrameEvent(9, function(inst)
				inst.sg.statemem.dodgecombostate = "death_flop"
				if inst.sg.statemem.queueddodge then
					-- We pressed dodge before this moment. This is a manual implementation of the control queue buffer, since we aren't using TryQueuedAction()
					-- We aren't using TryQueuedAction() so we can send extra data along with the state enter -- if the timing was perfect.

					-- Manually face the direction we were facing when we pressed the button, then go to the state.
					SGCommon.Fns.FaceActionTarget(inst, { dir = inst.sg.statemem.queueddodgedir }, inst.sg.statemem.queueddodgedir == nil)
					inst.sg:GoToState("death_flop", inst.sg.statemem.queuedperfect)

					-- Presses after this point will be handled in the controlevent EventHandler below.
				end
			end),
			FrameEvent60(21, function(inst) inst.sg.statemem.perfectwindow = false end),
		},

		events = lume.concat(_RevivableCommonEvents(),
		{
			EventHandler("controlevent", function(inst, data)
				if data.control == "dodge" then
					if not inst.sg.statemem.dodgecombostate then
						-- Pressed dodge before the window is open, so queue up a dodge.
						-- Store whether this press was within the 'perfect' window or not.

						inst.sg.statemem.queueddodge = true
						inst.sg.statemem.queueddodgedir = data.dir
						if inst.sg.statemem.perfectwindow then
							inst.sg.statemem.queuedperfect = inst.sg.statemem.perfectwindow
						end
					else
						-- Pressed dodge after the window is already open
						-- Go to the death_flop state, and include whether or not this was perfect.
						-- It will not be perfect if we have pressed after the dodgecombostate has been set AND after perfectwindow has been set to false.

						SGCommon.Fns.FaceActionTarget(inst, { dir = data.dir }, data.dir == nil)
						inst.sg:GoToState("death_flop", inst.sg.statemem.perfectwindow)
					end
				end
			end),

			EventHandler("animover", function(inst)
				inst.sg:GoToState("revivable_idle")
			end),
		}),

		onexit = function(inst)
			_UnsetRevivableControlQueueTicks(inst)
			inst.Physics:Stop()
		end,
	})

	states[#states + 1] = State({
		name = "death_wave",
		tags = { "busy", "revivable", "revivablestate" },

		onenter = function(inst)
			-- Skip the pre anim if we're transitioned into here from itself.
			if inst.sg.laststate == inst.sg.currentstate then
				inst.AnimState:PlayAnimation("death_wave")
			else
				inst.AnimState:PlayAnimation("death_wave_pre")
				inst.AnimState:PushAnimation("death_wave")
			end

			_SetRevivableControlQueueTicks(inst)
			inst.components.playercontroller:FlushControlQueue()
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				_AddRevivableStatememStates(inst)
			end),
		},

		onexit = function(inst)
			_UnsetRevivableControlQueueTicks(inst)
		end,

		events = lume.concat(_RevivableCommonEvents(),
		{
			EventHandler("animqueueover", function(inst)
				inst.sg:GoToState("revivable_idle")
			end),
		}),
	})

	states[#states + 1] = State({
		name = "death_ground_smack",
		tags = { "busy", "revivable", "revivablestate" },

		onenter = function(inst)
			-- Skip the pre anim if we're transitioned into here from itself.
			if inst.sg.laststate == inst.sg.currentstate then
				inst.AnimState:PlayAnimation("death_ground_smack")
			else
				inst.AnimState:PlayAnimation("death_ground_smack_pre")
				inst.AnimState:PushAnimation("death_ground_smack")
			end

			_SetRevivableControlQueueTicks(inst)
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				_AddRevivableStatememStates(inst)
			end),
		},

		onexit = function(inst)
			_UnsetRevivableControlQueueTicks(inst)
		end,

		events = lume.concat(_RevivableCommonEvents(),
		{
			EventHandler("animqueueover", function(inst)
				inst.sg:GoToState("revivable_idle")
			end),
		}),
	})

	states[#states + 1] = State({
		name = "death_kick",
		tags = { "busy", "revivable", "revivablestate" },

		onenter = function(inst)
			-- Skip the pre anim if we're transitioned into here from itself.
			if inst.sg.laststate == inst.sg.currentstate then
				inst.AnimState:PlayAnimation("death_kick")
			else
				inst.AnimState:PlayAnimation("death_kick_pre")
				inst.AnimState:PushAnimation("death_kick")
			end

			_SetRevivableControlQueueTicks(inst)
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				_AddRevivableStatememStates(inst)
			end),
		},

		onexit = function(inst)
			_UnsetRevivableControlQueueTicks(inst)
		end,

		events = lume.concat(_RevivableCommonEvents(),
		{
			EventHandler("animqueueover", function(inst)
				inst.sg:GoToState("revivable_idle")
			end),
		}),
	})

	states[#states + 1] = State({
		name = "revivable_hit",
		tags = { "hit", "busy", "airborne", "revivablestate" },

		default_data_for_tools = function(inst)
			return { pushback = 0.35 }
		end,

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "death"))

			if data ~= nil and data.attack and data.attack:GetDir() ~= nil then
				data.dir = data.attack:GetDir()
				SGCommon.Fns.FaceAwayActionTarget(inst, data, true)
			end
			inst.sg.statemem.death = true

			-- If hit while in the revivable state, get stunned for a moment (cannot move/emote)
			-- Also cannot be hit again while stunned.
			inst.HitBox:SetEnabled(false)

			inst.sg.statemem.speedmult = data and data.pushback or 0.35
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(-10 * inst.sg.statemem.speedmult) end),
			FrameEvent(13, function(inst) inst.Physics:SetMotorVel(-5 * inst.sg.statemem.speedmult) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(-4 * inst.sg.statemem.speedmult) end),
			FrameEvent(18, function(inst) inst.Physics:SetMotorVel(-2 * inst.sg.statemem.speedmult) end),
			FrameEvent(20, function(inst) inst.Physics:SetMotorVel(-1 * inst.sg.statemem.speedmult) end),
			FrameEvent(22, function(inst) inst.Physics:SetMotorVel(-.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(25, function(inst) inst.Physics:SetMotorVel(-.25 * inst.sg.statemem.speedmult) end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				--inst.sg:GoToState("revivable_hit_land", inst.sg.statemem.speedmult)
				if playerutil.AreAllMultiplayerPlayersDead() then
					inst.sg:ForceGoToState("death_pst")
				else
					inst.sg:GoToState("revivable_stunned")
				end
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetEnabled(true)
			inst.Physics:Stop()
		end,
	})

	states[#states + 1] = State({
		name = "revived",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("death_getup")
			SGPlayerCommon.Fns.SetCanDodge(inst)
			inst.HitBox:SetInvincible(true)
		end,

		timeline =
		{
			FrameEvent(41, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("unsheathe_fast")
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
		end,
	})
end

--------------------------------------------------------------------------
local function OnReviveApproachInteraction(inst, player)
	-- Set up a preview of the health change
	-- 	inst: revivee
	--	player: reviver

	local revive_health = player.components.health:GetReviveAmount()

	-- Reviver only loses health if Ascension 1
	inst:PushEvent("previewhealthchange", revive_health)

	if TheDungeon.progression.components.ascensionmanager:GetCurrentLevel() >= 1 then
		player:PushEvent("previewhealthchange", -revive_health)
	end
end

local function OnReviveDepartInteraction(inst, player)
	inst:PushEvent("previewhealthchange_end")
	player:PushEvent("previewhealthchange_end")
end

local function OnReviveInteract(target, player)
	-- We do everything in the stategraph state.
end

-- this is for the revivee
function SGPlayerCommon.Fns.SetupReviveInteractable(inst)
	local interact_radius = 3
	inst.components.interactable:SetRadius(interact_radius)
		:SetInteractStateName("revive_interact")
		:SetAbortStateName("revive_pst")
		:SetOnInteractFn(OnReviveInteract)

	local label = STRINGS.UI.ACTIONS.REVIVE
	inst.components.interactable:SetupForLabelPrompt(label, OnReviveApproachInteraction, OnReviveDepartInteraction, 4.5)

	-- Disable until a player is dead/revivable.
	inst.components.interactable:SetInteractCondition_Never()
end

local function OnRevivableStateChanged(inst, data)
	inst.components.revive:OnReviveeSGStateChanged(data)
end

local function OnRevivable(inst)
	inst.components.revive:ReviveeSetRevivable()
	inst:ListenForEvent("newstate", OnRevivableStateChanged)

	inst.sg:ForceGoToState("revivable_idle")
	inst.sg:AddLockStateTransitionTag("revivablestate")

	-- Allow to get hit, but not take damage
	inst.components.combat:SetDamageReceivedMult("dead_revivable", 0)
end

function SGPlayerCommon.Events.OnRevivable(inst)
	return EventHandler("revivable", OnRevivable)
end


local function OnRevived(inst, reviver)
	-- TODO: Make revival a power and process that power to allow for multiple ways to revive.
	local revive_health = math.max(reviver and reviver.components.health:GetReviveAmount() or 1, 1)

	-- Heal the target
	local revive_heal = Attack(reviver or inst, inst)
	revive_heal:SetHeal(revive_health)
	revive_heal:SetID("revive_heal")
	revive_heal:SetHealForced(true)
	inst.components.combat:ApplyHeal(revive_heal)

	-- Damage the reviver
	if TheDungeon.progression.components.ascensionmanager:GetCurrentLevel() >= 1 then
		if reviver and reviver.components.health:GetCurrent() > 1 then
			local revive_damage = Attack(inst, reviver)
			revive_damage:SetHeal(-revive_health)
			inst.components.combat:ApplyReviveDamage(revive_damage)
		end
	end

	inst.HitBox:SetInvincible(false)
	inst.components.combat:RemoveAllDamageMult("dead_revivable")

	inst.components.revive:ReviveeResetState()

	inst:RemoveEventCallback("revived", OnRevived)
	inst:RemoveEventCallback("newstate", OnRevivableStateChanged)

	inst.sg:RemoveLockStateTransitionTag("revivablestate")
	inst.sg:GoToState("revived")
end

function SGPlayerCommon.Events.OnRevived(inst, reviver)
	return EventHandler("revived", OnRevived)
end

--------------------------------------------------------------------------
local function OnPreSwallowed(inst, data)
TheLog.ch.Groak:printf("Player Pre Swallowed! inst: %s (%d), swallower: %s (%d)", inst.prefab, inst.Network:GetEntityID(), data.swallower and data.swallower.prefab or "", data.swallower and data.swallower.Network:GetEntityID() or "")
	SGCommon.Fns.OnPreSwallowedCommon(inst, data)

	-- Flip if the player is facing away from the swallower when pre-swallowed. Need to face towards the swallower's mouth position.
	if inst.Transform:GetFacingRotation() == data.swallower.Transform:GetFacingRotation() then
		inst.Transform:FlipFacingAndRotation()
	end

	inst.sg:GoToState("vacuum_pre")
end

function SGPlayerCommon.Events.OnPreSwallowed()
	return EventHandler("pre_swallowed", OnPreSwallowed)
end

--------------------------------------------------------------------------

local function OnEnterTown(inst)
	SGPlayerCommon.Fns.SheatheWeapon(inst)
end

function SGPlayerCommon.Events.OnEnterTown()
	return EventHandler("enter_town", OnEnterTown)
end

--------------------------------------------------------------------------

local function OnRoomBonusScreenOpened(inst)
	inst.sg:GoToState("roombonusscreen_active")
end

function SGPlayerCommon.Events.OnRoomBonusScreenOpened()
	return EventHandler("roombonusscreen_opened", OnRoomBonusScreenOpened)
end

--------------------------------------------------------------------------

-- Added the data parameter here in case we wanna grab the food and override some symbols or something
local function OnStartEarting(inst, data)
	inst.sg:GoToState("eat")
end

function SGPlayerCommon.Events.OnStartEating()
	return EventHandler("on_start_eating", OnStartEarting)
end

function SGPlayerCommon.States.AddFoodStates(states)
	states[#states + 1] = State({
		name = "eat",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("eat_food")
			-- inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "eat_food"))
		end,

		events =
		{
			EventHandler("animqueueover", function(inst)
				inst:PushEvent("on_done_eating")
				inst.sg:GoToState("unsheathe_fast")
			end)
		}

	})
end

--------------------------------------------------------------------------

function SGPlayerCommon.States.AddPotionStates(states)
	states[#states + 1] = State({
		name = "potion_pre",
		tags = { "busy" },

		onenter = function(inst)
			if SGPlayerCommon.Fns.IsWeaponSheathed(inst) then
				SGPlayerCommon.Fns.SetWeaponSheathed(inst, false)
			end

			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "potion_pre"))

			if inst.sg.mem.heal_aoe and inst.sg.mem.heal_aoe:IsValid() then
				inst.sg.mem.heal_aoe:Remove()
			end

			inst.sg.mem.heal_aoe = powerutil.SpawnParticlesAtPosition(inst:GetPosition(), "heal_aoe_ring", 0, inst)

			--TODO(jambell): temp, mocking up this implementation
			local x,z = inst.Transform:GetWorldXZ()
			local friendlies = FindTargetTagGroupEntitiesInRange(x, z, TUNING.POTION_AOE_RANGE, inst.components.combat:GetFriendlyTargetTags(), nil)
			for _,ent in ipairs(friendlies) do
				if ent.components.health and inst ~= ent then
					powerutil.SpawnParticlesOnEntity(ent, "heal_aoe_ring_affected", nil, 0)
				end
			end

			-- if inst.sg.mem.drink_from_refill then
			-- 	inst.AnimState:SetFrame(7)
			-- 	inst.sg.mem.drink_from_refill = false
			-- end
		end,

		timeline =
		{
			FrameEvent(TUNING.PLAYER.POTION_HOLD_REQUIREMENT_FRAMES, function(inst)
				if inst.components.playercontroller:IsControlHeld("potion") then
					inst.sg.statemem.heldpotion = true
				end
			end),
			FrameEvent(5, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(5, SGPlayerCommon.Fns.SetCanAttackOrAbility),
		},

		events =
		{
			EventHandler("animover", function(inst)
				local usage_data = inst.components.potiondrinker:GetEquippedPotionUsageData("POTIONS")
				inst.sg:GoToState(usage_data.quickdrink and "potion" or "potion_hold", { potion = inst.sg.statemem.potion, heldpotion = inst.sg.statemem.heldpotion })
			end),
		},
	})

	states[#states + 1] = State({
		name = "potion_hold",
		tags = { "busy" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "potion_hold_loop"))
			inst.sg.statemem.heldpotion = data.heldpotion ~= nil and data.heldpotion or false
		end,

		timeline =
		{
			FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(0, SGPlayerCommon.Fns.SetCanAttackOrAbility),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.statemem.heldpotion then
					inst.sg:GoToState("potion")
				else
					inst.sg:GoToState("potion_pre_cancel")
				end
			end),
		},
	})

	states[#states + 1] = State({
		name = "potion_pre_cancel",
		tags = { "busy" },

		onenter = function(inst, held_frames)
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "potion_cancel"))
		end,

		timeline =
		{
			FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(0, SGPlayerCommon.Fns.SetCanAttackOrAbility),
			FrameEvent(6, SGPlayerCommon.Fns.RemoveBusyState)
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	})

	states[#states + 1] = State({
		name = "potion",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "potion_pst"))
		end,

		timeline =
		{
			FrameEvent(13, function(inst)
				inst.components.coloradder:PushColor("potion", 0, 1 / 25, 0, 0)
			end),
			FrameEvent(14, function(inst)
				inst.components.coloradder:PushColor("potion", 0, 4 / 25, 0, 0)
			end),
			FrameEvent(15, function(inst)
				inst.components.coloradder:PushColor("potion", 0, 9 / 25, 0, 0)
			end),
			FrameEvent(16, function(inst)
				inst.components.coloradder:PushColor("potion", 0, 16 / 25, 0, 0)
			end),
			FrameEvent(17, function(inst)
				inst.components.coloradder:PushColor("potion", 0, 1, 0, 0)
				inst.components.bloomer:PushBloom("potion", 1)
			end),
			FrameEvent(19, function(inst)
				inst.components.coloradder:PopColor("potion")
				inst.components.bloomer:PopBloom("potion")
				local ox, oz = SGCommon.Fns.CalculateFacingXZOffsets(inst, -.3)
				EffectEvents.MakeEventSpawnEffect(inst, { fxname = "fx_heal_burst", offx = ox, offz = oz })
				inst.components.potiondrinker:DrinkPotion()
			end),
			FrameEvent(45, function(inst)
				SGCommon.Fns.SpawnAtDist(inst, "fx_player_flask_smash_glass", 1.5)
				SGCommon.Fns.SpawnAtDist(inst, "fx_player_flask_smash_impact", 1.5)
			end),
			FrameEvent(51, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.coloradder:PopColor("potion")
			inst.components.bloomer:PopBloom("potion")
		end,
	})

	states[#states + 1] = State({
		name = "potion_fast",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("potion_fast")
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				inst.components.coloradder:PushColor("potion", 0, 1 / 25, 0, 0)
			end),
			FrameEvent(2, function(inst)
				inst.components.coloradder:PushColor("potion", 0, 4 / 25, 0, 0)
			end),
			FrameEvent(3, function(inst)
				inst.components.coloradder:PushColor("potion", 0, 9 / 25, 0, 0)
			end),
			FrameEvent(4, function(inst)
				inst.components.coloradder:PushColor("potion", 0, 16 / 25, 0, 0)
			end),
			FrameEvent(5, function(inst)
				inst.components.coloradder:PushColor("potion", 0, 1, 0, 0)
				inst.components.bloomer:PushBloom("potion", 1)
			end),
			FrameEvent(7, function(inst)
				inst.components.coloradder:PopColor("potion")
				inst.components.bloomer:PopBloom("potion")
				local ox, oz = SGCommon.Fns.CalculateFacingXZOffsets(inst, 1)
				EffectEvents.MakeEventSpawnEffect(inst, { fxname = "fx_heal_burst", offx = ox, offz = oz })
				inst.components.potiondrinker:DrinkPotion()
			end),
			FrameEvent(23, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.coloradder:PopColor("potion")
			inst.components.bloomer:PopBloom("potion")
		end,
	})

	states[#states + 1] = State({
		name = "potion_refill_pre",
		tags = { "busy", "potion_refill" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "potion_refill_pre"))
		end,

		timeline =
		{
			FrameEvent(18, function(inst)
				TheWorld.components.ambientaudio:PlayMusicStinger(fmodtable.Event.Mus_potionRefill_Stinger)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("potion_refill")
			end),
		},
	})

	states[#states + 1] = State({
		name = "potion_refill",
		tags = { "busy", "potion_refill" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "potion_refill"))
		end,

		timeline =
		{
			-- TODO: Animate Bloom on the potion itself
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("potion_refill_loop")
			end),
		},
	})

	states[#states + 1] = State({
		name = "potion_refill_loop",
		tags = { "busy", "potion_refill" },

		onenter = function(inst)
			local hold_anim_length = 25
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "potion_refill_loop"))
			inst.sg:SetTimeoutTicks(hold_anim_length)
			inst.components.playercontroller:OverrideControlQueueTicks("potion", hold_anim_length + 2)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("potion_refill_pst")
			inst.sg.mem.drink_from_refill = true
			SGPlayerCommon.Fns.TryQueuedAction(inst, "potion")
		end,
	})

	states[#states + 1] = State({
		name = "potion_refill_pst",
		tags = { "busy", "potion_refill" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "potion_refill_pst"))
		end,

		timeline =
		{
			FrameEvent(12, function(inst)
				inst.sg.mem.drink_from_refill = false
			end)
		},

		onexit = function(inst)
			inst.components.playercontroller:OverrideControlQueueTicks("potion", nil)
			inst:DoTaskInAnimFrames(10, function(inst)
				inst.sg.mem.drink_from_refill = false
			end)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	})
end

--------------------------------------------------------------------------
local function GetInteractable(item)
	if item and item:IsValid() then
		return item.components.interactable
	end
end
local function IsPlayerInteracting(item, player)
	local interactable = GetInteractable(item)
	return not interactable or interactable:IsPlayerInteracting(player)
end
local function ClearInteractFromMem(inst)
	local interactable = GetInteractable(inst.sg.mem.interact_target)
	if interactable and interactable:IsPlayerInteracting(inst) then
		interactable:ClearInteract(inst)
	end
	-- else: Normally something shouldn't clear our interact, but it's not so
	-- bad so long as they cleaned up properly.
	inst.sg.mem.interact_target = nil
end

local function Interact_DefaultDataForTools(inst, cleanup)
	local item = DebugSpawn("flower_bush")
	table.insert(cleanup.spawned, item)
	local interactable = item.components.interactable
	interactable:StartInteract(inst)
	spawnutil.AddWorldLabel(item, "default_data_for_tools")
	return item
end

function SGPlayerCommon.States.AddTalkState(states)
	states[#states + 1] = State({
		name = "talk",
		tags = { "busy", "interact" },

		default_data_for_tools = Interact_DefaultDataForTools,

		onenter = function(inst, item)
			dbassert(IsPlayerInteracting(item, inst))

			-- temporary fix for going invisible because there is no fatigued + sheathed idle anim
			local fatigued = inst.components.health ~= nil and inst.components.health:IsLow()

			if not fatigued then
				if SGPlayerCommon.Fns.SheatheWeapon(inst, item) then
					inst.AnimState:PlayAnimation("idle", true)
				end
			end
			inst.sg.mem.interact_target = item
		end,

		timeline =
		{
			FrameEvent(11, function(inst)
				local interactable = GetInteractable(inst.sg.mem.interact_target)
				if interactable and interactable:IsPlayerInteracting(inst) then
					interactable:PerformInteract(inst)
				else
					assert(not interactable, "How did we get to this state without starting the interaction?")
					-- failure
					if not SGPlayerCommon.Fns.ShouldSheatheWeapon(inst) then
						inst.sg:GoToState("unsheathe_fast")
					end
				end
			end),
			FrameEvent(9, SGPlayerCommon.Fns.RemoveBusyState),
		},

		onexit = function(inst)
			-- Don't ClearInteractFromMem onexit. Let the conversation handle
			-- clearing the interaction since it immediately starts walking us
			-- to a talk position.
			inst.sg.mem.interact_target = nil
		end,

	})
end

local function CanPickUp(player)
	local pickup = player.sg.mem.interact_target.components.singlepickup
	return not pickup or pickup:CanPickUp(player)
end

function SGPlayerCommon.States.AddPickupState(states)
	states[#states + 1] = State({
		name = "pickup",
		tags = { "busy", "interact" },

		default_data_for_tools = Interact_DefaultDataForTools,

		onenter = function(inst, item)
			dbassert(IsPlayerInteracting(item, inst))
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "pickup_item"))
			inst.sg.mem.interact_target = item

			if not CanPickUp(inst) then
				inst.sg:GoToState("idle")				
			end
		end,

		timeline =
		{
			FrameEvent(5, function(inst)
				local interactable = GetInteractable(inst.sg.mem.interact_target)
				if interactable then
					interactable:PerformInteract(inst)
				end
			end),

			--CANCELS
			FrameEvent(5, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(5, SGPlayerCommon.Fns.SetCanAttackOrAbility),
			FrameEvent(7, SGPlayerCommon.Fns.RemoveBusyState),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			if CanPickUp(inst) then
				ClearInteractFromMem(inst)
			else				
				local interactable = GetInteractable(inst.sg.mem.interact_target)
				if interactable then
					interactable:ClearInteract(inst, true, true)
				end
				inst.sg.mem.interact_target = nil
			end
		end,
	})
end
--------------------------------------------------------------------------
local DEPOSIT_CURRENCY_RATE =
{
	-- For how long we've been in the 'deposit_currency' state, how many ticks between 'proc'
	-- Start slow to allow precision, but when the player has held for a while speed up because we know they're trying to spend a lot.
	{ ticksinstate = 60, ticks_between_proc = 0, deposits_per_proc = 3 },
	{ ticksinstate = 50, ticks_between_proc = 0, deposits_per_proc = 2 },
	{ ticksinstate = 40, ticks_between_proc = 0, deposits_per_proc = 1 },
	{ ticksinstate = 20, ticks_between_proc = 1, deposits_per_proc = 1 },
	{ ticksinstate = 10, ticks_between_proc = 2, deposits_per_proc = 1 },
	{ ticksinstate = 0, ticks_between_proc = 3, deposits_per_proc = 1 },
}

function SGPlayerCommon.States.AddDepositCurrencyState(states)
	states[#states + 1] = State({
		name = "deposit_currency",
		tags = { "interact" },

		default_data_for_tools = Interact_DefaultDataForTools,

		onenter = function(inst, item)
			TheLog.ch.InteractSpam:printf("deposit_currency:onenter(%s) %s", inst, item)
			TheLog.ch.InteractSpam:indent()

			-- inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "pickup_item"), true)
			inst.sg.mem.interact_target = item

			-- Never hog the Interaction -- allow others to interact, too.
			local interactable = GetInteractable(inst.sg.mem.interact_target)
			interactable:ClearInteract(inst, true)

			local initial_rate = DEPOSIT_CURRENCY_RATE[#DEPOSIT_CURRENCY_RATE] -- Start slow. Speed up when holding for longer.
			inst.sg.statemem.ticks_left = initial_rate.ticks_between_proc
			inst.sg.statemem.deposits_per_proc = initial_rate.deposits_per_proc

			-- Until our first successful ExecuteRepeatedInteract, we are not depositing.
			inst.sg.statemem.is_depositing = false

			TheLog.ch.InteractSpam:unindent()
		end,

		onupdate = function(inst)
			if not inst.components.playercontroller:IsControlHeld("interact") then
				inst.sg:GoToState("deposit_currency_pst")
			end

			if inst.sg.statemem.ticks_left and inst.sg.statemem.ticks_left >= 0 then
				inst.sg.statemem.ticks_left = inst.sg.statemem.ticks_left - 1
				return
			end

			local is_depositing = false
			local interactable = GetInteractable(inst.sg.mem.interact_target)
			if interactable then
				-- Multiple players may be vying for interaction. If another is locked on the interactable, then skip this
				-- update.
				if interactable.lock then
					dbassert(interactable.lock ~= inst, "How do we already have a lock?")
					TheLog.ch.InteractSpam:printf(
						"Skipping deposit_currency:onupdate(%s) because Interactable(%s) is locked by another Player(%s)", 
						inst,
						interactable,
						interactable.lock
					)
					return
				end

				local can, reason = interactable:ExecuteRepeatedInteract(inst, inst.sg.statemem.deposits_per_proc)
				if can then
					-- TODO @chrisp #vend - hack to make vending machines properly register start and stop of valid interactions
					local vending_machine = inst.sg.mem.interact_target.components.vendingmachine
					if vending_machine then
						is_depositing, reason = vending_machine:CanDeposit(inst)
					else
						is_depositing = true
					end
				end
				if not is_depositing then
					TheLog.ch.InteractSpam:printf("Can't deposit because %s", reason)
					inst.sg:GoToState("deposit_currency_pst")
				end
			else
				TheLog.ch.InteractSpam:printf("Can't deposit because interactable was removed")
				inst.sg:GoToState("deposit_currency_pst")
			end

			-- On the first successful deposit, send an event saying we've started depositing.
			if is_depositing and not inst.sg.statemem.is_depositing then
				inst.sg.statemem.is_depositing = true
				inst.sg.mem.interact_target:PushEvent("depositing_currency_changed", {
					player = inst, 
					is_depositing = inst.sg.statemem.is_depositing
				})
			end

			-- Reset the timer.
			local ticksinstate = inst.sg:GetTicksInState()
			for _, rate_data in pairs(DEPOSIT_CURRENCY_RATE) do
				if ticksinstate >= rate_data.ticksinstate then
					inst.sg.statemem.ticks_left = rate_data.ticks_between_proc
					inst.sg.statemem.deposits_per_proc = rate_data.deposits_per_proc
					break
				end
			end
		end,

		onexit = function(inst)
			TheLog.ch.InteractSpam:printf("deposit_currency:onexit(%s)", inst)
			TheLog.ch.InteractSpam:indent()

			local interactable = GetInteractable(inst.sg.mem.interact_target)

			-- If we were successfully depositing, send an event indicating that we've stopped.
			if inst.sg.statemem.is_depositing then
				inst.sg.statemem.is_depositing = false
				inst.sg.mem.interact_target:PushEvent("depositing_currency_changed", {
					player = inst, 
					is_depositing = inst.sg.statemem.is_depositing
				})
			end

			local target_sg = inst.sg.mem.interact_target.sg
			if target_sg and target_sg.mem.is_interacting then
				target_sg.mem.is_interacting = false
				target_sg:PushEvent("is_interacting_changed")
			end
			interactable:ForceClearInteraction(inst)
			inst.sg.mem.interact_target = nil
			TheLog.ch.InteractSpam:unindent()
		end,

		events =
		{
			EventHandler("controlupevent", function(inst, data)
				if data.control ~= "interact" then
					return
				end
				inst.sg:GoToState("deposit_currency_pst")
			end),
		},
	})

	states[#states + 1] = State({
		name = "deposit_currency_pst",
		tags = { "interact" },

		default_data_for_tools = Interact_DefaultDataForTools,

		onenter = function(inst, item)
			inst.sg:GoToState("idle")
			-- inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "knockback_pst"), true)
		end,

		events =
		{
			EventHandler("animover", function(inst, data)
				inst.sg:GoToState("idle")
			end),
		},
	})
end
--------------------------------------------------------------------------
function SGPlayerCommon.States.AddHeartstoneInteractStates(states)
	states[#states + 1] = State({
		name = "townpillar_interact",
		tags = { "busy", "interact" },

		default_data_for_tools = Interact_DefaultDataForTools,

		onenter = function(inst, item)
			dbassert(IsPlayerInteracting(item, inst))

			if SGPlayerCommon.Fns.SheatheWeapon(inst, item) then
				inst.AnimState:PlayAnimation("konjur_accept")
				-- Must store in mem since interaction spans multiple states.
				inst.sg.mem.interact_target = item
			end

			TheDungeon.HUD:HidePrompt(item)
		end,

		timeline =
		{
			FrameEvent(14, function(inst)
				local interactable = GetInteractable(inst.sg.mem.interact_target)
				if interactable and interactable:IsPlayerInteracting(inst) then
					interactable:PerformInteract(inst)
				else
					assert(not interactable, "How did we get to this state without starting the interaction?")
					-- failure
					inst.sg:GoToState("powerup_abort")
				end
			end),
		},

		onupdate = function(inst)
			local is_interact_invalid
			if not inst.sg.mem.interact_target then
				TheLog.ch.Player:printf("Interact failsafe triggered: Target is non-existent.  Aborting...")
				is_interact_invalid = true
			elseif not inst.sg.mem.interact_target:IsValid() then
				TheLog.ch.Player:printf("Interact failsafe triggered: Target %s is invalid.  Aborting...", inst.sg.mem.interact_target)
				is_interact_invalid = true
			end

			-- This can become a dbassert when we ship playtest, but I want to ensure QA hit it.
			assert(not is_interact_invalid, "Interactable failed to resolve invalid interactable.")
			if is_interact_invalid then
				inst.sg:GoToState("powerup_abort")
			end
		end,

		events =
		{
			EventHandler("deposit_heart", function(inst)
				inst.sg:GoToState("deposit_heart")
			end),
		},

		onexit = ClearInteractFromMem,
	})

	states[#states + 1] = State({
		name = "deposit_heart",
		tags = { "busy", "interact" },

		default_data_for_tools = Interact_DefaultDataForTools,

		onenter = function(inst, item)
			inst.sg.statemem.animovers = 0
			inst.AnimState:PlayAnimation("upgrade_accept")
		end,

		timeline =
		{

		},

		events =
		{
			EventHandler("animover", function(inst)
				SGPlayerCommon.Fns.RemoveBusyState(inst)
				inst:PushEvent("deposit_heart_finished")
				inst.sg:GoToState("idle")
			end),
		},
	})
end

function SGPlayerCommon.States.AddPowerupInteractStates(states)
	states[#states + 1] = State({
		name = "powerup_interact",
		tags = { "busy", "interact" },

		default_data_for_tools = Interact_DefaultDataForTools,

		onenter = function(inst, item)
			dbassert(IsPlayerInteracting(item, inst))

			if SGPlayerCommon.Fns.SheatheWeapon(inst, item) then
				inst.AnimState:PlayAnimation("idle", true)
				-- Must store in mem since interaction spans multiple states.
				inst.sg.mem.interact_target = item
			end

			TheDungeon.HUD:HidePrompt(item)
		end,

		timeline =
		{
			FrameEvent(11, function(inst)
				local interactable = GetInteractable(inst.sg.mem.interact_target)
				if interactable and interactable:IsPlayerInteracting(inst) then
					interactable:PerformInteract(inst)
				else
					assert(not interactable, "How did we get to this state without starting the interaction?")
					-- failure
					inst.sg:GoToState("powerup_abort")
				end
			end),
		},

		onupdate = function(inst)
			local is_interact_invalid
			if not inst.sg.mem.interact_target then
				TheLog.ch.Player:printf("Interact failsafe triggered: Target is non-existent.  Aborting...")
				is_interact_invalid = true
			elseif not inst.sg.mem.interact_target:IsValid() then
				TheLog.ch.Player:printf("Interact failsafe triggered: Target %s is invalid.  Aborting...", inst.sg.mem.interact_target)
				is_interact_invalid = true
			end

			-- This can become a dbassert when we ship playtest, but I want to ensure QA hit it.
			assert(not is_interact_invalid, "Interactable failed to resolve invalid interactable.")
			if is_interact_invalid then
				inst.sg:GoToState("powerup_abort")
			end
		end,

		events =
		{
			EventHandler("roombonusscreen_accept", function(inst)
				inst.sg:GoToState("powerup_accept")
			end),
			EventHandler("powerup_upgrade", function(inst)
				inst.sg:GoToState("powerup_upgrade")
			end),
			EventHandler("roombonusscreen_skip", function(inst)
				inst.sg:GoToState("konjur_accept")
			end),
			EventHandler("roombonusscreen_closed", function(inst)
				inst.sg:GoToState("powerup_abort")
			end),
		},

		onexit = ClearInteractFromMem,
	})

	-- A version of this state preparing for online play.
	-- This state gets activated when a player receives the "roombonusscreen_open" state.
	-- All players, upon opening of the screen, will be placed into this state, and receive the appropriate event on close of the screen.
	states[#states + 1] = State({
		name = "roombonusscreen_active",
		tags = { "busy" },

		onenter = function(inst, item)
			if SGPlayerCommon.Fns.SheatheWeapon(inst, item) then
				inst.AnimState:PlayAnimation("idle", true)
			end

			inst.HitBox:SetInvincible(true)
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("roombonusscreen_accept", function(inst)
				inst.sg:GoToState("powerup_accept")
			end),
			EventHandler("powerup_upgrade", function(inst)
				inst.sg:GoToState("powerup_upgrade")
			end),
			EventHandler("roombonusscreen_skip", function(inst)
				inst.sg:GoToState("konjur_accept")
			end),
			EventHandler("roombonusscreen_closed", function(inst)
				inst.sg:GoToState("powerup_abort")
			end),
		},

		onexit = function(inst)
			ClearInteractFromMem(inst)
			inst.HitBox:SetInvincible(false)
		end
	})

	states[#states + 1] = State({
		name = "powerup_accept",
		tags = { "busy" },

		default_data_for_tools = Interact_DefaultDataForTools,

		onenter = function(inst, item)
			inst.sg.statemem.animovers = 0
			inst.AnimState:PlayAnimation("power_accept")
		end,

		timeline =
		{

		},

		events =
		{
			EventHandler("animover", function(inst)
				SGPlayerCommon.Fns.RemoveBusyState(inst)
				inst.sg:GoToState("unsheathe_fast")
			end),
		},
	})

	states[#states + 1] = State({
		name = "powerup_upgrade",
		tags = { "busy", "interact" },

		default_data_for_tools = Interact_DefaultDataForTools,

		onenter = function(inst, item)
			inst.sg.statemem.animovers = 0
			inst.AnimState:PlayAnimation("upgrade_accept")
		end,

		timeline =
		{

		},

		events =
		{
			EventHandler("animover", function(inst)
				SGPlayerCommon.Fns.RemoveBusyState(inst)
				inst.sg:GoToState("unsheathe_fast")
			end),
		},
	})

	states[#states + 1] = State({
		-- This state is used for canceling out of the roombonusscreen without making any selection, which should only happen with a roombonusscreen error.
		name = "powerup_abort",
		tags = { "busy" },

		default_data_for_tools = Interact_DefaultDataForTools,

		onenter = function(inst, item)
			SGPlayerCommon.Fns.SetWeaponSheathed(inst, false)
			inst.AnimState:PlayAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "unsheathe_fast"))
			SGPlayerCommon.Fns.RemoveBusyState(inst)

		end,

		timeline =
		{

		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	})

	states[#states + 1] = State({
		name = "konjur_accept",
		tags = { "busy" },

		default_data_for_tools = Interact_DefaultDataForTools,

		onenter = function(inst, item)
			inst.sg.statemem.animovers = 0
			inst.AnimState:PlayAnimation("konjur_accept")
		end,

		timeline =
		{

		},

		events =
		{
			EventHandler("animover", function(inst)
				SGPlayerCommon.Fns.RemoveBusyState(inst)
				inst.sg:GoToState("unsheathe_fast")
			end),
		},
	})

	states[#states + 1] = State({
		name = "idle_accept",
		tags = { "busy", "interact" },

		default_data_for_tools = Interact_DefaultDataForTools,

		onenter = function(inst, item)
			local animname = "idle"
			animname = SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, animname)
			inst.AnimState:PlayAnimation(animname, true)
		end,

		timeline =
		{

		},

		events =
		{
			EventHandler("animover", function(inst)
				SGPlayerCommon.Fns.RemoveBusyState(inst)
				inst.sg:GoToState("idle")
			end),
		},
	})
end

--------------------------------------------------------------------------

function SGPlayerCommon.States.AddReviveInteractStates(states)
	states[#states + 1] = State({
		name = "revive_interact",
		tags = { "interact", "busy" },

		default_data_for_tools = function(inst, cleanup)
			inst:DoTaskInTime(0, function(inst) inst.sg.statemem.is_in_tools = true end) -- TODO? Find a better way to get this to work in tools & not hard crash the game
		end,

		onenter = function(inst, target)
			dbassert(IsPlayerInteracting(target, inst), "How did we get to this state without starting the interaction?")
			inst.AnimState:PlayAnimation("revive_pre")
			inst.AnimState:PushAnimation("revive_loop", true)

			inst.sg.mem.interact_target = target

			if target then
				local interactable = GetInteractable(inst.sg.mem.interact_target)
				interactable:PerformInteract(inst)

				local rc = inst.components.revive
				rc:ReviverStartReviving(target)

				inst.sg.statemem.revive_time = rc:GetReviveTime()
				inst.sg:SetTimeout(inst.sg.statemem.revive_time)

				-- else: the IsPlayerInteracting assert above should have failed
			end

			-- Override for allowing dodge; usually dodge cannot be performed if a state has the 'interact' tag.
			inst.sg.statemem.allow_dodge = true

			SGPlayerCommon.Fns.SetCanDodge(inst)
			SGPlayerCommon.Fns.SetCanAttackOrAbility(inst)

			-- Unsheathe our weapon to play post-animations properly in case we're unsheathed (e.g. spawning in & starting in a sheathed state)
			SGPlayerCommon.Fns.SetWeaponSheathed(inst, false)
		end,

		onupdate = function(inst)
			local target = inst.sg.mem.interact_target
			if inst.sg.statemem.is_in_tools then return end

			if not target or not target:IsValid() then
				inst.sg:GoToState("revive_pst")
				return
			end

			-- Update the revive component with the current time in this state:
			local time_in_state = inst.sg:GetTimeInState()
			inst.components.revive:ReviverUpdateTimeRemaining(time_in_state)

			--sound presentation
			local revive_progress = (inst.components.revive.revive_time - inst.components.revive.current_revive_time) / inst.components.revive.revive_time
			soundutil.SetInstanceParameter(inst, "fx_heal_revive_LP", "progress", revive_progress)

			local is_local_player_involved = (inst:IsLocal() or target:IsLocal()) and 1 or 0
			soundutil.SetLocalInstanceParameter(inst, "fx_heal_revive_LP", "isLocalPlayerInvolved", is_local_player_involved)

			local num_players_alive = 0
			for k, player in pairs(AllPlayers) do
				if player:IsAlive() then
					num_players_alive = (num_players_alive + 1) or 1
				end
			end
			soundutil.SetInstanceParameter(inst, "fx_heal_revive_LP", "numPlayersAlive", num_players_alive)

			-- Cancel reviving
			-- ... if the revive target moves away from the reviver.
			-- ... if the target has a reviver that is not you (inst)
			-- ... if the revive target is no longer revivable (i.e. hit by a monster)
			if not inst.components.revive:ReviverIsInRange() or
				(target.components.revive:HasReviver() and not target.components.revive:IsReviver(inst)) then
				inst.sg:GoToState("revive_pst")
				return
			end

			if not target.components.revive:CanRevive() and not target.components.revive:IsBeingRevived() then
				inst.sg:GoToState("revive_pst")
				return
			end

			-- Also cancel if the reviver stops holding down the interact button.
			if not inst.components.playercontroller:IsControlHeld("interact") then
				inst.sg:GoToState("revive_pst")
				return
			end
		end,

		ontimeout = function(inst)
			inst.sg.statemem.finished_reviving = true
			inst.sg:GoToState("revive_success_pst")
		end,

		onexit = function(inst)
			if inst.sg.statemem.finished_reviving then
				inst.components.revive:ReviverFinishReviving()
			else
				inst.components.revive:ReviverCancelReviving()
			end

			ClearInteractFromMem(inst)
		end,
	})

	states[#states + 1] = State({
		name = "revive_success_pst",
		tags = {},

		onenter = function(inst, item)
			inst.AnimState:PlayAnimation("revive_success_pst")
			inst.AnimState:PushAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "unsheathe_fast"))
			--sound
			local is_local_player_involved = (inst:IsLocal() or inst.sg.mem.interact_target:IsLocal()) and 1 or 0
			local params = {}
			params.fmodevent = fmodtable.Event.revive
			params.sound_max_count = 1
			local revive_sound = soundutil.PlaySoundData(inst, params)
			soundutil.SetLocalInstanceParameter(inst, revive_sound, "isLocalPlayerInvolved", is_local_player_involved)
		end,

		events =
		{
			EventHandler("animqueueover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	})

	states[#states + 1] = State({
		name = "revive_pst",
		tags = {},

		onenter = function(inst, item)
			inst.AnimState:PlayAnimation("revive_pst")
			inst.AnimState:PushAnimation(SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, "unsheathe_fast"))
		end,

		events =
		{
			EventHandler("animqueueover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	})
end

--------------------------------------------------------------------------
function SGPlayerCommon.States.AddTestState(states)
	local anims =
	{
		"turnaround",
		"poses",
		"head_sheet",
		"head_rotations",
	}

	states[#states + 1] = State({
		name = "buildtest",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.sg.statemem.test = 1
			inst.AnimState:PlayAnimation(anims[inst.sg.statemem.test], true)
			inst.AnimState:SetScale(1.5, 1.5)
			inst.Physics:SetEnabled(false)
			inst.HitBox:SetEnabled(false)
		end,

		events =
		{
			EventHandler("controlevent", function(inst, data)
				if data.control == "lightattack" then
					inst.sg.statemem.test = (inst.sg.statemem.test % #anims) + 1
					inst.AnimState:PlayAnimation(anims[inst.sg.statemem.test], true)
				elseif data.control == "heavyattack" then
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.AnimState:SetScale(1, 1)
			inst.Physics:SetEnabled(true)
			inst.HitBox:SetEnabled(true)
		end,
	})

	states[#states + 1] = State({
		name = "wave",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("emote_wave")
		end,

		events =
		{
			EventHandler("animover", function(inst, data)
				inst.sg:GoToState("unsheathe_fast")
			end),
		},
	})

	states[#states + 1] = State({
		name = "cheer",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("emote_pump")
		end,

		events =
		{
			EventHandler("animover", function(inst, data)
				inst.sg:GoToState("unsheathe_fast")
			end),
		},
	})

end

--------------------------------------------------------------------------

function SGPlayerCommon.States.AddEmoteStates(states)

	local anims = {}
	for name, def in pairs(Cosmetics.PlayerEmotes) do
		table.insert(anims, def.anim)
	end

	for i,anim in ipairs(anims) do
		-- Create a state for every emote
		states[#states + 1] = State({
			name = anim,
			tags = { "emote", "busy" },

			onenter = function(inst)
				inst.AnimState:PlayAnimation(anim)
				inst.sg.statemem.prevent_chain_emote_cancel = true
			end,

			timeline =
			{
				FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
				FrameEvent(0, SGPlayerCommon.Fns.SetCanAttackOrAbility),
				FrameEvent(15, function(inst) inst.sg.statemem.prevent_chain_emote_cancel = false end),
			},

			events =
			{
				EventHandler("animover", function(inst, data)
					inst.sg:GoToState("emote_pst")
				end),
			},
		})
	end

	-- Create a universal post-emote unsheathe
	states[#states + 1] = State({
		name = "emote_pst",
		tags = { "emote", "idle", "busy" },

		onenter = function(inst, loops)
			SGPlayerCommon.Fns.SetWeaponSheathed(inst, false)
			local animname = "unsheathe_fast"
			animname = SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, animname)
			inst.AnimState:PlayAnimation(animname, true)
		end,

		timeline =
			{
				FrameEvent(0, SGPlayerCommon.Fns.SetCanDodge),
				FrameEvent(0, SGPlayerCommon.Fns.SetCanAttackOrAbility),
				FrameEvent(6, SGPlayerCommon.Fns.RemoveBusyState)
			},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	})
end

--------------------------------------------------------------------------

function SGPlayerCommon.States.AddFrozenStates(states)
	return SGCommon.States.AddFrozenStates(states)
end

--------------------------------------------------------------------------

function SGPlayerCommon.Events.AddAllBasicEvents(events)
	events[#events + 1] = SGCommon.Events.OnLocomote({ run = true, turn = true })
	events[#events + 1] = SGCommon.Events.OnAttacked()
	events[#events + 1] = SGCommon.Events.OnKnockdown()
	events[#events + 1] = SGCommon.Events.OnKnockback()
	events[#events + 1] = SGCommon.Events.OnSwallowed()
	events[#events + 1] = SGPlayerCommon.Events.OnDeafen()
	events[#events + 1] = SGPlayerCommon.Events.OnStartEating()
	events[#events + 1] = SGPlayerCommon.Events.OnDying()
	events[#events + 1] = SGPlayerCommon.Events.OnAvoidedDying()
	events[#events + 1] = SGPlayerCommon.Events.OnAvoidedDeath()
	events[#events + 1] = SGPlayerCommon.Events.OnRevivable()
	events[#events + 1] = SGPlayerCommon.Events.OnRevived()
	events[#events + 1] = SGPlayerCommon.Events.OnDeath()
	events[#events + 1] = SGPlayerCommon.Events.OnControl()
	events[#events + 1] = SGPlayerCommon.Events.OnInputDisabled()
	events[#events + 1] = SGPlayerCommon.Events.OnConversation()
	events[#events + 1] = SGPlayerCommon.Events.OnPreSwallowed()
	events[#events + 1] = SGPlayerCommon.Events.OnEnterTown()
	events[#events + 1] = SGPlayerCommon.Events.OnRoomBonusScreenOpened()
	SGPlayerCommon.Events.AddMouthEvents(events)
end

function SGPlayerCommon.States.AddAllBasicStates(states)
	SGPlayerCommon.States.AddIdleState(states)
	SGPlayerCommon.States.AddSheathedStates(states)
	SGPlayerCommon.States.AddRunStates(states)
	SGPlayerCommon.States.AddTurnStates(states)
	SGPlayerCommon.States.AddHitState(states)
	SGPlayerCommon.States.AddKnockbackState(states)
	SGPlayerCommon.States.AddKnockdownStates(states)
	SGPlayerCommon.States.AddDeafenStates(states)
	SGPlayerCommon.States.AddDeathStates(states)
	SGPlayerCommon.States.AddReviveStates(states)
	SGPlayerCommon.States.AddReviveInteractStates(states)
	SGPlayerCommon.States.AddPotionStates(states)
	SGPlayerCommon.States.AddFoodStates(states)
	SGPlayerCommon.States.AddTalkState(states)
	SGPlayerCommon.States.AddPickupState(states)
	SGPlayerCommon.States.AddDepositCurrencyState(states)
	SGPlayerCommon.States.AddHeartstoneInteractStates(states)
	SGPlayerCommon.States.AddPowerupInteractStates(states)
	SGPlayerCommon.States.AddDisabledInputState(states)
	SGPlayerCommon.States.AddPlayerSkillStates(states)
	SGPlayerCommon.States.AddSpectateStates(states)
	SGPlayerCommon.States.AddMonsterInteractionStates(states)
	SGPlayerCommon.States.AddEmoteStates(states)
	SGPlayerCommon.States.AddFrozenStates(states)
	if DEV_MODE then
		SGPlayerCommon.States.AddTestState(states)
	end
end

--------------------------------------------------------------------------
SGPlayerCommon.Fns.DoAction = DoControlAction

function SGPlayerCommon.Fns.TryQueuedAction(inst, ...)
	local data = inst.components.playercontroller:GetQueuedControl(...)
	if data ~= nil then
		-- verbose control detail
		-- if select("#", ...) > 0 then
		--	TheLog.ch.Player:printf("TryQueuedAction %s (tick lifetime=%d)", select(1, ...), data.ticks)
		--end
		return DoControlAction(inst, data)
	end
	return false
end

function SGPlayerCommon.Fns.TryQueuedActionExcluding(inst, ...)
	local data = inst.components.playercontroller:GetQueuedControlExcluding(...)
	if data ~= nil then
		return DoControlAction(inst, data)
	end
	return false
end

function SGPlayerCommon.Fns.TryNextQueuedAction(inst)
	local data = inst.components.playercontroller:GetNextQueuedControl()
	--print("TryNextQueuedAction:")
	--dumptable(inst.components.playercontroller.controlqueue)
	if data ~= nil then
		-- verbose control detail
		-- TheLog.ch.Player:printf("TryNextQueuedAction %s (ticks lifetime=%d)", data.control, data.ticks)
		return DoControlAction(inst, data)
	end
	return false
end

--old:
-- reverse = >120
-- forward = <90
local reverse = 100
local up = 80
function SGPlayerCommon.Fns.IsForwardControl(inst, data)
	local angle
	local facingrot = inst.Transform:GetFacingRotation()
	if data ~= nil and data.dir ~= nil then
		angle = DiffAngle(data.dir, facingrot)
	end
	--print("FORWARD CONTROL")
	-- print("		"..angle.." < "..up, angle < up)
	return angle ~= nil and angle < up
		or DiffAngle(inst.Transform:GetRotation(), facingrot) < 60
end

function SGPlayerCommon.Fns.IsReverseControl(inst, data)
	if data == nil or data.dir == nil then
		return false
	end
	local facingrot = inst.Transform:GetFacingRotation()
	local angle = DiffAngle(data.dir, facingrot)
	-- print("--------------")
	-- print("DIRECTION:			", data.dir)
	-- print("DIFFERENCE:			", DiffAngle(data.dir, facingrot))
	-- print("--------------")
	-- print("reverse:", reverse)
	-- print("up:", up)
	-- print("--------------")
	-- print("REVERSE CONTROL")
	-- print("		"..angle.." > "..reverse, DiffAngle(data.dir, facingrot) > reverse)
	return angle > reverse
end

function SGPlayerCommon.Fns.IsUpwardControl(inst, data)
	-- print("UPWARD CONTROL")
	if data == nil or data.dir == nil then
		return false
	end
	local facingrot = inst.Transform:GetFacingRotation()
	local angle = DiffAngle(data.dir, facingrot)
	-- print("		"..angle.." < "..reverse, DiffAngle(data.dir, facingrot) < reverse)
	-- print("		"..angle.." > "..up, DiffAngle(data.dir, facingrot) > up)
	return angle < reverse
		and angle > up

end

function SGPlayerCommon.Fns.GetWeaponType(inst)
	-- Assume they're handling receiving no type on the other end
	return inst.components.inventory:GetEquippedWeaponType()
end
function SGPlayerCommon.Fns.ApplyWeaponPrefix(inst, name)
	local anim = name

	if not SGPlayerCommon.Fns.IsWeaponSheathed(inst) then
		local equipped_weapon_type = inst.components.inventory:GetEquippedWeaponType()
		if equipped_weapon_type ~= nil then
			anim = equipped_weapon_type.."_"..name
		end
	end

	return anim
end

-- Returns the prefix for a weapon the player might not have equipped
function SGPlayerCommon.Fns.GetWeaponPrefix(weapon, name)
	local anim = name
	if weapon ~= nil then
		local weapon_def = weapon:GetDef()
		anim = weapon_def.weapon_type.."_"..name
	end
	return anim
end

function SGPlayerCommon.Fns.ApplyFatiguePrefix(inst, name)
	local anim = name
	local should_fatigue = inst.components.health ~= nil and inst.components.health:IsLow()
	if should_fatigue then
		anim = "fatigue_"..anim
	end
	return anim
end

local ENABLE_BACK_LOOKING = true
function SGPlayerCommon.Fns.ApplyBackPrefixOnUpdate(inst, animname)

	local using_keyboard = inst.components.playercontroller:GetLastInputDeviceType() == "keyboard"

	if not ENABLE_BACK_LOOKING or SGPlayerCommon.Fns.IsWeaponSheathed(inst) or not using_keyboard then
		return animname
	end

	if inst.sg.statemem.transition_updn_frames then
		-- If transition_updn_frames exists, then it means we are transitioning from up/down. Don't apply a 'back' -- allow the transition to finish, first.
		return animname
	end

	if inst.sg.mem.last_run_backfwd_state == nil then
		-- Initialize if it doesn't exist already
		inst.sg.mem.last_run_backfwd_state = "fwd"
	end

	local oldstate = inst.sg.mem.last_run_backfwd_state

	local left = inst.Transform:GetFacing() == FACING_LEFT
	local dir = inst.components.playercontroller:GetMouseActionDirection()

	if left and math.abs(dir) <= 90 or -- Looking left, mouse is on right.
		not left and math.abs(dir) >= 90 then -- Looking right, mouse is on left.
		inst.sg.mem.last_run_backfwd_state = "back"
	else
		inst.sg.mem.last_run_backfwd_state = "fwd"
	end

	if inst.sg.mem.last_run_updn_state == "up" then
		-- Up running doesn't have transitions between back and fwd -- just snaps to fwd immediately.
		if not inst.sg.statemem.transition_updn_frames then
			if inst.sg.mem.last_run_backfwd_state == "back" then
				--running back
				animname = animname.."_back"
			end
		end
	else
		-- Down running DOES have transitions between back and fwd -- transition, here.
		if oldstate ~= inst.sg.mem.last_run_backfwd_state then
			-- Flipped from back<->fwd this frame. Start a transition.
			inst.sg.statemem.transition_backfwd_frames = 3 -- (actually held for 1 more frame than listed)
			animname = animname.."_down"
		elseif inst.sg.statemem.transition_backfwd_frames ~= nil and inst.sg.statemem.transition_backfwd_frames > 0 then
			-- in the middle of transitioning between back<->fwd, continue transitioning
			animname = animname.."_down"
			inst.sg.statemem.transition_backfwd_frames = inst.sg.statemem.transition_backfwd_frames - 1
		elseif inst.sg.mem.last_run_backfwd_state == "back" then
			--running back
			animname = animname.."_back"
			inst.sg.statemem.transition_backfwd_frames = nil
		end --otherwise just play neutral run
	end

	return animname
end

function SGPlayerCommon.Fns.ApplyUpPrefixOnUpdate(inst, name)
	if inst.sg.mem.last_run_updn_state == nil then
		inst.sg.mem.last_run_updn_state = "down"
	end

	if inst.sg.mem.last_run_backfwd_state == "back" and inst.sg.mem.last_run_updn_state == "down" then
		return name
	end

	local anim = name
	local oldstate = inst.sg.mem.last_run_updn_state

	local rotation = inst.Transform:GetRotation()
	if (rotation <= -30 and rotation >= -150) then
		inst.sg.mem.last_run_updn_state = "up"
	else
		inst.sg.mem.last_run_updn_state = "down"
	end

	if oldstate ~= inst.sg.mem.last_run_updn_state then -- Flipped from up<->dn this frame
		inst.sg.statemem.transition_updn_frames = 1 -- actually held for 2 frames
		anim = anim.."_side"
	elseif inst.sg.statemem.transition_updn_frames ~= nil and inst.sg.statemem.transition_updn_frames > 0 then -- in the middle of transitioning between up<->dn
		anim = anim.."_side"
		inst.sg.statemem.transition_updn_frames = inst.sg.statemem.transition_updn_frames - 1
	elseif inst.sg.mem.last_run_updn_state == "up" then --running up
		anim = anim.."_up"
		inst.sg.statemem.transition_updn_frames = nil
	end --otherwise just play neutral run
	return anim
end

function SGPlayerCommon.Fns.ApplyUpPrefixSimple(inst, name, invertrotationforanim)
	local anim = name

	local rotation = inst.Transform:GetRotation()
	if invertrotationforanim then
		rotation = rotation - 180
	end

	if (rotation <= -30 and rotation >= -150) then
		anim = anim.."_up"
	end

	return anim
end

--------------------------------------------------------------------------

function SGPlayerCommon.Fns.AttachSwipeFx(inst, prefab, background, stopOnInterruptState)
	background = background or false
	stopOnInterruptState = stopOnInterruptState or false
	local fx_type = inst.components.inventoryhoard:GetEquippedItem(Equipment.Slots.WEAPON):GetFXType()
	local fx_name = prefab .. "_" .. fx_type
	-- TheLog.ch.NetworkEventManager:printf("SGPlayerCommon.Fns.AttachSwipeFx parent ent=%d fx_name=%s", inst.GUID, fx_name)

	local fx_guid = TheNetEvent:FXAttach(inst.GUID, fx_name, background, NetFXSlot.id.DEFAULT, stopOnInterruptState)
	return Ents[fx_guid]
end

function SGPlayerCommon.Fns.HandleAttachSwipeFx(inst, fx_name, background, stopOnInterruptState)
	local fx = SGCommon.Fns.SpawnFXChildAtDist(inst, fx_name, 0)
	if fx then
		-- TheLog.ch.NetworkEventManager:printf("SGPlayerCommon.Fns.AttachSwipeFx parent GUID=%d fx_name=%s", inst.GUID, fx_name)

		inst.components.hitstopper:AttachChild(fx)
		if background then
			if inst.sg.statemem.bgswipefx then
				-- TheLog.ch.StateGraph:printf("Trying to attach a Background SwipeFx when one is already attached")
				SGPlayerCommon.Fns.HandleDetachSwipeFx(inst, background, true)
				dbassert(inst.sg.statemem.bgswipefx == nil)
			end
			inst.sg.statemem.bgswipefx = fx
		else
			if inst.sg.statemem.swipefx then
				-- TheLog.ch.StateGraph:printf("Trying to attach a SwipeFx when one is already attached")
				SGPlayerCommon.Fns.HandleDetachSwipeFx(inst, background, true)
				dbassert(inst.sg.statemem.swipefx == nil)
			end
			inst.sg.statemem.swipefx = fx
		end
		if stopOnInterruptState then
			EffectEvents.StopFxOnStateExit(inst, fx)
		end
		return fx
	else
		TheLog.ch.StateGraph:printf("fx can't be spawned: " .. fx_name)
	end
end

function SGPlayerCommon.Fns.DetachSwipeFx(inst, background, removeOnDetach)
	background = background or false
	removeOnDetach = removeOnDetach or false

	local fx
	if background then
		fx = inst.sg.statemem.bgswipefx
	else
		fx = inst.sg.statemem.swipefx
	end

	if fx ~= nil and fx:IsValid() then
		-- TheLog.ch.NetworkEventManager:printf("SGPlayerCommon.Fns.DetachSwipeFx parent ent=%d background=%s", inst.GUID, tostring(background))
		TheNetEvent:FXDetach(inst.GUID, background, NetFXSlot.id.DEFAULT, removeOnDetach)
	end
end

function SGPlayerCommon.Fns.HandleDetachSwipeFx(inst, background, removeOnDetach)
	local fx
	if background then
		fx = inst.sg.statemem.bgswipefx
		inst.sg.statemem.bgswipefx = nil
	else
		fx = inst.sg.statemem.swipefx
		inst.sg.statemem.swipefx = nil
	end

	if fx ~= nil and fx:IsValid() then
		inst.components.hitstopper:DetachChild(fx)
		SGCommon.Fns.DetachChild(fx)
		if removeOnDetach then
			-- TheLog.ch.NetworkEventManager:printf("Remove on detach! guid=%d name=%s", fx.GUID, fx.name)
			fx:Remove()
		end
	end
end

function SGPlayerCommon.Fns.AttachPowerSwipeFx(inst, prefab, background, stopOnInterruptState)
	background = background or false
	stopOnInterruptState = stopOnInterruptState or false
	assert(inst.sg.mem.attack_type, "inst.sg.mem.attack_type is not set. Please set it onenter of every attack state. Prefab=" .. inst.prefab)
	local power_fx_type = inst.components.powermanager:GetPowerAttackFX(inst.sg.mem.attack_type)
	if power_fx_type == nil then
		return nil
	end

	local fx_name = prefab .. "_" .. power_fx_type
	if not PrefabExists(fx_name) then
		TheLog.ch.Player:print("[AttachPowerSwipeFx] Tried to spawn prefab which doesn't exist: ", fx_name)
		return nil
	end

	local fx_guid = TheNetEvent:FXAttach(inst.GUID, fx_name, background, NetFXSlot.id.POWER, stopOnInterruptState)
	return Ents[fx_guid]
end

function SGPlayerCommon.Fns.HandleAttachPowerSwipeFx(inst, fx_name, background, stopOnInterruptState)
	local fx = SGCommon.Fns.SpawnFXChildAtDist(inst, fx_name, 0)
	if fx then
		-- TheLog.ch.NetworkEventManager:printf("SGPlayerCommon.Fns.AttachPowerSwipeFx ent=%d fx_name=%s", fx.GUID, fx.prefab)
		inst.components.hitstopper:AttachChild(fx)
		if background then
			if inst.sg.statemem.powerswipebgfx then
				SGPlayerCommon.Fns.HandleDetachPowerSwipeFx(inst, background, true)
				dbassert(inst.sg.statemem.powerswipebgfx == nil)
			end
			inst.sg.statemem.powerswipebgfx = fx
		else
			if inst.sg.statemem.powerswipefx then
				SGPlayerCommon.Fns.HandleDetachPowerSwipeFx(inst, background, true)
				dbassert(inst.sg.statemem.powerswipefx == nil)
			end
			inst.sg.statemem.powerswipefx = fx
		end

		if stopOnInterruptState then
			EffectEvents.StopFxOnStateExit(inst, fx)
		end
		return fx
	end
end

function SGPlayerCommon.Fns.DetachPowerSwipeFx(inst, background, removeOnDetach)
	background = background or false
	removeOnDetach = removeOnDetach or false

	local fx
	if background then
		fx = inst.sg.statemem.powerswipebgfx
	else
		fx = inst.sg.statemem.powerswipefx
	end

	if fx ~= nil and fx:IsValid() then
		TheNetEvent:FXDetach(inst.GUID, background, NetFXSlot.id.POWER, removeOnDetach)
	end
end

function SGPlayerCommon.Fns.HandleDetachPowerSwipeFx(inst, background, removeOnDetach)
	local fx
	if background then
		fx = inst.sg.statemem.powerswipebgfx
		inst.sg.statemem.powerswipebgfx = nil
	else
		fx = inst.sg.statemem.powerswipefx
		inst.sg.statemem.powerswipefx = nil
	end

	if fx ~= nil and fx:IsValid() then
		-- TheLog.ch.NetworkEventManager:printf("SGPlayerCommon.Fns.DetachPowerSwipeFx ent=%d fx_name=%s", fx.GUID, fx.prefab)
		inst.components.hitstopper:DetachChild(fx)
		SGCommon.Fns.DetachChild(fx)
		if removeOnDetach then
			fx:Remove()
		end
	end
end

function SGPlayerCommon.Fns.AttachPowerFxToProjectile(inst, prefab, owner, attack_type)
	local power_fx_type = owner.components.powermanager:GetPowerAttackFX(attack_type)
	if power_fx_type == nil then
		return nil
	end

	local fx_name = prefab .. "_" .. power_fx_type
	if not PrefabExists(fx_name) then
		TheLog.ch.Player:print("[AttachPowerSwipeFx] Tried to spawn prefab which doesn't exist: ", fx_name)
		return nil
	end

	local fx_guid = TheNetEvent:FXAttach(inst.GUID, fx_name, false, NetFXSlot.id.PROJECTILE, false)
	return Ents[fx_guid]
end

function SGPlayerCommon.Fns.HandleAttachPowerFxToProjectile(inst, fx_name)
	local fx = SGCommon.Fns.SpawnFXChildAtDist(inst, fx_name, 0)
	if fx then
		fx.entity:SetParent(inst.entity)
		fx.entity:AddFollower()

		local dir = inst.Transform:GetFacingRotation()
		fx.Transform:SetRotation(dir)

		-- TheLog.ch.NetworkEventManager:printf("SGPlayerCommon.Fns.AttachPowerSwipeFx ent=%d fx_name=%s", fx.GUID, fx.prefab)
		if inst.components.hitstopper ~= nil then
			inst.components.hitstopper:AttachChild(fx)
		end
		return fx
	end
end

function SGPlayerCommon.Fns.AttachExtraSwipeFx(inst, prefab)
	local fx_guid = TheNetEvent:FXAttach(inst.GUID, prefab, false, NetFXSlot.id.EXTRA, false)
	return Ents[fx_guid]
end

function SGPlayerCommon.Fns.HandleAttachExtraSwipeFx(inst, prefab)
	local fx_name = prefab
	local fx = SGCommon.Fns.SpawnFXChildAtDist(inst, fx_name, 0)
	-- TheLog.ch.NetworkEventManager:printf("SGPlayerCommon.Fns.AttachExtraSwipeFx ent=%d fx_name=%s", fx.GUID, fx.prefab)
	inst.components.hitstopper:AttachChild(fx)
	if inst.sg.statemem.extraswipefx then
		TheLog.ch.StateGraph:printf("Trying to attach ExtraSwipeFX when one is already attached")
		SGPlayerCommon.Fns.HandleDetachExtraSwipeFx(inst, true)
		dbassert(inst.sg.statemem.extraswipefx == nil)
	end
	inst.sg.statemem.extraswipefx = fx
	return fx
end

function SGPlayerCommon.Fns.DetachExtraSwipeFx(inst, removeOnDetach)
	removeOnDetach = removeOnDetach or false

	local fx = inst.sg.statemem.extraswipefx
	if fx ~= nil and fx:IsValid() then
		TheNetEvent:FXDetach(inst.GUID, false, NetFXSlot.id.EXTRA, removeOnDetach)
	end
end

function SGPlayerCommon.Fns.HandleDetachExtraSwipeFx(inst, removeOnDetach)
	local fx = inst.sg.statemem.extraswipefx
	inst.sg.statemem.extraswipefx = nil
	if fx ~= nil and fx:IsValid() then
		-- TheLog.ch.NetworkEventManager:printf("SGPlayerCommon.Fns.DetachExtraSwipeFx ent=%d fx_name=%s", fx.GUID, fx.prefab)
		inst.components.hitstopper:DetachChild(fx)
		SGCommon.Fns.DetachChild(fx)
		if removeOnDetach then
			fx:Remove()
		end
	end
end

function SGPlayerCommon.Fns.DoQuickRise(inst)
	SGCommon.Fns.SpawnAtDist(inst, "fx_player_quickrise", 0)
	SGCommon.Fns.FlickerColor(inst, TUNING.FLICKERS.PLAYER_QUICK_RISE.COLOR, TUNING.FLICKERS.PLAYER_QUICK_RISE.FLICKERS, TUNING.FLICKERS.PLAYER_QUICK_RISE.FADE, TUNING.FLICKERS.PLAYER_QUICK_RISE.TWEENS)
	inst.sg.statemem.candodgespecial = nil
	if inst.components.hitstopper ~= nil then
		inst.components.hitstopper:PushHitStop(TUNING.HITSTOP_PLAYER_QUICK_RISE_FRAMES)
	end
end

function SGPlayerCommon.Fns.CelebrateEquipment(inst, state_transition_delay)
	inst:DoTaskInAnimFrames(12, function()
		if inst ~= nil and inst:IsValid() then
			EffectEvents.MakeEventSpawnEffect(inst, { fxname = "fx_outfit_buy", ischild = true })
		end
	end)

	local emotes = { "emote_shoulder_look", "emote_pump", "emote_excited" }
	local random_idx = math.random(1, #emotes)
	if state_transition_delay then
		inst:DoTaskInAnimFrames(state_transition_delay, function() inst.sg:GoToState(emotes[random_idx]) end)
	else
		inst.sg:GoToState(emotes[random_idx])
	end
end
--------------------------------------------------------------------------

strict.strictify(SGPlayerCommon.Events, "SGPlayerCommon.Events")
strict.strictify(SGPlayerCommon.Fns,    "SGPlayerCommon.Fns")
strict.strictify(SGPlayerCommon.States, "SGPlayerCommon.States")

return SGPlayerCommon
