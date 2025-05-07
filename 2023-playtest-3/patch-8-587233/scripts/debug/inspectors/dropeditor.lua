local Consumable = require "defs.consumable"
local DebugNodes = require "dbui.debug_nodes"
local PrefabEditorBase = require "debug.inspectors.prefabeditorbase"
local lume = require "util.lume"

--Make sure our util functions are loaded
require "prefabs.drops_autogen"

local _static = PrefabEditorBase.MakeStaticData("drops_autogen_data")

local DropEditor = Class(PrefabEditorBase, function(self)
	PrefabEditorBase._ctor(self, _static)

	self.name = "Drop Editor"
	self.test_label = "Spawn test drop"
	self.test_count = 1

	self.testdrop = nil

	self:LoadLastSelectedPrefab("dropeditor")

	self:WantHandle()

	self:_BuildMaterialsList()
end)

DropEditor.PANEL_WIDTH = 600
DropEditor.PANEL_HEIGHT = 800

function DropEditor:OnDeactivate()
	DropEditor._base.OnDeactivate(self)
	if self.testdrop ~= nil then
		self.testdrop:Remove()
		self.testdrop = nil
	end
end

function DropEditor:SetupHandle(handle)
	-- Players pick up items, so move handle away from player so they don't
	-- pickup drops as they spawn.
	local x,z = GetDebugPlayer().Transform:GetWorldXZ()
	handle.Transform:SetPosition(x + 5, 0, z)
end

function DropEditor:_BuildMaterialsList()
	local tags = {}
	if #self.groupfilter > 0 then
		tags = {self.groupfilter}
	end
	self.materials_sorted = Consumable.GetItemList(Consumable.Slots.MATERIALS, tags)
	self.material_names = lume.map(self.materials_sorted, function(t)
		return t.name
	end)
end

function DropEditor:Test(prefab, params, count)
	if not GetDebugPlayer() then
		return
	end
	DropEditor._base.Test(self, prefab, params, count)

	if self.testdrop ~= nil then
		self.testdrop:Remove()
		self.testdrop = nil
	end
	if prefab ~= nil then
		if PrefabExists(prefab) then
			if params.build ~= nil then
				self:AppendPrefabAsset(prefab, Asset("ANIM", "anim/"..params.build..".zip"))
			end
		else
			RegisterPrefabs(MakeAutogenDrop(prefab, params, true))
		end
		TheSim:LoadPrefabs({ prefab })
		self.testdrop = SpawnPrefab(prefab, TheDebugSource)
		self.testdrop.components.loot:SetCount(count)
		if self.testdrop ~= nil then
			self.testdrop:ListenForEvent("onremove", function()
				self.testdrop = nil
			end)
			self.testdrop.Transform:SetPosition(self:GetHandlePosition())
			local rot = GetDebugPlayer().Transform:GetRotation()
			local spread = 45
			if self.testdrop.droppos == "front" then
				self.testdrop.Transform:SetRotation(rot + spread * (math.random() * 2 - 1))
			elseif self.testdrop.droppos == "back" then
				self.testdrop.Transform:SetRotation(rot + 180 + spread * (math.random() * 2 - 1))
			else
				self.testdrop.Transform:SetRotation(math.random() * 360)
			end
			if self.testdrop.autofacing then
				if GetDebugPlayer().Transform:GetFacing() == FACING_LEFT then
					self.testdrop.AnimState:SetScale(-1, 1)
				end
			elseif self.testdrop.reversefacing then
				if GetDebugPlayer().Transform:GetFacing() == FACING_RIGHT then
					self.testdrop.AnimState:SetScale(-1, 1)
				end
			end
		end
		if self.testdrop.OnEditorSpawn then
			self.testdrop:OnEditorSpawn(self)
		end
	end
end

function DropEditor:GatherErrors()
	local bad_items = {}
	for name,params in pairs(self.static.data) do
		local def = Consumable.FindItem(params.loot_id)
		if not def then
			bad_items[name] = ("loot_id '%s' is not a valid Consumable."):format(params.loot_id)
		end
	end
	return bad_items
end

