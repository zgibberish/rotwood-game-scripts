local Equipment = require "defs.equipment"
local emotion = require "defs.emotion"
local SGPlayerCommon = require "stategraphs.sg_player_common"

local COOKING_SONG_LENGTH_ANIM_FRAMES = 240
local events = {}

local buf = 5
local beat1 = 74
local beat2 = 89
local beat3 = 104
local beat4 = 119
local beat5 = 134
local beat6 = 149
local beat7 = 164
local beat8 = 179
local beat9 = 194

local beat_leadup = -60 -- how many ticks before the beat should we spawn the button?
						-- 60 ticks = 4 beats (15t per beat)

local RATING_EXCELLENT = 1
local RATING_GOOD = .8
local RATING_NORMAL = .5

local function SpawnButton(inst, button)
	inst.sg.mem.cookingtrack:SpawnButton(button)
end

local function PreBeat(inst, beat)
	inst.sg.mem.pressallowed = true
	inst.sg.mem.correctbutton = inst.sg.mem.sequence[beat].button
end

local function OnBeat(inst, beat)
	inst.sg.mem.currentbeat = beat
	inst.sg.mem.failnextpress = false
end

local function PostBeat(inst)
	if inst.sg.mem.presssucceeded then
		inst.sg.mem.score = inst.sg.mem.score + 1
	end
	inst.sg.mem.pressallowed = false
	inst.sg.mem.pressedbutton = false
	inst.sg.mem.presssucceeded = false

	inst.sg.mem.correctbutton = nil
end

local function LastBeatWrapup(inst)
	local percentage = inst.sg.mem.score / inst.sg.mem.maxscore
	local rating_parameter
	if percentage >= RATING_EXCELLENT then
		rating_parameter = 4
	elseif percentage >= RATING_GOOD then
		rating_parameter = 3
	elseif percentage >= RATING_NORMAL then
		rating_parameter = 2
	else
		rating_parameter = 1
	end

	TheAudio:SetPersistentSoundParameter("cooking_music", "Cooking_Rating", rating_parameter)
	end

