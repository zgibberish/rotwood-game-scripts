-- Tag events in animations.

local DebugNodes = require "dbui.debug_nodes"
local Equipment = require "defs.equipment"
local GameEventNamer = require "debug.inspectors.gameeventnamer"
local PrefabEditorBase = require "debug.inspectors.prefabeditorbase"
local SGCommon = require "stategraphs.sg_common"
local WorldAutogenData = require "prefabs.world_autogen_data"
local kstring = require "util.kstring"
local lume = require "util.lume"
local prop_data = require "prefabs.prop_autogen_data"
local spawnutil = require "util.spawnutil"
require "mathutil"


local _static = PrefabEditorBase.MakeStaticData("animtag_autogen_data")

local ANIMNAME_LISTBOX_WIDTH = 300

local AnimTagger = Class(PrefabEditorBase, function(self)
	PrefabEditorBase._ctor(self, _static)

	self.name = "Anim Tagger"
	self.prefab_label = "Tag Collection"

	self.testprefab = nil
	self.playback_speed = 1
	self.test_label = "Tag"

	self.eventnamer = GameEventNamer()

	self:LoadLastSelectedPrefab("animtagger")

	self:WantHandle()
end)

AnimTagger.PANEL_WIDTH = 660
AnimTagger.PANEL_HEIGHT = 990

AnimTagger.MENU_BINDINGS = {
	{
		name = "Help",
		bindings = {
			{
				name = "About AnimTagger",
				fn = function(params)
					params.panel:PushNode(DebugNodes.DebugValue([[
The AnimTagger lets you fire events on specific frames of an animation. You can
listen to these events on the "sg" Events tab of Embellisher or in code.
They're fired on the entity playing the animation.

]] .. DebugNodes.Embellisher.TAG_EXPLAIN))
				end,
			},
		},
	},
}

