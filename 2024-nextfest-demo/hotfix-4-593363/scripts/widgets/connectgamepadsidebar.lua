local Controls = require "input.controls"
local kassert = require "util.kassert"
local Image = require "widgets.image"
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local easing = require "util.easing"
local playerutil = require "util.playerutil"


local PANEL_WIDTH = 990

----------------------------------------------------------------------
-- A dialog that asks the player to use a device to start using it.

local ConnectGamepadSidebar = Class(Widget, function(self)
	Widget._ctor(self, "ConnectGamepadSidebar")

	self.bg = self:AddChild(Image("images/ui_ftf_gems/weapons_panel_bg.tex"))
		:SetScale(0.75)

	self.title = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TITLE))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_TITLE)
		:SetText(STRINGS.UI.PAUSEMENU.CONNECT_SIDEBAR.TITLE)
	self.instruction = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
		:SetAutoSize(PANEL_WIDTH)
	self.detected_input = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_WARN)
		:SetAutoSize(PANEL_WIDTH)

	self.gamepad_root = self:AddChild(Widget("gamepad_root"))

	self._on_gamepad_connection = function(is_connected, device_id)
		self:_UpdateGamepadList()
		self:_LayoutDialog()
	end
	TheInput:RegisterGamepadConnectionHandler(self, self._on_gamepad_connection)

	self:_LayoutDialog()
end)

function ConnectGamepadSidebar:OnRemoved()
	TheInput:UnregisterGamepadConnectionHandler(self)
end

function ConnectGamepadSidebar:IsWaitingToReconnect()
	return self.target_player ~= nil
end

function ConnectGamepadSidebar:StartLooking(someone_disconnected_cb, everyone_connected_cb)
	kassert.typeof("function", someone_disconnected_cb, everyone_connected_cb)
	self.someone_disconnected_cb = someone_disconnected_cb
	self.everyone_connected_cb = everyone_connected_cb
	self:StartUpdating()
end

function ConnectGamepadSidebar:OnUpdate(dt)
	if not self.everyone_connected_cb then
		return
	end

	self:_CheckForGamepadDisconnected()
end

function ConnectGamepadSidebar:_ApplyToPlayer(target_player)
	self.target_player = target_player
	self.instruction
		:SetText(STRINGS.UI.PAUSEMENU.CONNECT_SIDEBAR.INSTRUCTIONS:subfmt({
				player_id = target_player:GetHunterId(),
				player_name = target_player:GetColoredCustomUserName(true),
			}))
end

local function CreateGamepadText(font_size)
	return Text(FONTFACE.DEFAULT, font_size)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
		:SetAutoSize(PANEL_WIDTH)
		:SetHAlign(ANCHOR_LEFT)
		:OverrideLineHeight(font_size * 1.5)
end

