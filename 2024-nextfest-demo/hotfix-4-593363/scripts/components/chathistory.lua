local fmodtable = require "defs.sound.fmodtable"


local MAX_CHAT_HISTORY = 8

local ChatHistory = Class(function(self, inst)
	self.inst = inst
	self.history = {}
end)

function ChatHistory:ReceiveChatMessage(msg, sender)
	self:Append(msg)

	-- Hud may not exist, but when they open chat they'll still see this message.
	if TheDungeon.HUD then
		TheDungeon.HUD:RefreshChat()
	end

	if not sender or not sender:IsLocal() then
		TheFrontEnd:GetSound():PlaySound(fmodtable.Event.ui_chat_messageReceived)
	end
end

function ChatHistory:Append(msg)
	table.insert(self.history, msg)

	if #self.history > MAX_CHAT_HISTORY then
		table.remove(self.history, 1)
	end

	--remove after NextFest
	self:Save()
end

function ChatHistory:GetHistory()
	return self.history
end

function ChatHistory:Clear()
	self.history = {}
	self:Save()
end

function ChatHistory:Save()
	TheSaveSystem.about_players:SetValue("chat_history", self.history)
	return nil
end

function ChatHistory:Load()
	local val = TheSaveSystem.about_players:GetValue("chat_history")
	self.history = val and deepcopy(val) or {}
end

return ChatHistory
