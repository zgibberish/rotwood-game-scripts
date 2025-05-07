local ActionButton = require "widgets.actionbutton"
local Image = require "widgets.image"
local Panel = require "widgets.panel"
local PanelButton = require "widgets.panelbutton"
local Screen = require "widgets.screen"
local ScrollPanel = require "widgets.scrollpanel"
local TabGroup = require "widgets.tabgroup"
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local easing = require "util.easing"
local lume = require "util.lume"

require "class"

local function MakeSkinRow(contentWidth)
	local row = Widget("SkinRow")

	row.symbolName = row:AddChild(Text(FONTFACE.DEFAULT, 50, "SYMBOL NAME", UICOLORS.LIGHT_TEXT_TITLE))
								 :SetAutoSize(contentWidth - BUTTON_H - 20)
								 :Offset(0, 60)
								 
	row.darkBg = row:AddChild(Image("images/global/square.tex"))
		:SetMultColor(0.1, 0, 0)
		:SetMultColorAlpha(0.33)
		:SetSize(contentWidth - BUTTON_H - 20, 50)
		:LayoutBounds("center", "center")
		:Offset(0, -60)

	row.setName = row:AddChild(Text(FONTFACE.DEFAULT, 50, "SET NAME", UICOLORS.LIGHT_TEXT_TITLE))
		:SetAutoSize(contentWidth - BUTTON_H - 20)
		

	row.nextButton = row:AddChild(ActionButton())
		:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)
		-- :SetIcon("images/ui_ftf_dungeon_selection/ascension_arrow_right.tex", 17 * HACK_FOR_4K)
		:Offset(200, 0)

	row.previousButton = row:AddChild(ActionButton())
		:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)
		-- :SetIcon("images/ui_ftf_dungeon_selection/ascension_arrow_left.tex", 17 * HACK_FOR_4K)
		:Offset(-200, 0)


	return row
end

local BuildingSkinScreen = Class(Screen, function(self, building, player)
	Screen._ctor(self, STRINGS.CRAFT_WIDGET.CUSTOMIZE_BUILDING)

	assert(building)
	self.building = building.components.buildingskinner
	assert(self.building)

	self.width = 540
	self.contentWidth = self.width - 50
	self.height = RES_Y

	self.root = self:AddChild(Widget("BuildingSkinScreen_root"))

	self.bg = self.root:AddChild(Panel("images/ui_ftf_forging/forge_sidebar.tex"))
		:SetNineSliceCoords(50, 450, 60, 620)
		:SetNineSliceBorderScale(0.5)
		:SetSize(self.width, self.height + 20)
		:LayoutBounds("left", "center", -RES_X / 2, 0)
		:Offset(40, 0)

	self.headerHeight = 110
	self.header = self.root:AddChild(Widget("Sidebar Header"))
	self.headerBg = self.header:AddChild(Image("images/global/square.tex"))
		:SetSize(self.width, self.headerHeight)
		:SetMultColor(HexToRGB(0xFF00FF30))
		:SetMultColorAlpha(0)

	self.title = self.header:AddChild(Text(FONTFACE.DEFAULT, 50, "CUSTOMIZE BUILDING", UICOLORS.LIGHT_TEXT_TITLE))
		:SetAutoSize(self.contentWidth - BUTTON_H - 20)
		:LeftAlign()

	self.closeButton = self.header:AddChild(ActionButton())
		:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)
		-- :SetIcon("images/ui_ftf_dialog/convo_close.tex", 17 * HACK_FOR_4K)
		:SetOnClick(function() self:Close() end)
	self.closeButton:LayoutBounds("right", "center", self.headerBg)
		:Offset(-10, 5)

	self.header:LayoutBounds("center", "top", self.bg)

	local headerW, headerH = self.header:GetSize()
	-- Display item list
	self.listH = self.height - headerH - 15
	self.scrollWidthOffset = 0 -- To add spacing between the scroll bar and the right edge
	self.paddingHorizontal = -250
	self.itemRowW = self.width - self.scrollWidthOffset - self.paddingHorizontal * 2

	self.itemList = self.root:AddChild(ScrollPanel())
		:SetSize(self.width - self.scrollWidthOffset, self.listH)
		:SetVirtualMargin(15)
		:LayoutBounds("center", "below", self.header)
		:Offset(0, 0)

	-- Container for item rows within the scroll panel
	self.itemListContent = self.itemList:AddScrollChild(Widget())

	self.rows = {}
	for key, group in pairs(self.building.symbol_groups) do
		local row = self.itemListContent:AddChild(MakeSkinRow(self.contentWidth))
					--:Offset(500, 0, 0)
		
		print ("=====================", key, group)

		row.symbolName:SetText(string.upper(key))
		row.setName:SetText("default")
		row.group = key

		row.nextButton:SetOnClick(function()
			self.building:NextSkinSymbol(row.group)
			row.setName:SetText(self.building:GetCurrentSet(row.group))
		end)

		row.previousButton:SetOnClick(function()
			self.building:PreviousSkinSymbol(row.group)
			row.setName:SetText(self.building:GetCurrentSet(row.group))
		end)

		table.insert(self.rows, row)
	end

	self.itemListContent:LayoutChildrenInGrid(1, 2)
		:LayoutBounds("left", "top")
		:Offset(-225, 0)
	self.itemList:RefreshView()
		:LayoutBounds("center", "below", self.header)
		:Offset(0, 0)

	self.default_focus = self.rows[1]

	self:ApplySkin()
		:LayoutSkin()

	self.player = player
	
	-- TODO: should we make this into a function in the player that listens to start customizing? Similar to npc.lua
	player.components.playercontroller:SetInteractTarget(nil)
	player.sg:GoToState("idle")
	player:RemoveFromScene()

	TheCamera:SetZoom(-15)
	TheCamera:SetTarget(building)
	TheWorld:PushEvent("startcustomizing")
