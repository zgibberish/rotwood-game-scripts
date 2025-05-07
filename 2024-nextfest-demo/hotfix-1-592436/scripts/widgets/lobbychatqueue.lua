local Widget = require "widgets/widget"
local Text = require "widgets/text"
local ScrollableList = require "widgets/scrollablelist"

local MAX_MESSAGES = 20

local function message_constructor(data)
    local line_xpos = -85
    local username_maxwidth = 120
    local username_padding = 8
    local line_maxwidth = 180
    local line_maxchars = 50
    local multiline_maxrows = 8
    local multiline_indent = 10

    local group = Widget("item-lobbychat")
    group.user_widget = group:AddChild(Text(data.chat_font, data.chat_size - 5, nil, data.colour))
    group.user_widget:SetTruncatedString(data.username..":", username_maxwidth, 30, "..:")

    local username_width = group.user_widget:GetRegionSize()
    group.user_widget:SetPosition(line_xpos + username_width * .5, -2)

    group.message = group:AddChild(Text(FONTFACE.DEFAULT, data.chat_size, nil, WEBCOLORS.BLACK))
    group.message:SetString(data.message) --, multiline_maxrows, { line_maxwidth - username_width - username_padding, line_maxwidth - multiline_indent }, line_maxchars, true)

    local lines = group.message:GetText():split("\n")
    group.message:SetString(lines[1])

    local message_width = group.message:GetRegionSize()
    group.message:SetPosition(line_xpos + username_width + username_padding + message_width * .5, 0)

    local list = { group }

    for i = 2, #lines do
        group = Widget("item-lobbychat")

        group.message = group:AddChild(Text(FONTFACE.DEFAULT, data.chat_size, nil, WEBCOLORS.BLACK))
        group.message:SetString(lines[i])

        message_width = group.message:GetRegionSize()
        group.message:SetPosition(line_xpos + multiline_indent + message_width * .5, 0)

        table.insert(list, group)
    end

    return list
end

local LobbyChatQueue = Class(Widget, function(self, owner, chatbox, onReceiveNewMessage, nextWidget)
    Widget._ctor(self, "LobbyChatQueue")

    self.owner = owner

    self.list_items = {}

    self.chat_font = FONTFACE.CHAT
    self.chat_size = 22

    self.chatbox = chatbox

    self.new_message_fn = onReceiveNewMessage

    self.nextWidget = nextWidget

    self:StartUpdating()
end)

function LobbyChatQueue:GetChatAlpha( current_time, chat_time )
    return 1
end

function LobbyChatQueue:OnUpdate()
end

--For ease of overriding in mods
function LobbyChatQueue:GetDisplayName(name, prefab)
    return name ~= "" and name or STRINGS.UI.SERVERADMINSCREEN.UNKNOWN_USER_NAME
end

function LobbyChatQueue:OnMessageReceived(name, prefab, message, colour)
    self.list_items[#self.list_items + 1] =
    {
        message = message,
        chat_font = self.chat_font,
        chat_size = self.chat_size,
        colour = colour,
        username = self:GetDisplayName(name, prefab),
    }

    local startidx = math.max(1, (#self.list_items - MAX_MESSAGES) + 1) -- older messages are dropped
    local list_widgets = {}
    for k,v in pairs(self.list_items) do 
        if k >= startidx then 
            local list = message_constructor(v)
            for k2,v2 in pairs(list) do 
                table.insert(list_widgets, v2)
            end
        end
    end

    if not self.scroll_list then
        self.scroll_list = self:AddChild(ScrollableList(list_widgets, 115, 245, 20, 12, nil, nil, nil, nil, nil, 15))
        self.scroll_list:SetPosition(52, -2)
    else
        self.scroll_list:SetList(list_widgets)
        self.scroll_list:ScrollToEnd()
    end

    if self.new_message_fn then
        self.new_message_fn()
    end

    self:DoFocusHookups()
end

function LobbyChatQueue:DoFocusHookups()
    if self.scroll_list then 
        self.default_focus = self.scroll_list
        self.scroll_list:SetFocusChangeDir(MOVE_RIGHT, self.nextWidget)
    else
        self:SetFocusChangeDir(MOVE_RIGHT, self.nextWidget)
    end

end

function LobbyChatQueue:ScrollToEnd()
    if self.scroll_list then
        self.scroll_list:ScrollToEnd()
    end
end

function LobbyChatQueue:OnControl(controls, down)
    if not self:IsEnabled() or not self.focus then return false end

    if self.chatbox and controls:Has(Controls.Digital.ACCEPT) and TheInput:ControllerAttached() and not TheFrontEnd.tracking_mouse then
        return self.chatbox:OnControl(controls, down)
    end

    if self.scroll_list and (controls:Has(Controls.Digital.MENU_SCROLL_BACK, Controls.Digital.MENU_SCROLL_FWD)) then
        return self.scroll_list:OnControl(controls, down, true)
    elseif self.scroll_list and self.scroll_list.focus then
        return self.scroll_list:OnControl(controls, down)
    end

    return false
end

return LobbyChatQueue