function DropEditor:AddEditableOptions(ui, params)
	if ui:CollapsingHeader("Animation", ui.TreeNodeFlags.DefaultOpen) then
		self:AddSectionStarter(ui)

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

		--Symbol name
		local _, newsymbol = ui:InputText("Symbol", params.symbol, imgui.InputTextFlags.CharsNoBlank)
		if newsymbol ~= nil then
			if string.len(newsymbol) == 0 then
				newsymbol = nil
			end
			if params.symbol ~= newsymbol then
				params.symbol = newsymbol
				self:SetDirty()
			end
		end

		--Type name
		local typelist =
		{
			"solid",
			"curve",
			"soft",
			"jiggle",
			"twigfall",
		}
		local typeidx = nil
		for i = 1, #typelist do
			if params.droptype == typelist[i] then
				typeidx = i
				break
			end
		end
		local newtypeidx = ui:_Combo("Anim", typeidx or 1, typelist)
		if newtypeidx ~= typeidx then
			local newdroptype = typelist[newtypeidx]
			if params.droptype ~= newdroptype then
				params.droptype = newdroptype
				self:SetDirty()
			end
		end

		self:AddSectionEnder(ui)
	end

	if ui:CollapsingHeader("Orientation", ui.TreeNodeFlags.DefaultOpen) then
		self:AddSectionStarter(ui)

		if ui:TreeNode("Flipping", ui.TreeNodeFlags.DefaultOpen) then
			local fliplist =
			{
				"None",
				"Match motion",
				"Match owner's facing",
				"Reverse owner's facing",
				"Random",
			}
			local flipidx =
				(params.noflip and 1) or
				(params.motionfacing and 2) or
				(params.reversefacing and 4) or
				(params.randomflip and 5) or
				3
			local newflipidx = ui:_Combo("##flipping_mode", flipidx, fliplist)
			if newflipidx ~= nil then
				local newflipflags =
				{
					noflip = newflipidx == 1,
					motionfacing = newflipidx == 2,
					reversefacing = newflipidx == 4,
					randomflip = newflipidx == 5,
				}
				local flipdirty = false
				for k, v in pairs(newflipflags) do
					if not params[k] == v then
						params[k] = v or nil
						flipdirty = true
					end
				end
				if flipdirty then
					self:SetDirty()
				end
			end

			self:AddTreeNodeEnder(ui)
		end

		if ui:TreeNode("Spawn Position", ui.TreeNodeFlags.DefaultOpen) then
			local _, newpos = nil, (params.pos == "front" and 0) or (params.pos == "back" and 1) or 2
			_, newpos = ui:RadioButton("Front\t", newpos, 0)
			ui:SameLine()
			_, newpos = ui:RadioButton("Back\t", newpos, 1)
			ui:SameLine()
			_, newpos = ui:RadioButton("Random", newpos, 2)
			if newpos ~= nil then
				newpos = (newpos == 0 and "front") or (newpos == 1 and "back") or nil
				if params.pos ~= newpos then
					params.pos = newpos
					self:SetDirty()
				end
			end

			self:AddTreeNodeEnder(ui)
		end

		self:AddSectionEnder(ui)
	end

	if ui:CollapsingHeader("Loot", ui.TreeNodeFlags.DefaultOpen) then
		self:AddSectionStarter(ui)

		if self.last_seen_groupfilter ~= self.groupfilter then
			self.last_seen_groupfilter = self.groupfilter
			self:_BuildMaterialsList()
		end

		-- add dropdown to select rarity

		-- local rarity_idx = lume.find(Consumable.RarityIdx, params.rarity or ITEM_RARITY.s.COMMON)
		-- local rarity_changed, new_rarity_idx = ui:Combo("Drop Rarity", rarity_idx or 1, Consumable.RarityIdx)

		-- if rarity_changed then
		-- 	params.rarity = Consumable.RarityIdx[new_rarity_idx]
		-- 	self:SetDirty()
		-- end

		-- -- add text box to edit drop weight

		-- local drop_weight_changed, new_drop_weight = ui:DragInt("Drop Weight", params.drop_weight or 10)
		-- if drop_weight_changed then
		-- 	params.drop_weight = new_drop_weight
		-- 	self:SetDirty()
		-- end

		local idx = lume.find(self.material_names, params.loot_id)
		idx = ui:_Combo("Loot ID", idx or 1, self.material_names)
		local newitem = self.material_names[idx]
		local itemdef = self.materials_sorted[idx]
		if newitem and itemdef then
			if string.len(newitem) == 0 then
				newitem = nil
			end
			if params.loot_id ~= newitem then
				params.loot_id = newitem
				self:SetDirty()
			end
		end

		local w = ui:GetColumnWidth()
		local item_w = w * .5
		local weight_w = w * .7 - item_w
		local count_w = w * .7 - item_w
		ui:Columns(3, nil, false)
		ui:SetColumnOffset(1, item_w)
		ui:SetColumnOffset(2, item_w + weight_w)
		ui:SetColumnOffset(3, item_w + weight_w + count_w)

		ui:Text("Count Threshold")
		ui:NextColumn()
		ui:Text("Symbol")
		ui:NextColumn()
		ui:NextColumn()

		local numrows = params.count_thresholds ~= nil and #params.count_thresholds or 1
		local removerow = nil

		for i = 1, numrows do
			local count_threshold_row, rowsymbol, rowcount
			if params.count_thresholds ~= nil then
				count_threshold_row = params.count_thresholds[i]
				if count_threshold_row ~= nil then
					rowsymbol = count_threshold_row.symbol
					rowcount = count_threshold_row.count
				end
			end
			dbassert(count_threshold_row ~= nil or i == 1)

			ui:PushItemWidth(math.max(20, count_w - 10))
			local _, newcount = ui:InputText("##countthreshold"..tostring(i), rowcount ~= nil and tostring(rowcount) or "", imgui.InputTextFlags.CharsDecimal)
			if newcount ~= nil then
				if string.len(newcount) == 0 then
					newcount = nil
				else
					newcount = tonumber(newcount)
				end
				if rowcount ~= newcount then
					rowcount = newcount
					if rowcount == nil and rowsymbol == nil and numrows == 1 then
						params.count_thresholds = nil
						count_threshold_row = nil
					elseif count_threshold_row == nil then
						count_threshold_row = { count = rowcount }
						params.count_thresholds = { count_threshold_row }
					else
						count_threshold_row.count = rowcount
					end
					self:SetDirty()
				end
			end
			ui:PopItemWidth()

			ui:NextColumn()

			ui:PushItemWidth(math.max(20, weight_w - 10))
			local _, newsymbol = ui:InputText("##symbol"..tostring(i), rowsymbol ~= nil and tostring(rowsymbol) or "", imgui.InputTextFlags.CharsNoBlank)
			if newsymbol ~= nil then

				if string.len(newsymbol) == 0 then
					newsymbol = nil
				end

				if rowsymbol ~= newsymbol then
					rowsymbol = newsymbol
					if rowcount == nil and rowsymbol == nil and numrows == 1 then
						params.count_thresholds = nil
						count_threshold_row = nil
					elseif count_threshold_row == nil then
						count_threshold_row = { symbol = rowsymbol }
						params.count_thresholds = { count_threshold_row }
					else
						count_threshold_row.symbol = rowsymbol
					end
					self:SetDirty()
				end
			end
			ui:PopItemWidth()

			ui:NextColumn()

			if ui:Button(ui.icon.remove .."##countthreshold"..tostring(i), nil, nil, count_threshold_row == nil) then
				removerow = i
			end

			if i == numrows then
				ui:SameLineWithSpace()

				if ui:Button(ui.icon.add .."##countthreshold"..tostring(i)) then
					print("Add Button")
					if params.count_thresholds == nil then
						params.count_thresholds = { {}, {} }
					else
						print("Add Row")
						params.count_thresholds[numrows + 1] = {}
					end
					self:SetDirty()
				end
			end

			ui:NextColumn()
		end

		if removerow ~= nil then
			if numrows == 1 then
				params.count_thresholds = nil
			else
				table.remove(params.count_thresholds, removerow)
				if #params.count_thresholds == 1 and next(params.count_thresholds[1]) == nil then
					params.count_thresholds = nil
				end
			end
			self:SetDirty()
		end

		ui:Columns()

		self:AddSectionEnder(ui)
	end


	-- if ui:CollapsingHeader("Counts", ui.TreeNodeFlags.DefaultOpen) then
	-- 	self:AddSectionStarter(ui)


	-- 	self:AddSectionEnder(ui)
	-- end

end

DebugNodes.DropEditor = DropEditor

return DropEditor
