local CineAutogenData = require "prefabs.cine_autogen_data"
local DebugDraw = require "util.debugdraw"
local EffectEvents = require "effectevents"
local Enum = require "util.enum"
local ParticleSystemHelper = require "util.particlesystemhelper"
local SGCommon = require "stategraphs.sg_common"
local SGPlayerCommon = require "stategraphs.sg_player_common"
local audioid = require "defs.sound.audioid"
local camerautil = require "util.camerautil"
local fmodtable = require "defs.sound.fmodtable"
local kassert = require "util.kassert"
local lume = require "util.lume"
local soundutil = require "util.soundutil"


local eventfuncs = {}

local function NoAssets(param, assets, prefabs)
end

local function CreateEventHandler(name, func)
	return EventHandler(name, func)
end

local function CreateFrameEvent(frame, func)
	return FrameEvent(frame, func)
end

local function CreateHandler(frame_or_eventname, func)
	if type(frame_or_eventname) == "number" then
		return CreateFrameEvent(frame_or_eventname, func)
	else
		return CreateEventHandler(frame_or_eventname, func)
	end
end

-- Default run behaviour for func
local function JustRun(self, frame, param)
	return CreateHandler(frame, function(inst)
		self.func(inst, param)
	end)
end

-- Default run behaviour for editorfunc
local function JustRunEditor(self, editor, frame, param)
	return CreateHandler(frame, function(inst)
		self.func(inst, param)
	end)
end

local function JustRunCine(self, frame, param, data)
	if data and data.target_role then
		return CreateHandler(frame, function(inst)
			if data.sub_actor_removed then
				TheLog.ch.Cine:print("WARNING: Selected Sub Actor for event has been removed:", self.nicename)
				return
			end
			-- Determine the target actor to run the event on. If target_role is 'players', check to see if it needs to run on all players.
			if data.target_role == "players" and data.apply_to_all_players then
				for _, player in ipairs(TheNet:GetPlayersOnRoomChange()) do
					kassert.assert_fmt(player, "Cinematic has no role '%s' for timeline event '%s'.", data.target_role, self.nicename)
					self.func(player, param, inst)
				end
			else
				local actor = 	(data.target_role == "players" and AllPlayers[1]) -- TODO: Handle multiple players & networking
								or (data.target_role == "sub" and inst.cine.subactors[data.sub_actor_idx])
								or inst.cine.roles[data.target_role]

				-- Subactors might be assigned after loading; they aren't assigned on remote clients. Let the host deal with their presentation.
				if not actor and not TheNet:IsHost() then return end

				kassert.assert_fmt(actor, "Cinematic has no role '%s' for timeline event '%s'.", data.target_role, self.nicename)
				self.func(actor, param, inst)
			end
		end)
	else
		return JustRun(self, frame, param)
	end
end

local function AlwaysValid()
	return true
end

local function EventFunc(description)
	description.collectassets = description.collectassets or NoAssets
	description.editorfunc = description.editorfunc or JustRunEditor
	description.runfunc = description.runfunc or JustRun
	description.cinefunc = description.cinefunc or JustRunCine
	description.isvalid = description.isvalid or AlwaysValid
	eventfuncs[description.name] = description
end

-- Always use frames for duration. Use these standardized editors.
local function DurationViz(duration)
	local ticks = duration * ANIM_FRAMES
	return (" for %.01f seconds"):format(ticks * TICKS)
end
local function DurationEdit(ui, param, default_duration, max_duration)
	max_duration = max_duration or SecondsToAnimFrames(10)
	param.duration = ui:_SliderInt("Duration Frames", param.duration or default_duration, 0, max_duration)
	if param.duration == 0 then
		-- nil represents unlimited duration.
		param.duration = nil
	end
end

local function DoAfterDurationOrStateExit(inst, duration, fn, taskrunner)
	assert(inst)
	assert(fn)
	taskrunner = taskrunner or inst

	if duration then
		local task = taskrunner:DoTaskInAnimFrames(duration, fn)
		local setup_tick = GetTick()

		-- Need to listen for cine skipped event to see if we need to still run the function
		inst:ListenForEvent("cine_skipped", function()
			local current_tick = GetTick()
			local durationTicks = duration * ANIM_FRAMES
			local ticks_elapsed = current_tick - setup_tick
			if ticks_elapsed < durationTicks then
				task:Cancel()
				fn(inst)
			end
		end)
	else
		if inst.sg then
			inst.sg.mem.autogen_onexitfns = inst.sg.mem.autogen_onexitfns or {}
			table.insert(inst.sg.mem.autogen_onexitfns, fn)
		end
	end
end

local function RequireCineActorComponent(ui, inst, editor)
	if not inst.components.cineactor then
		editor.owner:WarningMsg(ui,
			"Missing cineactor component",
			("Prefab '%s' doesn't have a cineactor component. Lead actors in a cine need a cineactor component."):format(inst.prefab))
	end
end

local function String(s)
	if not s or s == "" then
		return "***not set***"
	end
	return '"'..s..'"'
end


-- For events using EventFuncEditor:SoundEffect.
function IsValidSoundEffectEvent(self, editor, event, testprefab)
	return event
		and event.param
		and event.param.soundevent ~= nil
end



EventFunc({
	name = "gameevent",
	nicename = "Fire Event",
	func = function(inst, param, data)
		inst:PushEvent(param.event_name, data)
	end,
	viz = function(self, ui, param)
		local s = String(param.event_name)
		return s
	end,
	edit = function(self, editor, ui, event, prefab)
		ui:Spacing()
		local param = event.param

		param.event_name = editor.eventnamer:EditEventName(ui, param.event_name)

		if not param.event_name then
			ui:TextColored(WEBCOLORS.CRIMSON, "You must provide a name for the event to be sent to code.")
		end
	end,
	isvalid = function(self, editor, event, testprefab)
		return event.param.event_name ~= nil
	end,
})

EventFunc({
	name = "attachswipefx",
	nicename = "Attach Swipe FX",
	func = function(inst, param, data)
		SGPlayerCommon.Fns.AttachSwipeFx(inst, param.fxname, param.backgroundfx, param.stoponinterruptstate)
		SGPlayerCommon.Fns.AttachPowerSwipeFx(inst, param.fxname, param.backgroundfx, param.stoponinterruptstate)

		-- If we have attached a swipe fx to any state, we should automatically detach it on exit of the state by default.
		-- A designer can still add an -early- detach by placing a DetachSwipeFx eventfunc in the state, too.
		inst.sg.mem.autogen_onexitfns = inst.sg.mem.autogen_onexitfns or {}
		local exitfn_count = #inst.sg.mem.autogen_onexitfns
		inst.sg.mem.autogen_onexitfns[exitfn_count + 1] = function()
			SGPlayerCommon.Fns.DetachSwipeFx(inst)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)

			-- For now, detaching BG Swipe FX at the same time. Sloth may want an option to detach these separately later, but for now they can be aligned.
			SGPlayerCommon.Fns.DetachSwipeFx(inst, true)
			SGPlayerCommon.Fns.DetachPowerSwipeFx(inst, true)
		end
	end,
	collectassets = function(param, assets, prefabs)
		table.insert(prefabs, param.fxname)
	end,
	viz = function(self, ui, param)
		local s = String(param.fxname)
		return s
	end,
	edit = function(self, editor, ui, event, prefab)
		ui:Dummy(0, 10)
		local param = event.param

		-- FX NAME:
		local changed, newfx = ui:InputText("FX", param.fxname or "", imgui.InputTextFlags.CharsNoBlank)
		if changed then
			param.fxname = newfx ~= "" and newfx or nil
		end

		local backgroundfx = param.backgroundfx
		backgroundfx = ui:_Checkbox("Background", backgroundfx)
		param.backgroundfx = backgroundfx == true or nil

		-- STOP WHEN EXITING STATE:
		-- local stoponinterruptstate = param.stoponinterruptstate
		-- stoponinterruptstate = ui:_Checkbox("Stop on State Interrupted",stoponinterruptstate)
		-- param.stoponinterruptstate = stoponinterruptstate == true or nil
		param.stoponinterruptstate = true

		-- THE REST OF THIS IS PREVIEW ONLY, NOT TOUCHED BY GAME CODE:
		ui:Dummy(0, 10)
		ui:Separator()
		ui:Dummy(0, 10)

		ui:Text("Preview Settings:")
		local fxtypes = { "basic", "fancy" } --TODO: make our fx types a global list, populate from there
		local fxid = lume.find(fxtypes, param.auditionfxtype) or 1
		local newfxid = ui:_Combo("Type", fxid, fxtypes)
		param.auditionfxtype = fxtypes[newfxid]

		prefab.sg.mem.fx_type = param.auditionfxtype

		local powerfxtypes = { "none", "electric" } --TODO: make our power fx types a global list, populate from there
		local powind = lume.find(powerfxtypes, param.auditionpowertype) or 1
		local newpowind = ui:_Combo("Power", powind, powerfxtypes)
		param.auditionpowertype = powerfxtypes[newpowind]
	end,

	isvalid = function(self, editor, event, testprefab)
		return event.param.fxname ~= nil
	end,

	editorfunc = function(self, editor, frame, param)
		return CreateHandler(frame, function(inst)
			-- Initialize these first, because this can play without actually editing the event.
			inst.sg.mem.fx_type = param.auditionfxtype
			inst.components.powermanager.attack_fx_mods = {}

			inst.sg.mem.attack_type = "light_attack" -- For the editor, forcing this to be "light_attack" because we don't actually care where it's stored at when auditioning.
														  -- This used to rely on the state itself to set the attack_type which for some reason only worked sometimes, even with the same setup. Forcing this to unblock FX artists and because it doesn't matter.
			inst.components.powermanager:SetPowerAttackFX(inst.sg.mem.attack_type, param.auditionpowertype)

			if param.backgroundfx then
				SGPlayerCommon.Fns.AttachSwipeFx(inst, param.fxname, true)
				SGPlayerCommon.Fns.AttachPowerSwipeFx(inst, param.fxname, true)
			else
				SGPlayerCommon.Fns.AttachSwipeFx(inst, param.fxname)
				SGPlayerCommon.Fns.AttachPowerSwipeFx(inst, param.fxname)
			end
		end)
	end,
})