function ConnectGamepadSidebar:_UpdateGamepadList()
	self.gamepad_root:RemoveAllChildren()

	local tex_fmt = "<p img='%s' color=0>"
	local font_size = FONTSIZE.SCREEN_SUBTITLE * 0.8

	local device_tuples = TheInput:GetAllFreeDevices()
	TheLog.ch.FrontEnd:printf("_UpdateGamepadList: found %s free devices", #device_tuples)
	for _,tup in ipairs(device_tuples) do
		local device_type, device_id = table.unpack(tup)
		local tex = TheInput:GetTexForControlName(Controls.Digital.ACTIVATE_INPUT_DEVICE.key, device_type, device_id)

		local line = STRINGS.UI.PAUSEMENU.CONNECT_SIDEBAR.GAMEPAD_LIST:subfmt({
				button_icon = tex_fmt:format(tex),
				device_icon = TheInput:GetLabelForDevice(device_type, device_id),
				device_name = TheInput:GetDeviceName(device_type, device_id),
			})
		self.gamepad_root:AddChild(CreateGamepadText(font_size))
			:SetText(line)
	end

	if #device_tuples == 0 then
		self.gamepad_root:AddChild(CreateGamepadText(font_size))
			:SetText(STRINGS.UI.PAUSEMENU.CONNECT_SIDEBAR.GAMEPAD_LIST_EMPTY)
	end
end

function ConnectGamepadSidebar:HandlePreControlDown(controls, device_type, trace, device_id)
	if not self:IsWaitingToReconnect() then
		return
	end
	-- Use HandlePreControlDown instead of AddGamepadButtonHandler so we only
	-- listen to buttons which ignores drifty gamepad sticks and we consume the
	-- input so ChangeInputDialog doesn't show.
	if controls:Has(Controls.Digital.ACTIVATE_INPUT_DEVICE) then
		return self:_TryAssignDevice(device_type, device_id)
	end
end

function ConnectGamepadSidebar:_FindMissingInput()
	for _,player in playerutil.LocalPlayers() do
		if not player.components.playercontroller:HasInputDevice() then
			return player
		end
	end
end

function ConnectGamepadSidebar:_CheckForGamepadDisconnected()
	local player = self:_FindMissingInput()
	if player == self.target_player then
		return
	end
	TheLog.ch.FrontEnd:printf("_CheckForGamepadDisconnected: found inputless player [%s]", player)

	local want_visible = not not player
	if self.has_animated_in ~= want_visible then
		if player then
			self:Show()
				:AnimateIn()
		else
			self:AnimateOut()
		end
	end

	if player then
		self.someone_disconnected_cb(self)
		self:_ApplyToPlayer(player)
		self:_UpdateGamepadList()
		self:_LayoutDialog()
	else
		self.target_player = nil
		self.everyone_connected_cb(self)
	end
end


function ConnectGamepadSidebar:_LayoutDialog()

	self.title
		:LayoutBounds("center", "top", self.bg)
		:Offset(-70, -85) -- left because part of bg is hidden
	self.instruction
		:LayoutBounds("center", "below", self.title)
		:Offset(0, -40)
	self.detected_input
		:LayoutBounds("center", "below", self.instruction)
		:Offset(0, -40)
	self.gamepad_root
		:LayoutChildrenInColumn(50, "left")
		:LayoutBounds("center", "below", self.detected_input)
		:Offset(0, -70)

	return self
end

local animate_offset = Vector2(300, 0)
function ConnectGamepadSidebar:AnimateIn()
	self.has_animated_in = true
	self.anim_pos = self.anim_pos or self:GetPositionAsVec2()
	local hidden = self.anim_pos + animate_offset
	self
		:Show()
		:SetMultColorAlpha(0)
		:SetPosition(hidden.x, hidden.y)
		:MoveTo(self.anim_pos.x, self.anim_pos.y, 0.75, easing.outQuad)
		:AlphaTo(1, 0.4, easing.outQuad)
	return self
end

function ConnectGamepadSidebar:AnimateOut()
	self.has_animated_in = false
	self.anim_pos = self.anim_pos or self:GetPositionAsVec2()
	local hidden = self.anim_pos + animate_offset
	self
		:SetMultColorAlpha(1)
		:SetPosition(self.anim_pos.x, self.anim_pos.y)
		:MoveTo(hidden.x, hidden.y, 0.75, easing.outQuad)
		:AlphaTo(0, 0.6, easing.outQuad)
	return self
end



--~ function ConnectGamepadSidebar:OnRawKey(raw_key, down)
--~ 	if self.inst:GetTimeAlive() < 1 then
--~ 		-- Ignore keyboard input for testing.
--~ 		return
--~ 	end
--~ 	self:_TryAssignDevice("keyboard", 1)
--~ end

--~ function ConnectGamepadSidebar:OnRawGamepadButton(gamepad_id, raw_button, down)
--~ 	self:_TryAssignDevice("gamepad", gamepad_id)
--~ end

function ConnectGamepadSidebar:_TryAssignDevice(device_type, device_id)
	local msg
	local can_switch = TheInput:IsDeviceFree(device_type, device_id)
	if can_switch then
		net_modifyplayer(self.target_player.Network:GetPlayerID(), TheInput:ConvertToInputID(device_type, device_id))
		msg = "" -- it won't be visible for long, so just clear.
	else
		msg = STRINGS.UI.PAUSEMENU.CONNECT_SIDEBAR.FOUND_IN_USE:subfmt({
				device_icon = TheInput:GetLabelForDevice(device_type, device_id)
			})
	end

	self.detected_input:SetText(msg)

	return can_switch
end


function ConnectGamepadSidebar:DebugDraw_AddSection(ui, panel)
	ConnectGamepadSidebar._base.DebugDraw_AddSection(self, ui, panel)

	ui:Spacing()
	ui:Text("ConnectGamepadSidebar")
	ui:Indent() do
		ui:Value("IsWaitingToReconnect", self:IsWaitingToReconnect())
		if ui:Button("AnimateIn") then
			self:StopUpdating()
			self:AnimateIn()
		end
		if ui:Button("AnimateOut") then
			self:StopUpdating()
			self:AnimateOut()
		end
		if ui:Button("StartUpdating", nil, nil, self:ShouldBeUpdating()) then
			self:StartUpdating()
		end
	end
	ui:Unindent()
end

return ConnectGamepadSidebar
