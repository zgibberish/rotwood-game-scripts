-- Anim tester for testing anim sequences.

local DebugNodes = require "dbui.debug_nodes"
local PrefabEditorBase = require "debug.inspectors.prefabeditorbase"
local prefabutil = require "prefabs.prefabutil"
require "mathutil"


local _static = PrefabEditorBase.MakeStaticData("animtest_autogen_data")


local AnimTester = Class(PrefabEditorBase, function(self)
	PrefabEditorBase._ctor(self, _static)

	self.name = "Anim Tester"
	self.prefab_label = "Anim Sequence"

	self.testprefab = nil
	self.playback_speed = 1
	self.test_label = "Play Sequence"

	self:WantHandle()

	self:SpawnEditPrefab()
end)

AnimTester.PANEL_WIDTH = 660
AnimTester.PANEL_HEIGHT = 990

function AnimTester:OnDeactivate()
	AnimTester._base.OnDeactivate(self)
	if self.testprefab ~= nil then
		self.testprefab:Remove()
		self.testprefab = nil
	end
end

function AnimTester:SetupHandle(handle)
	handle.move_fx = function(inst)
		if self.testprefab then
			local x, z = inst.Transform:GetWorldXZ()
			self.testprefab.Transform:SetPosition(x, 0, z)
		end
	end
	handle:DoPeriodicTask(0, handle.move_fx)
end

-- Generate the stategraph
local function MakeAnimTestStateGraph()
	local events = {}

	local states = {
		State({
			name = "dummy",
		}),
	}

	return StateGraph("sg_animtest_dummy", states, events, "dummy")
end

-- Generate the prefab
local function MakeAutogenAnimTest(name, params, debug)
	local assets = {}

	local build = params.build or name
	prefabutil.TryAddAsset_Anim(assets, build, debug)

	if params.bankfile ~= nil and params.bankfile ~= build then
		prefabutil.TryAddAsset_Anim(assets, params.bankfile, debug)
	end

	local function fn()
		local inst = CreateEntity()
			:TagAsDebugTool()

		inst.entity:AddTransform()
		inst.Transform:SetTwoFaced()
		inst.entity:AddAnimState()
		--[[Non-networked entity]]

		inst.persists = false

		inst:SetStateGraph(name, MakeAnimTestStateGraph())

		return inst
	end

	return Prefab(name, fn, assets)
end

function AnimTester:SpawnEditPrefab()
	local prefab = "animtest_dummy"
	local params = {}
	RegisterPrefabs(MakeAutogenAnimTest(prefab, params, true))
	TheSim:LoadPrefabs({ prefab })
	self.testprefab = SpawnPrefab("animtest_dummy", TheDebugSource)
end

function AnimTester:Test(prefab, params)
	local anims = params.animdata or {}
	if not GetDebugPlayer()
		or #anims == 0
		or not params.build or params.build:len() == 0
	then
		return
	end
	assert(anims[1].anim)
	AnimTester._base.Test(self, prefab, params)
	if self.testprefab ~= nil then
		self.testprefab:Remove()
		self.testprefab = nil
	end
	--d_allprefabs()
	-- why is it visible only the second time?
	local build = params.build

	prefab = "animtest_dummy"
	if PrefabExists(prefab) then
		self:AppendPrefabAsset(prefab, Asset("ANIM", "anim/"..build..".zip"))
		for i, v in pairs(anims) do
			local bankfile = v.bank
			if bankfile ~= nil and bankfile ~= build then
				self:AppendPrefabAsset(prefab, Asset("ANIM", "anim/"..bankfile..".zip"))
			end
		end
	else
		params.build = build
		params.bankfile = "bandicoot"
		RegisterPrefabs(MakeAutogenAnimTest(prefab, params, true))
	end

	TheSim:LoadPrefabs({ prefab })
	self.testprefab = SpawnPrefab("animtest_dummy", TheDebugSource)

	-- insert the states to play the anim sequence
	for i, v in pairs(anims) do
		-- Use numbers as statenames since they're already unique.
		local statename = tostring(i)
		local nextstatename = i == #anims and "1" or tostring(i + 1)
		if not params.loopanim and i == #anims then
			nextstatename = nil
		end
		self.testprefab.sg.sg.states[statename] = State({
			name = statename,

			onenter = function(inst)
				inst.AnimState:SetBank(v.bank)
				inst.AnimState:SetBuild(build)
				inst.AnimState:PlayAnimation(v.anim)
				inst.Transform:SetRotation(v.flip and 180 or 0)
			end,

			events = {
				EventHandler("animover", function(inst)
					if nextstatename then
						inst.sg:GoToState(nextstatename)
					end
				end),
			},
		})
	end

	self.testprefab.sg:GoToState("1")
	self.testprefab.AnimState:SetDeltaTimeMultiplier(1)

	self.handle:move_fx()

end

