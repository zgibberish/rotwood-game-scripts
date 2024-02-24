local Consumable = require "defs.consumable"
local DebugNodes = require "dbui.debug_nodes"
local DebugSettings = require "debug.inspectors.debugsettings"
local Hsb = require "util.hsb"
local ParticleSystem = require "components.particlesystem"
local PrefabEditorBase = require "debug.inspectors.prefabeditorbase"
local SGCommon = require "stategraphs.sg_common"
local lume = require "util.lume"
local prefabutil = require "prefabs.prefabutil"
require "prefabs.prop_autogen" --Make sure our util functions are loaded


local _static = PrefabEditorBase.MakeStaticData("prop_autogen_data")

-- These are mappings from data/scripts/prefabs/customscript/*.lua files to pretty names. We
-- use them to expose extra attributes or setup logic for some types of props.
local script_options =
{
	canopy = "Canopy",
	buildings = "Buildings",
	hitboxtrigger = "HitBox Touch Trigger",
	trap = "Traps",
	tree = "Tree",
	lightspot = "Light Spot",
	flowers = "Flower",
	powerdrops = "Power Drops",
	playerspawner = "Player Spawn Point",
	creaturespawner = "Spawners",
	dummies = "Dummies",
	prop_destructible = "Destructible Prop",
	screenopener = "Screen Opener",
	specialeventroom_prefab = "Special Event Room",
	konjursouls = "Konjur Soul",
	townpillar = "Town Pillar",
	dungeonstarter = "Dungeon Starter",
	plots = "Plots",
	totem = "Totem",
	poweritems = "PROTOTYPE Power Item",
	moving_cloud = "Moving Cloud",
	shopitem_config = "Shop Item",
	vendingmachine_config = "Vending Machine",
	storagechest_script = "Storage Chest",
	encounterpractice = "Encounter Practice",
}

local function run_script_fn(params, fn)
	if params.script then
		local require_succeeded, script = pcall(function()
			return require("prefabs.customscript.".. params.script)
		end)
		if not require_succeeded then
			TheLog.ch.Prop:print(script)
			return false
		end
		return fn(script, params)
	end
end


local PropEditor = Class(PrefabEditorBase, function(self)
	PrefabEditorBase._ctor(self, _static)

	self.name = "Prop Editor"
	self.test_label = "Spawn test prop"
	self.extrainfo_for_delete = "Will remove '%s' from all levels."

	-- Load the saved prefab first, which will get overwritten if there's already a selected prefab when this editor is open.
	self:LoadLastSelectedPrefab("propeditor")

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

	self:WantSpawnPosition()

	self.edit_options = DebugSettings("propeditor.edit_options")
		:Option("auto_respawn", false)

	self:_BuildMaterialsList()

	self.testprop = nil
	self.made_dirty_this_frame = false

	self.edit_group = {
		parallax = {},
		total_offset = Vector3(),
		applied_offset = Vector3(),
	}
end)

-- To effect some transformation on all props..
-- function PropEditor:OnActivate()
-- 	self._base.OnActivate(self)
--  -- e.g. Delete all proc_gen tables.
-- 	for _, params in pairs(self.static.data) do
-- 		if params.proc_gen then
-- 			params.proc_gen = nil
-- 		end
-- 	end
-- 	self:SetDirty()
-- end

PropEditor.PANEL_WIDTH = 670
PropEditor.PANEL_HEIGHT = 800

function PropEditor:OnDeactivate()
	self:RemoveTestProp()
end

function PropEditor:SetDirty()
	self.made_dirty_this_frame = true
	return PropEditor._base.SetDirty(self)
end

function PropEditor:GetLastSpawnPosition()
	if self.testprop ~= nil then
		return self.testprop:GetPosition()
	end
end

function PropEditor:RemoveTestProp()
	if self.testprop then
		self.testprop:Remove()
		self.testprop = nil
		return true
	else
		return false
	end
end

function PropEditor:Test(prefab, params)
	PropEditor._base.Test(self, prefab, params)
	if not GetDebugPlayer() or not prefab then
		return
	end
	local dest_pos = self:GetSpawnPosition()
	if self:RemoveTestProp() then
		self.parallax_hovered = nil
	end

	params.is_testprop = true
	self.testprop = self:SpawnProp(prefab, params, dest_pos)
	params.is_testprop = nil
	if not self.testprop then
		return
	end

	TheInput:SetEditMode(self, true)

	-- Remove the temp prop from the propmanager right now so we don't save it into our scene.
	self.testprop.persists = false
	if TheWorld.components.propmanager then
		TheWorld.components.propmanager:Debug_ForceUnregisterProp(self.testprop)
	end
	self.testprop:ListenForEvent("onremove", function(source)
		self.testprop = nil
		self:RemoveTestProp()
	end)

	local function apply_default(p, key, default)
		p[key] = p[key] or default
	end
	self.testprop:DoPeriodicTicksTask(1, function(inst_)
		local p = deepcopy(params)
		-- These are nil when their default values are set. Force
		-- the default so it's still seen.
		apply_default(p, "hue", 0)
		apply_default(p, "saturation", 0)
		apply_default(p, "brightness", 0)
		-- add/multcolor don't expect no-op colours to be set.
		inst_.components.colormultiplier:PopColor("prop_autogen")
		inst_.components.coloradder:PopColor("prop_autogen")
		inst_:ApplyPropParams_Safe(p)
	end)

	-- do we have an apply function and script_args? Then apply them
	if params.script and params.script_args then
		run_script_fn(params, function(script, _)
			if script.Apply then
				script.Apply(self.testprop, params.script_args)
			end
		end)
	end

	if self.testprop.OnEditorSpawn then
		self.testprop:OnEditorSpawn(self)
	end
end

-- Helpers to treat particle systems as props


function PropEditor:SpawnParticles(prefab, params, dest_pos)
	local ent = ParticleSystem.SpawnParticleSystemAsProp(prefab, params, dest_pos, TheDebugSource)
	return ent
end

-- EditableEditor calls this.
function PropEditor:SpawnProp(prefab, params, dest_pos)
	assert(params)
	assert(dest_pos)

	dest_pos.y = 0
	if PrefabExists(prefab) then
		local assets = {}
		local prefabs = {}

		local build = params.build or prefab
		local bank = params.bank or prefab

		prefabutil.CollectAssetsForAnim(assets, build, bank, params.bankfile, debug)
		prefabutil.CollectAssetsAndPrefabsForScript(assets, prefabs, prefab, params.script, params.script_args, debug)
		for _,a in ipairs(assets) do
			self:AppendPrefabAsset(prefab, a)
		end
		for _,p in ipairs(prefabs) do
			self:AppendPrefabDep(prefab, p)
		end
	else
		RegisterPrefabs(MakeAutogenProp(prefab, params, true))
	end

	TheSim:LoadPrefabs({ prefab, params.childprefab})
	local newprop = SpawnPrefab(prefab, TheDebugSource)
	if newprop == nil then
		return
	end

	if params.childprefab then
		-- Live update the offset
		newprop.debug_offset_task = newprop:DoPeriodicTicksTask(1, newprop.ApplyLocalOffsetToChild)
	end
	if newprop.components.snaptogrid ~= nil then
		newprop.components.snaptogrid:SetNearestGridPos(dest_pos:Get())
	else
		newprop.Transform:SetPosition(dest_pos:Get())
	end

	if params.variations then
		newprop.components.prop:SetVariation(1)
	end

	SetDebugEntity(newprop)
	return newprop
end

function PropEditor:CopyPropData(ref_ent, ent)
	if ent and ref_ent and ent ~= ref_ent then
		local data = deepcopy(ref_ent.components.prop.data)
		ent.components.prop:OnLoad(data)
	end
end

function PropEditor:_BuildMaterialsList()
	local tags = {}
	if #self.groupfilter > 0 then
		tags = {self.groupfilter}
	end
	self.materials_sorted = Consumable.GetItemList(Consumable.Slots.MATERIALS, tags)
	self.material_names = lume.map(self.materials_sorted, function(t)
		return t.name
	end)
end

local function GetErrors_MissingVariations(testprop, name, params)
	if not params.variations or not params.parallax then
		return
	end
	local anims = testprop.AnimState:GetAnimNamesFromAnimFile(params.bank or name)
	if anims then
		anims = lume.invert(anims)
		local missing = {}
		for i=1,params.variations do
			for _,layer in ipairs(params.parallax) do
				local expected_anim = "idle_".. layer.anim .. i
				if params.parallax_use_baseanim_for_idle then
					expected_anim = layer.anim .. i
				end

				if not anims[expected_anim] then
					table.insert(missing, expected_anim)
				end
			end
		end
		if next(missing) then
			return ("These variations with missing anims will spawn invisible: %s"):format(table.concat(missing, ", "))
		end
	end
end

-- GetErrors_MissingVariations on all props causes crashes: Can't get anim
-- names on some props. Maybe because they need re-exporting on our current
-- pipeline?
--~ function PropEditor:GatherErrors()
--~ 	local bad_items = {}
--~ 	-- testprop doesn't exist when we gather errors.
--~ 	if GetDebugPlayer() then
--~ 		for name,params in pairs(self.static.data) do
--~ 			bad_items[name] = GetErrors_MissingVariations(GetDebugPlayer(), name, params)
--~ 		end
--~ 	end
--~ 	return bad_items
--~ end

function PropEditor:ImportParallaxLayers(params)

	local function CalculateNumOfVariations(all_anims)
		local max_variations = 0
		for _, i in ipairs(all_anims) do
		-- Some prefabs(apothecary) use numbers for their parallax layer names
		-- So we cannot rely on endswith number to do the variation check
			local n, v = i:match('^(.-)(%d+)$')
			if n == nil or n == '' then
				return 0
			end
			max_variations = math.max(max_variations, tonumber(v))
		end
		return max_variations
	end

	local function TryLoadPrefabAnims(anim_state)
		local all_anims = anim_state:GetAnimNamesFromAnimFile(params.bank or anim_state:GetCurrentBankName() or self.prefabname)

		-- Return all the anims if the anim file name is the same as prefab name, which usually means this prefab requires all anims in the bank
		if #all_anims > 0 and anim_state:GetCurrentBankName() == self.prefabname then
			return all_anims
		end

		-- We use pattern [anim_file]_[prefab_suffix] to find the anim file
		local anim_file, prefab_suffix = self.prefabname:match('^(.-)_([^_]+)$')

		if anim_file == nil then
			return all_anims
		end

		if #all_anims == 0 then
			all_anims = anim_state:GetAnimNamesFromAnimFile(anim_file)
			if #all_anims > 0 then
				params.bank = anim_file
				params.build = anim_file
			end
		end

		local all_anims_filtered = {}
		-- If the prefab name has an extra suffix compares to the file name. This is probably gonna be a partial import of the anims
		-- We filter out those anim names not ending with prefab_suffix if possible
		for _, i in ipairs(all_anims) do
			if i:match(prefab_suffix .. '%d?$') then
				table.insert(all_anims_filtered, i)
			end
		end

		return #all_anims_filtered > 0 and all_anims_filtered or all_anims
	end

	local dirty = false
	local testprop = self.testprop
	local anim_state = testprop.AnimState or testprop.entity:AddAnimState()
	local all_anims = TryLoadPrefabAnims(anim_state)
	local num_of_variations = params.variations or CalculateNumOfVariations(all_anims)

	if #all_anims == 0 then
		return false
	end

	local function StripVariationSuffix(anim_name)
		local stripped_name, v = anim_name:match('^(.-)(%d+)$')
		return v and tonumber(v) <= num_of_variations and stripped_name or anim_name
	end

	local function GetIdleStateAnimations(all_anims)
		local idle_states = {}
		local idle_state_name_set = {}
		for _, i in ipairs(all_anims) do
			if(i:startswith('idle_')) then
				local anim_name = StripVariationSuffix(i:sub(6))
				if not idle_state_name_set[anim_name] then
					table.insert(idle_states, anim_name)
					idle_state_name_set[anim_name] = true
				end
			end
		end
		return idle_states
	end

	local idle_state_animations = GetIdleStateAnimations(all_anims)
	local has_idle_animation = #idle_state_animations > 0

	local function GetParallaxAnimName(anim_name)
		if has_idle_animation then
			for _, i in ipairs(idle_state_animations) do
				if anim_name:endswith(i) then
					return i
				end
			end
		end
		return anim_name
	end

	if params.parallax == nil then
		params.parallax = {}
	end

	local existing_parallax_name_set = {}
	local has_zero_distance_layer = false
	for _, v in ipairs(params.parallax) do
		existing_parallax_name_set[v.anim] = true
		has_zero_distance_layer = has_zero_distance_layer or v.distance == nil or v.distance == 0
	end

	if has_idle_animation == (params.parallax_use_baseanim_for_idle ~= nil and params.parallax_use_baseanim_for_idle or false) then
		params.parallax_use_baseanim_for_idle = not has_idle_animation
		dirty = true
	end

	local importing_parallax_name_set = {}
	for _, i in ipairs(all_anims) do
		local anim_name = GetParallaxAnimName(StripVariationSuffix(i))
		importing_parallax_name_set[anim_name] = true
	end

	local dist = has_zero_distance_layer and 0.001 or 0
	for k, _ in pairs(importing_parallax_name_set) do
		if k ~= 'x' and not existing_parallax_name_set[k] then
			table.insert(params.parallax, {anim = k, shadow = true, dist = dist})
			dist = dist + 0.001
			dirty = true
		end
	end

	if testprop.baseanim == nil then
		local k, _ = next(importing_parallax_name_set)
		testprop.baseanim = k
	end

	if params.variations == nil and num_of_variations > 0 then
		params.variations = num_of_variations
		dirty = true
	end

	return dirty
end

function PropEditor:AddEditableOptions(ui, params)
	if self.testprop and ui:Button("Remove test prop##PropEditor") then
		self:RemoveTestProp()
	end

	self.edit_options:Toggle(ui, "Auto Respawn", "auto_respawn")
	if self.edit_options.auto_respawn and self.made_dirty_this_frame then
		self:Test(self.prefabname, params)
	end
	self.made_dirty_this_frame = false

	local main_layer_index = 0
	self.main_layer_count = 0
	if params.parallax then
		self.main_layer_count = lume.count(params.parallax, function(layerparams)
			return layerparams.dist == nil or layerparams.dist == 0
		end)
		local _
		_, main_layer_index = lume.match(params.parallax, function(layerparams)
			return layerparams.dist == nil or layerparams.dist == 0
		end)
	end

	if not self.testprop or self.testprop.prefab ~= self.prefabname then
		self.testprop_all_anims = nil
	end

	if ui:CollapsingHeader("Animation", ui.TreeNodeFlags.DefaultOpen) then
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

			self:AddTreeNodeEnder(ui)
		end

		if ui:TreeNode("Parallax", ui.TreeNodeFlags.DefaultOpen) then
			if ui:Checkbox("Has idle_ anim", not params.parallax_use_baseanim_for_idle) then
				params.parallax_use_baseanim_for_idle = not params.parallax_use_baseanim_for_idle or nil
				self:SetDirty()
			end

			local w = ui:GetColumnWidth()
			local checkbox_w = 37
			w = w - checkbox_w * 4
			local anim_w = w * .5
			local dist_w = w * .16
			local offset_w = w * 0.28
			-- remaining width given to add/remove buttons
			ui:Columns(8, nil, false)
			ui:SetColumnOffset(1, anim_w)
			ui:SetColumnOffset(2, anim_w + dist_w)
			ui:SetColumnOffset(3, anim_w + dist_w + offset_w)
			ui:SetColumnOffset(4, anim_w + dist_w + offset_w + checkbox_w)
			ui:SetColumnOffset(5, anim_w + dist_w + offset_w + checkbox_w * 2)
			ui:SetColumnOffset(6, anim_w + dist_w + offset_w + checkbox_w * 3)
			ui:SetColumnOffset(7, anim_w + dist_w + offset_w + checkbox_w * 4)

			ui:Text("Anim")
			ui:NextColumn()
			ui:Text("Distance")
			ui:NextColumn()
			ui:Text("Offset")
			ui:NextColumn()
			ui:Text("Flip")
			if ui:IsItemHovered() then
				ui:SetTooltip("Flip over the Y axis.")
			end
			ui:NextColumn()
			ui:Text("Shdw")
			if ui:IsItemHovered() then
				ui:SetTooltip("Enable shadow for this layer.")
			end
			ui:NextColumn()
			ui:Text("Grnd")
			if ui:IsItemHovered() then
				ui:SetTooltipMultiline({
						"Set this single layer as Orientation: Ground Projection.",
						"Will be pushed to Background sorting layer or further back.",
					})
			end
			ui:NextColumn()
			ui:Text("Grp")
			if ui:IsItemHovered() then
				ui:SetTooltip("Group: Move multiple anims together.")
			end
			ui:NextColumn()
			-- No title for add/remove
			ui:NextColumn()

			local numrows = params.parallax ~= nil and #params.parallax or 1
			local removerow = nil

			local has_layer_hovered = false

			local function NilForZero(val)
				if val == 0 then
					return nil
				end
				return val
			end
			local function VecFromParallaxOffset(layer)
				return Vector3(
					layer.xoffset or 0,
					layer.yoffset or 0,
					layer.dist or 0)
			end
			local function SetParallaxOffset(i, newoffset)
				params.parallax = params.parallax or {}
				local layer = params.parallax[i]
				if not layer then
					layer = {}
					params.parallax[i] = layer
				end
				local oldoffset = layer
				if not oldoffset or VecFromParallaxOffset(oldoffset) ~= newoffset then
					layer.dist = NilForZero(newoffset.z)
					layer.xoffset = NilForZero(newoffset.x)
					layer.yoffset = NilForZero(newoffset.y)
					self:SetDirty()
				end
				return newoffset
			end

			params.parallax = params.parallax or {}

			for i = 1, numrows do
				local rowanim, rowdist, rowshadow, rowground
				local rowoffset = Vector3()
				local parallaxrow = params.parallax[i]
				if parallaxrow ~= nil then
					rowanim = parallaxrow.anim
					rowdist = parallaxrow.dist
					rowshadow = parallaxrow.shadow
					rowground = parallaxrow.onground
					rowoffset = VecFromParallaxOffset(parallaxrow)
				end
				dbassert(parallaxrow ~= nil or i == 1)
				parallaxrow = parallaxrow or {}
				params.parallax[i] = parallaxrow

				ui:SetNextColumnItemToFillWidth()
				local _, newanim = ui:InputText("##parallaxanim"..tostring(i), rowanim or "", imgui.InputTextFlags.CharsNoBlank)
				if newanim ~= nil then
					if string.len(newanim) == 0 then
						newanim = nil
					end
					if rowanim ~= newanim then
						rowanim = newanim
						parallaxrow.anim = newanim
						self:SetDirty()
					end
				end
				local request_highlight = ui:IsItemHovered()
				ui:NextColumn()

				local speed = 0.1

				ui:SetNextColumnItemToFillWidth()
				local changed_offset, newdist = ui:DragFloat("##parallaxdist"..i, rowdist and rowdist or 0, speed, -10, 10)
				ui:NextColumn()

				ui:SetNextColumnItemToFillWidth()
				local newoffset = rowoffset:to_xy()
				local to_pop = 0
				if main_layer_index == i then
					to_pop = ui:PushDisabledStyle()
				end
				changed_offset = ui:DragVec2f("##parallaxoffset"..i, newoffset, speed, -10, 10) or changed_offset
				if not rowdist or rowdist == 0 then
					-- TODO(dbriscoe): Should clear if main_layer_index, but might mess existing props.
					-- No offset for main anim.
					newoffset.x = 0
					newoffset.y = 0
				end
				if ui:IsItemHovered() then
					ui:SetTooltip("Beware of overusing the y offset. You probably want to change distance (z) instead.")
				end
				ui:PopStyleColor(to_pop)
				ui:NextColumn()

				if changed_offset then
					rowoffset = SetParallaxOffset(i, Vector3(newoffset.x, newoffset.y, newdist))
				end

				ui:SetNextColumnItemToFillWidth()
				if main_layer_index ~= i then
					if ui:Checkbox("##parallaxflip"..i, parallaxrow.flip) then
						parallaxrow.flip = not parallaxrow.flip or nil
						self:SetDirty()
					end
				else
					parallaxrow.flip = nil
				end
				ui:NextColumn()

				ui:SetNextColumnItemToFillWidth()
				if ui:Checkbox("##parallaxshadow"..i, rowshadow) then
					rowshadow = not rowshadow or nil
					parallaxrow.shadow = rowshadow
					self:SetDirty()
				end
				ui:NextColumn()

				ui:SetNextColumnItemToFillWidth()
				if params.onground then
					-- Already all ground projected.
					ui:Text(ui.icon.done)

				elseif ui:Checkbox("##parallaxground"..i, rowground) then
					rowground = not rowground or nil
					parallaxrow.onground = rowground
					self:SetDirty()
				end
				ui:NextColumn()

				if main_layer_index ~= i then
					self.edit_group.parallax[i] = ui:_Checkbox("##parallaxgroup"..i, self.edit_group.parallax[i]) or nil
					request_highlight = request_highlight or ui:IsItemHovered()
				end
				ui:NextColumn()

				ui:SetNextColumnItemToFillWidth()
				if ui:Button(ui.icon.remove .."##parallax"..tostring(i), ui.icon.width) then
					removerow = i
				end

				if i == numrows then
					ui:SameLineWithSpace(3)

					if ui:Button(ui.icon.add .."##parallax"..tostring(i), ui.icon.width) then
						if params.parallax == nil then
							params.parallax = { {}, {} }
						else
							params.parallax[numrows + 1] = {}
						end
						numrows = numrows + 1
						self:SetDirty()
					end
				end

				ui:NextColumn()

				if request_highlight
					and self.testprop
					and self.testprop.GetParallaxLayer
					and self.testprop.prefab == self.prefabname
				then
					has_layer_hovered = true
					local layer = self.testprop:GetParallaxLayer(i)
					if self.parallax_hovered ~= layer then
						if self.parallax_hovered then
							self.parallax_hovered:RemoveComponent("prophighlight")
						end
						layer:AddComponent("prophighlight")
						self.parallax_hovered = layer
					end
				end

				-- If we removed all data from our last row, don't store anything.
				if numrows == 1
					and rowanim == nil
					and rowoffset:is_zero()
					and rowshadow == nil
					and rowground == nil
				then
					params.parallax = nil
				end
			end

			if not has_layer_hovered and self.parallax_hovered then
				self.parallax_hovered:RemoveComponent("prophighlight")
				self.parallax_hovered = nil
			end

			if removerow ~= nil then
				if numrows == 1 then
					params.parallax = nil
				else
					table.remove(params.parallax, removerow)
					if #params.parallax == 1 and next(params.parallax[1]) == nil then
						params.parallax = nil
					end
				end
				self:SetDirty()
			end

			ui:Columns()

			if ui:Button("Sort##parallax") then
				if params.parallax ~= nil then
					local old = deepcopy(params.parallax)
					for i = #params.parallax, 1, -1 do
						local v = params.parallax[i]
						if v.dist == nil and v.anim == nil then
							params.parallax[i] = params.parallax[#params.parallax]
							params.parallax[#params.parallax] = nil
						end
					end
					table.sort(params.parallax, function(a, b)
						if a.dist ~= nil and b.dist ~= nil then
							return a.dist < b.dist
						elseif a.dist ~= nil then
							return a.dist <= 0
						elseif b.dist ~= nil then
							return b.dist > 0
						else
							return false
						end
					end)
					if not deepcompare(old, params.parallax) then
						self:SetDirty()
					end
				end
			end

			ui:SameLineWithSpace()
			if self.testprop then
				if ui:Button("Import##parallax") then
					if self:ImportParallaxLayers(params) then
						self:SetDirty()
					end
				end
			else
				ui:PushDisabledStyle()
				ui:Button("Import##parallax")
				if ui:IsItemHovered() then
					ui:SetTooltip("You must spawn a test prop before importing its parallax layers")
				end
				ui:PopDisabledStyle()
			end

			do ui:Indent()
				if params.parallax and ui:CollapsingHeader("Group Edit") then
					if lume.count(self.edit_group.parallax) > 1 then
						if not self.auto_respawn then
							ui:TextColored(WEBCOLORS.LIGHTGRAY, "Tip: Turn on Auto Respawn for live update.")
						end
						ui:DragVec3f("Offset Position", self.edit_group.total_offset, 0.01, -20, 20)
						local function MoveDelta(delta)
							for i in pairs(self.edit_group.parallax) do
								local layer = params.parallax[i]
								local dest = delta + VecFromParallaxOffset(layer)
								SetParallaxOffset(i, dest)
							end
						end
						if ui:IsItemActive() and not self.edit_group.total_offset:is_zero() then
							local delta = self.edit_group.total_offset - self.edit_group.applied_offset
							self.edit_group.applied_offset = self.edit_group.total_offset:clone()
							MoveDelta(delta)
						end
						local clear_delta = ui:Button("Clear Offset##GroupEdit")
						ui:SameLineWithSpace()
						if ui:Button("Undo##GroupEdit") then
							MoveDelta(-self.edit_group.applied_offset)
							clear_delta = true
						end
						if clear_delta then
							self.edit_group.total_offset = Vector3()
							self.edit_group.applied_offset = Vector3()
						end
					else
						ui:TextColored(WEBCOLORS.LIGHTGRAY, "Check multiple 'Grp' boxes to move multiple anims together.")
					end

					ui:Spacing()
					self.edit_group.query = ui:_InputTextWithHint("##Name##GroupEdit", "Enter a partial name ('bush' to match all bushes)...", self.edit_group.query)
					ui:SameLineWithSpace()
					if ui:Button("Select Matching##GroupEdit") then
						for i,layer in ipairs(params.parallax) do
							if main_layer_index ~= i
								and layer.anim
								and layer.anim:find(self.edit_group.query)
							then
								self.edit_group.parallax[i] = true
							end
						end
					end
					if ui:Button("Clear Group") then
						lume.clear(self.edit_group.parallax)
					end
				end
			end ui:Unindent()

			if params.parallax then
				if self.main_layer_count == 0 then
					self:WarningMsg(ui,
						"!!! Warning !!!",
						"Most props need one parallax layer at Distance 0 to act as the main anim that drives the stategraph. Otherwise we never receive animover and animations loop infinitely.")
				elseif self.main_layer_count > 1 then
					-- We could allow this, but a single prop at distance 0
					-- makes it clearer which will be the main entity and
					-- reduce z-fighting.
					self:WarningMsg(ui,
						"!!! Warning !!!",
						"You cannot have two layers at Distance 0. The second will be ignored. Use 0.001 to make it almost the same position.")
				end
			end

			self:AddTreeNodeEnder(ui)
		end

		if ui:TreeNode("Options##anim", ui.TreeNodeFlags.DefaultOpen) then
			--Variations
			local _, newvariations = ui:InputInt("Variations", params.variations or 0, 1, 10)
			if newvariations ~= nil then
				if newvariations <= 0 then
					newvariations = nil
				end
				if params.variations ~= newvariations then
					params.variations = newvariations
					self:SetDirty()
				end
			end
			if self.testprop then
				local err_msg = GetErrors_MissingVariations(self.testprop, self.prefabname, params)
				if err_msg then
					ui:TextColored(WEBCOLORS.YELLOW, err_msg)
				end
			end

			--Looping anim
			if ui:Checkbox("Looping", params.looping) then
				params.looping = not params.looping or nil
				params.randomstartframe = params.looping
				self:SetDirty()
			end

			if params.looping then
				--Random start frame
				ui:SameLineWithSpace(40)
				if ui:Checkbox("Random Start Frame", params.randomstartframe) then
					params.randomstartframe = not params.randomstartframe or nil
					self:SetDirty()
				end
			end

			if ui:Checkbox("Has boss_ variant", params.bossvariant) then
				params.bossvariant = not params.bossvariant or nil
				self:SetDirty()
			end
			if ui:IsItemHovered() then
				ui:SetTooltipMultiline({
						"Prop has states with boss_ after the anim name",
						"(idle_boss_leaf) to use when progressing deeper into the",
						"dungeon (and closer to the boss). The number of boss_",
						"variations must match the number of normal variations."
					})
			end
			if ui:Checkbox("Show silhouette", params.silhouette) then
				params.silhouette = not params.silhouette or nil
				self:SetDirty()
			end
			if ui:IsItemHovered() then
				ui:SetTooltip("Show a silhouette when player walks behind this prop.")
			end
			if params.bossvariant
				and self.testprop_all_anims
				and not lume.any(self.testprop_all_anims, function(x)
					return x:find("boss_")
				end)
			then
				self:WarningMsg(ui, "Missing boss_", "boss_ variant is enabled, but no animation state containing 'boss_' found. Expected state names like idle_boss_dog, idle_dog.")
			end
			if params.variations then
				if ui:Checkbox("Random variation", params.randomize) then
					params.randomize = not params.randomize or nil
					self:SetDirty()
				end
				if ui:IsItemHovered() then
					ui:SetTooltip("Pick a random variation on world creation.")
				end
			end
			if ui:Checkbox("Random Flip", params.randomflip) then
				params.randomflip = not params.randomflip or nil
				self:SetDirty()
			end
			if ui:IsItemHovered() then
				ui:SetTooltip("Pick a random facing on world creation.")
			end

			self:AddTreeNodeEnder(ui)
		end

		if ui:TreeNode("Preview Animation##anim", ui.TreeNodeFlags.DefaultOpen) then
			if self.testprop and self.testprop.AnimState == nil then
				ui:TextColored(WEBCOLORS.LIGHTGRAY, "Unavailable for props without AnimState on the main entity.\nTo fix: make one of the Distance values blank in Animation > Parallax.")
			elseif self.testprop and self.testprop.prefab == self.prefabname then
				ui:Value("Anim on Root", self.testprop.AnimState:GetCurrentAnimationName())
				local is_boss = self.testprop.baseanim:find("boss_") ~= nil
				if params.bossvariant
					and ui:Checkbox("Preview boss_ variant", is_boss)
				then
					if is_boss then
						-- Respawn to turn off boss (since we mess with its internals).
						self.spawn_at = self.spawn_targets_by_name.last
						self:Test(self.prefabname, params)
					else
						self.testprop.baseanim = "boss_".. self.testprop.baseanim
						if self.testprop.highlightchildren ~= nil then
							for _,child in ipairs(self.testprop.highlightchildren) do
								child.baseanim = "boss_".. child.baseanim
							end
						end
					end
					self.testprop.components.prop:SetVariation(self.preview_variation)
				end
				if params.variations then
					local changed
					changed, self.preview_variation = ui:SliderInt("Variation##preview", self.preview_variation or 1, 1, params.variations)
					self.preview_variation = math.floor(self.preview_variation)
					if changed then
						self.testprop.components.prop:SetVariation(self.preview_variation)
					end
				else
					self.preview_variation = nil
				end
				ui:Spacing()

				if params.parallax_use_baseanim_for_idle then
					ui:TextColored(WEBCOLORS.LIGHTGRAY, "idle animation is unavailable for legacy props without idle_ setup.")
				end
				local show_all_anims = not params.parallax or #params.parallax == 1
				local all_anims = self.testprop.AnimState:GetAnimNamesFromAnimFile(self.testprop.AnimState:GetCurrentBankName())
				self.testprop_all_anims = all_anims
				local anims = {}
				if show_all_anims then
					anims = all_anims
				else
					for _,anim in ipairs(all_anims) do
						-- All of our props with multiple animations use _part to
						-- indicate their part. Ignore animations that don't use
						-- this format because they're just used for different
						-- layers.
						local x = anim:gsub("_[^_]*$", "")
						if x ~= anim then
							table.insert(anims, x)
						end
					end
				end
				anims = lume.unique(anims)
				table.sort(anims)
				self.testanim = ui:_Combo("Animation##animpreview", self.testanim or 1, anims)
				if not show_all_anims and ui:IsItemHovered() then
					ui:SetTooltipMultiline(table.appendarrays({
								"Can only play anims with _ prefixes. (Animations play on all layers.)",
								"States idle_cat, purr_cat results in anims 'idle' and 'purr' on layer 'cat'.",
								"", "Full anim list:"}, all_anims))
				end
				self.testanim_loops = ui:_Checkbox("Looping##animpreview", self.testanim_loops)
				if ui:Button("Play##animpreview", nil, nil, #anims == 0) then
					if show_all_anims then
						self.testprop.AnimState:PlayAnimation(anims[self.testanim], self.testanim_loops)
					else
						-- Doesn't require a stategraph, but this is how the
						-- stategraph will play the anims so it's a good preview.
						-- Embellisher is a better alternative if it has a
						-- stategraph.
						SGCommon.Fns.PlayAnimOnAllLayers(self.testprop, anims[self.testanim], self.testanim_loops)
					end
				end
			else
				ui:TextColored(WEBCOLORS.LIGHTGRAY, "Spawn test prop to preview animations.")
			end

			self:AddTreeNodeEnder(ui)
		end


		self:AddSectionEnder(ui)
	end

	do
		local opts = lume.values(script_options)
		table.sort(opts)
		table.insert(opts, 1, "")

		local changed, newval = ui:ComboAsString("Special Prop Type", script_options[params.script], opts, true)
		if changed then
			local v,k = lume.match(script_options, function(v)
				return v == newval
			end)
			params.script = k
			self:SetDirty()
		end
		self:AddSectionEnder(ui)
	end

	if params.script then
		run_script_fn(params, function(script, _)
			if script.PropEdit or script.LivePropEdit then
				if ui:CollapsingHeader(script_options[params.script], ui.TreeNodeFlags.DefaultOpen) then
					ui:PushID("script.Edit")
					local inparams = deepcopy(params)
					params.script_args = params.script_args or {}
					if script.PropEdit then
						script.PropEdit(self,ui,params)
					end
					if script.LivePropEdit then
						script.LivePropEdit(self,ui,params, script.Defaults)
					end
					if not params.script or not next(params.script_args) then
						params.script_args = nil
					end
					if not deepcompare(params, inparams) then
						if script.Apply and self.testprop then
							script.Apply(self.testprop, params.script_args or {})
						end
						self:SetDirty()
					end
					ui:PopID()
				end
			end
		end)
	end

	if ui:CollapsingHeader("Paired Prop") then
		local changed
		params.childprefab, changed = self:PrefabSelector(ui, "Child Prefab", params.childprefab, self.groupfilter)
		if changed then
			if params.childprefab then
				params.childoffset = params.childoffset or { x=0, y=0, z=0, }
			else
				params.childoffset = nil
			end
		end
		if params.childprefab then
			params.childoffset = params.childoffset or { x=0, y=0, z=0, }
			changed = ui:DragVec3f("Child Offset", params.childoffset, 0.01, -20, 20) or changed
		end
		local changed2, text = ui:InputTextWithHint("Child Anim Name", "Anim name that works like parallax layers.", params.childanim)
		if changed2 then
			if text:len() == 0 then
				text = nil
			end
			params.childanim = text
			changed = true
		end
		if changed then
			self:SetDirty()
		end
	end

	if ui:CollapsingHeader("Sorting") then
		self:AddSectionStarter(ui)

		if params.parallax
			and lume.any(params.parallax, function(parallaxrow)
				return parallaxrow.onground
			end)
		then
			ui:Indent()
			ui:Text("Orientation")
			ui:Indent()
			ui:Text("Orientation must be Billboard when any parallax layer uses Ground Projection.")
			ui:Unindent()
			ui:Unindent()
			if params.onground then
				params.onground = nil
				self:SetDirty()
			end

		elseif ui:TreeNode("Orientation", ui.TreeNodeFlags.DefaultOpen) then
			--Ground orientation
			local orientation = 0
			if params.onground then
				orientation = 1
			elseif params.layer == "auto" then
				orientation = 2
			end
			local _, neworientation = nil, orientation
			_, neworientation = ui:RadioButton("Billboard\t", neworientation, 0)
			ui:SameLine()
			_, neworientation = ui:RadioButton("Ground Projection\t", neworientation, 1)
			ui:SameLine()
			_, neworientation = ui:RadioButton("Parts Below Ground", neworientation, 2)
			ui:SameLine()
			if neworientation ~= orientation then
				params.onground = neworientation == 1 or nil
				params.layer = neworientation == 2 and "auto" or nil
				self:SetDirty()
			end

			self:AddTreeNodeEnder(ui)
		end

		if ui:TreeNode("Layer", ui.TreeNodeFlags.DefaultOpen) then
			if params.layer == "auto" then
				if ui:TreeNode("AutoSort Layer Settings", ui.TreeNodeFlags.DefaultOpen) then
					--AutoSort Layer Settings
					local rowanim
					ui:Columns(2, "layersettings", false)
					ui:SetColumnOffset(1, 200)
					if params.parallax ~= nil then
						for i,parallaxrow in pairs(params.parallax) do
							rowanim = parallaxrow.anim
							ui:Text(rowanim)
							ui:NextColumn()

							local _, newautosort = nil, parallaxrow.autosortlayer
							if newautosort == "below" then
								newautosort = 1
							elseif newautosort == "above" then
								newautosort = 2
							else
								newautosort = 0
							end

							local _, newautosort = nil, newautosort
							_, newautosort = ui:RadioButton("Below ground\t##"..i, newautosort, 1)
							ui:SameLine()
							_, newautosort = ui:RadioButton("Above ground\t##"..i, newautosort, 2)
							ui:SameLine()
							_, newautosort = ui:RadioButton("Both\t##"..i, newautosort, 0)
							if newautosort ~= (parallaxrow.autosortlayer or 0) then
								if newautosort == 1 then
									parallaxrow.autosortlayer = "below"
									parallaxrow.underground = true
								elseif newautosort == 2 then
									parallaxrow.autosortlayer = "above"
									parallaxrow.underground = nil
								else
									parallaxrow.autosortlayer = nil
									parallaxrow.underground = nil
								end
								self:SetDirty()
							end
							ui:NextColumn()
						end
					end
					ui:Columns(1)
--					dbassert(parallaxrow ~= nil or i == 1)

					self:AddTreeNodeEnder(ui)
				end
			else
				--Layer
				local _, newlayer = nil, params.layer
				if newlayer == "backdrop" then
					newlayer = 2
				elseif newlayer == "bg" then
					newlayer = 1
				else
					newlayer = 0
				end

				_, newlayer = ui:RadioButton("World\t", newlayer, 0)
				ui:SetTooltipIfHovered("Drawn after the world mesh. For fg and grid props. Player/npc/monsters are drawn here at +0.")
				ui:SameLine()
				_, newlayer = ui:RadioButton("Background\t", newlayer, 1)
				ui:SetTooltipIfHovered("Drawn after the world mesh but before layer 'World'. For grid props that are on the ground.")
				ui:SameLine()
				_, newlayer = ui:RadioButton("Backdrop\t", newlayer, 2)
				ui:SetTooltipIfHovered("Drawn before the world mesh. For distant bg props.")

				if newlayer == 3 then
					newlayer = "auto"
				elseif newlayer == 2 then
					newlayer = "backdrop"
				elseif newlayer == 1 then
					newlayer = "bg"
				else
					newlayer = nil
				end
				if newlayer ~= params.layer then
					params.layer = newlayer
					params.sortorder = nil
					self:SetDirty()
				end

				--Sort order
				local sortorderlist =
				{
					"+3   (Most in front for layer)",
					"+2",
					"+1",
					"+0   (Default)",
					"-1",
					"-2",
					"-3   (Most behind for layer)",
				}
				local defaultsortorderidx = math.ceil(#sortorderlist / 2)
				local sortorderidx = defaultsortorderidx - (params.sortorder or 0)
				local newsortorderidx = ui:_Combo("Sort Order Within Layer", math.clamp(sortorderidx, 1, #sortorderlist), sortorderlist)
				if newsortorderidx ~= sortorderidx then
					local newsortorder = defaultsortorderidx - newsortorderidx
					if newsortorder == 0 then
						newsortorder = nil
					end
					if params.sortorder ~= newsortorder then
						params.sortorder = newsortorder
						self:SetDirty()
					end
				end
			end

			self:AddTreeNodeEnder(ui)
		end


		if ui:TreeNode("Prop Type", ui.TreeNodeFlags.DefaultOpen) then
			local tt = "\nPrimarily used to organize props while editing prop placement."
			local _, proptype = nil, params.proptype or 0
			_, proptype = ui:RadioButton("Grid\t", proptype, PropType.Grid)
			ui:SetTooltipIfHovered("For anything in the world space. ".. tt)
			ui:SameLine()
			_, proptype = ui:RadioButton("Decor\t", proptype, PropType.Decor)
			ui:SetTooltipIfHovered("For fg/bg elements that aren't part of gameplay. ".. tt)
			ui:SameLine()
			_, proptype = ui:RadioButton("Lighting\t", proptype, PropType.Lighting)
			ui:SetTooltipIfHovered("For render lights (not props that look like lights).")
			ui:SameLine()
			_, proptype = ui:RadioButton("Particles\t", proptype, PropType.Particles)
			ui:SetTooltipIfHovered("For any particle systems.")
			proptype = proptype ~= 0 and proptype or nil
			if proptype ~= params.proptype and proptype ~= 0 then
				params.proptype = proptype
				self:SetDirty()
			end
			self:AddTreeNodeEnder(ui)
		end

		if ui:Checkbox("On Water", params.on_water) then
			params.on_water = not params.on_water or nil
			self:SetDirty()
		end
		if params.on_water then
			ui:SameLine()
			if ui:Checkbox("Colorize Below Water", params.water_colorize) then
				params.water_colorize = not params.water_colorize or nil
				self:SetDirty()
			end
			-- if we're on water and ground projected we have to be sorting layer world and sort order < 0
			print("params.sortorder",params.sortorder)
			if params.layer == "auto" then
				self:WarningMsg(ui,
					"!!! Warning !!!",
					"'On Water' props can not have 'Parts Below Ground' enabled.")
			end
			if params.onground and (params.layer ~= nil or params.sortorder == nil or params.sortorder >= 0) then
				self:WarningMsg(ui,
					"!!! Warning !!!",
					"Ground projected 'On Water' props need to have sorting layer 'Foreground' and negative sort order.")
			end
		end

		self:AddSectionEnder(ui)
	end

	if ui:CollapsingHeader("Size") then
		self:AddSectionStarter(ui)

		if ui:TreeNode("Physics", ui.TreeNodeFlags.DefaultOpen) then
			--Physics type
			-- NB: these keys must match those in prop_autogen.lua
			local physicstypemap =
			{
				nothing  = "None",
				dec      = "Decor - (round square)",
				smdec    = "Small Decor - (circle)",
				obs      = "Obstacle - (round line)",
				vert_obs = "Vertical Obstacle - (round line in z)",
				smobs    = "Small Obstacle - (round line)",
				holeblock    = "Hole - (round line jump/flyable)",
			}
			local physicstype = physicstypemap[params.physicstype] or physicstypemap.nothing
			local physicstype_display_order = {
				"dec",
				"smdec",
				"obs",
				"smobs",
				"vert_obs",
				"holeblock",
			}
			local physicstypestrlist = lume.map(physicstype_display_order, function(v)
				return physicstypemap[v]
			end)
			table.insert(physicstypestrlist, 1, physicstypemap.nothing)
			local newphysicstype = ui:_ComboAsString("##physicstype", physicstype, physicstypestrlist, true)
			if newphysicstype ~= physicstype then
				physicstypemap = table.invert(physicstypemap)
				newphysicstype = physicstypemap[newphysicstype] -- use the pretty names as a lookup!
				if params.physicstype ~= newphysicstype then
					params.physicstype = newphysicstype
					if newphysicstype == nil then
						params.physicssize = nil
					end
					self:SetDirty()
				end
			end

			if physicstype then
				--Physics size
				ui:PushItemWidth(100)
				local _, newphysicssize = ui:InputText("Size##physics", params.physicssize, imgui.InputTextFlags.CharsDecimal)
				if newphysicssize ~= nil then
					if string.len(newphysicssize) == 0 then
						newphysicssize = nil
					else
						newphysicssize = tonumber(newphysicssize)
					end
					if params.physicssize ~= newphysicssize then
						params.physicssize = newphysicssize
						self:SetDirty()
					end
				end
				ui:PopItemWidth()
			end

			self:AddTreeNodeEnder(ui)
		end

		if ui:TreeNode("Snap to Grid", ui.TreeNodeFlags.DefaultOpen) then
			local w = ui:GetColumnWidth()
			local level_w = w * .2
			local wid_w = w * .2
			local ht_w = w * .2
			local expand_w = w * .1
			ui:Columns(5, nil, false)
			ui:SetColumnOffset(1, level_w)
			ui:SetColumnOffset(2, level_w + wid_w)
			ui:SetColumnOffset(3, level_w + wid_w + ht_w)
			ui:SetColumnOffset(4, level_w + wid_w + ht_w + expand_w)

			ui:Text("Level")
			ui:NextColumn()
			ui:Text("Cols")
			ui:NextColumn()
			ui:Text("Rows")
			ui:NextColumn()
			ui:Text("+Npc")
			ui:NextColumn()
			ui:NextColumn()

			local numrows = params.gridsize ~= nil and #params.gridsize or 1
			local removerow = nil

			for i = 1, numrows do
				local gridsizerow, rowwid, rowht, rowlevel, rowexpand
				if params.gridsize ~= nil then
					gridsizerow = params.gridsize[i]
					if gridsizerow ~= nil then
						rowwid = gridsizerow.w
						rowht = gridsizerow.h
						rowlevel = gridsizerow.level
						rowexpand = gridsizerow.expand
					end
				end
				dbassert(gridsizerow ~= nil or i == 1)

				ui:PushItemWidth(math.max(20, level_w - 32))
				local _, newlevel = ui:InputText("##gridsizelevel"..tostring(i), rowlevel ~= nil and tostring(rowlevel) or "", imgui.InputTextFlags.CharsDecimal)
				if newlevel ~= nil then
					if string.len(newlevel) == 0 then
						newlevel = nil
					else
						newlevel = tonumber(newlevel)
					end
					if rowlevel ~= newlevel then
						rowlevel = newlevel
						if rowwid == nil and rowht == nil and rowlevel == nil and rowexpand == nil and numrows == 1 then
							params.gridsize = nil
							gridsizerow = nil
						elseif gridsizerow == nil then
							gridsizerow = { level = rowlevel }
							params.gridsize = { gridsizerow }
						else
							gridsizerow.level = rowlevel
						end
						self:SetDirty()
					end
				end
				ui:PopItemWidth()

				ui:NextColumn()

				ui:PushItemWidth(math.max(20, wid_w - 10))
				local _, newwid = ui:InputText("##gridsizewid"..tostring(i), rowwid or "", imgui.InputTextFlags.CharsDecimal)
				if newwid ~= nil then
					if string.len(newwid) == 0 then
						newwid = nil
					else
						newwid = tonumber(newwid)
						if newwid ~= nil then
							newwid = math.max(0, math.floor(newwid))
						end
					end
					if rowwid ~= newwid then
						rowwid = newwid
						if rowwid == nil and rowht == nil and rowlevel == nil and rowexpand == nil and numrows == 1 then
							params.gridsize = nil
							gridsizerow = nil
						elseif gridsizerow == nil then
							gridsizerow = { w = rowwid }
							params.gridsize = { gridsizerow }
						else
							gridsizerow.w = rowwid
						end
						self:SetDirty()
					end
				end
				ui:PopItemWidth()

				ui:NextColumn()

				ui:PushItemWidth(math.max(20, ht_w - 10))
				local _, newht = ui:InputText("##gridsizeht"..tostring(i), rowht ~= nil and tostring(rowht) or "", imgui.InputTextFlags.CharsDecimal)
				if newht ~= nil then
					if string.len(newht) == 0 then
						newht = nil
					else
						newht = tonumber(newht)
						if newht ~= nil then
							newht = math.max(0, math.floor(newht))
						end
					end
					if rowht ~= newht then
						rowht = newht
						if rowwid == nil and rowht == nil and rowlevel == nil and rowexpand == nil and numrows == 1 then
							params.gridsize = nil
							gridsizerow = nil
						elseif gridsizerow == nil then
							gridsizerow = { h = rowht }
							params.gridsize = { gridsizerow }
						else
							gridsizerow.h = rowht
						end
						self:SetDirty()
					end
				end
				ui:PopItemWidth()

				ui:NextColumn()

				local changed, newexpand = ui:Checkbox("##expandgridsize"..tostring(i), rowexpand ~= nil)
				if ui:IsItemHovered() then
					ui:SetTooltip("Expand grid size in front (bottom) to include space for the npc to stand.")
				end
				if changed then
					newexpand = newexpand and { bottom = 2 } or nil
					if not deepcompare(rowexpand, newexpand) then
						rowexpand = newexpand
						if rowwid == nil and rowht == nil and rowlevel == nil and rowexpand == nil and numrows == 1 then
							params.gridsize = nil
							gridsizerow = nil
						elseif gridsizerow == nil then
							dbassert(rowexpand) --sanity check
							gridsizerow = { expand = rowexpand }
							params.gridsize = { gridsizerow }
						else
							gridsizerow.expand = rowexpand
						end
						self:SetDirty()
					end
				end

				ui:NextColumn()

				if ui:Button(ui.icon.remove .."##gridsize"..tostring(i), nil, nil, gridsizerow == nil) then
					removerow = i
				end

				if i == numrows then
					ui:SameLineWithSpace()

					if ui:Button(ui.icon.add .."##gridsize"..tostring(i)) then
						if params.gridsize == nil then
							params.gridsize = { {}, {} }
						else
							params.gridsize[numrows + 1] = {}
						end
						self:SetDirty()
					end
				end

				ui:NextColumn()
			end

			if removerow ~= nil then
				if numrows == 1 then
					params.gridsize = nil
				else
					table.remove(params.gridsize, removerow)
					if #params.gridsize == 1 and next(params.gridsize[1]) == nil then
						params.gridsize = nil
					end
				end
				self:SetDirty()
			end

			ui:Columns()

			self:AddTreeNodeEnder(ui)
		end

		self:AddSectionEnder(ui)
	end

	if ui:CollapsingHeader("Dev Options") then
		self:AddSectionStarter(ui)

		-- Adding native components must be complete before we spawn new entities.
		if ui:Checkbox("Has Sound", params.sound) then
			params.sound = not params.sound or nil
			self:SetDirty()
		end

		if ui:Checkbox("Clickable", params.clickable) then
			params.clickable = not params.clickable or nil
			self:SetDirty()
		end

		-- Props that are spawned from code and should never be saved by
		-- propmanager. (ent.persists must change *before* prop component is
		-- added.)
		if ui:Checkbox("Persists", not params.nonpersist) then
			params.nonpersist = not params.nonpersist or nil
			self:SetDirty()
		end

		if ui:Checkbox("Make Placer", params.placer) then
			params.placer = not params.placer or nil
			self:SetDirty()
		end

		if ui:Checkbox("Hide MOUSEOVER layer", params.hidemouseover) then
			params.hidemouseover = not params.hidemouseover or nil
			self:SetDirty()
		end

		ui:Value("Script File", params.script)
		local script_hovered = ui:IsItemHovered()

		ui:TextWrapped("Script Args:  ".. table.inspect(params.script_args))
		if script_hovered or ui:IsItemHovered() then
			ui:SetTooltip("Editable via the 'Special Prop Type' dropdown. See script_options.")
		end


		local _, newsg = ui:InputText("Stategraph Name Override", params.stategraph_override, imgui.InputTextFlags.CharsNoBlank)
		if newsg ~= nil then
			if string.len(newsg) == 0 then
				newsg = nil
			end
			if params.stategraph_override ~= newsg then
				params.stategraph_override = newsg
				self:SetDirty()
			end
		end
		if ui:IsItemHovered() then
			ui:SetTooltip("This is needed when the object has no stategraph and the auto-generated doesn't do the trick.")
		end
		self:AddSectionEnder(ui)
	end

	self:ColorUi(ui, params)

	if ui:CollapsingHeader("Fx") then
		self:AddSectionStarter(ui)

		if ui:TreeNode("Ambience", ui.TreeNodeFlags.DefaultOpen) then
			--Targets
			if ui:TreeNode("Targets##lighting") then
				self:AddTargetList(ui, params, "lighttargets")
				self:AddTreeNodeEnder(ui)
			end

			--Light override
			local _, newlightoverride = ui:SliderInt("Light Override", params.lightoverride or 0, 0, 100, "%d%%")
			if newlightoverride ~= nil then
				if newlightoverride == 0 then
					newlightoverride = nil
				end
				if params.lightoverride ~= newlightoverride then
					params.lightoverride = newlightoverride
					self:SetDirty()
				end
			end

			self:AddTreeNodeEnder(ui)
		end

		if ui:TreeNode("Bloom", ui.TreeNodeFlags.DefaultOpen) then
			--Targets
			if ui:TreeNode("Targets##bloom") then
				self:AddTargetList(ui, params, "bloomtargets")
				self:AddTreeNodeEnder(ui)
			end

			--Bloom
			local _, newbloom = ui:SliderInt("Intensity", params.bloom or 0, 0, 100, "%d%%")
			if newbloom ~= nil then
				if newbloom == 0 then
					newbloom = nil
				end
				if params.bloom ~= newbloom then
					params.bloom = newbloom
					self:SetDirty()
				end
			end

			--Glow color
			local _, newglow = ui:Checkbox("Override Glow Color", params.glowcolor ~= nil)
			if newglow ~= (params.glowcolor ~= nil) then
				if newglow then
					local glowcolor = 0xFFFFFFFF
					params.glowcolor = HexToStr(glowcolor)
				else
					params.glowcolor = nil
				end
				self:SetDirty()
			end
			if params.glowcolor ~= nil then
				local glowcolor = params.glowcolor ~= nil and StrToHex(params.glowcolor) or 0xFFFFFFFF
				local glowr, glowg, glowb = HexToRGBFloats(glowcolor)
				local _, newglowr, newglowg, newglowb = ui:ColorEdit3("Glow Color", glowr, glowg, glowb, ui.ColorEditFlags.PickerHueBar | ui.ColorEditFlags.Uint8 | ui.ColorEditFlags.DisplayRGB | ui.ColorEditFlags.InputRGB)
				if newglowr ~= nil or newglowg ~= nil or newglowb ~= nil then
					local newglowcolor = RGBFloatsToHex(newglowr or glowr, newglowg or glowg, newglowb or glowb, 1)
					if newglowcolor ~= glowcolor then
						params.glowcolor = HexToStr(newglowcolor)
						self:SetDirty()
					end
				end
			end

			self:AddTreeNodeEnder(ui)
		end

		self:AddSectionEnder(ui)
	end

	if ui:CollapsingHeader("Rim Lights") then
		self:AddSectionStarter(ui)

		ui:Text("-TODO-")

		self:AddSectionEnder(ui)
	end


	if ui:CollapsingHeader("Networking") then
		self:AddSectionStarter(ui)

		-- Network type
		local networkenabledlist =
		{
			"Inherit from script",
			"Networking OFF",
			"Networking ON",
		}

		local typeidx = 1
		if params.networked == 0 then	-- Off
			typeidx = 2
		elseif params.networked == 1 then	-- On
			typeidx = 3
		end

		local newtypeidx = ui:_Combo("##networktype", typeidx, networkenabledlist)
		if newtypeidx ~= typeidx then
			if newtypeidx == 1 then
				params.networked = nil	-- inherit
			elseif newtypeidx == 2 then
				params.networked = 0	-- Off
			elseif newtypeidx == 3 then
				params.networked = 1	-- On
			end
			self:SetDirty()
		end

		if params.networked == 1 then
			ui:Indent()

			if ui:Checkbox("Minimal Entity", params.isminimal) then
				-- toggle isminimal
				if params.isminimal then
					params.isminimal = nil
				else
					params.isminimal = true
					params.transferable = nil
					params.animhistory = nil
				end
				self:SetDirty()
			end

			if ui:Checkbox("Only allowed to spawn on Host", params.hostspawn) then
				params.hostspawn = not params.hostspawn or nil
				self:SetDirty()
			end

			-- Only show the specific network settings if the entity is NOT a minimal entity
			if not params.isminimal then
				if ui:Checkbox("Ownership is transferable", params.transferable) then
					params.transferable = not params.transferable or nil
					self:SetDirty()
				end

				if ui:Checkbox("Sync Anim History", params.animhistory) then
					params.animhistory = not params.animhistory or nil
					self:SetDirty()
				end
			end

			ui:Unindent()
		end

		self:AddSectionEnder(ui)
	end

	if params.script then
		run_script_fn(params, function(script, _)
			if script.Validate then
				ui:PushID("script.Validate")
				local inparams = deepcopy(params)
				script.Validate(self,ui,params,self.prefabname)
				if not deepcompare(params, inparams) then
					if script.Apply and self.testprop then
						script.Apply(self.testprop, params.script_args or {})
					end
					self:SetDirty()
				end
				ui:PopID()
			end
		end)
	end
end

function PropEditor:ColorUi(ui, params)
	if not ui:CollapsingHeader("Color") then
		return
	end

	self:AddSectionStarter(ui)

	if Hsb.RawUi(ui, "##HsbColorShift", params) then
		self:SetDirty()
	end

	if ui:TreeNode("RGB Color Multiplier") then
		--Mult color
		local multcolor = params.multcolor ~= nil and StrToHex(params.multcolor) or 0xFFFFFFFF
		local multr, multg, multb, multa = HexToRGBFloats(multcolor)
		multr = math.floor(multr * 100 + .5)
		multg = math.floor(multg * 100 + .5)
		multb = math.floor(multb * 100 + .5)
		multa = math.floor(multa * 100 + .5)
		local _, newmultr = ui:SliderInt("x R", multr, 0, 100, "%d%%")
		local _, newmultg = ui:SliderInt("x G", multg, 0, 100, "%d%%")
		local _, newmultb = ui:SliderInt("x B", multb, 0, 100, "%d%%")
		local _, newmulta = ui:SliderInt("x A", multa, 0, 100, "%d%%")
		if ui:Button("Reset RGB Color Multiplier") then
			newmultr, newmultg, newmultb, newmulta = 100, 100, 100, 100
		end
		if newmultr ~= nil or newmultg ~= nil or newmultb ~= nil or newmulta ~= nil then
			local newmultcolor = RGBFloatsToHex((newmultr or multr) / 100, (newmultg or multg) / 100, (newmultb or multb) / 100, (newmulta or multa) / 100)
			if newmultcolor ~= multcolor then
				if newmultcolor == 0xFFFFFFFF then
					params.multcolor = nil
				else
					params.multcolor = HexToStr(newmultcolor)
				end
				self:SetDirty()
			end
		end

		self:AddTreeNodeEnder(ui)
	end

	if ui:TreeNode("RGB Add Color") then
		--Add color
		local addcolor = params.addcolor ~= nil and StrToHex(params.addcolor) or 0x00000000
		local addr, addg, addb = HexToRGBInts(addcolor)
		local _, newaddr = ui:SliderInt("+ R", addr, 0, 255, "%+d")
		local _, newaddg = ui:SliderInt("+ G", addg, 0, 255, "%+d")
		local _, newaddb = ui:SliderInt("+ B", addb, 0, 255, "%+d")
		if ui:Button("Reset RGB Add Color") then
			newaddr, newaddg, newaddb = 0, 0, 0
		end
		if newaddr ~= nil or newaddg ~= nil or newaddb ~= nil then
			local newaddcolor = RGBIntsToHex(newaddr or addr, newaddg or addg, newaddb or addb, 0)
			if newaddcolor ~= addcolor then
				if newaddcolor == 0x00000000 then
					params.addcolor = nil
				else
					params.addcolor = HexToStr(newaddcolor)
				end
				self:SetDirty()
			end
		end

		self:AddTreeNodeEnder(ui)
	end

	if ui:TreeNode("Color Fade") then
		local hasfade = params.fade ~= nil
		local changed, newfade = ui:Checkbox("Fade", hasfade)
		if changed then
			if not newfade then
				params.fade = nil
			else
				params.fade = {bottom = -1, top = 3}
			end
			self:SetDirty()
		end

		if newfade then
			local fadebottom, fadetop = params.fade.bottom or -1, params.fade.top or 3
			local bottomchanged, newfadebottom = ui:SliderFloat("Bottom (full black):",fadebottom, -20, 20, "%.2f")
			local topchanged, newfadetop = ui:SliderFloat("Top (full color):",fadetop, -20, 20, "%.2f")
			if bottomchanged or topchanged then
				params.fade = {bottom = lume.round(newfadebottom, 0.01), top = lume.round(newfadetop, 0.01)}
				self:SetDirty()
			end
		end
		self:AddTreeNodeEnder(ui)
	end
	self:AddSectionEnder(ui)
end

function PropEditor:EnumListUi(ui, label, all_values, current_values)
	if not ui:TreeNode(label, ui.TreeNodeFlags.DefaultClosed) then
		return
	end
	local list = current_values
	local removed = {}
	local added = {}
	for _, value in ipairs(all_values) do
		local index = list and lume(list):find(value):result()
		local is_on = index ~= nil
		if ui:RadioButton(value, is_on) then
			if is_on then
				table.insert(removed, index)
			else
				table.insert(added, value)
			end
		end
	end
	local changed = next(removed) or next(added)
	if changed then
		for _, r in ipairs(removed) do
			table.remove(list, r)
		end
		for _, a in ipairs(added) do
			table.insert(list, a)
		end
	end
	self:AddTreeNodeEnder(ui)
	return changed
end

function PropEditor:AddTargetList(ui, params, id)
	local indent = 42
	local w = ui:GetColumnWidth() - indent
	local anim_w = w * .5
	local type_w = w * .8 - anim_w
	ui:Columns(3, nil, false)
	ui:SetColumnOffset(1, indent + anim_w)
	ui:SetColumnOffset(2, indent + anim_w + type_w)

	ui:Text("Name")
	ui:NextColumn()
	ui:Text("Type")
	ui:NextColumn()
	ui:NextColumn()

	local numrows = params[id] ~= nil and #params[id] or 1
	local removerow = nil

	for i = 1, numrows do
		local listrow, rowanim, rowtype
		if params[id] ~= nil then
			listrow = params[id][i]
			if listrow ~= nil then
				rowanim = listrow.name
				rowtype = listrow.type
			end
		end
		dbassert(listrow ~= nil or i == 1)

		ui:PushItemWidth(math.max(20, anim_w - 10))
		local _, newanim = ui:InputText("##"..id.."name"..tostring(i), rowanim or "", imgui.InputTextFlags.CharsNoBlank)
		if newanim ~= nil then
			if string.len(newanim) == 0 then
				newanim = nil
			end
			if rowanim ~= newanim then
				rowanim = newanim
				if rowanim == nil and rowtype == nil and numrows == 1 then
					params[id] = nil
					listrow = nil
				elseif listrow == nil then
					listrow = { name = rowanim }
					params[id] = { listrow }
				else
					listrow.name = newanim
				end
				self:SetDirty()
			end
		end
		ui:PopItemWidth()

		ui:NextColumn()

		ui:PushItemWidth(math.max(20, type_w - 10))
		local typelist =
		{
			"",
			"Symbol",
			"Layer",
		}
		local rowtypeidx = 1
		for i = 1, #typelist do
			if rowtype == typelist[i] then
				rowtypeidx = i
				break
			end
		end
		local newtypeidx = ui:_Combo("##"..id.."type"..tostring(i), rowtypeidx, typelist)
		if newtypeidx ~= rowtypeidx then
			local newtype = typelist[newtypeidx]
			if string.len(newtype) == 0 then
				newtype = nil
			end
			if rowtype ~= newtype then
				rowtype = newtype
				if rowanim == nil and rowtype == nil and numrows == 1 then
					params[id] = nil
					listrow = nil
				elseif listrow == nil then
					listrow = { type = rowtype }
					params[id] = { listrow }
				else
					listrow.type = newtype
				end
				self:SetDirty()
			end
		end
		ui:PopItemWidth()

		ui:NextColumn()

		if ui:Button(ui.icon.remove .."##"..id..tostring(i), nil, nil, listrow == nil) then
			removerow = i
		end

		if i == numrows then
			ui:SameLineWithSpace()

			if ui:Button(ui.icon.add .."##"..id..tostring(i)) then
				if params[id] == nil then
					params[id] = { {}, {} }
				else
					params[id][numrows + 1] = {}
				end
				self:SetDirty()
			end
		end

		ui:NextColumn()
	end

	if removerow ~= nil then
		if numrows == 1 then
			params[id] = nil
		else
			table.remove(params[id], removerow)
			if #params[id] == 1 and next(params[id][1]) == nil then
				params[id] = nil
			end
		end
		self:SetDirty()
	end

	ui:Columns()
end

function PropEditor:PrefabDropdownChanged(newname)
	PropEditor._base.PrefabDropdownChanged(self, newname)
	lume.clear(self.edit_group.parallax)
	self:RemoveTestProp()
end

function PropEditor:BeforeRename(oldname, newname)
	local EditableEditor = require "debug.inspectors.editableeditor"
	EditableEditor.RunOnAllPropData(self, function(ed, propdata, levelname)
		local old_data = propdata[oldname]
		propdata[oldname] = nil
		assert_warning(propdata[newname] == nil, "Clobbering existing prop name in propdata! ".. newname)
		if old_data then
			propdata[newname] = old_data
			return true
		end
	end)
end

local function UseOldAnimBuildDefaults(oldname, newname)
	-- If no bank/build are specified then we use the name, but if we renamed
	-- then we want to apply the old name.
	local params = _static.data[newname]
	assert(params, newname)
	params.bank = params.bank or oldname
	params.build = params.build or oldname
end

function PropEditor:AfterRename(oldname, newname)
	UseOldAnimBuildDefaults(oldname, newname)
	DebugNodes.SceneGenEditor:FindOrCreateEditor():OnPropRenamed(oldname, newname)
end

function PropEditor:AfterDuplicate(oldname, newname)
	UseOldAnimBuildDefaults(oldname, newname)
end

function PropEditor:BeforeDelete(prop_name)
	local EditableEditor = require "debug.inspectors.editableeditor"
	EditableEditor.RunOnAllPropData(self, function(ed, propdata, levelname)
		local old_data = propdata[prop_name]
		propdata[prop_name] = nil
		if old_data then
			return true
		end
	end)
	DebugNodes.SceneGenEditor:FindOrCreateEditor():OnPropDeleted(prop_name)
end

-- Don't submit this code uncommented. Don't want the button unless a coder is
-- using it.
--~ function PropEditor:BatchModify(prefabs)
--~ 	for prefab_name,prefab in pairs(prefabs) do
--~ 		if prefab_name:find("trap_")
--~ 			--~ and prefab.proptype == PropType.Decor
--~ 			--~ and prefab.layer == nil -- Foreground
--~ 		then
--~ 			local newgroup = "trap_props"
--~ 			TheLog.ch.Prop:printf("Changed '%s' group: %s -> %s", prefab_name, prefab.group, newgroup)
--~ 			prefab.group = newgroup
--~ 		end
--~ 	end
--~ end

DebugNodes.PropEditor = PropEditor

return PropEditor