EventFunc({
	name = "detachswipefx",
	nicename = "Detach Swipe FX",
	func = function(inst, param, data)
		SGPlayerCommon.Fns.DetachSwipeFx(inst)
		SGPlayerCommon.Fns.DetachPowerSwipeFx(inst)

		SGPlayerCommon.Fns.DetachSwipeFx(inst, true)
		SGPlayerCommon.Fns.DetachPowerSwipeFx(inst, true)
	end,
})

EventFunc({
	name = "spawnimpactfx",
	nicename = "Spawn Impact",
	func = function(inst, param)
		local testfx = SGCommon.Fns.PlayGroundImpact(inst, param)
		return testfx
	end,

	collectassets = function(param, assets, prefabs)
		if param.impact_type == GroundImpactFXTypes.id.ParticleSystem then
			table.insert(prefabs, GroupPrefab("impacts"))
		else
			table.insert(prefabs, GroupPrefab("fx_impact"))
		end
	end,

	editorfunc = function(self, editor, frame, param)
		return CreateHandler(frame, function(inst)
			TheSim:LoadPrefabs({ GroupPrefab("fx_impact"), GroupPrefab("impacts") })
			local testfx = self.func(inst, param)
			if testfx then
				TheLog.ch.Embellisher:printf("Played impact '%s'", testfx.prefab)
				if param.impact_type == GroundImpactFXTypes.id.ParticleSystem then
					testfx:ListenForEvent("onremove", function()
						editor:UnregisterParticles(testfx)
					end)
					editor:RegisterParticles(testfx)
				else
					testfx:ListenForEvent("onremove", function()
						editor:UnregisterFX(testfx)
					end)
					editor:RegisterFX(testfx)
				end
			end
		end)
	end,

	viz = function(self, ui, param)
		local impact_name = GroundImpactFXTypes:FromId(param.impact_type or GroundImpactFXTypes.id.ParticleSystem)
		return String(GroundImpactFXSizes:FromId(param.impact_size).." "..impact_name.." impact effect")
	end,

	edit = function(self, editor, ui, event, prefab)
		local param = event.param

		param.impact_type = param.impact_type or GroundImpactFXTypes.id.ParticleSystem
		local new_impact_type = ui:_Combo("Impact Type", param.impact_type, GroundImpactFXTypes:Ordered())
		if new_impact_type ~= param.impact_type then
			param.impact_type = new_impact_type
		end

		param.impact_size = param.impact_size or GroundImpactFXSizes.id.Small
		local new_impact_size = ui:_Combo("Impact Size", param.impact_size, GroundImpactFXSizes:Ordered())
		if new_impact_size ~= param.impact_size then
			param.impact_size = new_impact_size
		end

		editor:SymbolName(ui, param, prefab)

		local inheritrotation = param.inheritrotation
		inheritrotation = ui:_Checkbox("Use Entity Facing", param.inheritrotation)
		param.inheritrotation = inheritrotation == true or nil

		param.offx = param.offx or 0
		param.offz = param.offz or 0

		local symbolspace = param.followsymbol and true or false
		local changed, x, z = ui:DragFloat2(
			"offset",
			param.offx,
			param.offz,
			symbolspace and 1 or 0.01,
			symbolspace and -1000 or -10,
			symbolspace and 1000 or 10
		)
		if changed then
			param.offx = x
			param.offz = z
		end
		editor:PoseButton(event, ui, prefab)

		if param.impact_type == 2 then
			local changed, sx, sz = ui:DragFloat2("scale", param.scalex or 1, param.scalez or 1, 0.005, 0, 5)
			if changed then
				param.scalex = sx
				param.scalez = sz
			end
		end

		-- visualize offset position
		local offx = param.offx or 0
		local offy = param.offy or 0
		local offz = param.offz or 0

		local time = TheSim:GetTick() * TheSim:GetTickTime()
		local t = (time * 3) % (2 * math.pi)
		local c = (math.sin(t) + 1) / 2
		local color = { 1 - c, 1, 0 }

		local x, y, z = prefab.Transform:GetWorldPosition()
		local dir = prefab.Transform:GetFacing() == FACING_LEFT and -1 or 1
		local x, y = TheSim:WorldToScreenXY(x + dir * offx, y + offy, z + dir * offz)
		TheSim:WorldToScreenXY(x + dir * offx, y + offy, z + dir * offz)
		ui:ScreenLine({ x - 10, y }, { x + 10, y }, color)
		ui:ScreenLine({ x, y - 10 }, { x, y + 10 }, color)
		ui:ScreenLine({ x - 7, y - 7 }, { x + 7, y + 7 }, color)
		ui:ScreenLine({ x - 7, y + 7 }, { x + 7, y - 7 }, color)
	end,

	-- not part of normal eventfuncs API
	GetAllImpactFx = function(self)
		local GroundTiles = require "defs.groundtiles"

		local ret = {}
		local empty = GroundTiles.TileGroups.EMPTY.Order[1] -- IMPASSABLE
		for grp_name,group in pairs(GroundTiles.TileGroups) do
			if not group.is_proto
				and not group.is_shadow_group
			then
				for id,tile_name in ipairs(group.Order) do
					local tile = GroundTiles.Tiles[tile_name]
					if tile_name ~= empty
						and not tile.underground
					then
						local t = {}
						for _,impact_size in ipairs(GroundImpactFXSizes:Ordered()) do
							t[impact_size] = {
								fx        = TileToImpactFx(GroundImpactFXTypes.id.FX, tile_name, impact_size),
								particles = TileToImpactFx(GroundImpactFXTypes.id.ParticleSystem, tile_name, impact_size),
								tile      = tile_name,
							}
						end
						table.insert(ret, t)
					end
				end
			end
		end
		return ret
	end,
})