function AnimTester:AddEditableOptions(ui, params)
	local function TextField(label, params, paramname, index)
		local param = index and params[index][paramname] or params[paramname]
		local _, newvalue = ui:InputText(label, param, imgui.InputTextFlags.CharsNoBlank)
		if newvalue ~= nil then
			if newvalue and newvalue:len() == 0 then
				newvalue = nil
			end

			if param ~= newvalue then
				if index then
					params[index][paramname] = newvalue
				else
					params[paramname] = newvalue
				end
				self:SetDirty()
			end
		end
	end
	local function Bool(label, params, paramname, index)
		local param = index and params[index][paramname] or params[paramname] or false
		local newvalue = ui:_Checkbox(label, param)
		if newvalue ~= param then
			if index then
				params[index][paramname] = newvalue
			else
				params[paramname] = newvalue
			end
			self:SetDirty()
		end
	end

	if not params.animdata or #params.animdata == 0 then
		self:WarningMsg(ui, "No anims", "Click 'Add anim' before you can Apply.")
	end

	if not params.build or params.build:len() == 0 then
		self:WarningMsg(ui, "No build", "Fill in the name of a Build before you can Apply.")
	end

	ui:BeginChild("Anim Info#animinfo", 0, 100, true)
	if ui:Button("Reset") then
		self.playback_speed = 1
	end
	ui:SameLine()
	if self.stepatframe then
		local frame = self.testprefab.AnimState:GetCurrentAnimationFrame()
		if frame ~= self.stepatframe then
			self.stepatframe = nil
			self.paused = true
		end
	end

	local changed, speed = ui:SliderFloat("Playback speed:", self.playback_speed or 1, 0, 2)
	self.playback_speed = speed
	if self.testprefab then
		if not self.stepatframe then
			self.testprefab.AnimState:SetDeltaTimeMultiplier(self.playback_speed)
			if self.paused then
				self.testprefab.AnimState:SetDeltaTimeMultiplier(0)
			end
		end
	end
	local name = self.testprefab.AnimState:GetCurrentAnimationName()
	local bank = self.testprefab.AnimState:GetCurrentBankName()

	local frames = ""
	if name then
		local curframe = name and self.testprefab.AnimState:GetCurrentAnimationFrame() + 1
		local totframes = name and self.testprefab.AnimState:GetCurrentAnimationNumFrames()
		frames = curframe .. "/" .. totframes
	end
	ui:Columns(3, "", false)
	ui:Text("Bank: " .. (bank or "<None>"))
	ui:NextColumn()
	ui:Text("Anim: " .. (name or "<None>"))
	ui:NextColumn()
	ui:Text(frames)
	--	ui:NextColumn()
	ui:Columns(1)

	if ui:Button("Restart") then
		self.testprefab.sg:GoToState("1")
	end
	ui:SameLineWithSpace(10)

	if ui:Button("Step") then
		self.stepatframe = self.testprefab.AnimState:GetCurrentAnimationFrame()
		self.testprefab.AnimState:SetDeltaTimeMultiplier(1)
	end

	ui:SameLineWithSpace(10)

	self.paused = self.paused or false
	if ui:Button(self.paused and "Resume" or "Pause  ") then
		self.paused = not self.paused
	end
	ui:EndChild()
	ui:Columns(1)

	--	self:AddSectionEnder(ui)

	Bool("Loop anim", params, "loopanim")

	if ui:CollapsingHeader("Anims", ui.TreeNodeFlags.DefaultOpen) then
		TextField("Build", params, "build")

		local w = ui:GetColumnWidth()
		local btn_w = 110
		ui:Columns(4, "", false)
		ui:SetColumnOffset(0, 0)
		ui:SetColumnOffset(1, btn_w)
		ui:SetColumnOffset(2, w / 3 + btn_w)
		ui:SetColumnOffset(3, w / 3 * 2 + btn_w)
		local record = deepcopy(params.animdata) or {}
		local bank_anims = {}
		for i = 1, #record do
			local bank = record[i].bank
			if bank
				and bank:len() > 0
				and not bank_anims[bank]
			then
				local t = self.testprefab.AnimState:GetAnimNamesFromAnimFile(bank)
				table.sort(t)
				bank_anims[bank] = t
			end
		end
		for i = 1, #record do
			if ui:Button(ui.icon.add .."##"..i) then
				-- insert a line before this one
				table.insert(record, i, { bank = record[i].bank, anim = "" })
			end
			ui:SameLineWithSpace(3)
			if ui:Button(ui.icon.remove .. "##" .. i) then
				-- delete this line
				table.remove(record, i, { bank = "", anim = "" })
				break
			end
			ui:SameLineWithSpace(3)
			if ui:Button(ui.icon.arrow_up .. "##" .. i, nil, nil, i == 1) then
				-- move this line up
				local work = deepcopy(record[i])
				record[i] = deepcopy(record[i - 1])
				record[i - 1] = deepcopy(work)
			end
			ui:SameLineWithSpace(3)
			if ui:Button(ui.icon.arrow_down .. "##" .. i, nil, nil, i == #record) then
				-- move this line down
				local work = deepcopy(record[i])
				record[i] = deepcopy(record[i + 1])
				record[i + 1] = deepcopy(work)
			end
			ui:NextColumn()
			TextField("Bank##" .. i, record, "bank", i)
			ui:NextColumn()
			record[i].anim = ui:_ComboAsString("Anim##" .. i, record[i].anim, bank_anims[record[i].bank] or {})
			ui:NextColumn()
			Bool("Flip##" .. i, record, "flip", i)
			ui:NextColumn()
		end
		if ui:Button("Add anim") then
			-- insert a line before this one
			local bankname = params.build
			if #record ~= 0 then
				bankname = record[#record].bank
			end
			table.insert(record, { bank = bankname, anim = "" })
		end
		if not deepcompare(record, params.animdata) then
			params.animdata = deepcopy(record)
			self:SetDirty()
		end
		ui:Columns(1)
	end

	ui:Spacing()
	ui:Spacing()
	ui:Spacing()
	ui:Separator()
	ui:TextWrapped("AnimTester lets you test animations without them being hooked up in the game, but doesn't create anything that's used in-game. It's solely for visualizing animations.")
end

DebugNodes.AnimTester = AnimTester

return AnimTester