local states =
{
	State({
		name = "default_light_attack",
		onenter = function(inst) inst.sg:GoToState("light_attack1_pre") end,
	}),

	State({
		name = "default_heavy_attack",
		onenter = function(inst) inst.sg:GoToState("heavy_attack_pre") end,
	}),

	State({
		name = "default_dodge",
		onenter = function(inst) inst.sg:GoToState("roll", TUNING.PLAYER.ROLL.NORMAL.IFRAMES) end,
	}),

	State({
		name = "idle",
		onenter = function(inst)
			inst.AnimState:PlayAnimation("idle", true)
		end,
	}),

	State({
		name = "cooking",
		onenter = function(inst, data)
			inst.Physics:Stop()
			inst.sg.mem.oldstategraphname = data.oldstategraphname
			inst.sg.mem.sequence = data.sequence_data.button_sequence
			inst.sg.mem.cooker = data._cooker
			inst.sg.mem.cookingtrack = TheDungeon.HUD:StartCookingTrack( { target = inst })

			inst.sg.mem.maxscore = data.sequence_data.max_score
			inst.sg.mem.score = 0
			inst.sg:SetTimeoutAnimFrames(COOKING_SONG_LENGTH_ANIM_FRAMES)
		end,

		timeline =
		{
			-- FrameEvent(12, function(inst)  TheDungeon.HUD:MakeCookingButton({ target = inst, button = "1!" }) end),
			-- FrameEvent(29, function(inst)  TheDungeon.HUD:MakeCookingButton({ target = inst, button = "2!" }) end),
			-- FrameEvent(44, function(inst)  TheDungeon.HUD:MakeCookingButton({ target = inst, button = "3!" }) end),
			-- FrameEvent(59, function(inst)  TheDungeon.HUD:MakeCookingButton({ target = inst, button = "4!" }) end),

			FrameEvent(beat1 + beat_leadup, function(inst) SpawnButton(inst, inst.sg.mem.sequence[1].button) end),      --TheDungeon.HUD:MakeCookingButton({ target = inst, button = inst.sg.mem.sequence[1].button }) end),
			FrameEvent(beat2 + beat_leadup, function(inst) SpawnButton(inst, inst.sg.mem.sequence[2].button) end),      --TheDungeon.HUD:MakeCookingButton({ target = inst, button = inst.sg.mem.sequence[1].button }) end),
			FrameEvent(beat3 + beat_leadup, function(inst) SpawnButton(inst, inst.sg.mem.sequence[3].button) end),      --TheDungeon.HUD:MakeCookingButton({ target = inst, button = inst.sg.mem.sequence[1].button }) end),
			FrameEvent(beat4 + beat_leadup, function(inst) SpawnButton(inst, inst.sg.mem.sequence[4].button) end),      --TheDungeon.HUD:MakeCookingButton({ target = inst, button = inst.sg.mem.sequence[1].button }) end),
			FrameEvent(beat5 + beat_leadup, function(inst) SpawnButton(inst, inst.sg.mem.sequence[5].button) end),      --TheDungeon.HUD:MakeCookingButton({ target = inst, button = inst.sg.mem.sequence[1].button }) end),
			FrameEvent(beat6 + beat_leadup, function(inst) SpawnButton(inst, inst.sg.mem.sequence[6].button) end),      --TheDungeon.HUD:MakeCookingButton({ target = inst, button = inst.sg.mem.sequence[1].button }) end),
			FrameEvent(beat7 + beat_leadup, function(inst) SpawnButton(inst, inst.sg.mem.sequence[7].button) end),      --TheDungeon.HUD:MakeCookingButton({ target = inst, button = inst.sg.mem.sequence[1].button }) end),
			FrameEvent(beat8 + beat_leadup, function(inst) SpawnButton(inst, inst.sg.mem.sequence[8].button) end),      --TheDungeon.HUD:MakeCookingButton({ target = inst, button = inst.sg.mem.sequence[1].button }) end),
			FrameEvent(beat9 + beat_leadup, function(inst) SpawnButton(inst, inst.sg.mem.sequence[9].button) end),      --TheDungeon.HUD:MakeCookingButton({ target = inst, button = inst.sg.mem.sequence[1].button }) end),


			FrameEvent(beat1-buf, function(inst)  		PreBeat(inst, 1) end),
			FrameEvent(beat1, function(inst)  			OnBeat(inst, 1) end),      --TheDungeon.HUD:MakeCookingButton({ target = inst, button = inst.sg.mem.sequence[1].button }) end),
			FrameEvent(beat1+buf, 	function(inst)  	PostBeat(inst) end),

			FrameEvent(beat2-buf, 	function(inst)  	PreBeat(inst, 2) end),
			FrameEvent(beat2, 		function(inst)  	OnBeat(inst, 2) end),      --TheDungeon.HUD:MakeCookingButton({ target = inst, button = inst.sg.mem.sequence[2].button }) end),
			FrameEvent(beat2+buf, 	function(inst)  	PostBeat(inst) end),

			FrameEvent(beat3-buf, function(inst) 		PreBeat(inst, 3) end),
			FrameEvent(beat3, function(inst) 			OnBeat(inst, 3) end),      --TheDungeon.HUD:MakeCookingButton({ target = inst, button = inst.sg.mem.sequence[3].button }) end),
			FrameEvent(beat3+buf, 	function(inst)  	PostBeat(inst) end),

			FrameEvent(beat4-buf, function(inst) 		PreBeat(inst, 4) end),
			FrameEvent(beat4, function(inst) 			OnBeat(inst, 4) end),      --TheDungeon.HUD:MakeCookingButton({ target = inst, button = inst.sg.mem.sequence[4].button }) end),
			FrameEvent(beat4+buf, 	function(inst)  	PostBeat(inst) end),

			FrameEvent(beat5-buf, function(inst) 		PreBeat(inst, 5) end),
			FrameEvent(beat5, function(inst) 			OnBeat(inst, 5) end),      --TheDungeon.HUD:MakeCookingButton({ target = inst, button = inst.sg.mem.sequence[5].button }) end),
			FrameEvent(beat5+buf, 	function(inst)  	PostBeat(inst) end),

			FrameEvent(beat6-buf, function(inst) 		PreBeat(inst, 6) end),
			FrameEvent(beat6, function(inst) 			OnBeat(inst, 6) end),      --TheDungeon.HUD:MakeCookingButton({ target = inst, button = inst.sg.mem.sequence[6].button }) end),
			FrameEvent(beat6+buf, 	function(inst)  	PostBeat(inst) end),

			FrameEvent(beat7-buf, function(inst) 		PreBeat(inst, 7) end),
			FrameEvent(beat7, function(inst) 			OnBeat(inst, 7) end),      --TheDungeon.HUD:MakeCookingButton({ target = inst, button = inst.sg.mem.sequence[7].button }) end),
			FrameEvent(beat7+buf, 	function(inst)  	PostBeat(inst) end),

			FrameEvent(beat8-buf, function(inst) 		PreBeat(inst, 8) end),
			FrameEvent(beat8, function(inst) 			OnBeat(inst, 8) end),      --TheDungeon.HUD:MakeCookingButton({ target = inst, button = inst.sg.mem.sequence[8].button }) end),
			FrameEvent(beat8+buf, 	function(inst)  	PostBeat(inst) end),

			FrameEvent(beat9-buf, 	function(inst) 		PreBeat(inst, 9) end),
			FrameEvent(beat9, 		function(inst) 		OnBeat(inst, 9) end),      --TheDungeon.HUD:MakeCookingButton({ target = inst, button = inst.sg.mem.sequence[9].button }) end),
			FrameEvent(beat9+buf+2, 	function(inst)  PostBeat(inst)
														LastBeatWrapup(inst) end),
		},
		events =
		{
			EventHandler("oncontrol_music", function(inst, data)
				local succeeded

				print("--")
				print(inst.sg:GetTicksInState())
				if not inst.sg.mem.pressallowed then
					succeeded = false
					inst.sg.mem.failnextpress = true
					print("Pressed off beat")
				elseif inst.sg.mem.pressedbutton then
					succeeded = false
					inst.sg.mem.failnextpress = true
					print("Double-pressed")
				elseif inst.sg.mem.failnextpress then
					succeeded = false
					inst.sg.mem.failnextpress = false
				else
					inst.sg.mem.pressedbutton = true
					succeeded = inst.sg.mem.correctbutton == data.control
					if not succeeded then
						inst.sg.mem.failnextpress = true
						print("Wrong button!")
						print("Pressed:", data.control.key)
						print("Requested:", inst.sg.mem.correctbutton.key)
					end
				end

				if succeeded then
					print("Succeed!")
					inst.sg.mem.presssucceeded = true
					inst.AnimState:PlayAnimation("pickup_item_ctr")
					inst.AnimState:PushAnimation("idle", true)
					TheDungeon.HUD:MakeCookingButton({ target = inst, button = "<p img='images/ui_ftf_options/checkbox_checked.tex'>"})--"YES!", y_offset = 2000 })
				else
					print("Fail!")
					inst.sg.mem.presssucceeded = false
					inst.AnimState:PlayAnimation("knockback")
					inst.AnimState:PushAnimation("idle", true)
					TheDungeon.HUD:MakeCookingButton({ target = inst, button = "<p img='images/ui_ftf_options/checkbox_unchecked.tex'>"})--"NO!!!", y_offset = 2000 })
					inst.sg.mem.cooker.inst:PushEvent("emote", emotion.emote.dubious)
				end
				print("--")
			end),
		},
		ontimeout = function(inst)
			local score = string.format("%s / %s!", inst.sg.mem.score, inst.sg.mem.maxscore)
			TheDungeon.HUD:MakeCookingButton({ target = inst, button = score })
			TheDungeon.HUD:StopCookingTrack(inst.sg.mem.cookingtrack)

			if inst.sg.mem.score == inst.sg.mem.maxscore then
				TheLog.ch.Player:print("Perfect cook score. refill potion.")
				inst.components.potiondrinker:RefillPotion()
			end

			inst:PushEvent("minigame_complete", {
					score = inst.sg.mem.score,
					maxscore = inst.sg.mem.maxscore,
				})

			-- Reset the player's stategraph + fx type
			inst:SetStateGraph(inst.sg.mem.oldstategraphname)
			local equipped_weapon = inst.components.inventoryhoard:GetEquippedItem(Equipment.Slots.WEAPON)
			inst.sg.mem.fx_type = equipped_weapon:GetFXType()
		end,
		onupdate = function(inst)
			-- temporarily "lock out" other players from input
			for i,v in ipairs(AllPlayers) do
				if v ~= inst then
					v:PushEvent("deafen", inst)
				end
			end
		end,
	}),

}

SGPlayerCommon.States.AddAllBasicStates(states)

return StateGraph("sg_player_cooking", states, events, "idle")