EventFunc({
	name = "spawneffect", -- aka spawnfx
	nicename = "Spawn Effect",
	func = function(inst, param)
		return EffectEvents.MakeEventSpawnEffect(inst, param)
	end,
	collectassets = function(param, assets, prefabs)
		table.insert(prefabs, param.fxname)
	end,
	editorfunc = function(self, editor, frame, param)
		return CreateHandler(frame, function(inst)
			TheSim:LoadPrefabs({ param.fxname })
			local testfx = self.func(inst, param)
			if testfx then
				testfx:ListenForEvent("onremove", function()
					editor:UnregisterFX(testfx)
				end)
				editor:RegisterFX(testfx)
			end
		end)
	end,
	viz = function(self, ui, param)
		local s = String(param.fxname)
		if param.followsymbol then
			s = s .. " on symbol " .. String(param.followsymbol)
		end
		return s
	end,
	edit = function(self, editor, ui, event, prefab)
		local param = event.param

		editor:EffectName(ui, param)
		editor:SymbolName(ui, param, prefab)
		local parent = param.ischild
		local inheritrotation = param.inheritrotation

		ui:Columns(2, "parentflags", false)
		parent = ui:_Checkbox("Parent to Entity", parent)
		ui:NextColumn()
		inheritrotation = ui:_Checkbox("Use Entity Facing", param.inheritrotation)
		ui:Columns(1)

		param.inheritrotation = inheritrotation == true or nil

		local symbolspace = param.followsymbol and true or false
		local changed, x, y, z = ui:DragFloat3(
			"offset",
			param.offx or 0,
			param.offy or 0,
			param.offz or 0,
			symbolspace and 1 or 0.01,
			symbolspace and -1000 or -10,
			symbolspace and 1000 or 10
		)
		if changed then
			param.offx = x
			param.offy = y
			param.offz = z
		end
		editor:PoseButton(event, ui, prefab)
		param.ischild = parent == true or nil

		local changed, sx, sz = ui:DragFloat2("scale", param.scalex or 1, param.scalez or 1, 0.005, 0, 5)
		if changed then
			param.scalex = sx
			param.scalez = sz
		end

		local stopatexitstate = param.stopatexitstate
		stopatexitstate = ui:_Checkbox("Stop on State Exit", stopatexitstate)
		param.stopatexitstate = stopatexitstate == true or nil

		if param.ischild then
			local detachatexitstate = param.detachatexitstate
			detachatexitstate = ui:_Checkbox("Detach on State Exit", detachatexitstate)
			param.detachatexitstate = detachatexitstate == true or nil
		end

		-- visualize this
		local offx = param.offx or 0
		local offy = param.offy or 0
		local offz = param.offz or 0

		local time = TheSim:GetTick() * TheSim:GetTickTime()
		local t = (time * 3) % (2 * math.pi)
		local c = (math.sin(t) + 1) / 2
		local color = { 1 - c, 1, 0 }

		if param.followsymbol then
			local x, y, z = prefab.AnimState:GetSymbolPosition(param.followsymbol, offx, offy, offz)
			--testfx.Transform:SetPosition(x,y,z)
			local x, y = TheSim:WorldToScreenXY(x, y, z)
			ui:ScreenLine({ x - 10, y }, { x + 10, y }, color)
			ui:ScreenLine({ x, y - 10 }, { x, y + 10 }, color)
			ui:ScreenLine({ x - 7, y - 7 }, { x + 7, y + 7 }, color)
			ui:ScreenLine({ x - 7, y + 7 }, { x + 7, y - 7 }, color)
		else
			local x, y, z = prefab.Transform:GetWorldPosition()
			local dir = prefab.Transform:GetFacing() == FACING_LEFT and -1 or 1
			local x, y = TheSim:WorldToScreenXY(x + dir * offx, y + offy, z + dir * offz)
			TheSim:WorldToScreenXY(x + dir * offx, y + offy, z + dir * offz)
			ui:ScreenLine({ x - 10, y }, { x + 10, y }, color)
			ui:ScreenLine({ x, y - 10 }, { x, y + 10 }, color)
			ui:ScreenLine({ x - 7, y - 7 }, { x + 7, y + 7 }, color)
			ui:ScreenLine({ x - 7, y + 7 }, { x + 7, y - 7 }, color)
		end
	end,
	isvalid = function(self, editor, event, testprefab)
		return event.param.fxname ~= nil
	end,
})

EventFunc({
	name = "spawnparticles",
	nicename = "Spawn Particle System",
	func = function(inst, param)
		return ParticleSystemHelper.MakeEventSpawnParticles(inst, param)
	end,
	editorfunc = function(self, editor, frame, param)
		return CreateHandler(frame, function(inst)
			local particles = self.func(inst, param)
			if particles then
				particles:ListenForEvent("onremove", function()
					editor:UnregisterParticles(particles)
				end)
				editor:RegisterParticles(particles)
			end
		end)
	end,
	collectassets = function(param, assets, prefabs)
		table.insert(prefabs, param.particlefxname)
	end,
	viz = function(self, ui, param)
		local s = String(param.particlefxname)
		if param.followsymbol then
			s = s .. " on symbol " .. String(param.followsymbol)
		end
		if param.duration then
			s = s .. DurationViz(param.duration)
		end
		return s
	end,
	edit = function(self, editor, ui, event, prefab)
		local param = event.param
		editor:ParticleEffectName(ui, param)
		editor:SymbolName(ui, param, prefab)
		local parent = param.ischild
		local use_entity_facing = param.use_entity_facing

		ui:Columns(2, "parentflags", false)
		parent = ui:_Checkbox("Parent to Entity", parent)
		ui:NextColumn()
		use_entity_facing = ui:_Checkbox("Use Entity Facing", param.use_entity_facing)
		ui:Columns(1)

		param.use_entity_facing = use_entity_facing == true or nil

		local symbolspace = param.followsymbol and true or false
		local changed, x, y, z = ui:DragFloat3(
			"offset",
			param.offx or 0,
			param.offy or 0,
			param.offz or 0,
			symbolspace and 1 or 0.01,
			symbolspace and -1000 or -10,
			symbolspace and 1000 or 10
		)
		if changed then
			param.offx = x
			param.offy = y
			param.offz = z
		end
		editor:PoseButton(event, ui, prefab)
		param.ischild = parent == true or nil

		-- visualize this
		local offx = param.offx or 0
		local offy = param.offy or 0
		local offz = param.offz or 0

		local time = TheSim:GetTick() * TheSim:GetTickTime()
		local t = (time * 3) % (2 * math.pi)
		local c = (math.sin(t) + 1) / 2
		local color = { 1 - c, 1, 0 }

		if param.followsymbol then
			local x, y, z = prefab.AnimState:GetSymbolPosition(param.followsymbol, offx, offy, offz)
			local x, y = TheSim:WorldToScreenXY(x, y, z)
			ui:ScreenLine({ x - 10, y }, { x + 10, y }, color)
			ui:ScreenLine({ x, y - 10 }, { x, y + 10 }, color)
			ui:ScreenLine({ x - 7, y - 7 }, { x + 7, y + 7 }, color)
			ui:ScreenLine({ x - 7, y + 7 }, { x + 7, y - 7 }, color)
		else
			local x, y, z = prefab.Transform:GetWorldPosition()
			local x, y = TheSim:WorldToScreenXY(x + offx, y + offy, z + offz)
			ui:ScreenLine({ x - 10, y }, { x + 10, y }, color)
			ui:ScreenLine({ x, y - 10 }, { x, y + 10 }, color)
			ui:ScreenLine({ x - 7, y - 7 }, { x + 7, y + 7 }, color)
			ui:ScreenLine({ x - 7, y + 7 }, { x + 7, y - 7 }, color)
		end
		local in_front = param.render_in_front or false
		local behind = ui:_Checkbox("World space", not in_front) -- If "in_front" is true, this particle FX will be rendered in UI space
		param.render_in_front = not behind or nil
		local name = param.name or ""

		local stopatexitstate = param.stopatexitstate
		stopatexitstate = ui:_Checkbox("Stop on State Exit", stopatexitstate)
		param.stopatexitstate = stopatexitstate == true or nil

		local detachatexitstate = param.detachatexitstate
		detachatexitstate = ui:_Checkbox("Detach on State Exit", detachatexitstate)
		param.detachatexitstate = detachatexitstate == true or nil

		local changed, newname = ui:InputTextWithHint(
			"Particles Name",
			"Optional",
			name,
			imgui.InputTextFlags.CharsNoBlank
		)
		if ui:IsItemHovered() then
			ui:SetTooltipMultiline({
					"We'll skip spawn if particles with the same name already exist on this entity.",
					"A name is required to stop this particle system from an event.",
				})
		end
		if changed then
			param.name = newname ~= "" and newname or nil
		end

		DurationEdit(ui, param, 0)
	end,
	isvalid = function(self, editor, event, testprefab)
		return event.param.particlefxname ~= nil
	end,
})

