local DebugNodes = require "dbui.debug_nodes"
local iterator = require "util.iterator"
local lume = require "util.lume"
require "consolecommands"
require "constants"

local autogen_categories = {
	drops     = require("prefabs.drops_autogen_data"),
	fx        = require("prefabs.fx_autogen_data"),
	npc        = require("prefabs.npc_autogen_data"),
	--~ particles = require("prefabs.particles_autogen_data"),
	prop      = require("prefabs.prop_autogen_data"),
	world     = require("prefabs.world_autogen_data"),
}

local no_category = "uncategorized"

local DebugPrefabs = Class(DebugNodes.DebugNode, function(self)
	DebugNodes.DebugNode._ctor(self, "Debug Prefabs")
	self.filter = nil

	self.sorted_categories = lume.keys(autogen_categories)
	table.insert(self.sorted_categories, no_category)
	table.sort(self.sorted_categories)

	self:UpdateCache()

	--jcheng: this could be set to true if we want the filter to be in focus immediately after launching this window
	--however until the bug where modifiers are stuck when clicking imgui widgets, this is a bad idea
	self.wants_focus = false
end)

DebugPrefabs.PANEL_WIDTH = 600
DebugPrefabs.PANEL_HEIGHT = 600


local function get_category_for_prefab(prefab_name)
	for name,cat in pairs(autogen_categories) do
		if cat[prefab_name] then
			return name
		end
	end
end

function DebugPrefabs:UpdateCache()

	self.cached = {}

	for _,name in ipairs(self.sorted_categories) do
		self.cached[name] = {}
	end

	local prefix_filter =  "^".. (self.filter or "")

	--first add the ones that start with the search term
	for k, v in iterator.sorted_pairs( Prefabs ) do
		--k = k:sub("_","")
		--local filter = self.filter:sub("_","")
		if self.filter == nil or k:find(prefix_filter)
		then
			local cat = get_category_for_prefab(k)
			if not cat then
				cat = no_category
			end
			table.insert(self.cached[cat], k)
		end
	end

	--then add ones that match anywhere
	for k, v in iterator.sorted_pairs( Prefabs ) do
		if self.filter == nil
			or (not k:find(prefix_filter) and k:find(self.filter))
		then
			local cat = get_category_for_prefab(k)
			if not cat then
				cat = no_category
			end
			table.insert(self.cached[cat], k)
		end
	end

end

function DebugPrefabs:RenderPanel( ui, panel )

	local changed
	changed, self.filter = ui:FilterBar(self.filter)
	if changed then
		self:UpdateCache()
	end

	if self.wants_focus then
		ui:SetKeyboardFocusHere()
		self.wants_focus = false
	end

	if self.selected_prefab then
		ui:Text("Click in world to spawn: ".. self.selected_prefab)
		ui:SameLineWithSpace()
		if ui:Button("Clear Selection") then
			self.selected_prefab = nil
		end
		ui:Spacing()
	else
		ui:Text("No prefab selected to spawn.")
		ui:Dummy(0, 6) -- keep v-alignment with if case
	end

	if ui:Checkbox("Show bank", self.show_bank) then
		self.show_bank = not self.show_bank
	end
	ui:SameLineWithSpace()
	if ui:Checkbox("Show deps", self.show_deps) then
		self.show_deps = not self.show_deps
	end

	if ui:Button("Expand all") then
		self.show_all = true
	end
	ui:SameLineWithSpace()
	if ui:Button("Collapse all") then
		self.show_all = false
	end

	local n_columns = 2
	if self.show_bank then
		n_columns = n_columns + 1
	end
	if self.show_deps then
		n_columns = n_columns + 1
	end
	for _,cat_name in ipairs(self.sorted_categories) do
		if self.show_all ~= nil then
			ui:SetNextItemOpen(self.show_all, ui.Cond.Always)
		end
		if ui:TreeNode(cat_name) then
			local cached_list = self.cached[cat_name]
			if #cached_list > 0 then

				ui:Columns(n_columns, "prefabs")
				ui:Text("Prefab")
				ui:NextColumn()
				ui:Text("Actions")
				ui:SetColumnWidth(-1, 130)
				ui:NextColumn()
				if self.show_bank then
					ui:Text("Bank")
					ui:NextColumn()
				end
				if self.show_deps then
					ui:Text("Select Dependencies")
					ui:NextColumn()
				end
				ui:Separator()

				for _, v in pairs( cached_list ) do
					ui:Text( v )
					ui:NextColumn()

					local is_spawnable = cat_name ~= "world"
					if is_spawnable then
						if ui:Button( "Spawn".."###spawn"..v ) then
							c_spawn(v)
						end
						ui:SameLineWithSpace()
						if ui:Button( "Select".."###select"..v ) then
							self.selected_prefab = v
						end
					end
					ui:NextColumn()

					if self.show_bank then
						local prefab = Prefabs[v]
						if prefab then
							local text = lume.map(prefab.assets, function(x)
								if x.type == "ANIM" then
									return x.file
								end
							end)
							ui:Text(table.concat(text, " "))
						end
						ui:NextColumn()
					end
					if self.show_deps then
						local prefab = Prefabs[v]
						if prefab then
							-- Buttons are kindof unmanageable, but dropdown is also bad.
							--~ local deps = shallowcopy(prefab.deps)
							--~ table.insert(deps, 1, "")
							--~ local idx = lume.find(deps, self.selected_prefab) or 1
							--~ local new_idx = ui:_Combo("Select###selectdep"..v, idx, deps)
							--~ if idx ~= new_idx and new_idx > 1 then
							--~ 	self.selected_prefab = deps[new_idx]
							--~ end
							for i,d in ipairs(prefab.deps) do
								if ui:Button(d.."###selectdep"..d ) then
									self.selected_prefab = d
								end
								if (i % 4) ~= 0 then
									ui:SameLineWithSpace()
								end
							end
							ui:Dummy(0,5)
							ui:Dummy(0,10)
						end
						ui:NextColumn()
					end
				end
				ui:Columns(1)

			else
				ui:TextColored(BGCOLORS.HALF, "no matches")
			end
			ui:TreePop()
		end
	end
	self.show_all = nil

	if not ui:WantCaptureMouse()
		and ui:IsMouseClicked(0)
		and self.selected_prefab
	then
		c_spawn(self.selected_prefab)
	end
end

DebugNodes.DebugPrefabs = DebugPrefabs

return DebugPrefabs
