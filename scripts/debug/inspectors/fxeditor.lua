-- vfx editor for tuning animation-based vfx. See also ParticleEditorScreen for
-- actual particle systems.

local DebugNodes = require "dbui.debug_nodes"
local DebugSettings = require "debug.inspectors.debugsettings"
local EventFuncEditor = require "debug.inspectors.eventfunceditor"
local FxTimeline = require("components/fxtimeline")
local PrefabEditorBase = require("debug/inspectors/prefabeditorbase")
local Timeline = require("util/timeline")
local eventfuncs = require "eventfuncs"
local fmodtable = require "defs.sound.fmodtable"
local iterator = require "util.iterator"
local lume = require "util.lume"
require "mathutil"

--Make sure our util functions are loaded
require("prefabs/fx_autogen")

local _static = PrefabEditorBase.MakeStaticData("fx_autogen_data")

local FxEditor = Class(PrefabEditorBase, function(self)
	PrefabEditorBase._ctor(self, _static)

	self.name = "Fx Editor"
	self.test_label = "Spawn test particles"

	self:LoadLastSelectedPrefab("fxeditor")

	self.testfx = nil

	self:WantHandle()

	self.funceditor = EventFuncEditor(self)

	self.timeline = {
		editor = Timeline(),
		group_def = FxTimeline.group_def,
		visible = 1,
		ui = {
			prettyname = {
				shift = 'HSB Color Shift',
				multiply = 'RGBA Color Scale',
				add = 'RGB Color Add',
				shift_hue = 'Shift Hue',
				shift_saturation = 'Shift Saturation',
				shift_brightness = 'Shift Brightness',
				multiply_red = 'Scale Red',
				multiply_green = 'Scale Green',
				multiply_blue = 'Scale Blue',
				multiply_alpha = 'Scale Alpha',
				add_red = 'Add Red',
				add_green = 'Add Green',
				add_blue = 'Add Blue',
			},
			help = {
				shift    = "Tweak color by shifting along HSB axes.",
				multiply = "Reduce amount of a single color component. No effect on black (already zero values).",
				add      = "Increase amount of a single color component. No effect on white (already max values).",
			},
			fmt = {
				default = "%.f",
				shift = "%+.0f%%",
				multiply = "%.0f00%%",
				add = "+%.f",
				shift_hue = "%+.0fº",
			},
		},
	}
end)

FxEditor.PANEL_WIDTH = 660
FxEditor.PANEL_HEIGHT = 990

function FxEditor:OnDeactivate()
	FxEditor._base.OnDeactivate(self)
	if self.testfx ~= nil then
		self.testfx:Remove()
		self.testfx = nil
	end
end

function FxEditor:SetupHandle(handle)
	handle.move_fx = function(inst)
		local frame_number = -1
		if self.testfx then
			local x,z = inst.Transform:GetWorldXZ()
			self.testfx.Transform:SetPosition(x, 0, z)
			if self.testfx.components.fxtimeline then
				frame_number = self.testfx.components.fxtimeline:_get_anim_progress()
			end
		end
		self.timeline.editor:set_editor_frame(frame_number)
	end
	handle:DoPeriodicTask(0, handle.move_fx)
end

function FxEditor:Test(prefab, params)
	if not GetDebugPlayer() then
		return
	end
	FxEditor._base.Test(self, prefab, params)

	if self.testfx ~= nil then
		self.testfx:Remove()
		self.testfx = nil
	end

	if prefab ~= nil then
		local bak_looping = params.looping
		params.looping = params.looping or self.test_looping

		if PrefabExists(prefab) then
			local build = params.build or prefab
			self:AppendPrefabAsset(prefab, Asset("ANIM", "anim/"..build..".zip"))
			if params.bankfile ~= nil and params.bankfile ~= build then
				self:AppendPrefabAsset(prefab, Asset("ANIM", "anim/"..params.bankfile..".zip"))
			end
		else
			RegisterPrefabs(MakeAutogenFx(prefab, params, true))
		end
		TheSim:LoadPrefabs({ prefab })
		self.testfx = SpawnPrefab(prefab, TheDebugSource)
		if self.testfx ~= nil then
			if self.testfx.OnEditorSpawn then
				self.testfx:OnEditorSpawn(self)
			end
			self.testfx:ListenForEvent("onremove", function()
				self.testfx = nil
			end)
			-- Position is set by debug_draggable, but can be slow. Ensure
			-- initial frame is at the right spot.
			self.handle:move_fx()
		end

		params.looping = bak_looping
	end
end