EventFunc({
	name = "playsound",
	nicename = "Play Sound",
	always_can_overlap = true,
	func = function(inst, param, data)
		local event_source = param.event_source
		-- data is only set if it's an event handler
		local name = param.name
		if param.stopatexitstate then
			name = soundutil.AddSGAutogenStopSound(inst, param)
		end
		TheLog.ch.AudioSpam:print("Play Sound:", param.soundevent)
		soundutil.PlaySoundData(inst, param, name, inst)
		return param.fallthrough
	end,
	viz = function(self, ui, param)
		local s = String(param.soundevent)
		if param.name then
			s = s .. " as " .. String(param.name)
		end
		return s
	end,
	isvalid = IsValidSoundEffectEvent,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		editor:SoundEffect(ui, param)
		local name = param.name or ""

		local stopatexitstate = param.stopatexitstate
		stopatexitstate = ui:_Checkbox("Stop on State Exit", stopatexitstate)
		param.stopatexitstate = stopatexitstate == true or nil
		local name_hint = param.stopatexitstate and param.soundevent or "Optional"
		local changed, newname = ui:InputTextWithHint("Sound Name", name_hint, name, imgui.InputTextFlags.CharsNoBlank)
		if ui:IsItemHovered() then
			ui:SetTooltipMultiline({
					"A name is required to modify this sound from other events",
					"like setting parameters or stopping.",
					"Won't play if sound with this name is already playing on this entity.",
				})
		end
		if changed then
			param.name = newname ~= "" and newname or nil
		end

		editor:SoundVolume(ui, param)
		editor:SoundAutostop(ui, param)
		editor:SoundMaxCount(ui, param, inst)
	end,
})

EventFunc({
	name = "playsound_window",
	nicename = "Play Windowed Sound",
	always_can_overlap = true,
	func = function(inst, param, data)
		TheLog.ch.AudioSpam:print("Play Windowed Sound:", param.soundevent)
		soundutil.PlayWindowedSound(inst, param, inst)
		return param.fallthrough
	end,
	viz = function(self, ui, param)
		local s = ("%s after %d frames"):format(String(param.soundevent), param.window_frames or 5)
		return s
	end,
	isvalid = IsValidSoundEffectEvent,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		editor:SoundEffect(ui, param)
		editor:SoundVolume(ui, param)
		-- No max count since we are skipping other plays.
		-- No stop on exit since we aren't playing yet.
		editor:SoundWindow(ui, param, inst)
	end,
})

EventFunc({
	name = "playcountedsound",
	nicename = "Play CountedSound",
	always_can_overlap = true,
	func = function(inst, param, data)
		return soundutil.PlayCountedSound(inst, param)
	end,
	viz = function(self, ui, param)
		local s = String(param.soundevent .. " - " .. math.floor(param.maxcount or 1))
		if param.name then
			s = s .. " as " .. String(param.name)
		end
		return s
	end,
	isvalid = IsValidSoundEffectEvent,
	edit = function(self, editor, ui, event)
		local param = event.param
		editor:SoundEffect(ui, param)
		local name = param.name or ""

		local stopatexitstate = param.stopatexitstate
		stopatexitstate = ui:_Checkbox("Stop on State Exit", stopatexitstate)
		param.stopatexitstate = stopatexitstate == true or nil
		local changed, newname = ui:InputTextWithHint(
			"Sound Name",
			"Optional",
			name or "",
			imgui.InputTextFlags.CharsNoBlank
		)
		if changed then
			param.name = newname ~= "" and newname or nil
		end

		editor:SoundVolume(ui, param)

		ui:Separator()
		ui:Text('Current count will be sent to the FMOD event as the parameter "Count"')
		local changed, maxcount = ui:DragInt("Max Count", param.maxcount or 1, 1, 1, 99)
		if changed then
			param.maxcount = maxcount or 1
		end
	end,
})

EventFunc({
	name = "playfoleysound",
	nicename = "Play Foley Sound",
	always_can_overlap = true,
	func = function(inst, param, data)
		local foleysounder = inst.components.foleysounder
		local volume = param.volume --soundutil.ConvertVolume(param.volume) -- DO NOT ConvertVolume here, ConvertVolume is at the end of the chain.
		--assert(foleysounder, "You must add a foleysounder component before tagging foley sounds.")
		if foleysounder ~= nil then
			if param.soundtag == "Footstep" then
				foleysounder:PlayFootstep(volume, inst)
			elseif param.soundtag == "Footstep Stop" then
				foleysounder:PlayFootstepStop(volume)
			elseif param.soundtag == "Hand" then
				foleysounder:PlayHand(volume)
			elseif param.soundtag == "Jump" then
				foleysounder:PlayJump(volume)
			elseif param.soundtag == "Land" then
				foleysounder:PlayLand(volume)
			elseif param.soundtag == "Bodyfall" then
				foleysounder:PlayBodyfall(volume)
			end
		end
		return param.fallthrough
	end,
	viz = function(self, ui, param)
		return String(param.soundtag)
	end,
	edit = function(self, editor, ui, event, prefab)
		if prefab.components.foleysounder then
			local param = event.param
			local tags = { "Footstep", "Footstep Stop", "Hand", "Jump", "Land", "Bodyfall" } -- Possible option: only show the option if the foleysounder has that event configured?

			local curind = lume.find(tags, param.soundtag) or 1
			local newind = ui:_Combo("Sound Event", curind, tags)
			param.soundtag = tags[newind]

			editor:SoundVolume(ui, param)

		else
			ui:Text("Cannot add foley tags without a FoleySounder component.")
			ui:Text("Please add a FoleySounder component to the prefab.")
		end
	end,
})

EventFunc({
	name = "setsoundparameter",
	nicename = "Set Sound Parameter",
	always_can_overlap = true,
	func = function(inst, param, data)
		TheLog.ch.AudioSpam:print("Set Sound Parameter:", inst, param.sound_name, param.param_value)
		inst.SoundEmitter:SetParameter(param.sound_name, param.param_name, param.param_value)
		return param.fallthrough
	end,
	viz = function(self, ui, param)
		local s = String(param.sound_name)
		return s
	end,
	edit = function(self, editor, ui, event)
		local value
		local param = event.param
		-- Hm. We could suggest names from audioid.lua or other events in the embellisher.
		local changed, newname = ui:InputText("Sound Name", param.sound_name or "", imgui.InputTextFlags.CharsNoBlank)
		if changed then
			param.sound_name = newname ~= "" and newname or nil
		end
		changed, newname = ui:InputText("Parameter Name", param.param_name or "", imgui.InputTextFlags.CharsNoBlank)
		if changed then
			param.param_name = newname ~= "" and newname or nil
		end
		changed, value = ui:DragFloat("Parameter", param.param_value or 1, 0.005, -10, 10)
		if changed then
			param.param_value = value ~= 1 and value or nil
		end
	end,
	isvalid = function(self, editor, event, testprefab)
		return event.param.sound_name ~= nil
			and event.param.param_name ~= nil
			and event.param.param_value ~= nil
	end,
})

EventFunc({
	name = "stopallsounds",
	nicename = "Stop All Named Sounds",
	func = function(inst, param)
		inst.SoundEmitter:KillAllNamedSounds()
	end,
})

EventFunc({
	name = "stopsound",
	nicename = "Stop Sound",
	always_can_overlap = true,
	func = function(inst, param)
		soundutil.KillSound(inst, param.name)
	end,
	viz = function(self, ui, param)
		local s = String(param.name)
		return s
	end,
	edit = function(self, editor, ui, event)
		local param = event.param
		local changed, newname = ui:InputTextWithHint("Sound Name", "The name set on Play Sound event.", param.name or "", imgui.InputTextFlags.CharsNoBlank)
		if changed then
			param.name = newname ~= "" and newname or nil
		end
	end,
	isvalid = function(self, editor, event, testprefab)
		return event.param.name ~= nil
	end,
})

local function ClearCameraShake(inst)
	TheCamera:StopShake()
end
EventFunc({
	name = "shakecamera",
	nicename = "Shake Camera",
	is_targetless = true,
	no_overlap = true,
	func = function(inst, param, data)
		local duration_seconds = 5 -- Default to very long so it turns off with state.
		if param.duration then
			duration_seconds = param.duration * ANIM_FRAMES * TICKS
		end
		ShakeAllCameras(
			CAMERASHAKE[param.mode],
			duration_seconds,
			param.speed or 0.025,
			param.scale or 0.15,
			inst,
			param.dist or 50
		)
		-- Camera shake automatically turns itself off, so we only clear on
		-- exit if no duration is set.
		if not param.duration then
			inst.sg.mem.autogen_onexitfns = inst.sg.mem.autogen_onexitfns or {}
			table.insert(inst.sg.mem.autogen_onexitfns, ClearCameraShake)
		end
	end,
	testbtn = true, -- implementation is safe for firing on the inst

	viz = function(self, ui, param)
		if param.duration then
			return DurationViz(param.duration)
		end
		return "until state exit"
	end,

	edit = function(self, editor, ui, event, prefab)
		local param = event.param

		-- CAMERASHAKE is arranged such that k = mode, v = int which is read by
		-- the camerashaker. Prepare an i,v table to pick by mode name.
		local modes = lume.keys(CAMERASHAKE)
		table.sort(modes)
		local curind = lume.find(modes, param.mode) or 1
		local newind = ui:_Combo("Mode", curind, modes)
		param.mode = modes[newind]

		local max_duration = math.ceil(SecondsToAnimFrames(16)) -- camera shake limits to 16 seconds
		DurationEdit(ui, param, 0, max_duration)

		local changed, speed = ui:DragFloat("Speed", param.speed or 0.025, 0.0001, 0, 0.05)
		if changed then
			param.speed = speed or nil
		end

		local changed, scale = ui:DragFloat("Scale", param.scale or 0.15, 0.001, 0, 0.5)
		if changed then
			param.scale = scale or nil
		end

		local changed, dist = ui:DragFloat("Distance", param.dist or 50, 1, 0, 100)
		if changed then
			param.dist = math.floor(dist) or nil
		end

		if not TheGameSettings:Get("graphics.screen_shake") then
			ui:TextColored(
				WEBCOLORS.KHAKI,
				"Screen shake is disabled in your game settings.\nTurn it on to preview this event."
			)
		end
	end,
})


