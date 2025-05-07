local GameEventNamer = require "debug.inspectors.gameeventnamer"
local PrefabEditorBase = require "debug.inspectors.prefabeditorbase"
local eventfuncs = require "eventfuncs"
local fmodtable = require "defs.sound.fmodtable"
local fxdata = require "prefabs.fx_autogen_data"
local lume = require "util.lume"
local particledata = require "prefabs.particles_autogen_data"
local soundutil = require "util.soundutil"
require "class"


local animtagger_static = PrefabEditorBase.MakeStaticData("animtag_autogen_data")


-- The editor that's passed into eventfuncs.
local EventFuncEditor = Class(function(self, owner)
	-- Should limit accesses to owner to what's in PrefabEditorBase and testprefab.
	self.owner = owner

	self.registeredfx = {}
	self.registeredparticles = {}
	self.eventnamer = GameEventNamer()
	-- For StateGraph.State:Debug_GetDefaultDataForTools
	self.state_cleanup = {
		spawned = {},
		cb = {},
	}
end)


function EventFuncEditor:DrawViz(ui, event, testprefab)
	local eventdef = eventfuncs[event.eventtype]

	local s = eventdef.nicename or eventdef.name
	if eventdef.viz and testprefab then
		s = s .. " " .. eventdef:viz(ui, event.param)
	end
	ui:Text(s)
end

function EventFuncEditor:RegisterFX(fx)
	self.registeredfx[fx] = true
end

function EventFuncEditor:UnregisterFX(fx)
	self.registeredfx[fx] = nil
end

function EventFuncEditor:RemoveAllFX()
	for i, v in pairs(self.registeredfx) do
		i:Remove()
	end
	self.registeredfx = {}
end

function EventFuncEditor:RegisterParticles(particles)
	self.registeredparticles[particles] = true
end

function EventFuncEditor:UnregisterParticles(particles)
	self.registeredparticles[particles] = nil
end

function EventFuncEditor:RemoveAllParticles()
	for i, v in pairs(self.registeredparticles) do
		i:Remove()
	end
	self.registeredparticles = {}
end

function EventFuncEditor:SetDeltaTimeMultiplier(mult)
	for i, v in pairs(self.registeredfx) do
		i.AnimState:SetDeltaTimeMultiplier(mult)
	end
	for i, v in pairs(self.registeredparticles) do
		i.components.particlesystem:SetDeltaTimeMultiplier(mult)
	end
end


local NONEGROUP = "NONEGROUP"

local function CollectGroups(data, current)
	local curgroup = NONEGROUP
	local allgroups = {}
	for k,v in pairs(data) do
		if current == k then
			curgroup = v.group
		end
		if v.group then
			allgroups[v.group] = true
		end
	end
	local groups = lume.keys(allgroups)
	table.sort(groups, function(a,b) return string.upper(a) < string.upper(b) end)
	table.insert(groups, 1, "<None>")

	return curgroup, groups
end

local function GetKeysMatchingGroup(data, curgroup)
	local items = {}
	for k,v in pairs(data) do
		if curgroup == NONEGROUP or v.group == curgroup then
			table.insert(items, k)
		end
	end
	table.insert(items,"")
	table.sort(items, function(a,b) return string.upper(a) < string.upper(b) end)
	return items
end

function EventFuncEditor:SoundEffect(ui, param, allow_empty)
	local soundnames = lume.keys(fmodtable.Event)
	table.sort(soundnames, function(a,b) return string.upper(a) < string.upper(b) end)
	if allow_empty then
		table.insert(soundnames, 1, "")
	end

	param.soundevent = ui:_ComboAsString("Sound Event", param.soundevent, soundnames, allow_empty)

	ui:Indent() do
		local sound = TheFrontEnd:GetSound()
		if ui:Button("Play##soundevent", nil, nil, param.soundevent == nil) then
			sound:PlaySound(fmodtable.Event[param.soundevent], "SoundEffect_Test", param.volume)
		end
		ui:SameLineWithSpace()
		if ui:Button("Stop##soundevent") then
			sound:KillSound("SoundEffect_Test")
		end
		ui:Value("Timeline Position", sound:GetTimelinePosition("SoundEffect_Test"))
	end ui:Unindent()

	return param.soundevent
