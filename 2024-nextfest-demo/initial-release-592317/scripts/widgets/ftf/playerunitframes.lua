local Widget = require("widgets/widget")
local PlayerStatusWidget = require("widgets/ftf/playerstatuswidget")
local easing = require "util.easing"


local PlayerUnitFrames =  Class(Widget, function(self)
	Widget._ctor(self, "PlayerUnitFrames")

	self:ForceFullScreenBounds()

	self.unit_frames = {}
	self.is_animated_in = true

	self.inst:ListenForEvent("playerentered", function(inst, new_ent) self:AddUnitFrame(new_ent) end, TheWorld)
	self.inst:ListenForEvent("playerexited", function(inst, new_ent) self:RemoveUnitFrame(new_ent) end, TheWorld)

	-- Ensure any pre-existing players get added since it's too later for their events.
	for _,player in ipairs(AllPlayers) do
		self:AddUnitFrame(player)
	end
end)

function PlayerUnitFrames:AnimateIn()
	for player,unit_frame in pairs(self.unit_frames) do
		unit_frame:AnimateIn()
	end
	self.is_animated_in = true
end

function PlayerUnitFrames:AnimateOut()
	for player,unit_frame in pairs(self.unit_frames) do
		unit_frame:AnimateOut()
	end
	self.is_animated_in = false
end

function PlayerUnitFrames:AddUnitFrame(player)
	if self.unit_frames[player] then
		return
	end
	local unit_frame = self:AddChild(PlayerStatusWidget(player))
	self.unit_frames[player] = unit_frame

	local playerID = player:GetHunterId()
	assert(playerID <= 4, "Didn't expect hunter ids to go past 4: HunterID is ".. playerID)
	unit_frame:SetLayoutMode(PlayerStatusWidget.UNIT_FRAME_LAYOUT_ORDER[playerID])
	unit_frame:AnimateIn(true)

	if not self.is_animated_in then
		unit_frame:AnimateOut()
	end
end

function PlayerUnitFrames:RemoveUnitFrame(player)
	local unit_frame = self.unit_frames[player]
	if unit_frame then
		self.unit_frames[player] = nil
		unit_frame:AnimateOut(function()
			unit_frame:Remove()
		end)
	end
end

-- Pass nil player to unfocus all.
function PlayerUnitFrames:FocusUnitFrame(player, time)
	time = time or 0 -- How long does it take to become focused/unfocused state
	local scaleAmount = 0.75 -- If unfocused, what do we scale down to?
	local tintAmount = 0.4 -- If unfocused, what do we tint down to?
	for k,v in pairs(self.unit_frames) do
		if player and k ~= player then
			self.unit_frames[k]:ScaleTo(nil, scaleAmount, time, easing.inOutQuad)
			self.unit_frames[k]:TintTo(nil, {tintAmount, tintAmount, tintAmount, 1}, time, easing.inOutQuad)
		else
			self.unit_frames[k]:ScaleTo(nil, 1, time, easing.inOutQuad)
			self.unit_frames[k]:TintTo(nil, {1, 1, 1, 1}, time, easing.inOutQuad)
		end
	end
end

function PlayerUnitFrames:Debug_FillAllLocalPlayerSlots()
	TheLog.ch.UI:print("Ran Debug_FillAllLocalPlayerSlots. Player bugs may occur.")
	self.hack_players = self.hack_players or {}
	for _,p in ipairs(self.hack_players) do
		self:RemoveUnitFrame(p)
		p:Remove()
	end
	self.hack_players = {}

	local max_players = table.numkeys(PlayerStatusWidget.UNIT_FRAME_LAYOUT_ORDER)
	local dupes = max_players - table.numkeys(self.unit_frames)
	for i=1,dupes do
		-- Can't use DebugSpawn or they won't get added to unit frames.
		local player = SpawnPrefab("player_side", TheDebugSource)
		-- Force no inputs since they're not real players. Prevents interaction
		-- from kicking off and accessing their nonexistent quest data.
		player.components.playercontroller.IsEnabled = function() end
		table.insert(self.hack_players, player)
		player.GetHunterId = function(inst)
			-- Fake player id to ensure it's <4
			return max_players - i + 1
		end
		player:SetCustomUserName("FakeUserName")
		player.components.charactercreator:Randomize()
		player.components.inventoryhoard:Debug_GiveAllEquipment()
		c_random_powers(9, player)
		c_power("pwr_shield", nil, nil, player) -- ensure shield is visible
		player:PushEvent("update_skin_color")
		self:AddUnitFrame(player)
	end
end


function PlayerUnitFrames:DebugDraw_AddSection(ui, panel)
	PlayerUnitFrames._base.DebugDraw_AddSection(self, ui, panel)

	ui:Spacing()
	ui:Text("PlayerUnitFrames")
	ui:Indent() do
		if ui:Button("AnimateIn") then
			self:AnimateIn()
		end
		if ui:Button("AnimateOut") then
			self:AnimateOut()
		end
	end
	ui:Unindent()
end

return PlayerUnitFrames