EventFunc({
	name = "stopparticles",
	nicename = "Stop Particle System",
	func = function(inst, param)
		ParticleSystemHelper.MakeEventStopParticles(inst, param)
	end,
	viz = function(self, ui, param)
		local s = String(param.name)
		return s
	end,
	edit = function(self, editor, ui, event)
		local param = event.param
		local changed, newname = ui:InputTextWithHint("Particles Name", "The name set on Spawn Particle System event.", param.name or "", imgui.InputTextFlags.CharsNoBlank)
		if changed then
			param.name = newname ~= "" and newname or nil
		end
	end,
	isvalid = function(self, editor, event, testprefab)
		return event.param.name ~= nil
	end,
})


-- invincible seems useful, but needs testing. Maybe also only something we
-- want in sg code.
--~ local function RestoreInvincible(inst)
--~ 	inst.HitBox:SetInvincible(inst.sg.statemem.was_invincible)
--~ end
--~ EventFunc({
--~ 	name = "invincible",
--~ 	nicename = "Set Invincible",
--~ 	-- Cine already makes everything invincible.
--~ 	required_editor = "embellisher",
--~ 	func = function(inst, param)
--~ 		inst.sg.statemem.was_invincible = inst.HitBox:IsInvincible()
--~ 		inst.HitBox:SetInvincible(true)
--~ 		DoAfterDurationOrStateExit(inst, param.duration, RestoreInvincible)
--~ 	end,
--~ 	--~ viz = function(self, ui, param)
--~ 	--~ 	local s = String(param.name)
--~ 	--~ 	return s
--~ 	--~ end,
--~ 	edit = function(self, editor, ui, event, inst)
--~ 		if not inst.HitBox then
--~ 			ui:TextColored(WEBCOLORS.YELLOW, "Entity doesn't have a HitBox.")
--~ 		end
--~ 	end,
--~ 	isvalid = function(self, editor, event, inst)
--~ 		return not inst or inst.HitBox
--~ 	end,
--~ })


EventFunc({
	name = "blurscreen",
	nicename = "Blur Screen",
	is_targetless = true,
	no_overlap = true,
	-- To make a blur for embellisher, it needs scale down based on distance
	-- from originator (like camera shakes).
	required_editor = "cineeditor",
	no_nil_duration = true,

	func = function(inst, param)
		if param.cut or not param.duration then
			TheWorld.components.blurcoordinator:SetBlurFromParams(param)
		else
			TheWorld.components.blurcoordinator:FadeTo(param.duration * ANIM_FRAMES, param)
		end
	end,
	viz = function(self, ui, param)
		local s = String(param.modename or "None")
		if param.cut or not param.duration then
			s = s .. " snap"
		else
			s = s .. " fade" .. DurationViz(param.duration)
		end
		return s
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		local should_preview = TheWorld.components.blurcoordinator:RenderBlurUI(ui, param)
		editor:RequestSeeWorld(should_preview)

		DurationEdit(ui, param, 0)
		camerautil.Edit_Curve(ui, param)
		camerautil.Edit_BlendCut(ui, param, inst)
	end,
})


local function ResetLighting(inst)
	-- Clearing the AnimState's self light override is unsupported.
	TheWorld.components.lightcoordinator:ResetColor()
end
EventFunc({
	name = "lightintensity",
	nicename = "Set Light Intensity",
	func = function(inst, param)
		inst.AnimState:SetLightOverride(param.self_intensity)
		if not param.skip_world then
			TheWorld.components.lightcoordinator:SetIntensity(param.world_intensity)
			inst:DoTaskInTime(0, function() DoAfterDurationOrStateExit(inst, param.duration, ResetLighting) end)
		end
	end,
	viz = function(self, ui, param)
		local s
		if param.skip_world then
			s = ("(self %.0f%%)"):format(param.self_intensity * 100)
			-- duration is ignored because there's no self light cleanup.
		else
			s = ("(world %.0f%%, self %.0f%%)"):format(param.world_intensity * 100, param.self_intensity * 100)
			if param.duration then
				s = s .. DurationViz(param.duration)
			else
				s = s .. " until state exit"
			end
		end
		return s
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		event.param.self_intensity = ui:_SliderFloat("Self Intensity", event.param.self_intensity or 1.0, 0, 1)
		local should_preview = ui:IsItemActive()
		DurationEdit(ui, param, 0)

		param.skip_world = not ui:_Checkbox("Change World Intensity", not param.skip_world)
		if not param.skip_world then
			ui:Text("Don't Change World Intensity from two events at the same time!")
			should_preview = TheWorld.components.lightcoordinator:RenderIntensityUI(ui, event.param) or should_preview
		end
		editor:RequestSeeWorld(should_preview)
		if should_preview then
			inst.AnimState:SetLightOverride(event.param.self_intensity)
		end
	end,
})

local function ClearTitleCard(inst)
	TheDungeon.HUD:HideTitleCard()
end
EventFunc({
	name = "titlecard",
	nicename = "Title Card",
	no_overlap = true,

	-- Ignore roles for title card since we don't want gotostate to cause early
	-- exit.
	cinefunc = JustRun,
	func = function(inst, param)
		TheDungeon.HUD:ShowTitleCard(param.titlekey)
		DoAfterDurationOrStateExit(inst, param.duration, ClearTitleCard, TheDungeon.HUD.inst)
	end,
	viz = function(self, ui, param)
		local s = String(param.titlekey)
		if param.duration then
			s = s .. DurationViz(param.duration)
		end
		return s
	end,
	edit = function(self, editor, ui, event, inst)
		local cards = lume.keys(STRINGS.TITLE_CARDS)
		table.sort(cards)
		local idx = lume.find(cards, event.param.titlekey or inst.prefab) or 1
		idx = ui:_Combo("Title Card", idx, cards)
		if ui:IsItemHovered() then
			ui:SetTooltipMultiline({
				"If you can't find the title you want,",
				"add it to STRINGS.TITLE_CARDS.",
			})
		end
		event.param.titlekey = cards[idx]
		DurationEdit(ui, event.param, 0)
		ui:Text("Note: Ignores roles.")
	end,
	isvalid = function(self, editor, event, testprefab)
		return event.param.titlekey ~= nil
	end,
})


local function ClearLetterbox(inst)
	TheFrontEnd:GetLetterbox():AnimateOut()
end
EventFunc({
	name = "letterbox",
	nicename = "Letterbox",
	is_targetless = true,
	no_overlap = true,
	func = function(inst, param)
		TheFrontEnd:GetLetterbox():AnimateIn()
		DoAfterDurationOrStateExit(inst, param.duration, ClearLetterbox, TheDungeon.HUD.inst)
	end,
	viz = function(self, ui, param)
		if param.duration then
			return DurationViz(param.duration)
		end
		return "until state exit"
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		DurationEdit(ui, param, 0)
	end,
})



local function RestoreHud(inst)
	TheDungeon.HUD:AnimateIn()
end
EventFunc({
	name = "uihidehud",
	nicename = "Hide Hud",
	is_targetless = true,
	no_overlap = true,
	func = function(inst, param)
		TheDungeon.HUD:AnimateOut()
		DoAfterDurationOrStateExit(inst, param.duration, RestoreHud, TheDungeon.HUD.inst)
	end,
	viz = function(self, ui, param)
		if param.duration then
			return DurationViz(param.duration)
		end
		return "until state exit"
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		DurationEdit(ui, param, 0)
	end,
})

local function RestorePlayerInputs(inst)
	for k, v in pairs(AllPlayers) do
		v:PushEvent("inputs_enabled")
	end