function AnimTagger:CanTag(animfile, animname)
	if self.testprefab then
		local animfiles = self.testprefab.AnimState:GetCurrentBankAnimFiles()
		for i,v in pairs(animfiles) do
			--print("",i,v)
			if v == animfile then
				animfile = animfile:sub(6)
				animfile = animfile:sub(1, #animfile - #".zip")
				local allanims = self:GetAnimsForAnimFile(self.testprefab, animfile)
				for _,anim in pairs(allanims) do
					if anim == animname then
						return true
					end
				end
			end
		end
	end
	return false
end

function AnimTagger:StartTagging(animfile, animname, frame, weapon)
	if weapon then
		self:SwitchLoadout(weapon)
	end
	if self:CanTag(animfile, animname) then
		animfile = animfile:sub(6)
		animfile = animfile:sub(1, #animfile - #".zip")
		self:SetAnimFile(animfile)
		self.curanim = animname
		self:SetAnimation(self.curanim)
		self.testprefab.AnimState:SetFrame(frame or 1)
		self.curframe = frame
		self:SetDirty()
	end
end

function AnimTagger:OnPrefabDropdownChanged(prefabname)
	AnimTagger._base.OnPrefabDropdownChanged(self, prefabname)

	self:DespawnPrefab()
	self.desiredloadout = nil
end

function AnimTagger:OnRevert(params)
	-- params have already been reset
	ApplyAnimEvents()
end

function AnimTagger:DespawnPrefab()
	if self.testprefab then
		self.testprefab:Remove()
		self.testprefab = nil
	end
end

function AnimTagger:OnDeactivate()
	self:DespawnPrefab()
	AnimTagger._base.OnDeactivate(self)
end

-- Generate the prefab
local function MakeAutogenAnimTest(name, params, debug)
	local assets = {}

	local function fn()
		local inst = CreateEntity()
			:TagAsDebugTool()

		inst.entity:AddTransform()
		inst.Transform:SetTwoFaced()
		inst.entity:AddAnimState()
		--[[Non-networked entity]]

		inst.persists = false

		return inst
	end

	return Prefab(name, fn, assets)
end

function AnimTagger:SpawnEditPrefab()
end

function AnimTagger:SetAnimFile(file)
	local params = _static.data[self.prefabname]
	self.animfile = file
	self.allanims = self:GetAnimsForAnimFile(self.testprefab, self.animfile)
	local allprefabs = _static.data
	-- set up the foreign events for display
	self.foreign_events = {}
	for prefab, prefab_params in pairs(allprefabs) do
		if prefab_params ~= params then
			for bankname, bankanims in pairs(prefab_params.anim_events or {}) do
				if bankname == self.animfile then
					for animname, eventdata in pairs(bankanims or {}) do
						self.foreign_events[animname] = self.foreign_events[animname] or {}
						for _, event in pairs(eventdata.events or {}) do
							table.insert(self.foreign_events[animname], {event = event, prefab = prefab})
						end
					end
				end
			end
		end
	end
end

function AnimTagger:Test(prefab, params)
	if TheWorld == nil then
		return
	end

	AnimTagger._base.Test(self, prefab, params)
	self:DespawnPrefab()

	self.prefab_selection = self.prefab_selection or 1
	prefab = params.prefab[self.prefab_selection].prefab or "player_side"
	if not PrefabExists(prefab) then
		RegisterPrefabs(MakeAutogenAnimTest(prefab, params, true))
	end
	ExecuteConsoleCommand("d_allprefabs()")
	TheSim:LoadPrefabs({ prefab })

	local components_to_keep = {
		"inventory",
		"inventoryhoard",
		"playercontroller",
		"combat",
		"damagebonus",
		"hitbox",
		"playerstatsfxer",
		"health",
		"locomotor",
		"lucky",
		"cabbagetower",
		"cabbagerollstracker",
		"charactercreator",
	}

	local components_to_really_keep = {
		-- these should never be stripped since they manage child state
		-- fixes network assert on tool exit
		"cabbagetower",
		"cabbagerollstracker",
		"charactercreator",
	}

	self.testprefab = spawnutil.SpawnPreviewPhantom(self.handle, prefab, 1.0, components_to_keep)
	--	EntityScript.SetStateGraph = oldSetStateGraph
	self.hasinventory = self.testprefab.components.inventoryhoard

	-- set to a specific loadout if needed
	if self.desiredloadout then
		local inventoryhoard = self.testprefab.components.inventoryhoard
		local slot = Equipment.Slots.WEAPON
		inventoryhoard:Debug_GiveItem(slot, self.desiredloadout, 1, true)
	end

	if self.testprefab.components.inventoryhoard then
		local inventoryhoard = self.testprefab.components.inventoryhoard
		local slot = Equipment.Slots.WEAPON
		self.currentweapon = inventoryhoard:GetEquippedItem(slot)
	else
		self.currentweapon = nil
	end

	-- and remove the components we kept around for weapon switching
	for _, v in pairs(components_to_keep) do
		if not table.arrayfind(components_to_really_keep, v) then
			self.testprefab:RemoveComponent(v)
		end
	end

	self.testprefab:SetStateGraph()
	SetDebugEntity(self.testprefab)
	-- insert the states to play the anim sequence
	local animfile = self.testprefab.AnimState:GetCurrentAnimationFile()
	-- if no anim is set then grab the first one from the bank
	if not animfile then
		local bankanimfiles = self.testprefab.AnimState:GetCurrentBankAnimFiles()
		for _, _animfile in pairs(bankanimfiles) do
			animfile = _animfile
			break
		end
	end
	if animfile then
		animfile = animfile:sub(6)
		animfile = animfile:sub(1, #animfile - #".zip")
	end
	self:SetAnimFile(animfile)

	self.curframe = 0
	self:SetFrame(self.testprefab, self.curframe)

	self.curanim = self.testprefab.AnimState:GetCurrentAnimationName()

	self.playing = false
	self:SetTimeMultiplier(self.testprefab, 0)
end

function AnimTagger:SetTimeMultiplier(inst, mult)
	inst.AnimState:SetDeltaTimeMultiplier(mult)
	local children = inst.highlightchildren
	if children then
		for i, v in pairs(children) do
			if v.AnimState then
				v.AnimState:SetDeltaTimeMultiplier(mult)
			end
		end
	end
end

function AnimTagger:SetFrame(inst, frame)
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

function AnimTagger:Cleanup(params)
	table.remove_emptychildren(params)
end

function AnimTagger:DeleteEvent(curanim, params, event)
	-- actually delete the event
	local events = params.anim_events or {}
	local bankevents = events[self.animfile] or {}
	local animevents = bankevents[curanim] or {}
	local genevents = animevents.events or {}
	for j, k in pairs(genevents) do
		if k == event then
			table.remove(genevents, j)
			break
		end
	end
	-- clean out potential empty tables
	if not next(params.anim_events[self.animfile][curanim].events) then
		params.anim_events[self.animfile][curanim].events = nil
	end
	if not next(params.anim_events[self.animfile][curanim]) then
		params.anim_events[self.animfile][curanim] = nil
	end
	if not next(params.anim_events[self.animfile]) then
		params.anim_events[self.animfile] = nil
	end
	if not next(params.anim_events) then
		params.anim_events = nil
	end
	-- Re-apply the events to the timeline
	ApplyAnimEvents(params)
	self:SetDirty()
end

function AnimTagger:Apply()
	ApplyAnimEvents()
	self:SetDirty()
end


function AnimTagger:IsExistingPrefabName(prefab)
	return self.static.data[prefab] and true
end

function AnimTagger:GetAnimsForAnimFile(inst, animfile)
	-- Get the anims. If we're a compound object then massage the data accordingly
	local labels = inst.AnimState:GetAnimNamesFromAnimFile(animfile)

	local allanims = {}
	local children = inst.highlightchildren
	if children then
		local baseanims = {}
		table.insert(baseanims, inst.baseanim)

		for i, v in pairs(children) do
			table.insert(baseanims, v.baseanim)
		end

		local resanims = {}
		for i, anim in pairs(labels) do
			local actual_anim = nil -- this will drop any anims that don't apply to the layered object, like leaves_l1 in tree. Entirely not sure how to deal with that
			for _, v in pairs(baseanims) do
				local postfix = "_"..v
				if kstring.endswith(anim, postfix) then
					actual_anim = anim:sub(1, math.max(#anim - #postfix, 0))
					break
				end
			end
			if actual_anim then
				resanims[actual_anim] = true
			end
		end
		for i, v in pairs(resanims) do
			table.insert(allanims, i)
		end
	else
		for i, v in pairs(labels) do
			table.insert(allanims, v)
		end
	end
	table.sort(allanims)
	return allanims
end

function AnimTagger:SetAnimation(anim)
	local children = self.testprefab.highlightchildren
	if children then
		SGCommon.Fns.PlayAnimOnAllLayers(self.testprefab, self.curanim)
	else
		self.testprefab.AnimState:PlayAnimation(self.curanim)
	end
end

function AnimTagger:GetNumFrames(inst)
	local numFrames = inst.AnimState:GetCurrentAnimationNumFrames()
	return numFrames
end

function AnimTagger:SwitchLoadout(weapon, params)
	self.desiredloadout = weapon
	self:Test("animtest_dummy", params or self.params)
	--	self.deferswitchloadad = weapon
end

local function EditEventFrame(ui, event, numFrames)
	local changed, frame = ui:SliderInt("Frame", event.frame, 0, numFrames)
	if changed then
		event.frame = math.clamp(math.floor(frame), 0, numFrames)
	end
	return changed
end

function AnimTagger:_ApplyEventChanges(params)
	TheLog.ch.AnimTagger:print("Apply changes!")
	if deepcompare(self.editevent, self.workevent) then
		return
	end
	TheLog.ch.AnimTagger:print("changed!")
	-- remove the old event
	local animfile = self.animfile
	local name = self.curanim
	params.anim_events = params.anim_events or {}
	params.anim_events[animfile] = params.anim_events[animfile] or {}
	params.anim_events[animfile][name] = params.anim_events[animfile][name] or {}
	params.anim_events[animfile][name].events = params.anim_events[animfile][name].events or {}

	local genevents = params.anim_events[animfile][name].events or {}
	for i, v in pairs(genevents) do
		if v == self.editevent then
			table.remove(genevents, i)
			break
		end
	end
	-- insert the new event
	table.insert(genevents, self.workevent)
	self.editevent = nil
	self.workevent = nil
	-- Re-apply the events to the timeline
	self:Apply()
end

function AnimTagger:GetBaseAnim(prefab)
	-- get the baseanim
	if prop_data[prefab] then
		-- should be able to get the root from there, it's the item at depth 0
		local parallax = prop_data[prefab].parallax
		for j,v in pairs(parallax) do
			if not v.dist or v.dist == 0 then
				local baseanim = v.anim
				return baseanim
			end
		end
	else
		-- not a prop, we're gonna try to spawn it....yuck, but can't think of another way to get the baseanim
		if Prefabs[prefab] and not WorldAutogenData[prefab] then
			-- need debugspawn as the prefab may not be loaded
			local ent = DebugSpawn(prefab)
			if ent then
				local baseanim = ent.baseanim
				ent:Remove()
				return baseanim
			end
		end
	end
end


function AnimTagger:AddEditableOptions(ui, params)
	self.params = params
	--	if self.deferswitchloadad then
	--		self.desiredloadout = self.deferswitchloadad
	--		self:Test("animtest_dummy", params)
	--		self.deferswitchloadad = false
	--	end

	ui:Columns(1)


	ui:Text("Prefabs")

	local prefabs = type(params.prefab)=="table" and params.prefab or { {prefab = params.prefab} }

	self.prefab_selection = self.prefab_selection or 1
	local prefab_selection = self.prefab_selection
	for i=1,#prefabs do
		local clicked
		clicked, prefab_selection = ui:RadioButton("##animbank_selection"..i, prefab_selection, i)
		if clicked then
			self.prefab_selection = i
			self:Test("animtest_dummy", params or self.params)
		end
		ui:SameLineWithSpace(3)
		if ui:Button(ui.icon.add .."##"..i) then
			-- insert another line after this one
			table.insert(prefabs,i+1,{})
			params.prefab = deepcopy(prefabs)
			if self.prefab_selection > i then
				self.prefab_selection = self.prefab_selection + 1
			end
			self:SetDirty()
		end
		ui:SameLineWithSpace(3)
		if ui:Button(ui.icon.remove .."##"..i, nil, nil, i == 1 and #prefabs == 0) then
			-- delete this line
			table.remove(prefabs,i)
			params.prefab = deepcopy(prefabs)
			if self.prefab_selection > i then
				self.prefab_selection = self.prefab_selection - 1
			end
			self:SetDirty()
		end
		ui:SameLineWithSpace(3)
		local oldentry = prefabs[i] or {}
		local oldprefab = oldentry.prefab or ""
		local prefab = PrefabEditorBase.PrefabPicker(ui, "Prefab##"..i, oldprefab)
		if prefab ~= oldprefab then
			local baseanim = self:GetBaseAnim(prefab)
			prefabs[i].baseanim = baseanim

			params.bankfile = nil

			prefabs[i].prefab = prefab
			params.prefab = deepcopy(prefabs)
			self:SetDirty()
		end
	end
	ui:Columns(1)

	ui:Text("Anim Banks")
	local w = ui:GetColumnWidth()
	ui:Columns(2, "overrides", false)
	ui:SetColumnOffset(1, w - 40)

	ui:Columns(1)

	w = ui:GetColumnWidth()
	ui:Columns(4, "", false)
	ui:SetColumnOffset(0, 0)
	ui:SetColumnOffset(1, 80)
	ui:SetColumnOffset(2, w / 3 + 80)
	ui:SetColumnOffset(3, w / 3 * 2 + 80)

	if not self.testprefab then
		return
	end

	if params.build and params.build ~= self.testprefab.AnimState:GetBuild() then
		self.testprefab.AnimState:SetBuild(params.build)
		--self:Test("animtest_dummy",params)
	end
	if params.bankfile and params.bankfile ~= self.testprefab.AnimState:GetCurrentBankName() then
		self.testprefab.AnimState:SetBank(params.bankfile)
	end

	ui:Columns(1)

	local animnames = self.testprefab.AnimState:GetAnimNamesFromAnimFile()
	-- if no anim is playing then get animnames from the bank
	if #animnames == 0 then
		local bankanimfiles = self.testprefab.AnimState:GetCurrentBankAnimFiles()
		for _, animfile in pairs(bankanimfiles) do
			animfile = animfile:sub(6)
			animfile = animfile:sub(1, #animfile - #".zip")
			local allanims = self:GetAnimsForAnimFile(self.testprefab, animfile)
			for _,anim in pairs(allanims) do
				table.insert(animnames, anim)
			end
		end
	end

	self.invalid_prefab = #animnames == 0

	if self.invalid_prefab then
		ui:PushStyleColor(ui.Col.Text, { 0.7, 0, 0, 1 })
		ui:Text("Invalid prefab!")
		ui:PopStyleColor()
	end

	if self.invalid_prefab then
		ui:Spacing()
		ui:Separator()
		ui:Spacing()
	else
		local animbanks = {}
		local animfiles = self.testprefab.AnimState:GetCurrentBankAnimFiles()
		for i, v in pairs(animfiles) do
			--print(i,v)
			local name = v:sub(6)
			name = name:sub(1, #name - #".zip")
			table.insert(animbanks, name)
		end

		table.sort(animbanks)
		local animbank_selections = {}
		local animbank_selection = 1
		for i, animfile in pairs(animbanks) do
			local anims = self:GetAnimsForAnimFile(self.testprefab, animfile)
			local donecount = 0
			for _, v in pairs(anims) do
				local currentanim_events = params.anim_events
					and params.anim_events[animfile]
					and params.anim_events[animfile][v]
					or {}
				donecount = donecount + ((currentanim_events.done == true) and 1 or 0)
			end
			local label = string.format("%s (%d/%d)", animfile, donecount, #anims)
			if donecount == #anims then
				label = ui.icon.done .. "  " .. label
			else
				label = "      " .. label
			end
			table.insert(animbank_selections, label)

			if self.animfile == animfile then
				animbank_selection = i
			end
		end
		-- Radiobuttons for the anim banks
		for i, v in pairs(animbank_selections) do
			local clicked
			clicked, animbank_selection = ui:RadioButton(v, animbank_selection, i)
			if clicked then
				local animfile = animbanks[i]
				self:SetAnimFile(animfile)
				self:SetDirty()
			end
		end

		ui:Spacing()
		ui:Separator()
		ui:Spacing()
		-- Select weapon for prefab since those change the stategraphs.
		if self.testprefab and self.currentweapon then
			-- Line up combo with prefab name.
			local w = ui:GetItemWidth()
			ui:PushItemWidth(w - 70)

			local current = self.currentweapon
			local weapons = lume.keys(Equipment.Items.WEAPON)
			local cur_idx = lume.find(weapons, current.id) or 1
			local changed, new_idx = ui:Combo("Weapon", cur_idx, weapons)
			if changed then
				self:SwitchLoadout(weapons[new_idx], params)
			end

			ui:PopItemWidth()
		end


		if self.curanim then
			ui:Text("Anim File: " .. self.testprefab.AnimState:GetCurrentAnimationFile())
			self.selected_anim = 1
			for i, v in pairs(self.allanims) do
				if self.curanim == v then
					self.selected_anim = i
				end
			end
			local animlabel = (self.allanims[self.selected_anim] or "<nil>")
			if self.testprefab.baseanim then
				animlabel = animlabel.." (root:"..self.testprefab.baseanim..")"
			end
			--ui:Text("Current Animation: " .. (self.allanims[self.selected_anim] or "<nil>")
			ui:Text("Current Animation: " .. animlabel)
			self.curanim = self.allanims[self.selected_anim]

			local numFrames = self:GetNumFrames(self.testprefab)
			if ui:Button(ui.icon.arrow_left) then
				self.curframe = self.curframe - 1
				self.curframe = math.clamp(self.curframe, 1, numFrames)
				self:SetFrame(self.testprefab, self.curframe)
			end
			ui:SameLineWithSpace(5)
			if ui:Button(ui.icon.arrow_right) then
				self.curframe = self.curframe + 1
				self.curframe = math.clamp(self.curframe, 1, numFrames)
				self:SetFrame(self.testprefab, self.curframe)
			end
			ui:SameLineWithSpace(5)
			local format = "%d//" .. string.format("%d", numFrames)
			local xp, yp = ui:GetCursorPos()
			local w = ui:GetColumnWidth()
			ui:PushItemWidth(w - xp + 50)
			local changed, value = ui:SliderInt("##curframe", self.curframe, 0, numFrames-1, format)
			ui:PopItemWidth(w)
			if changed then
				self.curframe = value
				self.curframe = math.clamp(self.curframe, 1, numFrames)
				self:SetFrame(self.testprefab, self.curframe)
			end
		end
		if self.allanims then
			ui:Columns(2, "anims", true)
			ui:SetColumnOffset(1, ANIMNAME_LISTBOX_WIDTH + 10)
			ui:Text("Animation")
			ui:NextColumn()
			local cw = ui:GetColumnWidth()
			ui:Text("Events")
			ui:SameLineWithSpace(5)
			if ui:SmallButton("Add") then
				local postfix
				local baseanim = self.testprefab.baseanim
				if baseanim then
					if self.curanim ~= "" then
						postfix = "_" .. baseanim
					else
						postfix = baseanim
					end
				end
				self.editevent = {
					name = "",
					frame = math.floor(self.curframe),
					postfix = postfix,
					--anim = self.testprefab.AnimState:GetCurrentAnimationName()
				}
				self.workevent = deepcopy(self.editevent)
				self.editevent.tempevent = true -- to ensure we're different
				ui:OpenPopup("Add Event")
				ui:SetNextWindowSize(400, 400)
			end
			local currentanim = params.anim_events
				and params.anim_events[self.animfile]
				and params.anim_events[self.animfile][self.curanim]
				or {}
			ui:SameLine()
			local anim_done = currentanim.done

			local sx, sy = ui:GetCursorPos()
			ui:SetCursorPos(sx + cw - 150, sy)

			local changed, newdone = ui:Checkbox("Done", anim_done)

			if changed then
				params.anim_events = params.anim_events or {}
				params.anim_events[self.animfile] = params.anim_events[self.animfile] or {}
				params.anim_events[self.animfile][self.curanim] = params.anim_events[self.animfile][self.curanim] or {}
				params.anim_events[self.animfile][self.curanim].done = newdone and true or nil
				if not next(params.anim_events[self.animfile][self.curanim]) then
					params.anim_events[self.animfile][self.curanim] = nil
				end
				self:SetDirty()
			end
			ui:NextColumn()

			--ui:Columns(2,"anims_sub",true)
			--ui:SetColumnOffset(1, 210)

			ui:PushItemWidth(ANIMNAME_LISTBOX_WIDTH)

			local labels = {}
			local EVENT = ui.icon.receive .. "  "
			local NOEVENT = "      "
			local UNCHECK = "      "
			local CHECK = ui.icon.done .. "  "
			for i, v in pairs(self.allanims) do
				local candidate = params.anim_events
					and params.anim_events[self.animfile]
					and params.anim_events[self.animfile][v]
					or {}
				if v == "" then
					v = "<BaseAnim>"
				end
				local label = ""
				if candidate.events then
					label = label .. EVENT
				else
					label = label .. NOEVENT
				end
				if candidate.done then
					label = label .. CHECK
				else
					label = label .. UNCHECK
				end
				label = label .. v
				table.insert(labels, label)
			end

			local changed, new_sel_idx = ui:ListBox("##selected_anim", labels, self.selected_anim, 12)
			if changed and new_sel_idx ~= self.selected_anim then
				self.curanim = self.allanims[new_sel_idx]
				self:SetAnimation(self.curanim)

				self.curframe = 0
			end
			ui:PopItemWidth()
			ui:NextColumn()

			-- show the events
			local currentanim_events = params.anim_events
				and params.anim_events[self.animfile]
				and params.anim_events[self.animfile][self.curanim]
				and params.anim_events[self.animfile][self.curanim].events
				or {}

			ui:PushStyleVar(ui.StyleVar.ChildBorderSize, 0)
			ui:BeginChild("Anim Info#animinfo", 0, 300, true)

			-- list the events
			local events = {}
			for i, v in pairs(currentanim_events or {}) do
				table.insert(events, { event = v, index = #events })
			end

			-- inject the foreign events for display only
			local foreign_events = self.foreign_events[self.curanim] or {}
			for i, v in pairs(foreign_events or {}) do
				table.insert(events, { event = v.event, prefab = v.prefab, index = #events, foreign = true })
			end

			table.sort(events, function(a, b)
				if a.event.frame < b.event.frame then
					return true
				else
					return a.event.frame == b.event.frame and a.index < b.index
				end
			end)
			local lastframe
			for i, v in pairs(events) do
				ui:Columns(1)
				local colw = ui:GetColumnWidth()
				local event = v.event
				if event.frame == self.curframe then
					local layer = ui.Layer.WindowGlobal
					local col = 0.4
					local color = { col, col, col }
					local sx, sy = ui:GetCursorScreenPos()
					ui:DrawRectFilled(layer, sx, sy - 3, sx + colw, sy + 20, color)
				end

				ui:Columns(3, "anim events", false)
				ui:SetColumnOffset(1, 70)
				ui:SetColumnOffset(2, 140)

				if v.event.frame ~= lastframe then
					ui:Text(string.format("%-20s", v.event.frame))
					if ui:IsItemClicked() then
						self.curframe = v.event.frame
						self:SetFrame(self.testprefab, self.curframe)
					end
					lastframe = v.event.frame
				end
				ui:NextColumn()

				if not v.foreign then
					if ui:SmallTooltipButton(ui.icon.edit .. "##" .. i, "Edit Event") then
						self.editevent = v.event
						-- to retrofit old events, if there are any
						self.workevent = deepcopy(self.editevent)
						ui:OpenPopup("Edit Event")
						ui:SetNextWindowSize(400, 400)
					end
					ui:SameLineWithSpace(5)
					if ui:SmallTooltipButton(ui.icon.remove .. "##" .. i, "Delete Event") then
						if not TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
							ui:OpenPopup(" Confirm delete?##" .. i)
						else
							-- delete immediately
							self:DeleteEvent(self.curanim, params, v.event)
						end
					end
				end
				if ui:BeginPopupModal(" Confirm delete?##" .. i, false, ui.WindowFlags.AlwaysAutoResize) then
					ui:Spacing()
					self:PushRedButtonColor(ui)
					ui:SameLineWithSpace(20)
					if ui:Button("Delete##confirm") then
						ui:CloseCurrentPopup()
						self:DeleteEvent(self.curanim, params, v.event)
					end
					self:PopButtonColor(ui)
					ui:SameLineWithSpace()
					if ui:Button("Cancel##delete") then
						ui:CloseCurrentPopup()
					end
					ui:SameLineWithSpace(20)
					ui:Spacing()
					ui:EndPopup()
				end

				ui:NextColumn()
				if v.foreign then
					ui:PushStyleColor(ui.Col.Text, { 0.6, 0.6, 0.6, 1 })
					ui:Text(tostring(v.event.name))
					ui:PopStyleColor(1)
					if ui:IsItemHovered() then
						ui:SetTooltip("Defined in "..v.prefab)
					end
				else
					ui:Text(string.format("%-80s", tostring(v.event.name)))
					if ui:IsItemClicked() then
						self.curframe = v.event.frame
						self:SetFrame(self.testprefab, self.curframe)
					end
				end
				ui:NextColumn()
			end


			self:_EditEventPopup(ui, "Edit Event", params)

			ui:EndChild()
			ui:PopStyleVar()
			-- /show the events

			ui:Columns(1)
		end
	end

	self:_EditEventPopup(ui, "Add Event", params)

	ui:Columns(1)
end

function AnimTagger:_EditEventPopup(ui, label, params)
	if ui:BeginPopupModal(label, true, ui.WindowFlags.AlwaysAutoResize) then
		local numFrames = self:GetNumFrames(self.testprefab)
		local event = self.workevent
		EditEventFrame(ui, event, numFrames - 1)
		event.name = self.eventnamer:EditEventName(ui, event.name)
		local is_valid = event.name and event.name ~= ""
		if ui:Button("OK", 50, nil, not is_valid) then
			self:_ApplyEventChanges(params)
			ui:CloseCurrentPopup()
		end
		ui:SameLineWithSpace(30)
		if ui:Button("Cancel") then
			ui:CloseCurrentPopup()
		end
		ui:EndPopup()
	end
end

DebugNodes.AnimTagger = AnimTagger

return AnimTagger
