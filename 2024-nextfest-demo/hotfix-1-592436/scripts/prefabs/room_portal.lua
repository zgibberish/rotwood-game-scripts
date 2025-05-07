local biomes = require "defs.biomes"
local color = require "math.modules.color"
local ease = require "util.ease"
local gate_tuning = require "defs.gate_tuning"
local lume = require "util.lume"

local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

-- "Unlock" means the gate allows the player to pass.
-- "Excite" means the player is close so we show activity.

local tuning = {
	fade_in_seconds = 0.85,
	delay_seconds = 0.3,
	-- Only one bloom colour but two different intensities depending on state.
	-- That makes it easier to smoothly blend between the different states.
	bloom_color = color(202/255, 44/255, 255/255, 1),
	bloom_intensity_unlock = 0.6,
	bloom_intensity_nearby = 1.0,
	add_color = color(255/255, 180/255, 240/255, 0),
	add_intensity_unlock = 0.5,
	add_intensity_nearby = 1.0,
	nearby_radius = 5,
}
tuning.unlock_max_bloom = tuning.bloom_color:multiply(tuning.bloom_intensity_unlock)
tuning.unlock_max_add = tuning.add_color:multiply(tuning.add_intensity_unlock)

local prefabs = {
	indicator = "gate_indicator",
}

local function SetIndicatorUnlockProgress(inst, progress)
	progress = ease.quadout(progress)
	local add = tuning.unlock_max_add:multiply(progress)
	inst.components.coloradder:PushColor("indicator_activation", add:unpack())
	local bloom = tuning.unlock_max_bloom:multiply(progress)
	inst.components.bloomer:PushBloom("indicator_activation", bloom:unpack())
end