end
EventFunc({
	name = "disableplayinput",
	nicename = "Disable Player Input",
	is_targetless = true,
	no_overlap = true,
	func = function(inst, param)
		for k, v in pairs(AllPlayers) do
			v:PushEvent("inputs_disabled")
		end
		DoAfterDurationOrStateExit(inst, param.duration, RestorePlayerInputs, TheDungeon.HUD.inst)
	end,
	viz = function(self, ui, param)
		if param.duration then
			return DurationViz(param.duration)
		end
		return "until state exit"
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		DurationEdit(ui, param, 0)
	end,
})



EventFunc({
	name = "uibosshealthbar",
	nicename = "Boss Health Bar",
	required_editor = "cineeditor",
	no_overlap = true,
	func = function(inst, param)
		inst.components.boss:ActivateBoss()
	end,
	viz = function(self, ui, param)
		return "show"
	end,
	edit = function(self, editor, ui, event, inst)
		ui:Checkbox("Show", true)
		if ui:IsItemHovered() then
			ui:SetTooltip("Only show is currently supported")
		end
		if inst and not inst.components.boss then
			editor.owner:WarningMsg(ui,
				"Missing boss component",
				("Prefab '%s' doesn't have a boss component."):format(inst.prefab))
		end
	end,
})


local Facings = Enum{ "toward_players", "away_from_players", "left", "right" }
EventFunc({
	name = "facing",
	nicename = "Set Facing",
	func = function(inst, param)
		-- Will be nil for Facings.toward_players
		if param.facing == Facings.s.away_from_players then
			SGCommon.Fns.FaceAwayActionTarget(inst, TheFocalPoint)
		elseif param.facing == Facings.s.toward_players then
			SGCommon.Fns.FaceTarget(inst, TheFocalPoint)
		elseif param.facing == Facings.s.left then
			inst.Transform:SetRotation(180)
		else -- Right
			inst.Transform:SetRotation(0)
		end
	end,
	viz = function(self, ui, param)
		return String(param.facing)
	end,
	edit = function(self, editor, ui, event, inst)
		ui:TextWrapped("In multiplayer, 'players' is the centrepoint of all players (camera focal point).")
		local param = event.param
		param.facing = ui:_ComboAsString("Facing", param.facing, Facings:Ordered())
	end,
})


EventFunc({
	name = "cameratargetoverride",
	nicename = "Camera Target",
	no_overlap = true,

	func = function(inst, param)
		TheWorld:DoTaskInTime(0, function()
			camerautil.StartTarget(inst, param)
		 	DoAfterDurationOrStateExit(inst, param.duration, camerautil.ReleaseCamera)
		end)
	end,
	viz = function(self, ui, param)
		if param.duration then
			return DurationViz(param.duration)
		end
		return "until state exit"
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		camerautil.Edit_Distance(ui, param, inst)
		camerautil.Edit_Offset(ui, param, inst)
		param.cut = ui:_Checkbox("Snap Cut", param.cut) or nil
		DurationEdit(ui, param, 0)
	end,
})

EventFunc({
	name = "cameratargetbegin",
	nicename = "Start Camera Target",
	required_editor = "cineeditor",
	no_overlap = true,
	no_nil_duration = true,

	func = function(inst, param)
		if param.cut then
			TheCamera:SetTarget(inst)
			TheCamera:Snap()
		else
			camerautil.BlendToTarget(inst, param)
		end
	end,
	viz = function(self, ui, param)
		local s = ""
		if param.cut then
			s = "snap cut"
		elseif param.duration then
			s = DurationViz(param.duration)
		end
		return s .. ". Lasts until End Camera Target"
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		camerautil.Edit_Curve(ui, param)
		camerautil.Edit_BlendCut(ui, param, inst)
	end,
})

EventFunc({
	name = "cameratargetend",
	nicename = "End Camera Target",
	required_editor = "cineeditor",
	no_overlap = true,
	no_nil_duration = true, -- we need a duration to know our blend length

	func = function(inst, param)
		param.duration = param.duration or 0
		if param.cut then
			camerautil.ReleaseCamera(inst)
			TheCamera:Snap()
		else
			camerautil.BlendToTarget(TheFocalPoint, param, camerautil.ReleaseCamera)
		end
	end,
	viz = function(self, ui, param)
		if param.cut then
			return "snap cut"
		end
		return "transition".. DurationViz(param.duration)
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		camerautil.Edit_Curve(ui, param)
		camerautil.Edit_BlendCut(ui, param, inst)
	end,
})

--~ local function ReleaseFocus(inst)
--~ 	local focalpoint = TheFocalPoint.components.focalpoint
--~ 	focalpoint:StopFocusSource(inst)
--~ end
--~ local cameratargetadd_defaults = {
--~ 	minrange = 10,
--~ 	maxrange = 60,
--~ 	weight   = 0.5,
--~ 	priority = 100,
--~ }
--~ EventFunc({
--~ 		name = "cameratargetadd",
--~ 		nicename = "Camera Focus Shift",
--~ 		func = function(inst, param)
--~ 			local focalpoint = TheFocalPoint.components.focalpoint
--~ 			local focus = lume.overlaymaps({}, param, cameratargetadd_defaults)
--~ 			focalpoint:StartFocusSource(inst, focus)
--~ 			DoAfterDurationOrStateExit(inst, param.duration, ReleaseFocus)
--~ 		end,
--~ 		viz = function(self, ui, param)
--~ 			if param.duration then
--~ 				return DurationViz(param.duration)
--~ 			end
--~ 			return "until state exit"
--~ 		end,
--~ 		edit = function(self, editor, ui, event, inst)
--~ 			local param = event.param
--~ 			local d = cameratargetadd_defaults
--~ 			event.param.minrange = ui:_SliderFloat("Min Range", event.param.minrange or d.minrange, 5, 60)
--~ 			event.param.maxrange = ui:_SliderFloat("Max Range", event.param.maxrange or d.maxrange, 10, 100)
--~ 			event.param.weight   = ui:_SliderFloat("Weight", event.param.weight or d.weight, 0, 1)
--~ 			event.param.priority = ui:_SliderFloat("Priority", event.param.priority or d.priority, 1, 200)

--~ 			DurationEdit(ui, param, 0)
--~ 		end,
--~ 	})

EventFunc({
	name = "camerapitch",
	nicename = "Camera Pitch",
	required_editor = "cineeditor",
	is_targetless = true,
	no_overlap = true,
	no_nil_duration = true,

	func = function(inst, param)
		param.duration = param.duration or 0
		if param.cut then
			TheCamera:SetPitch(param.pitch or camerautil.defaults.pitch)
			TheCamera:Snap()
		else
			camerautil.BlendPitch(inst, param)
		end
	end,
	viz = function(self, ui, param)
		if param.cut
			or not param.duration -- see below TODO
		then
			return "snap cut"
		end
		return "transition".. DurationViz(param.duration)
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		param.pitch = ui:_SliderFloat("Pitch", param.pitch or camerautil.defaults.pitch, 1, 89)
		local should_preview = ui:IsItemActive()
		camerautil.Edit_BlendCut(ui, param, inst)
		camerautil.Edit_Curve(ui, param)

		if should_preview then
			TheCamera:SetPitch(param.pitch)
			TheCamera:Snap()
			self.was_previewing = true
		elseif self.was_previewing then
			self.was_previewing = nil
			TheCamera:SetPitch(camerautil.defaults.pitch)
		end
	end,
})

EventFunc({
	name = "cameradist",
	nicename = "Camera Zoom",
	required_editor = "cineeditor",
	is_targetless = true,
	no_nil_duration = true,

	func = function(inst, param)
		param.duration = param.duration or 0
		if param.cut then
			TheCamera:SetDistance(param.dist)
			TheCamera:Snap()
		else
			camerautil.BlendDist(inst, param)
		end
	end,
	viz = function(self, ui, param)
		local s = ""
		if param.cut
			or not param.duration -- see below TODO
		then
			s = "snap cut"
		else
			s = "transition".. DurationViz(param.duration)
		end
		if param.dist then
			s = s .. (" to %0.01f"):format(param.dist)
		else
			s = s .. " to gameplay"
		end
		return s
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		if param.dist then
			camerautil.Edit_Distance(ui, param, inst)
			ui:TextWrapped("If this distance doesn't work, ensure it doesn't occur on frame 0")
			if ui:Button("Use default gameplay distance") then
				param.dist = nil
			end
		else
			if ui:Button("Use custom distance") then
				param.dist = camerautil.defaults.dist
			end
		end
		camerautil.Edit_Curve(ui, param)
		camerautil.Edit_BlendCut(ui, param, inst)
	end,
})