end

function EventFuncEditor:SoundMaxCount(ui, param, inst)
	if ui:Checkbox("Limit/Track Sound Count##SoundMaxCount", param.sound_max_count) then
		if param.sound_max_count then
			param.sound_max_count = nil
		else
			param.sound_max_count = 3
		end
	end
	ui:Indent() do
		local show_tooltip = ui:IsItemHovered()
		if param.sound_max_count then
			self:SoundInstigator(ui, inst)
		end
		if param.sound_max_count then
			param.sound_max_count = ui:_SliderInt("Max Count per Instigator##SoundMaxCount", param.sound_max_count, 1, 10)
			ui:Text([[Parameters:
startCount_instigator - Count playing when this sound started.
recentCount_instigator - Count of this sound *started* "recently".
activeCount_instigator - Current playing count. Updated when a new sound plays.]])
		end
		show_tooltip = show_tooltip or ui:IsItemHovered()
		if show_tooltip then
			ui:SetTooltipMultiline({
					"Limit the number of times this sound can play per instigator",
					"(the thing that caused it to play -- usually a player).",
				})
		end
	end ui:Unindent()
	return param.sound_max_count
end

function EventFuncEditor:SoundWindow(ui, param, inst)
	param.window_frames = ui:_SliderInt("Window Duration##window", param.window_frames or 5, 1, 100)
	ui:TextWrapped(("Window closes and sound plays after %d frames or when entity gets destroyed, whichever comes first. Sound plays on entity that opened the window."):format(param.window_frames))
	self:SoundInstigator(ui, inst)
	ui:Text([[Parameters:
countDuringWindow_instigator - number of times it tried to play (including the first).]])
end

function EventFuncEditor:SoundAutostop(ui, param)
	local is_loop = soundutil.IsLoop(param.soundevent)
	param.autostop = ui:_Checkbox("Stop on Remove##SoundData", param.autostop or is_loop) or nil
	if ui:IsItemHovered() then
		local tip = {
			-- We often put entities into limbo when they die which removes
			-- them from the scene, but doesn't destroy. The distinction isn't
			-- too important for designers.
			"Stop (with fadeout) when this entity is removed from scene or destroyed (usually after death).",
		}
		if is_loop then
			table.insert(tip, 1, "Looping sounds are *always* Stop on Remove.")
		end
		ui:SetTooltipMultiline(tip)
	end
end

function EventFuncEditor:SoundVolume(ui, param)
	local newvolume = ui:_SliderInt("Volume##SoundData", param.volume or 100, 0, 100, "%d%%")
	if newvolume then
		if newvolume == 100 then
			newvolume = nil
		end
		param.volume = newvolume
	end
end

function EventFuncEditor:SoundInstigator(ui, inst)
	if not inst then
		ui:TextColored(WEBCOLORS.LIGHTGRAY, "No entity to determine tracking.")
	elseif inst.components.soundtracker then
		ui:TextColored(WEBCOLORS.LIGHTGRAY, "Sound is tracked on this entity.")
	else
		ui:TextColored(WEBCOLORS.LIGHTGRAY, "Sound is tracked on the world.")
	end
end

-- Sound effect, volume, maxcount
function EventFuncEditor:SoundData(ui, param, allow_empty, key)
	local root_param = param
	if key then
		-- Change the destination key since we often want to stuff it in a
		-- "sound" table.
		param = root_param[key] or {}
	end
	self:SoundEffect(ui, param, allow_empty)
	self:SoundVolume(ui, param)
	self:SoundAutostop(ui, param)
	self:SoundMaxCount(ui, param)
	if key then
		if not next(param) then
			param = nil
		end
		root_param[key] = param
	end
end

