local Screen = require "widgets.screen"
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local easing = require "util.easing"
local fmodtable = require "defs.sound.fmodtable"
local lume = require "util.lume"
local templates = require "widgets.ftf.templates"
local ScrollPanel = require("widgets/scrollpanel")
local Panel = require "widgets.panel"

function ListTitle(title)
	local title_panel = Widget()
	title_panel.title_text = title_panel:AddChild(Text(FONTFACE.DEFAULT, 72, title, UICOLORS.WHITE):SetGlyphColor(UICOLORS.WHITE))
	return title_panel
end

local ManageMPScreen = Class(Screen, function(self)
	Screen._ctor(self, "ManageMPScreen")
	self.active = true
	self.refreshTimeRemaining = 0
	self.refreshPeriod = 2

	-- Add background
	self.panel = self:AddChild(Widget())
		:LayoutBounds("center", "center", self)

	self.bg = self.panel:AddChild(templates.SmallOverlayBackground())
		:SetSize(2500,1600)


	local joincode = TheNet:GetJoinCode()
	if joincode ~= "" then
		self.online_joincode_button = self:AddChild(templates.Button(STRINGS.UI.ONLINESCREEN.JOINCODE_LABEL .. " " .. joincode))
			:SetToolTip(STRINGS.UI.ONLINESCREEN.JOINCODE_LABEL_TOOLTIP)
			:SetUncolored()	
			:SetAnchors("left", "top")
			:SetSize(480, 80)
			:SetTextSize(FONTSIZE.OVERLAY_TEXT)
			:SetOnClick(function() self:OnClickOnlineJoinCode() end)
			:LayoutBounds("left", "top", self.bg)
			:Offset(20,-20)
	end


	-- Clients currently in the game list
	self.gamelistroot = self.panel:AddChild(Panel())
		:LayoutBounds("center", "center", self.bg)
		:SetSize(1200, 1100)
		:Offset(-610, 0)

	--self.gamelist = self.gamelistroot:AddChild(templates.SmallOverlayBackground())
	--	:SetAnchors("fill", "fill")

	self.gamelisttitle = self.gamelistroot:AddChild(ListTitle(STRINGS.UI.MANAGEMP.PLAYERS_IN_GAME))
		:SetAnchors("center", "top")
		:Offset(0, 30)

	self.gamelist_content_scroll = self.gamelistroot:AddChild( ScrollPanel() )
		:SetAnchors("center", "center")
		:SetVirtualMargin( SPACING.M1 )
		:SetScrollBarOuterMargin( 0 )
		:SetSize(1200,1100)

	self.gamelistcontent = self.gamelist_content_scroll:AddScrollChild( Widget() )

	self:UpdateGameList()


	-- Blacklist
	self.blacklistroot = self.panel:AddChild(Panel())
		:LayoutBounds("center", "center", self.bg)
		:SetSize(1200, 1100)
		:Offset(610, 0)

	--self.blacklist = self.blacklistroot:AddChild(templates.SmallOverlayBackground())
	--	:SetAnchors("fill", "fill")

	self.blacklisttitle = self.blacklistroot:AddChild(ListTitle(STRINGS.UI.MANAGEMP.BLACK_LIST))
		:SetAnchors("center", "top")
		:Offset(0, 30)

	self.blacklist_content_scroll = self.blacklistroot:AddChild( ScrollPanel() )
		:SetAnchors("center", "center")
		:SetVirtualMargin( SPACING.M1 )
		:SetScrollBarOuterMargin( 0 )
		:SetSize(1200,1100)

	self.blacklistcontent = self.blacklist_content_scroll:AddScrollChild( Widget() )

	self:UpdateBlackList()

	-- Back button
	self.closeButton = self:AddChild(templates.BackButton())
		:SetPrimary()
		:SetOnClick(function() 	TheFrontEnd:PopScreen(self) end)
		:LayoutBounds("left", "bottom", self.bg)
		:Offset(30, 20)

	self.default_focus = self.closeButton
end)