EventFunc({
	name = "cameraoffset",
	nicename = "Camera Offset",
	required_editor = "cineeditor",
	is_targetless = true,
	no_nil_duration = true,

	func = function(inst, param)
		param.duration = param.duration or 0
		if param.cut then
			camerautil.ApplyOffset(param.offset)
			TheCamera:Snap()
		else
			camerautil.BlendOffset(inst, param)
		end
	end,
	viz = function(self, ui, param)
		if param.cut then
			return "snap cut"
		end
		return "transition".. DurationViz(param.duration)
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		camerautil.Edit_Offset(ui, param, inst)
		camerautil.Edit_Curve(ui, param)
		camerautil.Edit_BlendCut(ui, param, inst)
	end,
})


EventFunc({
	name = "cinestart",
	nicename = "Cinematic",
	required_editor = "embellisher", -- not cineeditor
	func = function(inst, param)
		inst.components.cineactor:PlayAsLeadActor(param.cine)
	end,
	collectassets = function(param, assets, prefabs)
		table.insert(prefabs, param.cine)
	end,
	viz = function(self, ui, param)
		return String(param.cine)
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		local cines = lume.keys(CineAutogenData)
		table.sort(cines)
		param.cine = ui:_ComboAsString("Cinematic", param.cine, cines)
		RequireCineActorComponent(ui, inst, editor)
	end,
})

--------------------------------------------------------------
-- CineEditor-only events

EventFunc({
	name = "fade",
	nicename = "Fade Screen",
	required_editor = "cineeditor",
	is_targetless = true,
	no_nil_duration = true,

	func = function(inst, param)
		local duration = param.duration * ANIM_FRAMES * TICKS
		TheFrontEnd:Fade(param.fade_in, duration, nil, nil, nil, param.fade_type)
	end,
	viz = function(self, ui, param)
		local fade_dir = param.fade_in and "in" or "out"
		return fade_dir .. " with duration".. DurationViz(param.duration)
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param

		local _, fade_dir = nil, param.fade_in and 0 or 1
		_, fade_dir = ui:RadioButton("Fade In", fade_dir, 0)
		ui:SameLine()
		_, fade_dir = ui:RadioButton("Fade Out", fade_dir, 1)
		ui:SameLine()
		if fade_dir ~= param.fade_in then
			param.fade_in = fade_dir == 0
		end
		ui:NewLine()

		local fade_types = { "black", "white", "swipe" }
		param.fade_type = ui:_ComboAsString("Fade Type", param.fade_type, fade_types)
	end,
})

EventFunc({
	name = "pushanim",
	nicename = "Push Animation",
	required_editor = "cineeditor",
	func = function(inst, param)
		if not inst:IsInLimbo() then
			if param.interrupt then
				inst.AnimState:PlayAnimation(param.anim, param.loop)
			else
				inst.AnimState:PushAnimation(param.anim, param.loop)
			end
		else
			TheLog.ch.Cine:printf("Entity GUID %d (%s) in limbo: Did not play anim %s", inst.GUID, inst.prefab, param.anim)
		end
	end,
	viz = function(self, ui, param)
		return String(param.anim)
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		if not inst.AnimState or not inst.AnimState:HasAnimation() then
			ui:TextColored(WEBCOLORS.YELLOW, "Select an actor with an AnimState.")
			-- Maybe it's this event that was causing us to have no animation, so debug clear.
			if ui:Button("Clear Data") then
				param = {}
			end
			return
		end
		local anims = inst.AnimState:GetCurrentBankAnimNames()
		table.sort(anims)
		local idx = lume.find(anims, param.anim) or 1
		idx = ui:_Combo("Anim", idx, anims)
		param.anim = anims[idx]
		param.loop = ui:_Checkbox("Loop", param.loop) or nil
		param.interrupt = ui:_Checkbox("Interrupt", param.interrupt) or nil
		if ui:Button("Test and Set Length") then
			self.func(inst, param)
			if not param.loop then
				param.duration = inst.AnimState:GetCurrentAnimationNumFrames()
			end
		end
		if param.loop then
			param.duration = nil
			--~ -- TODO(dbriscoe): Could we always snap to anim length; without crashing?
			--~ else
			--~ 	param.duration = inst.AnimState:GetAnimationNumFrames(param.anim)
		end
	end,
})

EventFunc({
	name = "setsheathed",
	nicename = "Set Player Sheathed",
	required_editor = "cineeditor",
	func = function(inst, param)
		SGPlayerCommon.Fns.SetWeaponSheathed(inst, param.sheathed)
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		param.sheathed = ui:_Checkbox("Sheathed", param.sheathed)
	end,
})

EventFunc({
	name = "musicbossstart",
	nicename = "Play Boss Music",
	required_editor = "cineeditor",
	-- Okay to use run_on_skip since this event is instantaneous. Only run if
	-- we skipped and didn't already play.
	run_on_skip = true,
	no_overlap = true,

	func = function(inst, param, data)
		TheWorld.components.ambientaudio:StopAllMusic()
		TheWorld.components.ambientaudio:StopAmbient()
		TheAudio:PlayPersistentSound(audioid.persistent.boss_music, fmodtable.Event[param.soundevent] or "")
		return param.fallthrough
	end,
	viz = function(self, ui, param)
		local s = String(param.soundevent)
		if param.name then
			s = s .. " as " .. String("audioid.persistent.boss_music")
		end
		return s
	end,
	isvalid = IsValidSoundEffectEvent,
	edit = function(self, editor, ui, event)
		local param = event.param
		editor:SoundEffect(ui, param)
		-- Not sure we should allow any other kinds. Could really mess up
		-- ambientaudio if any persistent sounds can be played.
		param.persistent_key = "boss_music"

		if ui:Button("Reset music") then
			TheLog.ch.Audio:print("***///***eventfuncs.lua: Stopping level music.")
			TheWorld.components.ambientaudio:StopLevelMusic()
			TheWorld.components.ambientaudio:StartMusic()
		end
	end,
})

EventFunc({
	name = "musicbosspause",
	nicename = "Boss Kill Shot Sound",
	required_editor = "cineeditor",
	run_on_skip = true,
	no_overlap = true,

	func = function(inst, param)
		TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_BossKillshot", 1)
		--TheFrontEnd:GetSound():PlaySound(fmodtable.Event.Hit_boss_killshot)
	end,
})

EventFunc({
	name = "musicbossstop",
	nicename = "Play Boss Complete Music",
	required_editor = "cineeditor",
	run_on_skip = true,
	no_overlap = true,

	func = function(inst, param)
		TheLog.ch.AudioSpam:print("Stopping persistent music id:", audioid.persistent.boss_music)
		TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_BossComplete", 1)
		TheWorld.components.ambientaudio:StartAmbient()
		TheWorld.components.ambientaudio:SetIsInBossFlowParameter(false)
	end,
})

EventFunc({
	name = "levelmusicstop",
	nicename = "Stop Level Music",
	required_editor = "cineeditor",
	run_on_skip = true,
	no_overlap = true,

	func = function(inst, param)
		TheLog.ch.Audio:print("***///***eventfuncs.lua: Stopping level music.")
		TheWorld.components.ambientaudio:StopLevelMusic()
	end,
})

EventFunc({
	name = "roommusicstop",
	nicename = "Stop Room Music",
	required_editor = "cineeditor",
	run_on_skip = true,
	no_overlap = true,

	func = function(inst, param)
		TheLog.ch.Audio:print("***///***eventfuncs.lua: Stopping room music.")
		TheWorld.components.ambientaudio:StopRoomMusic()
	end,
})

EventFunc({
	name = "bossmusicstop",
	nicename = "Stop Boss Music",
	required_editor = "cineeditor",
	run_on_skip = true,
	no_overlap = true,

	func = function(inst, param)
		TheLog.ch.Audio:print("***///***eventfuncs.lua: Stopping boss music.")
		TheWorld.components.ambientaudio:StopBossMusic()
	end,
})

EventFunc({
	name = "allmusicstop",
	nicename = "Stop All Music",
	required_editor = "cineeditor",
	run_on_skip = true,
	no_overlap = true,

	func = function(inst, param)
		TheLog.ch.Audio:print("***///***eventfuncs.lua / cinematic editor: Stopping level music.")
		TheWorld.components.ambientaudio:StopAllMusic()
	end,
})