function EventFuncEditor:SoundSnapshot(ui, param, allow_empty)
	local soundnames = lume.keys(fmodtable.Snapshot)
	table.sort(soundnames, function(a,b) return string.upper(a) < string.upper(b) end)
	if allow_empty then
		table.insert(soundnames, 1, "")
	end

	param.sound_snapshot = ui:_ComboAsString("Sound Snapshot", param.sound_snapshot, soundnames, allow_empty)

	ui:Indent() do
		if ui:Button("Play##snapshot", nil, nil, param.sound_snapshot == nil) then
			if self.playing_snapshot then
				TheAudio:StopFMODSnapshot(self.playing_snapshot)
			end
			self.playing_snapshot = fmodtable.Snapshot[param.sound_snapshot]
			TheAudio:StartFMODSnapshot(self.playing_snapshot)
		end
		ui:SameLineWithSpace()
		if ui:Button("Stop##snapshot") then
			if self.playing_snapshot then
				TheAudio:StopFMODSnapshot(self.playing_snapshot)
				self.playing_snapshot = nil
			end
		end
		ui:Value("Active Snapshot", self.playing_snapshot)
	end ui:Unindent()

	return param.sound_snapshot
end

function EventFuncEditor:ParticleEffectName(ui, param)
	if param ~= self.lastparticlefxparam then
		self.lastparticlefxparam = param
		self.lastparticlefxeditgroup = nil
	end

	local curgroup, groups = CollectGroups(particledata, param.particlefxname)
	if self.lastparticlefxeditgroup then
		curgroup = self.lastparticlefxeditgroup
	end

	local curind = lume.find(groups, curgroup) or 1
	local newind = ui:_Combo("Group", curind, groups)
	if newind ~= curind then
		curgroup = newind ~= 1 and groups[newind] or nil
		self.lastparticlefxeditgroup = curgroup or NONEGROUP
	end

	local fx = GetKeysMatchingGroup(particledata, curgroup)
	curind = lume.find(fx, param.particlefxname) or 1
	newind = ui:_Combo("Effect", curind, fx)
	param.particlefxname = fx[newind]
	if param.particlefxname == "" then
		param.particlefxname = nil
	end
end

function EventFuncEditor:EffectName(ui, param)
	if param ~= self.lastfxparam then
		self.lastfxparam = param
		self.lastfxeditgroup = nil
	end

	local curgroup, groups = CollectGroups(fxdata, param.fxname)
	if self.lastfxeditgroup then
		curgroup = self.lastfxeditgroup
	end

	local curind = lume.find(groups, curgroup) or 1
	local newind = ui:_Combo("FX Group", curind, groups)
	if newind ~= curind then
		curgroup = newind ~= 1 and groups[newind] or nil
		self.lastfxeditgroup = curgroup or NONEGROUP
	end

	local fx = GetKeysMatchingGroup(fxdata, curgroup)
	curind = lume.find(fx, param.fxname) or 1
	newind = ui:_Combo("FX", curind, fx)
	param.fxname = fx[newind]
	if param.fxname == "" then
		param.fxname = nil
	end
end

function EventFuncEditor:SymbolName(ui, param, prefab)
	if prefab.AnimState then
		local symnames = prefab.AnimState:GetSymbolNames()
		table.sort(symnames)
		table.insert(symnames, 1, "<None>")
		local curind = lume.find(symnames, param.followsymbol) or 1
		local newind = ui:_Combo("On Symbol", curind, symnames)
		param.followsymbol = newind ~= 1 and symnames[newind] or nil
	end
end

function EventFuncEditor:RequestSeeWorld(wants_to_see)
	if wants_to_see then
		self.show_world_until = GetTime() + 1
	end
end

function EventFuncEditor:StateGraphStateName(ui, label, statename, inst)
	local default = "idle"
	local names = lume.keys(inst.sg.sg.states)
	table.sort(names)
	local idx = lume.find(names, statename or default) or 1
	idx = ui:_Combo(label, idx, names)
	statename = names[idx]
	--[[if statename == default then
		statename = nil
	end]]
	return statename
end