function ManageMPScreen:SetOwningPlayer(player)
	ManageMPScreen._base.SetOwningPlayer(self, player)
	self.controls:SetOwningPlayer(player)
end

function ManageMPScreen:OnClickOnlineJoinCode()
	local success = TheNet:CopyJoinCodeToClipboard()
	if success then
		if self.online_joincode_button and not self.online_joincode_copied then
			self.online_joincode_button:Disable()
			local offx, offy = self.online_joincode_button:GetSize()
			self.online_joincode_copied = self:AddChild(Text(FONTFACE.BODYTEXT, FONTSIZE.OVERLAY_TEXT))
				:SetText(STRINGS.UI.PAUSEMENU.JOINCODE_COPIED)
				:LayoutBounds("left", "center", self.online_joincode_button)
				:LayoutBounds("center", "below", self.online_joincode_button)

			local fadeStatus = Updater.Series({
				Updater.Wait(2.0),
				Updater.Ease(function(v) self.online_joincode_copied:SetMultColorAlpha(v) end, 1, 0, 0.5, easing.inOutQuad),
				Updater.Do(function()
					self.online_joincode_copied:Remove()
					self.online_joincode_copied = nil
					self.online_joincode_button:Enable()
				end)
			})

			self:RunUpdater(fadeStatus)
		end
	end
end

function ManageMPScreen:MakeClientButton(id, clientname)
	local client_panel = Widget()
	local namefield = client_panel:AddChild(Text(FONTFACE.DEFAULT, 80, clientname, UICOLORS.WHITE))

	local kickButton = client_panel:AddChild(templates.Button(STRINGS.UI.MANAGEMP.KICK))
	kickButton:SetOnClick(function() 
		TheNet:KickClient(id) 
		self.refreshTimeRemaining = 0.2	-- make it refresh in 0.2 seconds
	end)
		:LayoutBounds("after", "center", namefield)
		:Offset(30, 0)
		:SetSize(120, 20)

	return client_panel
end

function ManageMPScreen:UpdateGameList()
	self.gamelistcontent:KillAllChildren()

	-- List the clients that are curently in the game:
	local clients = TheNet:GetClientList()

	local belowbutton = nil
	for _i,v in ipairs(clients) do
		if not v.islocal then
			local widget = self.gamelistcontent:AddChild(self:MakeClientButton(v.id, v.name))
				:LayoutBounds("center", "below", belowbutton)
				:Offset(0, -30)
			belowbutton = widget
		end
	end
end


function ManageMPScreen:MakeBlackListButton(ip, clientname)
	local client_panel = Widget()
	local namefield = client_panel:AddChild(Text(FONTFACE.DEFAULT, 80, clientname, UICOLORS.WHITE))

	local kickButton = client_panel:AddChild(templates.Button(STRINGS.UI.MANAGEMP.REMOVE))
	kickButton:SetOnClick(function() 
		TheNet:RemoveFromBlackList(ip) 
		self.refreshTimeRemaining = 0.2	-- make it refresh in 0.2 seconds
	end)
		:LayoutBounds("after", "center", namefield)
		:Offset(30, 0)
		:SetSize(120, 20)

	return client_panel
end

function ManageMPScreen:UpdateBlackList()
	self.blacklistcontent:KillAllChildren()

	-- List the clients that are curently in the game:
	local blacklist = TheNet:GetBlackList()

	local belowbutton = nil
	for _i,v in ipairs(blacklist) do
		if not v.islocal then
			local widget = self.blacklistcontent:AddChild(self:MakeBlackListButton(v.ip, v.name))
				:LayoutBounds("center", "below", belowbutton)
				:Offset(0, -30)
			belowbutton = widget
		end
	end
end

function ManageMPScreen:UpdateUI()
	self:UpdateGameList()
	self:UpdateBlackList()
end


function ManageMPScreen:OnUpdate(dt)
	self.refreshTimeRemaining = math.max(0, self.refreshTimeRemaining - dt)

	if self.refreshTimeRemaining <= 0 then
		self.refreshTimeRemaining = self.refreshPeriod
		self:UpdateUI()
	end
end

return ManageMPScreen