EventFunc({
	name = "ambientstop",
	nicename = "Stop Ambient Sounds",
	required_editor = "cineeditor",
	run_on_skip = true,
	no_overlap = true,

	func = function(inst, param)
		TheLog.ch.Audio:print("***///***eventfuncs.lua / cinematic editor: Stopping all ambient sounds.")
		TheWorld.components.ambientaudio:StopAmbient()
	end,
})

EventFunc({
	name = "ambientstop",
	nicename = "Stop All Music and Ambient Sounds",
	required_editor = "cineeditor",
	run_on_skip = true,
	no_overlap = true,

	func = function(inst, param)
		TheLog.ch.Audio:print("***///***eventfuncs.lua / cinematic editor: Stopping all ambient sounds.")
		TheWorld.components.ambientaudio:StopEverything()
	end,
})

EventFunc({
	name = "gotostate",
	nicename = "Goto State",
	-- We've pivoted to use gotostate for any anim that's heavily embellished
	-- to author fx/sfx in the more familiar embellisher.
	required_editor = "cineeditor",
	func = function(inst, param)
		-- If no goto state is selected, then don't do anything.
		if not param.statename then
			return
		end

		if inst.sg and inst.sg:HasState(param.statename) then
			local data = inst.sg.states and inst.sg.states[param.statename] and inst.sg.states[param.statename]:Debug_GetDefaultDataForTools() or nil
			inst.sg:GoToState(param.statename, data)
		else
			TheLog.ch.Cine:print("ERROR: gotostate but missing a stategraph or state:", inst, param.statename)
		end
	end,
	viz = function(self, ui, param)
		return String(param.statename)
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		if not inst.sg then
			ui:TextColored(WEBCOLORS.YELLOW, "Select an actor with a StateGraph.")
			return
		end
		param.statename = editor:StateGraphStateName(ui, "State", param.statename, inst)
	end,
})

EventFunc({
	name = "setvisible",
	nicename = "Set Visibility",
	required_editor = "cineeditor",
	func = function(inst, param)
		local cineutil = require "prefabs.cineutil"
		if param.show then
			cineutil.ShowActor(inst)
		else
			cineutil.HideActor(inst)
		end
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		param.show = ui:_Checkbox("Is Visible", param.show)
	end,
})

EventFunc({
	name = "teleport",
	nicename = "Teleport",
	required_editor = "cineeditor",

	func = function(inst, param, cine_prefab)
		local pos = param.pos or Vector3.zero
		local targets = { inst }

		local base_pos = (cine_prefab and cine_prefab:GetPosition()) or Vector3.zero
		if param.target_role == "lead" then
			base_pos = cine_prefab.cine.roles.lead:GetPosition()
		elseif param.target_role == "sub" then
			local sub_actor = cine_prefab.cine.subactors[param.sub_actor_idx or 1]
			if sub_actor then
				base_pos = sub_actor:GetPosition()
			end
		elseif param.target_role == "players" then
			base_pos = AllPlayers[1]:GetPosition() -- TODO: Handle multiple players & networking
		else -- 'scene' teleport target; teleports to absolute world coodinates
			base_pos = Vector3.zero
		end

		for _,ent in ipairs(targets) do
			ent.Transform:SetPosition(base_pos.x + pos.x, base_pos.y, base_pos.z + pos.z)
		end
	end,
	viz = function(self, ui, param)
		local pos = param.pos or Vector3.zero
		local s = ""
		if param.target_role == "players" then
			s = s .. "players"
		else
			s = s .. "self"
		end
		s = s .. " to "

		if param.target_role == "lead" then
			s = s .. "Lead actor"
		elseif param.target_role == "sub" then
			s = s .. "Sub actor"
		else
			s = s .. "root position"
		end

		s = s .. (" with an offset of (%0.1f, 0, %0.1f)"):format(pos.x, pos.z)
		return s
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param

		local idx = lume.find(editor.owner.roles, param.target_role) or 1
		local changed = false
		changed, idx = ui:Combo("Target Role##Target", idx, editor.owner.roles_pretty)
		if changed then
			param.target_role = editor.owner.roles[idx]
		end
		if ui:IsItemHovered() then
			ui:SetTooltip("Teleports the selected role to the position of the selected target. Select 'Scene' to teleport to the cinematic's root position.")
		end

		if param.target_role == editor.owner.roles[3] then -- Sub actor
			local names = {}
			for _, subactor in ipairs(editor.owner.params.subactors) do
				local subactor_name = subactor.label .. " (" .. subactor.prefabname .. ")"
				table.insert(names, subactor_name)
			end
			local sub_actor_changed, sub_actor_idx = ui:Combo("Sub Actor:##Target", param.sub_actor_idx or 1, names)
			if sub_actor_changed then
				param.sub_actor_idx = sub_actor_idx
			end
		else
			param.sub_actor_idx = nil
		end

		editor:WorldPosition(ui, "Offset Position", param)
		if ui:IsItemHovered() or ui:IsItemClicked() then
			local pos = param.pos or Vector3.zero
			DebugDraw.GroundCircle(pos.x, pos.z, 2)
		end
	end,
})

EventFunc({
	name = "movetopoint",
	nicename = "Move Towards",
	required_editor = "cineeditor",
	no_nil_duration = true,

	func = function(inst, param, cine)
		local basepos = not param.use_world_pos and cine:GetPosition() or Vector3(0, 0, 0)
		local pos = param.pos or Vector3(0, 0, 0)
		if inst:HasTag("player") then -- TODO: Handle multiple players & networking
			local timeout_ticks = param.duration * ANIM_FRAMES
			local run_threshold = 3
			inst.components.forcedlocomote:LocomoteTo(basepos + pos, timeout_ticks, param.threshold or run_threshold)
		else
			local function _OnMoveToComplete(inst)
				inst.Physics:Stop()
			end

			inst:ListenForEvent("movetopoint_complete", function(inst)
				_OnMoveToComplete(inst)
				inst:RemoveEventCallback("movetopoint_complete", _OnMoveToComplete)
				inst.sg:GoToState(param.pst_state or "idle")
			end)
			SGCommon.Fns.MoveToPoint(inst, basepos + pos, param.duration * ANIM_FRAMES / SECONDS)
			inst.sg:GoToState(param.pre_state or "idle")
		end
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		local pos, changed = editor:WorldPosition(ui, "Destination Point", param)
		if ui:IsItemHovered() then
			ui:SetTooltip("NOTE: Destination point is an offset relative to the lead actor start position or Scene Actor World Position.")
		end

		if changed then
			local base_x, base_y, base_z = editor.owner.testprefab:GetPosition():Get()
			param.pos = { x = pos.x + base_x, y = pos.y + base_y, z = pos.z + base_z }
		end

		local use_world_pos = param.use_world_pos
		use_world_pos = ui:_Checkbox("World coordinates", use_world_pos)
		param.use_world_pos = use_world_pos == true or nil

		param.pre_state = editor:StateGraphStateName(ui, "Pre Movement State", param.pre_state, inst)
		param.pst_state = editor:StateGraphStateName(ui, "Post Movement State", param.pst_state, inst)
	end,
})

local runintoscene_threshold = 3
EventFunc({
	name = "runintoscene",
	nicename = "Run Players Into Scene",
	required_editor = "cineeditor",
	no_nil_duration = true,
	no_overlap = true,

	func = function(inst, param)
		local pos = param.pos and Vector3(param.pos) or Vector3.zero
		local timeout_ticks = param.duration * ANIM_FRAMES
		for _,player in ipairs(AllPlayers) do
			player.components.forcedlocomote:LocomoteTo(pos, timeout_ticks, param.threshold or runintoscene_threshold)
		end
	end,
	viz = function(self, ui, param)
		local pos = param.pos or Vector3.zero
		return ("to within %0.1f of (%0.1f, 0, %0.1f)%s"):format(
			param.threshold or runintoscene_threshold,
			pos.x,
			pos.z,
			DurationViz(param.duration))
	end,
	edit = function(self, editor, ui, event, inst)
		local param = event.param
		editor:WorldPosition(ui, "World Destination", param)
		local should_draw = ui:IsItemHovered()
		param.threshold = ui:_DragFloat("Threshold", param.threshold or runintoscene_threshold, 0.1, 2, 10)
		should_draw = should_draw or ui:IsItemHovered()
		if should_draw then
			local pos = param.pos or Vector3.zero
			DebugDraw.GroundCircle(pos.x, pos.z, param.threshold or runintoscene_threshold)
		end
		ui:TextWrapped("Will stop moving when within threshold of destination *or* after event ends.")
	end,
	isvalid = function(self, editor, event, testprefab)
		return event.param.pos ~= nil
	end,
})

-- end CineEditor-only events
--------------------------------------------------------------



return eventfuncs