local function ensure_complete_timeline_data(params, element_keys)
	-- Ensure all tables exist.
	local tl = params.timelines or {}
	for _,key in ipairs(element_keys) do
		tl[key] = tl[key] or {}
	end
	params.timelines = tl
end

function FxEditor:_create_timeline_event(merged_key, prev_event)
	local group, element = table.unpack(lume.split(merged_key, "_")) -- keys were concat in group_def.merged_keys
	local bounds = FxTimeline.group_def.get_element_bounds(group, element)
	local event = {
		-- -1 indicates the first unused entry. The number of values
		-- determines the maximum number of points in the curve editor.
		-- The curve editor currently only supports 8 values.
		curve = CreateCurve(bounds.noop, bounds.noop),
	}
	if prev_event and prev_event.curve then
		-- Find the last value and copy it as our first value.
		local y = EvaluateCurve(prev_event.curve, 1)
		event.curve[1] = 0
		event.curve[2] = y
		event.curve[3] = 1
		event.curve[4] = 1 -- default end value is 1
		event.curve[5] = -1
	end
	-- Default to filling the rest of the timeline.
	return self.timeline.group_def.duration, event
end

function FxEditor:_draw_timeline_event(ui, merged_key, event)
	local group, element = table.unpack(lume.split(merged_key, "_")) -- keys were concat in group_def.merged_keys
	local bounds = FxTimeline.group_def.get_element_bounds(group, element)

	ui:TextColored(self.colorscheme.header, self.timeline.ui.help[group])
	local fmt = (self.timeline.ui.fmt[merged_key]
		or self.timeline.ui.fmt[group]
		or self.timeline.ui.fmt.default)
	ui:Value("Output at 0", bounds.min, fmt)
	if group == 'add' then
		-- We add 1/1, which is better visualized as 255.
		ui:Value("Output at 1", 255, fmt)
	else
		ui:Value("Output at 1", bounds.max, fmt)
	end
	return ui:CurveEditor(self.timeline.ui.prettyname[merged_key], event.curve)
end

function FxEditor:CopyColors(params)
	self.copypastecolors =
	{
		hue = params.hue,
		saturation = params.saturation,
		brightness = params.brightness,

		multcolor = params.multcolor and deepcopy(params.multcolor) or nil,
		addcolor = params.addcolor and deepcopy(params.addcolor) or nil,

		timelines = params.timelines and deepcopy(params.timelines) or nil,

		lightoverride = params.lightoverride,
		bloom = params.bloom,
		glowcolor = params.glowcolor,
	}
end

function FxEditor:PasteColors(params)
	local curcolors =
	{
		hue = params.hue,
		saturation = params.saturation,
		brightness = params.brightness,

		multcolor = params.multcolor and deepcopy(params.multcolor) or nil,
		addcolor = params.addcolor and deepcopy(params.addcolor) or nil,

		timelines = params.timelines and deepcopy(params.timelines) or nil,


		lightoverride = params.lightoverride,
		bloom = params.bloom,
		glowcolor = params.glowcolor,
	}
	if not deepcompare(curcolors, self.copypastecolors) then
		params.hue = self.copypastecolors.hue
		params.saturation = self.copypastecolors.saturation
		params.brightness = self.copypastecolors.brightness

		params.multcolor = self.copypastecolors.multcolor and deepcopy(self.copypastecolors.multcolor) or nil
		params.addcolor = self.copypastecolors.addcolor and deepcopy(self.copypastecolors.addcolor) or nil

		params.timelines = self.copypastecolors.timelines and deepcopy(self.copypastecolors.timelines) or nil

		params.lightoverride = self.copypastecolors.lightoverride
		params.bloom = self.copypastecolors.bloom
		params.glowcolor = self.copypastecolors.glowcolor and deepcopy(self.copypastecolors.glowcolor) or nil

		self:SetDirty()
	end
end

function FxEditor:CopyPasteColors(ui, params)
	ui:Columns(1)
	local colw = ui:GetColumnWidth()
	ui:Columns(2,"",false)
	ui:SetColumnOffset(1, colw - 185)
	ui:NextColumn()
	ui:Text("Color & Fx Data");ui:SameLine();ui:Dummy(4,0);ui:SameLine()
	if ui:SmallButton("Copy") then
		self:CopyColors(params)
	end
	local canpaste = self.copypastecolors ~= nil
	ui:SameLine() ui:Dummy(4,0) ui:SameLine()
	if ui:SmallButton("Paste",not canpaste) then
		self:PasteColors(params)
	end
	ui:Columns(1)

end