-- Push the appropriate style for a modal popup.
--
-- Allows us to turn off the background dim when we want to tune.
-- Pass returned value to PopStyleColor()
function EventFuncEditor:PushModalStyle(ui)
	local should_show_world = self.show_world_until and self.show_world_until > GetTime()
	if should_show_world then
		ui:PushStyleColor(ui.Col.ModalWindowDimBg, { 0, 0, 0, 0 })
		return 1
	end
	return 0
end

function EventFuncEditor:PoseButton(event, ui, prefab)
	local function setAnim(inst, bank, anim, frame)
		if bank then
			inst.AnimState:SetBank(bank)
		end
		if anim then
			inst.AnimState:PlayAnimation(anim)
		end
		inst.AnimState:SetFrame(frame)
		local children = inst.highlightchildren
		if children then
			for i, v in pairs(children) do
				if v.AnimState then
					v.AnimState:SetFrame(frame)
				end
			end
		end
	end

	--	if event.frame then
	-- this only works for animevents
	--		return
	--	end

	ui:SameLine()
	if ui:SmallButton("?") then
		local qualifies = {}
		if event.frame then
			table.insert(qualifies, { frame = event.frame })
		else
			for presetname, preset in pairs(animtagger_static.data) do
				if preset.prefab == prefab.prefab then
					for bankname, bankevents in pairs(preset.anim_events or {}) do
						for animname, animdata in pairs(bankevents or {}) do
							for _, animevent in pairs(animdata.events or {}) do
								if animevent.name == event.name then
									table.insert(
										qualifies,
										{ bankname = bankname, animname = animname, frame = animevent.frame }
									)
								end
							end
						end
					end
				end
			end
		end
		if #qualifies == 1 then
			local v = qualifies[1]
			setAnim(self.owner.testprefab, v.bankname, v.animname, v.frame)
		elseif #qualifies > 1 then
			ui:OpenPopup(" Select Pose")
			ui:SetNextWindowSize(400, 400)
			self.pose_backup = {
				bank = self.owner.testprefab.AnimState:GetCurrentBankName(),
				anim = self.owner.testprefab.AnimState:GetCurrentAnimationName(),
				frame = self.owner.testprefab.AnimState:GetCurrentAnimationFrame(),
			}

			self.qualifyingposes = qualifies
		end
	end
	if ui:BeginPopupModal(" Select Pose", false, ui.WindowFlags.AlwaysAutoResize) then
		ui:Spacing()
		self.selectedpose = self.selectedpose or 0

		local qualifies = {}
		for i, v in pairs(self.qualifyingposes) do
			table.insert(qualifies, string.format("%s - %s:%d", v.bankname, v.animname, v.frame))
		end

		local changed, new_sel_idx = ui:ListBox("##poselist", qualifies, self.selectedpose, 12)
		if changed and new_sel_idx ~= self.selected_anim then
			self.selectedpose = new_sel_idx
			local v = self.qualifyingposes[new_sel_idx]
			setAnim(self.owner.testprefab, v.bankname, v.animname, v.frame)
		end

		self.owner:PushRedButtonColor(ui)
		ui:SameLineWithSpace(20)

		if ui:Button("Okay#pose") then
			ui:CloseCurrentPopup()
			self.qualifyingposes = nil
		end
		self.owner:PopButtonColor(ui)
		ui:SameLineWithSpace()
		if ui:Button("Cancel##pose") then
			ui:CloseCurrentPopup()
			self.qualifyingposes = nil
			setAnim(self.owner.testprefab, self.pose_backup.bank, self.pose_backup.anim, self.pose_backup.frame)
		end
		ui:SameLine()
		ui:Dummy(20, 0)
		ui:Spacing()
		ui:EndPopup()
	end
end

function EventFuncEditor:WorldPosition(ui, label, param)
	local pos = param.pos or Vector3.zero:clone()
	local changed, x, y, z = ui:DragVec3f(
		label,
		pos,
		0.01,
		-100,
		100)
	if changed then
		pos.y = 0
		if Vector3.LengthSq(pos) == 0 then
			param.pos = nil
		else
			param.pos = Vector3.to_table(pos)
		end
	end
	return pos, changed
end

return EventFuncEditor
