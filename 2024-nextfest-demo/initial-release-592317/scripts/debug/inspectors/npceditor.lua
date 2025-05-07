local DebugNodes = require "dbui.debug_nodes"
local Npc = require "components.npc"
local PrefabEditorBase = require "debug.inspectors.prefabeditorbase"
local SGCommon = require "stategraphs.sg_common"
local emotion = require "defs.emotion"
local lume = require "util.lume"
local prefabutil = require "prefabs.prefabutil"
require "prefabs.npc_autogen" -- Load util functions


local _static = PrefabEditorBase.MakeStaticData("npc_autogen_data")
local _prop_static = PrefabEditorBase.MakeStaticData("prop_autogen_data")

local NpcEditor = Class(PrefabEditorBase, function(self)
	PrefabEditorBase._ctor(self, _static)

	self.name = "NPC Editor"
	self.test_label = "Spawn test NPC"

	local selected = GetDebugEntity()
	if selected ~= nil then
		local params = _static.data[selected.prefab]
		if params ~= nil then
			self.prefabname = selected.prefab
			if params.group ~= nil then
				self.groupfilter = params.group
			end
		end
	end

	self:LoadLastSelectedPrefab("npceditor")

	self:WantHandle()

	self.testnpc = nil
end)

NpcEditor.PANEL_WIDTH = 600
NpcEditor.PANEL_HEIGHT = 800

function NpcEditor:OnDeactivate()
	NpcEditor._base.OnDeactivate(self)
	if self.testnpc ~= nil then
		self.testnpc:Remove()
		self.testnpc = nil
	end
end

function NpcEditor:SetupHandle(handle)
	handle.move_npc = function(inst)
		if self.testnpc then
			local x,z = inst.Transform:GetWorldXZ()
			self.testnpc.Transform:SetPosition(x, 0, z)
		end
	end
	handle:DoPeriodicTask(0, handle.move_npc)
end

function NpcEditor:Test(prefab, params)
	NpcEditor._base.Test(self, prefab, params)
	if not GetDebugPlayer() or not prefab then
		return
	end
	if self.testnpc ~= nil then
		self.testnpc:Remove()
		self.testnpc = nil
	end

	self.testnpc = self:SpawnNpc(prefab, params)
	if not self.testnpc then
		return
	end

	self.testnpc.persists = false

	self.testnpc:ListenForEvent("onremove", function()
		self.testnpc = nil
	end)
	self.handle:move_npc()
end

function NpcEditor:SpawnNpc(prefab, params)
	if PrefabExists(prefab) then
		local assets = {}
		local prefabs = {}

		assert(params)

		local build = params.build or prefab
		local bank = params.bank or "npc_template"
		local head = params.head or ("%s_head"):format(prefab)

		prefabutil.CollectAssetsForAnim(assets, build, bank, params.bankfile, debug)
		prefabutil.CollectAssetsForAnim(assets, head, nil, nil, debug)
		prefabutil.CollectAssetsAndPrefabsForScript(assets, prefabs, prefab, params.script, params.script_args, debug)
		for _,a in ipairs(assets) do
			self:AppendPrefabAsset(prefab, a)
		end
		for _,p in ipairs(prefabs) do
			self:AppendPrefabDep(prefab, p)
		end
	else
		RegisterPrefabs(MakeAutogenNpc(prefab, params, true))
	end

	TheSim:LoadPrefabs({ prefab, params and params.home})
	local newnpc = SpawnPrefab(prefab, TheDebugSource)
	if newnpc == nil then
		return
	end

	SetDebugEntity(newnpc)
	return newnpc
end

