local AccoladeWidget = require "widgets/ftf/accoladewidget"
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local easing = require "util/easing"
local Enum = require "util/enum"

local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

local Moods = Enum{
	"MOTIVATIONAL",
	"NERVOUS",
	"SKEPTICAL"
}

local MOOD_TO_TEX =
{
	[Moods.s.MOTIVATIONAL] = "images/ui_ftf_dungeon_progress/Flitt1.tex",
	[Moods.s.NERVOUS] = "images/ui_ftf_dungeon_progress/Flitt2.tex",
	[Moods.s.SKEPTICAL] = "images/ui_ftf_dungeon_progress/Flitt3.tex",
}

local function _get_boss_icon()
	local biome = TheDungeon:GetDungeonMap().nav:GetBiomeLocation()
	return biome.icon
end

local function _get_miniboss_progress()
	return TheDungeon:GetDungeonMap().nav:GetProgressForFirstMinibossEncounter()
end

local function _get_miniboss_room()
	return TheDungeon:GetDungeonMap().nav:GetRoomForFirstMinibossEncounter()
end

local function _get_num_rooms()
	local seen, max = TheDungeon:GetDungeonMap().nav:GetRoomCount_SeenAndMaximum()
	-- _get_num_rooms() returns 1 too high because it is artificially
	-- increased by 1 to account for the boss room which is actually after the mapgen
	return max - 1
end

local function _build_progress_marker_table()
	local num_rooms = _get_num_rooms()
	local hype_room = num_rooms
	local miniboss_room = _get_miniboss_room()
	local progress_markers = {}

	local important_rooms =
	{
		[0] = { icon = nil, scale = 1, important = true },
		[miniboss_room] = { icon_fn = function() return "images/ui_ftf_pausescreen/ic_miniboss.tex" end, scale = 0.75, important = true },
		[hype_room] = { icon_fn = _get_boss_icon, scale = 1, important = true },
	}

	for i = 0, hype_room do
		local progress = i/num_rooms
		if important_rooms[i] then
			local tbl = shallowcopy(important_rooms[i])
			tbl.progress = progress
			table.insert(progress_markers, tbl)
		else
			table.insert(progress_markers, { progress = progress })
		end
	end


	return progress_markers
end

local FlittTipWidget = Class(Widget, function(self)
	Widget._ctor(self, "FlittTipWidget")
	self.flitt_tips = self:AddChild(Image("images/ui_ftf_dungeon_progress/Tips.tex"))
	local w, h = self.flitt_tips:GetSize()

	local tip = self:GetTip()

	self.tip_text = self.flitt_tips:AddChild(Text(FONTFACE.DEFAULT, 65, tip.text, HexToRGB(0x5E4E4AFF)))
		:Offset(15, -15)
		:SetRegionSize(w-40, h-60)
		:EnableWordWrap(true)
		:Spool(50)

	self.flitt_img = self:AddChild(Image(MOOD_TO_TEX[tip.mood]))
		:LayoutBounds("left", "above", self.flitt_tips)
		:Offset(-10, -75)
		:SendToBack()
		:SetScale(0.9)
end)