local function SetIndicatorExciteProgress(inst, progress)
	progress = ease.quadout(progress)
	if lume.approximately(progress, 0, 0.001) then
		-- Our 0 value isn't 0, so manually pop.
		inst.components.bloomer:PopBloom("indicator_excite")
		inst.components.coloradder:PopColor("indicator_excite")

	else
		-- adder/bloomer merges their values, so we need the bottom to start at
		-- the unlocked value and only apply our additional amount (assume the
		-- unlock colours are already applied.

		local add_progress = lume.lerp(tuning.add_intensity_unlock, tuning.add_intensity_nearby, progress) - tuning.add_intensity_unlock
		local add = tuning.add_color:multiply(add_progress)
		inst.components.coloradder:PushColor("indicator_excite", add:unpack())

		-- We don't subtract bloom_intensity_unlock here because, unlike add,
		-- it makes the transition worse. Maybe related to how bloom merges
		-- values?
		local bloom_progress = lume.lerp(tuning.bloom_intensity_unlock, tuning.bloom_intensity_nearby, progress)
		local bloom = tuning.bloom_color:multiply(bloom_progress)
		inst.components.bloomer:PushBloom("indicator_excite", bloom:unpack())
	end
end

local function UnlockIndicator(inst)
	return inst:DoDurationTaskForTicks(
		math.ceil(tuning.fade_in_seconds * SECONDS),
		inst.SetIndicatorUnlockProgress,
		math.ceil(tuning.delay_seconds * SECONDS))
end

local function ExciteIndicator(inst, cmd)
	local fn = inst.SetIndicatorExciteProgress
	if cmd == "invert" then
		fn = function(inst_, progress)
			return inst.SetIndicatorExciteProgress(inst_, 1 - progress)
		end
	end
	return inst:DoDurationTaskForTicks(
		math.ceil(tuning.fade_in_seconds * SECONDS),
		fn)
end

local function DebugDrawEntity_gateindicator(inst, ui, panel, colors)
	local scale = inst.AnimState:GetScale()
	local changed,new_scale = ui:DragFloat("Scale", scale)
	if changed then
		inst.AnimState:SetScale(new_scale, new_scale)
	end

	ui:TextColored(colors.header, "Room Unlock Activation")
	local new_bloom
	changed,new_bloom = ui:SliderFloat("Preview Progress", inst._edit_bloom_progress or 0, 0, 1)
	if changed then
		inst._edit_bloom_progress = new_bloom
		inst:SetIndicatorUnlockProgress(new_bloom)
	end
	tuning.delay_seconds = ui:_DragFloat("Delay Duration", tuning.delay_seconds, 0.01, 0.1, 10, "%0.2f seconds")
	tuning.fade_in_seconds = ui:_DragFloat("Anim Duration", tuning.fade_in_seconds, 0.01, 0.1, 10, "%0.2f seconds")
	tuning.bloom_color = ui:_ColorObjEdit("Bloom Color", tuning.bloom_color)
	tuning.add_color = ui:_ColorObjEdit("Add Color", tuning.add_color)

	local intensities = {
		"bloom_intensity_unlock",
		"bloom_intensity_nearby",
		"add_intensity_unlock",
		"add_intensity_nearby",
	}
	for _,key in ipairs(intensities) do
		tuning[key] = ui:_SliderFloat(key, tuning[key], 0, 1)
	end
	-- Color or intensities may have modified these max values.
	tuning.unlock_max_bloom = tuning.bloom_color:multiply(tuning.bloom_intensity_unlock)
	tuning.unlock_max_add = tuning.add_color:multiply(tuning.add_intensity_unlock)

	local function CancelTask(inst_)
		if inst._edit_bloom_task then
			inst._edit_bloom_task:Cancel()
		end
	end

	if ui:Button(ui.icon.playback_jump_back .."##unlock") then
		CancelTask(inst)
		inst:SetIndicatorUnlockProgress(0)
	end
	ui:SameLineWithSpace()
	if ui:Button(ui.icon.playback_play .." Unlock##unlock") then
		CancelTask(inst)
		inst._edit_bloom_task = inst:UnlockIndicator()
	end
	if ui:Button(ui.icon.playback_jump_back .."##excite") then
		CancelTask(inst)
		inst:SetIndicatorExciteProgress(0)
	end
	ui:SameLineWithSpace()
	if ui:Button(ui.icon.playback_play .." Excite##excite") then
		CancelTask(inst)
		inst._edit_bloom_task = inst:ExciteIndicator()
	end
	ui:SameLineWithSpace()
	if ui:Button(ui.icon.playback_play .." Unexcite##excite") then
		CancelTask(inst)
		inst._edit_bloom_task = inst:ExciteIndicator("invert")
	end
	--~ ui:Value("Raw Config", table.inspect(tuning, { depth = 5, process = table.inspect.processes.skip_mt, }))
end

local function OnPostLoadWorld(inst)
	local worldmap = TheDungeon:GetDungeonMap()
	local biome_location = worldmap.nav:GetBiomeLocation()

	local cardinal = inst.components.roomportal:GetCardinal()

	local data = gate_tuning.GetTuningForCardinal(cardinal)
	if data then
		local world = data.world
		inst.components.playerproxrect:SetRect(table.unpack(world.hitbox))

		if true then
			local room = worldmap:GetDestinationForCardinalDirection(cardinal)
			local anim = room and worldmap.nav:GetArtNameForRoom(room)
			if worldmap:IsDebugMap()
				and cardinal ~= "west"
			then
				-- Always show indicator in debug maps so it isn't obscured by
				-- placements.
				anim = "coin1"
			end
			local pos = inst:GetPosition() + world.indicator
			if anim then
				TheLog.ch.Spawn:printf("'%s' SPAWNS: '%s'", tostring(inst), prefabs.indicator)
				inst.indicator = SpawnPrefab(prefabs.indicator, inst)
				inst.indicator.persists = false
				inst.indicator.Transform:SetPosition(pos:Get())
				inst.indicator.Transform:SetRotation(world.indicator_rot or 0)
				local s = world.indicator_scale or 1
				inst.indicator.AnimState:SetScale(s, s)
				inst.indicator.AnimState:PlayAnimation(anim)
				inst.indicator.DebugDrawEntity = DebugDrawEntity_gateindicator
				inst.indicator.SetIndicatorUnlockProgress = SetIndicatorUnlockProgress
				inst.indicator.SetIndicatorExciteProgress = SetIndicatorExciteProgress
				inst.indicator.UnlockIndicator = UnlockIndicator
				inst.indicator.ExciteIndicator = ExciteIndicator
				inst.indicator.components.playerproxradial:SetRadius(tuning.nearby_radius)
			end

			local gate_prefab = biome_location.gate_prefab_fmt:format(cardinal:sub(1,1))
			TheLog.ch.Spawn:printf("'%s' SPAWNS: '%s'", tostring(inst), gate_prefab)
			inst.gate = SpawnPrefab(gate_prefab, inst)
			assert(inst.gate)
			inst.gate:SetStateGraph("sg_roomgate")
			-- You can't save changes to the prop, but we'll allow you to edit
			-- it to tweak how it should look.
			--~ inst.gate.components.prop:IgnoreEdits()
			--~ inst.gate.components.prop.ListenForEdits = function() end
			pos = inst:GetPosition() + world.gate
			inst.gate.Transform:SetPosition(pos:Get())

			if room then
				function inst.gate:SetGateLocked(is_locked, instant)
					is_locked = is_locked or not room
					local gate_anim = is_locked and "idle" or "open"
					self.sg:GoToState(gate_anim, instant)

					if inst.indicator then
						inst.indicator.sg:GoToState(is_locked and "locked" or "unlocked")
					end
				end
			else
				-- No destination so always stay in blocked state.
				function inst.gate:SetGateLocked(...)
					self.sg:GoToState("blocked")
				end
			end
			inst.gate:SetGateLocked(inst.is_room_locked, true)

			-- MapLayout:EliminateInvalidExits will blocked exits, but we still
			-- spawn gates so their physics will block players when world
			-- collision is manually authored.
			if not worldmap:HasGateInCardinalDirection(cardinal)
				and not TheWorld.has_debug_visible_exits
			then
				inst.gate:Hide()
			end
		end
	else
		print("Invalid room_portal cardinal: "..tostring(cardinal))
		dbassert(false)
		inst:DoTaskInTicks(0, inst.Remove)
	end
end

local function OnRoomLocked(inst)
	inst.is_room_locked = true
	-- nosimreset: gate can be invalidated by being deleted first during TransitionLevel
	if inst.gate and inst.gate:IsValid() then
		inst.gate:SetGateLocked(inst.is_room_locked)
	end
end

local function OnRoomUnlocked(inst)
	inst.is_room_locked = false
	-- nosimreset: gate can be invalidated by being deleted first during TransitionLevel
	if inst.gate and inst.gate:IsValid() then
		inst.gate:SetGateLocked(inst.is_room_locked)
	end
end

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddTransform()

	inst:AddTag("block_worldbounds")
	inst:AddTag("CLASSIFIED")
	--[[Non-networked entity]]

	inst:AddComponent("roomportal")
	inst:AddComponent("playerproxrect")

	inst.OnPostLoadWorld = OnPostLoadWorld

	inst:ListenForEvent("room_locked", function() OnRoomLocked(inst) end, TheWorld)
	inst:ListenForEvent("room_unlocked", function() OnRoomUnlocked(inst) end, TheWorld)
	if not TheWorld.components.roomlockable:IsLocked() then
		OnRoomUnlocked(inst)
		inst.components.roomportal:OnRoomUnlocked(inst)
	end

	if TheDungeon:GetDungeonMap():IsDebugMap() then
		inst.components.playerproxrect:SetDebugDrawEnabled(true)
	end

	return inst
end

-- Biomes specify gate dependencies and that's handled in the world.
local prefabs_deps = lume.values(prefabs)
return Prefab("room_portal", fn, nil, prefabs_deps)