function NpcEditor:AddEditableOptions(ui, params)

	--~ if not self.testnpc or self.testnpc.prefab ~= self.prefabname then
	--~ 	-- any cached data is stale
	--~ end

	if ui:CollapsingHeader("Animation") then
		self:AddSectionStarter(ui)

		if ui:TreeNode("Build/Bank (optional if same as Prefab)") then
			--Build name
			local _, newbuild = ui:InputText("Build", params.build, imgui.InputTextFlags.CharsNoBlank)
			if newbuild ~= nil then
				if string.len(newbuild) == 0 then
					newbuild = nil
				end
				if params.build ~= newbuild then
					params.build = newbuild
					self:SetDirty()
				end
			end

			--Bank name
			local _, newbank = ui:InputText("Bank", params.bank, imgui.InputTextFlags.CharsNoBlank)
			if newbank ~= nil then
				if string.len(newbank) == 0 then
					newbank = nil
				end
				if params.bank ~= newbank then
					params.bank = newbank
					self:SetDirty()
				end
			end

			--Bank file
			local _, newbankfile = ui:InputText("Bank File", params.bankfile, imgui.InputTextFlags.CharsNoBlank)
			if newbankfile ~= nil then
				if string.len(newbankfile) == 0 then
					newbankfile = nil
				end
				if params.bankfile ~= newbankfile then
					params.bankfile = newbankfile
					self:SetDirty()
				end
			end

			local _, newhead = ui:InputText("Head File", params.head, imgui.InputTextFlags.CharsNoBlank)
			if newhead ~= nil then
				if string.len(newhead) == 0 then
					newhead = nil
				end
				if params.head ~= newhead then
					params.head = newhead
					self:SetDirty()
				end
			end


			self:AddTreeNodeEnder(ui)
		end

		if ui:TreeNode("Preview Animation##anim", ui.TreeNodeFlags.DefaultOpen) then
			if self.testnpc and self.testnpc.prefab == self.prefabname then
				ui:Value("Anim on Root", self.testnpc.AnimState:GetCurrentAnimationName())

				local anims = self.testnpc.AnimState:GetAnimNamesFromAnimFile(self.testnpc.AnimState:GetCurrentBankName())
				table.sort(anims)
				self.testanim = ui:_Combo("Animation##animpreview", self.testanim or 1, anims)
				self.testanim_loops = ui:_Checkbox("Looping##animpreview", self.testanim_loops)
				if ui:Button("Play##animpreview", nil, nil, #anims == 0) then
					SGCommon.Fns.PlayAnimOnAllLayers(self.testnpc, anims[self.testanim], self.testanim_loops)
				end
			else
				ui:TextColored(WEBCOLORS.LIGHTGRAY, "Spawn test npc to preview animations.")
			end

			self:AddTreeNodeEnder(ui)
		end


		self:AddSectionEnder(ui)
	end

	if ui:CollapsingHeader("Villager", ui.TreeNodeFlags.DefaultOpen) then
		params.role = ui:_Enum("Role", params.role, Npc.Role, true)

		local hint = "Default: VISITOR"
		params.initial_state = ui:_InputTextWithHint("Initial State", hint, params.initial_state, imgui.InputTextFlags.CharsNoBlank)

		params.home = self:AutogenPrefabSelector(ui, _prop_static.data, "Home Prefab", params.home, "town_buildings")
		self:AddSectionEnder(ui)

		if ui:Checkbox("Has Held Item", params.held_item) then
			params.held_item = not params.held_item
		end

		local feelings = lume.values(emotion.feeling)
		table.insert(feelings, 1, "none")
		params.default_feeling = ui:_ComboAsString("Default Feeling", params.default_feeling, feelings, true)

		-- Assume dirty for simplicity.
		self:SetDirty()
	end

	if ui:CollapsingHeader("Wanderer") then
		self:AddSectionStarter(ui)

		local changed, enabled = ui:Checkbox("Minigame", params.script == "npc_minigame")
		if changed then
			if enabled then
				params.script = "npc_minigame"
				params.script_args = nil
			else
				params.script = nil
				params.script_args = nil
			end
			self:SetDirty()
		end

		self:AddSectionEnder(ui)
	end

	if ui:CollapsingHeader("Dev Options") then
		self:AddSectionStarter(ui)

		local _, newscript = ui:InputText("Script File", params.script, imgui.InputTextFlags.CharsNoBlank)
		if newscript ~= nil then
			if string.len(newscript) == 0 then
				newscript = nil
			end
			if params.script ~= newscript then
				params.script = newscript
				self:SetDirty()
			end
		end

		self:AddSectionEnder(ui)
	end
end


-- Don't submit this code uncommented. Don't want the button unless a coder is
-- using it.
--~ function NpcEditor:BatchModify(prefabs)
--~ 	local fix = {
--~ 		npc_armorsmith = "armorer_1",
--~ 	}
--~ 	for key,val in pairs(fix) do
--~ 		prefabs[key].home = val
--~ 	end
--~ 	self:SetDirty()
--~ end

DebugNodes.NpcEditor = NpcEditor

return NpcEditor
