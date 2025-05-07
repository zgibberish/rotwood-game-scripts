local Widget = require "widgets.widget"
local easing = require "util.easing"
local Panel = require "widgets.panel"
local Image = require "widgets.image"


local STAFF_LINE_WIDTH = 500
local STAFF_LINE_HEIGHT = 50

local STAFF1_Y = 100
local STAFF2_Y = 50
local STAFF3_Y = 0
local STAFF4_Y = -50
local SPAWNER_X = 300

local CURRENT_BEAT_X = -170
local BEAT_TWO_X = -35
local BEAT_THREE_X = 100
local BEAT_FOUR_X = 235

local buttons_to_update = {}

local CookingButtonTrack = Class(Widget, function(self, target, button)
	Widget._ctor(self, "CookingButtonTrack")

	self.root = self:AddChild(Widget("CookingTrack Root"))
		:Offset(0, -200)

	self.contentBlock = self.root:AddChild(Widget("Content Block"))

	self.contentBg = self.contentBlock:AddChild(Panel("images/ui_ftf_dialog/dialog_content_bg.tex"))
		:SetNineSliceCoords(100, 60, 110, 70)
		:SetNineSliceBorderScale(1)
		:SetMultColor(UICOLORS.DIALOG_BUTTON_NORMAL)
		:SetInnerSize(300, 140)

	self.staffblock = self.contentBg:AddChild(Widget("Staff Block"))
		:Offset(20, -10)

	self.staffline1 = self.staffblock:AddChild(Image("images/ui_ftf_dialog/dialog_forge_itemrow_normal.tex"))
		:SetMultColor(UICOLORS.BACKGROUND_LIGHT)
		:Offset(25, STAFF1_Y)
		:ScaleToSize(STAFF_LINE_WIDTH, STAFF_LINE_HEIGHT)

	self.staffline2 = self.staffblock:AddChild(Image("images/ui_ftf_dialog/dialog_forge_itemrow_normal.tex"))
		:SetMultColor(UICOLORS.BACKGROUND_LIGHT)
		:Offset(25, STAFF2_Y)
		:ScaleToSize(STAFF_LINE_WIDTH, STAFF_LINE_HEIGHT)

	self.staffline3 = self.staffblock:AddChild(Image("images/ui_ftf_dialog/dialog_forge_itemrow_normal.tex"))
		:SetMultColor(UICOLORS.BACKGROUND_LIGHT)
		:Offset(25, STAFF3_Y)
		:ScaleToSize(STAFF_LINE_WIDTH, STAFF_LINE_HEIGHT)

	self.staffline4 = self.staffblock:AddChild(Image("images/ui_ftf_dialog/dialog_forge_itemrow_normal.tex"))
		:SetMultColor(UICOLORS.BACKGROUND_LIGHT)
		:Offset(25, STAFF4_Y)
		:ScaleToSize(STAFF_LINE_WIDTH, STAFF_LINE_HEIGHT)

	self.currentbeat = self.staffblock:AddChild(Image("images/ui_ftf_dialog/dialog_forge_itemrow_normal.tex"))
		:SetMultColor(UICOLORS.BACKGROUND_DARK)
		:Offset(CURRENT_BEAT_X, 0)
		:ScaleToSize(10, 150)

	-- self.beattwo = self.staffblock:AddChild(Image("images/ui_ftf_dialog/dialog_forge_itemrow_normal.tex"))
	-- 	:SetMultColor(UICOLORS.BACKGROUND_MID)
	-- 	:Offset(BEAT_TWO_X, 0)
	-- 	:ScaleToSize(10, 150)
	-- self.beatthree = self.staffblock:AddChild(Image("images/ui_ftf_dialog/dialog_forge_itemrow_normal.tex"))
	-- 	:SetMultColor(UICOLORS.BACKGROUND_MID)
	-- 	:Offset(BEAT_THREE_X, 0)
	-- 	:ScaleToSize(10, 150)
	-- self.beatfour = self.staffblock:AddChild(Image("images/ui_ftf_dialog/dialog_forge_itemrow_normal.tex"))
	-- 	:SetMultColor(UICOLORS.BACKGROUND_MID)
	-- 	:Offset(BEAT_FOUR_X, 0)
	-- 	:ScaleToSize(10, 150)

	self.spawners = {}

	self.spawners[Controls.Digital.MINIGAME_WEST] = self.staffblock:AddChild(Image("images/global/square.tex"))
		:SetSize(1, 1)
		:Offset(SPAWNER_X, STAFF2_Y - 24)

	self.spawners[Controls.Digital.MINIGAME_NORTH] = self.staffblock:AddChild(Image("images/global/square.tex"))
		:SetSize(1, 1)
		:Offset(SPAWNER_X, STAFF1_Y - 24)

	self.spawners[Controls.Digital.MINIGAME_EAST] = self.staffblock:AddChild(Image("images/global/square.tex"))
		:SetSize(1, 1)
		:Offset(SPAWNER_X, STAFF3_Y - 24)

	self.spawners[Controls.Digital.MINIGAME_SOUTH] = self.staffblock:AddChild(Image("images/global/square.tex"))
		:SetSize(1, 1)
		:Offset(SPAWNER_X, STAFF4_Y - 24)

	self.start_x, self.start_y = nil, nil

	self.time_updating = 0

	self.x_offset_target = CURRENT_BEAT_X
	self.x_offset_target_time = 0.775


	self.fade_time = 1
	self.note_lifetime = 2.15

	self.s_x = nil
	self.s_y = nil
	self.s_z = nil

	self:SetClickable(false)

end)