function FlittTipWidget:GetTip()
	local run_state = TheDungeon.progression.components.runmanager:GetRunState()
	local progress = TheDungeon:GetDungeonProgress()
	local tip_key = nil

	if run_state == RunStates.s.ABANDON then
			tip_key = "ABANDONED"
	elseif run_state == RunStates.s.DEFEAT or run_state == RunStates.s.ACTIVE then
		-- Support "ACTIVE" run state here so debug opening the screen still returns a string.
		local miniboss_progress = _get_miniboss_progress()
		local boss_progress = 1.0

		if progress < miniboss_progress then
			-- lost before reaching the miniboss
			tip_key = "LOST_EARLY"
		elseif progress == miniboss_progress then
			-- lost while fighting the miniboss
			tip_key = "LOST_DURING_MINIBOSS"
			local miniboss = TheDungeon:GetCurrentMiniboss()
			miniboss = string.upper(miniboss)
			local tips = STRINGS.UI.HUNTPROGRESSSCREEN[tip_key][miniboss]

			if tips == nil then
				-- couldn't find tips about this specific miniboss, return a general tip
				tips = STRINGS.UI.HUNTPROGRESSSCREEN[tip_key]["GENERAL"]
			end

			return tips[math.random(#tips)]
		elseif progress > miniboss_progress and progress < boss_progress then
			-- lost after beating the miniboss, but before reaching the boss
			tip_key = "LOST_BEAT_MINIBOSS"
		elseif progress >= boss_progress then
			-- lost while fighting the boss
			tip_key = "LOST_BOSS"
			local boss = TheDungeon:GetCurrentBoss()
			boss = string.upper(boss)
			local tips = STRINGS.UI.HUNTPROGRESSSCREEN[tip_key][boss]

			if tips ~= nil then
			    local ents = TheSim:FindEntitiesXZ(0, 0, 1000, { "boss" })
				local boss_ent = ents and ents[1] or nil
				if boss_ent ~= nil then
					-- find boss, get current health
					local boss_health = boss_ent.components.health:GetPercent()
					local tip_options = {}

					for _, tip in ipairs(tips) do
						local health = tip.health or 1
						if boss_health <= health then
							table.insert(tip_options, tip)
						end
					end

					if #tip_options > 0 then
						-- Get the tip that is closest to the boss' health
						local smallest_delta = 1
						local best_tips = {}
						for _, tip in ipairs(tip_options) do
							local health = tip.health or 1
							local delta = health - boss_health
							if delta < smallest_delta then
								smallest_delta = delta
								-- wipe current list of best tips & start a new one
								best_tips = {}
								table.insert(best_tips, tip)
							elseif delta == smallest_delta then
								-- just add yourself to the list of best tips
								table.insert(best_tips, tip)
							end
						end

						if #best_tips > 0 then
							return best_tips[math.random(#best_tips)]
						end
					end
				end
			end

			-- didn't find a tip? Return a general one as fallback.
			tips = STRINGS.UI.HUNTPROGRESSSCREEN[tip_key]["GENERAL"]
			return tips[math.random(#tips)]
		end
	elseif run_state == RunStates.s.VICTORY then
		-- We currently do not show this screen if you win the run.
		tip_key = "WON"
	end

	if tip_key ~= nil then
		local tips = STRINGS.UI.HUNTPROGRESSSCREEN[tip_key]
		return tips[math.random(#tips)]
	end
end

local HuntProgressMarker = Class(Widget, function(self, marker)
	Widget._ctor(self, "HuntProgressWidget")
	self:AddChild(Image("images/ui_ftf_dungeon_progress/ProgressPoint.tex"))

	if marker.icon_fn ~= nil then
		self:AddChild(Image(marker.icon_fn()))
			:SetScale(marker.scale, marker.scale)
			:LayoutBounds("center", "below")
			:Offset(0, -5)
			:SetMultColor(HexToRGB(0x5E4E4AFF))
			:SetHiddenBoundingBox(true)
	end
end)

local HuntProgressBar = Class(Widget, function(self)
	Widget._ctor(self, "HuntProgressBar")
	TheFrontEnd:GetSound():PlaySound(fmodtable.Event.ui_dungeonProgressWidget_start)

	self.bar_root = self:AddChild(Widget("Bar Root"))

	self.bar_root:AddChild(Image("images/ui_ftf_dungeon_progress/ProgressBar_Cap_L.tex")) -- left cap
	local middle_bar = self.bar_root:AddChild(Image("images/ui_ftf_dungeon_progress/ProgressBar.tex")):LayoutBounds("after", "center") -- the middle
	self.bar_root:AddChild(Image("images/ui_ftf_dungeon_progress/ProgressBar_Cap_R.tex")):LayoutBounds("after", "center") -- right cap
	-- self.bar_root:LayoutChildrenInGrid(3, 0) -- arrange them as they should be

	self.bar_w = middle_bar:GetSize()

	self.progress_markers = _build_progress_marker_table()

	for _, marker in ipairs(self.progress_markers) do

		local progress_marker = nil
		local y_offset = 0

		if marker.important then
			progress_marker = middle_bar:AddChild(HuntProgressMarker(marker))
				:SetAnchors("left", "center")

			y_offset = -15
		else
			progress_marker = middle_bar:AddChild(Image("images/ui_ftf_dungeon_progress/ProgressPointSmall.tex"))
				:SetAnchors("left", "center")

			y_offset = -5
		end

		local x_offset = self.bar_w * marker.progress

		progress_marker:Offset(x_offset, y_offset)
	end

	self.player_marker = middle_bar:AddChild(Image("images/ui_ftf_dungeon_progress/ProgressPlayerIcon.tex"))
		:SetAnchors("center", "bottom")
	local w, h = self.player_marker:GetSize()

	self.player_marker:LayoutBounds("left", "above", middle_bar):Offset(-w/2, 0)

	self.inst:DoTaskInTime(1, function() self:MoveMarkerToProgress(TheDungeon:GetDungeonProgress()) end)
end)

function HuntProgressBar:MoveMarkerToProgress(progress)
	local x, y = self.player_marker:GetPosition()
	local x_delta = self.bar_w * progress
	local x_tar = x + x_delta

	-- tween time for both the marker and the sound parameter adjustment
	-- also serves as cue for stopping the lp
	local ease_time = 1.33
	local dungeon_progress = TheDungeon:GetDungeonProgress()

	self:RunUpdater(Updater.Series{
		Updater.Ease(function(v) self.player_marker:SetPosition(v, y) end, x, x_tar, ease_time, easing.outExpo)
	})

	-- play sound if the widget's actually moving
	if dungeon_progress > 0 then
		-- Store the sound handle in a variable
		local progressSound = TheFrontEnd:GetSound():PlaySound_Autoname(fmodtable.Event.ui_dungeonProgressWidget_LP)

		-- Ensure 'progressSound' is not nil or invalid
		if progressSound then
			self.progress_sound = progressSound

			TheFrontEnd:GetSound():SetParameter(self.progress_sound, "ui_easePercentage", ease_time)

			-- Create a parallel updater
			self:RunUpdater(Updater.Parallel({
				-- update param over the ease time from 0 to % dungeon progress
				-- we stop the sound and easing earlier than 100% because movement gets infinitessimally small towards the end
				Updater.Ease(function(v)
					if self.progress_sound then
						if v/dungeon_progress < .99 then
							TheFrontEnd:GetSound():SetParameter(self.progress_sound, "progress", v)
						else
							TheFrontEnd:GetSound():KillSound(self.progress_sound)
							self.progress_sound = nil
						end
					end
				end, 0, TheDungeon:GetDungeonProgress(), ease_time, easing.inSine),

				-- -- update param with how far into the ease we are
				-- -- need this to smooth volume presentation
				Updater.Ease(function(v)
					if self.progress_sound then
						TheFrontEnd:GetSound():SetParameter(self.progress_sound, "ui_easePercentage", v)
					end
				end, 0, ease_time, ease_time, easing.outQuad),

				-- Second updater to stop the sound after the specified time
				-- Updater.Do(function()
				-- 	self.inst:DoTaskInTime(ease_time, function()
				-- 		if self.progress_sound then
				-- 			TheFrontEnd:GetSound():KillSound(self.progress_sound)
				-- 			self.progress_sound = nil
				-- 		end
				-- 	end)
				-- end)
			}))
		end
	end

end

function HuntProgressBar:PopulateBar(data)

end

local HuntProgressWidget = Class(AccoladeWidget, function(self, data)
	AccoladeWidget._ctor(self, "HuntProgressWidget")
end)

function HuntProgressWidget:PopulatePanelContents()

	local biome = TheDungeon:GetDungeonMap().nav:GetBiomeLocation()

	self.title = self:AddWidgetToContents(Text(FONTFACE.DEFAULT, 100, biome.pretty.name_upper, HexToRGB(0x5E4E4AFF)))
		:LayoutBounds("center", "top", self.bg)
		:Offset(0, -40)

	local title_ornament = biome:GetRegion().title_ornament
	local deco_offset = 20

	self.deco_left = self:AddChild(Image(title_ornament))
		:SetMultColor(HexToRGB(0x5E4E4AFF))
		:LayoutBounds("before", "center", self.title)
		:Offset(-deco_offset, 0)

	self.deco_right = self:AddChild(Image(title_ornament))
		:SetMultColor(HexToRGB(0x5E4E4AFF))
		:LayoutBounds("after", "center", self.title)
		:Offset(deco_offset, 0)
		:SetScale(-1, 1)



	self.flitt_tip = self:AddWidgetToContents(FlittTipWidget())
		:LayoutBounds("center", "top", self.bg)
		:Offset(0, -130)

	self.progress_bar = self:AddWidgetToContents(HuntProgressBar())
	local w, h = self.progress_bar:GetSize()
	self.progress_bar:LayoutBounds("center", "below", self.flitt_tips)
		:Offset(0, -h * 4)

	HuntProgressWidget._base.PopulatePanelContents(self)
end

return HuntProgressWidget