end)

function BuildingSkinScreen:Close()
	self.player.components.playercontroller:SetInteractTarget(nil)
	self.player.sg:GoToState("idle")
	self.player:ReturnToScene()
	
	TheCamera:SetTarget(TheFocalPoint)
	TheCamera:SetZoom(0)
	TheCamera:SetOffset(0, 0, 0)
	TheWorld:PushEvent("stopcustomizing")

	TheFrontEnd:PopScreen(self)
end

function BuildingSkinScreen:ApplySkin()

	self.skinDirectory = "images/ui_ftf_skin/" -- Defines what skin to use

	-- Add header background
	self.skinHeaderBg = self.header:AddChild(Image(self.skinDirectory .. "panel_header.tex"))
		:SetHiddenBoundingBox(true)
		:SendToBack()
	self.skinHeaderBgW, self.skinHeaderBgH = self.skinHeaderBg:GetSize()

	-- Change title colour
	self.title:SetGlyphColor(UICOLORS.BACKGROUND_DARK)

	-- Add chain edges to the bg panel
	self.skinEdgeLeft = self.root:AddChild(Image(self.skinDirectory .. "panel_left.tex"))
		:SetHiddenBoundingBox(true)
	self.skinEdgeRight = self.root:AddChild(Image(self.skinDirectory .. "panel_right.tex"))
		:SetHiddenBoundingBox(true)

	-- Place header above panel edges
	self.header:SendToFront()

	-- Add glow and illustration at the bottom

	return self
end

function BuildingSkinScreen:LayoutSkin()

	local targetW = self.width + 40
	local targetH = targetW / self.skinHeaderBgW * self.skinHeaderBgH
	self.skinHeaderBg:SetSize(targetW, targetH)
		:LayoutBounds("center", "bottom", self.headerBg)

	-- Edge textures
	local textureW, textureH = 100, 1280
	local targetH = RES_Y
	local targetW = targetH / textureH * textureW
	self.skinEdgeLeft:SetSize(targetW, RES_Y)
		:LayoutBounds("before", "center", self.bg)
		:Offset(targetW * 0.5, 0)
	self.skinEdgeRight:SetSize(targetW, RES_Y)
		:LayoutBounds("after", "center", self.bg)
		:Offset(-targetW * 0.5, 0)

	return self
end


return BuildingSkinScreen