function FxEditor:GatherErrors()
	local ParticlesAutogenData = require "prefabs.particles_autogen_data"

	local bad_items = {}
	for name,params in pairs(self.static.data) do
		if params.soundevent and not fmodtable.Event[params.soundevent] then
			bad_items[name] = ("Sound '%s' doesn't exist in fmodtable."):format(params.soundevent)
		end
	end
	local required_impactfx = eventfuncs.spawnimpactfx:GetAllImpactFx()
	for _,impactfx_set in ipairs(required_impactfx) do
		-- TODO(dbriscoe): Because there are so many missing, just check
		-- that any exist. Assuming that Sloth does all of them at once.
		local found = lume.match(impactfx_set, function(impactfx)
			-- Not clear to me how to tell whether they should be fx or
			-- particles. I think Sloth just chooses what looks best and sets
			-- up embellishments for them.
			return self.static.data[impactfx.fx] or ParticlesAutogenData[impactfx.particles]
		end)

		if not found then
			-- We could list all sizes, but we only require one.
			local impactfx = impactfx_set.Small
			bad_items[impactfx.fx] = ("Missing impact fx for ground tile: %s"):format(impactfx.tile)
		end
	end
	return bad_items
end

function FxEditor:AddEditableOptions(ui, params)
	--~ if ui:Button("c_select fx") then
	--~ 	c_select(self.testfx)
	--~ end
	self.test_looping = ui:_Checkbox("Force Loop for Test", self.test_looping)
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

		if ui:TreeNode("Anim", ui.TreeNodeFlags.DefaultOpen) then
			--Anim name
			local _, newanim = ui:InputText("Anim", params.anim, imgui.InputTextFlags.CharsNoBlank)
			if newanim ~= nil then
				if string.len(newanim) == 0 then
					newanim = nil
				end
				if params.anim ~= newanim then
					params.anim = newanim
					self:SetDirty()
				end
			end

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

			--Looping anim
			local _, newloop = ui:Checkbox("Looping", params.looping == true)
			if newloop == not params.looping then
				params.looping = newloop or nil
				params.randomstartframe = params.looping
				self:SetDirty()
			end

			if params.looping then
				--Random start frame
				ui:SameLine()
				ui:Dummy(40, 0)
				ui:SameLine()
				local _, newrandomstartframe = ui:Checkbox("Random Start Frame", params.randomstartframe == true)
				if newrandomstartframe == not params.randomstartframe then
					params.randomstartframe = newrandomstartframe or nil
					self:SetDirty()
				end
			end

			--Shadow
			local _, newshadow = ui:Checkbox("Shadow", params.shadow == true)
			if newshadow == not params.shadow then
				params.shadow = newshadow or nil
				self:SetDirty()
			end

			self:AddTreeNodeEnder(ui)
		end

		self:AddSectionEnder(ui)
	end

	if ui:CollapsingHeader("Orientation", ui.TreeNodeFlags.DefaultOpen) then
		self:AddSectionStarter(ui)

		if ui:TreeNode("Flipping", ui.TreeNodeFlags.DefaultOpen) then
			local fliplist =
			{
				"None",
				"Flip",
				"Auto",
				"Random",
			}
			local flipidx =
				(params.noflip and 1) or
				(params.flip and 2) or
				(params.randomflip and 4) or
				3
			local newflipidx = ui:_Combo("##flipping_mode", flipidx, fliplist)
			if newflipidx ~= nil then
				local newflipflags =
				{
					noflip = newflipidx == 1,
					flip = newflipidx == 2,
					randomflip = newflipidx == 4,
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

		self:AddSectionEnder(ui)
	end

	if ui:CollapsingHeader("Sorting") then
		self:AddSectionStarter(ui)

		if ui:TreeNode("Orientation##Sorting", ui.TreeNodeFlags.DefaultOpen) then
			--Ground orientation
			local _, newonground = nil, params.onground and 1 or 0
			_, newonground = ui:RadioButton("Billboard\t", newonground, 0)
			ui:SameLine()
			_, newonground = ui:RadioButton("Ground Projection", newonground, 1)
			if (newonground == 1) == not params.onground then
				params.onground = newonground == 1 or nil
				self:SetDirty()
			end

			-- Clip at world edge?
			if params.onground then
				local _, newclip = ui:Checkbox("Clip at world edge", params.clip_at_worldedge == true)
				if newclip == not params.clip_at_worldedge then
					params.clip_at_worldedge = newclip or nil
					self:SetDirty()
				end
			else
				params.clip_at_worldedge = nil
			end

			self:AddTreeNodeEnder(ui)
		end

		if ui:TreeNode("Layer", ui.TreeNodeFlags.DefaultOpen) then
			--Layer
			local _, newlayer = nil, params.layer
			if newlayer == "backdrop" then
				newlayer = 2
			elseif newlayer == "bg" then
				newlayer = 1
			else
				newlayer = 0
			end
			_, newlayer = ui:RadioButton("Foreground\t", newlayer, 0)
			ui:SameLine()
			_, newlayer = ui:RadioButton("Background\t", newlayer, 1)
			ui:SameLine()
			_, newlayer = ui:RadioButton("Backdrop", newlayer, 2)
			if newlayer == 2 then
				newlayer = "backdrop"
			elseif newlayer == 1 then
				newlayer = "bg"
			else
				newlayer = nil
			end
			if newlayer ~= params.layer then
				params.layer = newlayer
				if newlayer == "bg" then
					params.sortorder = 2
				else
					params.sortorder = nil
				end
				self:SetDirty()
			end

			--Sort order
			local sortorderlist =
			{
				"+3",
				"+2   (Background default)",
				"+1",
				"+0   (Foreground default)",
				"-1",
				"-2",
				"-3",
			}
			local defaultsortorderidx = math.ceil(#sortorderlist / 2)
			local sortorderidx = defaultsortorderidx - (params.sortorder or 0)
			local newsortorderidx = ui:_Combo("Sort Order", math.clamp(sortorderidx, 1, #sortorderlist), sortorderlist)
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

			--Final offset
			local finaloffsetlist =
			{
				"+7   (Detached Hit Fx)",
				"+6   (Detached Status or Buff Fx)",
				"+5",
				"+4",
				"+3",
				"+2",
				"+1   (Fx tied to anim, e.g. Swipe)",
				"+0",
				"-1",
				"-2",
				"-3",
				"-4",
				"-5",
				"-6",
				"-7",
			}
			local defaultfinaloffsetidx = math.ceil(#finaloffsetlist / 2)
			local finaloffsetidx = defaultfinaloffsetidx - (params.finaloffset or 0)
			local newfinaloffsetidx = ui:_Combo("Final Offset", math.clamp(finaloffsetidx, 1, #finaloffsetlist), finaloffsetlist)
			if newfinaloffsetidx ~= finaloffsetidx then
				local newfinaloffset = defaultfinaloffsetidx - newfinaloffsetidx
				if newfinaloffset == 0 then
					newfinaloffset = nil
				end
				if params.finaloffset ~= newfinaloffset then
					params.finaloffset = newfinaloffset
					self:SetDirty()
				end
			end

			self:AddTreeNodeEnder(ui)
		end

		self:AddSectionEnder(ui)
	end

	if ui:CollapsingHeader("Color") then
		self:AddSectionStarter(ui)
		self:CopyPasteColors(ui, params)

		if ui:TreeNode("HSB Color Shift") then
			--HSB
			local _, newh = ui:SliderInt("Hue", params.hue or 0, -180, 180, "%+dº")
			local _, news = ui:SliderInt("Saturation", params.saturation or 0, -100, 100, "%+d%%")
			local _, newb = ui:SliderInt("Brightness", params.brightness or 0, -100, 100, "%+d%%")
			if ui:Button("Reset HSB Color Shift") then
				newh, news, newb = 0, 0, 0
			end
			if newh ~= nil then
				if newh == 0 then
					newh = nil
				end
				if params.hue ~= newh then
					params.hue = newh
					self:SetDirty()
				end
			end
			if news ~= nil then
				if news == 0 then
					news = nil
				end
				if params.saturation ~= news then
					params.saturation = news
					self:SetDirty()
				end
			end
			if newb ~= nil then
				if newb == 0 then
					newb = nil
				end
				if params.brightness ~= newb then
					params.brightness = newb
					self:SetDirty()
				end
			end

			self:AddTreeNodeEnder(ui)
		end

		if ui:TreeNode("RGB Color Scale") then
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
			if ui:Button("Reset RGB Color Scale") then
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

		if ui:TreeNode("Timeline") then
			local group_def = self.timeline.group_def
			if params.timelines then
				ensure_complete_timeline_data(params, group_def.merged_keys)

				self.timeline.editor:set_data(group_def.duration, group_def.merged_keys, params.timelines, self.timeline.ui.prettyname)
				local modified = self.timeline.editor:RenderEditor(ui, self, FxEditor._create_timeline_event, FxEditor._draw_timeline_event)
				if modified then
					self:SetDirty()
				end
			else
				-- This button prevents us from adding timeline data to every
				-- edited event. Once we've added it, we let Timeline handle
				-- creation.
				if ui:Button("Add Timeline") then
					ensure_complete_timeline_data(params, group_def.merged_keys)
					self.timeline.editor:set_data(group_def.duration, group_def.merged_keys, params.timelines, self.timeline.ui.prettyname)
					local create_only_one = true
					self.timeline.editor:add_default_timeline(self, FxEditor._create_timeline_event, create_only_one)
					self:SetDirty()
				end
			end

			self:AddTreeNodeEnder(ui)
		end

		self:AddSectionEnder(ui)
	end

	if ui:CollapsingHeader("Fx") then
		self:AddSectionStarter(ui)

		if ui:TreeNode("Ambience", ui.TreeNodeFlags.DefaultOpen) then
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

		local _, new_additive = ui:Checkbox("Additive Blending", params.additive == true)
		if new_additive == not params.additive then
				params.additive = new_additive or nil
				self:SetDirty()
		end

		self:AddSectionEnder(ui)
	end

	if ui:CollapsingHeader("Scale") then
		self:AddSectionStarter(ui)

		if ui:TreeNode("Scale", ui.TreeNodeFlags.DefaultOpen) then
			--Scale override
			local changed,sx,sy,sz = ui:DragFloat2("scale", params.scalex or 1, params.scaley or 1, 0.005, 0, 5)
			if changed then
				params.scalex = sx ~= 1 and sx or nil
				params.scaley = sy ~= 1 and sy or nil
				self:SetDirty()
			end

			self:AddTreeNodeEnder(ui)
		end

		self:AddSectionEnder(ui)
	end

	if ui:CollapsingHeader("Target Options") then
		self:AddSectionStarter(ui)

		if ui:TreeNode("Target Tint Color", ui.TreeNodeFlags.DefaultOpen) then
			--Target tint color
			local tintcolor = params.target_tint ~= nil and StrToHex(params.target_tint) or 0x00000000
			local tintr, tintg, tintb = HexToRGBInts(tintcolor)
			local _, newtintr = ui:SliderInt("+ R##target_tint", tintr, 0, 255, "%+d")
			local _, newtintg = ui:SliderInt("+ G##target_tint", tintg, 0, 255, "%+d")
			local _, newtintb = ui:SliderInt("+ B##target_tint", tintb, 0, 255, "%+d")
			if ui:Button("Reset Target Tint Color") then
				newtintr, newtintg, newtintb = 0, 0, 0
			end
			if newtintr ~= nil or newtintg ~= nil or newtintb ~= nil then
				local newtintcolor = RGBIntsToHex(newtintr or tintr, newtintg or tintg, newtintb or tintb, 0)
				if newtintcolor ~= tintcolor then
					if newtintcolor == 0x00000000 then
						params.target_tint = nil
					else
						params.target_tint = HexToStr(newtintcolor)
					end
					self:SetDirty()
				end
			end

			self:AddTreeNodeEnder(ui)
		end

		self:AddSectionEnder(ui)
	end

	if ui:CollapsingHeader("Sound") then
		self:AddSectionStarter(ui)

		-- Don't pass testfx as the instigator since fx are never the
		-- instigator.

		self.funceditor:SoundData(ui, params, true)

		-- SoundData's max count and sound window are incompatible!

		if ui:Checkbox("Sound Window", params.window_frames) then
			if params.window_frames then
				params.window_frames = nil
			else
				params.window_frames = 5
				params.sound_max_count = nil
			end
		end
		ui:Indent() do
			if params.sound_max_count then
				params.window_frames = nil
			elseif params.window_frames then
				self.funceditor:SoundWindow(ui, params)
			end
		end ui:Unindent()

		self:AddSectionEnder(ui)
		-- Always try to dirty to simplify editor code.
		self:SetDirty()
	end

	-- this is similar to propeditor.lua
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

			ui:BeginDisabled()
			if ui:Checkbox("Minimal Entity", params.isminimal) then
				-- toggle isminimal
				if params.isminimal then
					params.isminimal = nil
				else
					params.isminimal = true
				end
				self:SetDirty()
			end
			ui:EndDisabled()

			if not params.isminimal then
				params.isminimal = true
				self:SetDirty()
			end

			ui:Unindent()
		elseif params.isminimal then
			params.isminimal = nil
			self:SetDirty()
		end

		self:AddSectionEnder(ui)
	end

end

DebugNodes.FxEditor = FxEditor

return FxEditor