function CookingButtonTrack:Init(data)
	-- local button_text = string.format("<p img='images/ui_ftf_dialog/dialog_content_bg.tex'>")
	-- if data.y_offset == nil then
	-- 	data.y_offset = 0
	-- end

	-- --self.x_offset_mod = data.x_offset_mod

	-- self.s_x, self.s_y, self.s_z = data.target.AnimState:GetSymbolPosition("head", 0, 0, 0)
	-- local x,y = self:CalcLocalPositionFromWorldPoint(self.s_x, self.s_y, self.s_z)
	-- self:SetPosition(x + 10, y + 50)

	-- --self:AlphaTo(0, self.fade_time, easing.inExpo, function() self:Remove() end)

	-- self.number:SetText(button_text)
	self.target = data.target
	self:StartUpdating()
end

function CookingButtonTrack:SpawnButton(control)
	if control == " " then
		-- rest has no button.
		return
	end
	-- explicitly use symbols for input device on target player
	local tex = self.target.components.playercontroller:GetTexForControl(control)
	local newbutton = self.spawners[control]:AddChild(Image(tex))
		:SetSize(50 * HACK_FOR_4K, 50)

	if newbutton ~= nil then
		table.insert(buttons_to_update, { button = newbutton, time_updating = 0, clearing = false })
	end
end


function CookingButtonTrack:OnUpdate(dt)
	for k,v in pairs(buttons_to_update) do
		if v ~= nil then
			v.time_updating = v.time_updating + dt

			local x_offset = easing.linear(v.time_updating, 0, self.x_offset_target, self.x_offset_target_time)
			v.button:SetPosition(0 + x_offset, 0)

			if v.time_updating >= self.note_lifetime and not v.clearing then
				self:ClearButton(k, v)
			end
		end
	end
end


function CookingButtonTrack:ClearButton(index, button_data)
	button_data.clearing = true
	button_data.button:AlphaTo(0, self.fade_time, easing.outQuad, function()
		button_data.button:Remove()
		buttons_to_update[index] = nil
	end)
end

function CookingButtonTrack:StopTrack()
	self:Remove()
end



return CookingButtonTrack
