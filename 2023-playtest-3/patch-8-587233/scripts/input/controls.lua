local strict = require "util.strict"

local t =
{

	Digital =
	{
		-- player action controls
		ATTACK_LIGHT =
		{
			displayname = "Light Attack",
		},
		ATTACK_HEAVY =
		{
			displayname = "Heavy Attack",
		},
		USE_POTION =
		{
			displayname = "Use Potion",
		},
		DODGE =
		{
			displayname = "Dodge",
		},
		SKILL =
		{
			displayname = "Skill",
		},

		-- mouse-specific controls. Use these only when making mouse-only interactions!
		CLICK_PRIMARY =
		{
			-- Better to use ACTION.
			displayname = "Controls.Digital.CLICK_PRIMARY",
		},
		CLICK_SECONDARY =
		{
			-- No gamepad equivalent.
			displayname = "Controls.Digital.CLICK_SECONDARY",
		},

		-- Generic primary "activate a thing"
		ACTION =
		{
			displayname = "Controls.Digital.ACTION",
		},

		-- player movement controls
		MOVE_UP =
		{
			displayname = "Controls.Digital.MOVE_UP",
		},
		MOVE_DOWN =
		{
			displayname = "Controls.Digital.MOVE_DOWN",
		},
		MOVE_LEFT =
		{
			displayname = "Controls.Digital.MOVE_LEFT",
		},
		MOVE_RIGHT =
		{
			displayname = "Controls.Digital.MOVE_RIGHT",
		},

		ZOOM_IN =
		{
			displayname = "Controls.Digital.ZOOM_IN",
		},
		ZOOM_OUT =
		{
			displayname = "Controls.Digital.ZOOM_OUT",
		},

		-- system
		PAUSE =
		{
			displayname = "Controls.Digital.PAUSE",
		},

		-- player HUD controls
		MAP =
		{
			displayname = "Controls.Digital.MAP",
		},
		INV_1 =
		{
			displayname = "Controls.Digital.INV_1",
		},
		INV_2 =
		{
			displayname = "Controls.Digital.INV_2",
		},
		INV_3 =
		{
			displayname = "Controls.Digital.INV_3",
		},
		INV_4 =
		{
			displayname = "Controls.Digital.INV_4",
		},
		INV_5 =
		{
			displayname = "Controls.Digital.INV_5",
		},
		INV_6 =
		{
			displayname = "Controls.Digital.INV_6",
		},
		INV_7 =
		{
			displayname = "Controls.Digital.INV_7",
		},
		INV_8 =
		{
			displayname = "Controls.Digital.INV_8",
		},
		INV_9 =
		{
			displayname = "Controls.Digital.INV_9",
		},
		INV_10 =
		{
			displayname = "Controls.Digital.INV_10",
		},

		-- Generic minigame controls. Minigame should block player movement and
		-- use cardinal directions with button icons.
		MINIGAME_NORTH =
		{
			displayname = "Controls.Digital.MINIGAME_NORTH",
		},
		MINIGAME_SOUTH =
		{
			displayname = "Controls.Digital.MINIGAME_SOUTH",
		},
		MINIGAME_WEST =
		{
			displayname = "Controls.Digital.MINIGAME_WEST",
		},
		MINIGAME_EAST =
		{
			displayname = "Controls.Digital.MINIGAME_EAST",
		},

		-- UI controls
		RADIAL_ACTION = -- RS-click
		{
			displayname = "Controls.Digital.RADIAL_ACTION",
		},

		-- Gamepad mostly uses MENU_PAGE_UP/DOWN, and not SCROLL.
		MENU_SCROLL_FWD = -- Scroll down or to the right.
		{
			displayname = "Controls.Digital.MENU_SCROLL_FWD",
		},
		MENU_SCROLL_BACK = -- Scroll up or to the left.
		{
			displayname = "Controls.Digital.MENU_SCROLL_BACK",
		},

		MENU_UP =  -- d-pad up
		{
			displayname = "Controls.Digital.MENU_UP",
			repeat_rate = 10, -- see also NAV_REPEAT_TIME
		},
		MENU_DOWN = -- d-pad down
		{
			displayname = "Controls.Digital.MENU_DOWN",
			repeat_rate = 10,
		},
		MENU_LEFT = -- d-pad left
		{
			displayname = "Controls.Digital.MENU_LEFT",
			repeat_rate = 10,
		},
		MENU_RIGHT = -- d-pad right
		{
			displayname = "Controls.Digital.MENU_RIGHT",
			repeat_rate = 10,
		},

		Y =
		{
			displayname = "Controls.Digital.Y",
		},
		B =
		{
			displayname = "Controls.Digital.B",
		},
		A =
		{
			displayname = "Controls.Digital.A",
		},
		X =
		{
			displayname = "Controls.Digital.X",
		},

		-- Like MENU_ but does not repeat.
		MENU_ONCE_UP =  -- d-pad up
		{
			displayname = "Controls.Digital.MENU_ONCE_UP",
		},
		MENU_ONCE_DOWN = -- d-pad down
		{
			displayname = "Controls.Digital.MENU_ONCE_DOWN",
		},
		MENU_ONCE_LEFT = -- d-pad left
		{
			displayname = "Controls.Digital.MENU_ONCE_LEFT",
		},
		MENU_ONCE_RIGHT = -- d-pad right
		{
			displayname = "Controls.Digital.MENU_ONCE_RIGHT",
		},

		MENU_PAGE_UP =
		{
			displayname = "Controls.Digital.MENU_PAGE_UP",
			repeat_rate = 4,
		},
		MENU_PAGE_DOWN =
		{
			displayname = "Controls.Digital.MENU_PAGE_DOWN",
			repeat_rate = 4,
		},

		MENU_TAB_PREV =
		{
			displayname = "Controls.Digital.MENU_TAB_PREV",
			repeat_rate = 4,
		},
		MENU_TAB_NEXT =
		{
			displayname = "Controls.Digital.MENU_TAB_NEXT",
			repeat_rate = 4,
		},

		MENU_SUB_TAB_PREV =
		{
			displayname = "Controls.Digital.MENU_SUB_TAB_PREV",
			repeat_rate = 4,
		},
		MENU_SUB_TAB_NEXT =
		{
			displayname = "Controls.Digital.MENU_SUB_TAB_NEXT",
			repeat_rate = 4,
		},

		MENU_SCREEN_ADVANCE =
		{
			displayname = "Controls.Digital.MENU_SCREEN_ADVANCE",
		},
		MENU_CANCEL_INPUT_BINDING =
		{
			-- Do not display or allow rebinding of this key!
			displayname = "Controls.Digital.MENU_CANCEL_INPUT_BINDING",
		},
		NON_MODAL_CLICK =
		{
			displayname = "Controls.Digital.NON_MODAL_CLICK",
		},
		MENU_ACCEPT =
		{
			displayname = "Controls.Digital.MENU_ACCEPT",
		},
		MENU_REJECT =
		{
			displayname = "Controls.Digital.MENU_REJECT",
		},
		CINE_HOLD_SKIP =
		{
			displayname = "Controls.Digital.CINE_HOLD_SKIP",
		},
		MENU_CANCEL =
		{
			displayname = "Controls.Digital.MENU_CANCEL",
		},
		MENU_SUBMIT =
		{
			displayname = "Controls.Digital.MENU_SUBMIT",
		},

		ACTIVATE_INPUT_DEVICE =
		{
			displayname = "Controls.Digital.ACTIVATE_INPUT_DEVICE",
		},

		ACCEPT = -- A
		{
			displayname = "Controls.Digital.ACCEPT",
			--repeat_rate = 5,
		},
		CANCEL = -- B
		{
			displayname = "Controls.Digital.CANCEL",
		},
		PREVVALUE =
		{
			displayname = "Controls.Digital.PREVVALUE",
		},
		NEXTVALUE =
		{
			displayname = "Controls.Digital.NEXTVALUE",
		},

		FEEDBACK =
		{
			displayname = "Submit Feedback",
		},

		-- dev controls
		OPEN_DEBUG_CONSOLE =
		{
			displayname = "Controls.Digital.OPEN_DEBUG_CONSOLE",
		},
		TOGGLE_LOG =
		{
			displayname = "Controls.Digital.TOGGLE_LOG",
		},
		OPEN_DEBUG_MENU =
		{
			displayname = "Controls.Digital.OPEN_DEBUG_MENU",
		},

		-- additional hud controls
		OPEN_INVENTORY =
		{
			displayname = "Controls.Digital.OPEN_INVENTORY",
		},
		OPEN_CRAFTING =
		{
			displayname = "Controls.Digital.OPEN_CRAFTING",
		},
		INVENTORY_EXAMINE = -- d-pad up
		{
			displayname = "Controls.Digital.INVENTORY_EXAMINE",
		},

		MAP_ZOOM_IN =
		{
			displayname = "Controls.Digital.MAP_ZOOM_IN",
		},
		MAP_ZOOM_OUT =
		{
			displayname = "Controls.Digital.MAP_ZOOM_OUT",
		},

		-- mp controls
		TOGGLE_SAY =
		{
			displayname = "Controls.Digital.TOGGLE_SAY",
		},
		TOGGLE_WHISPER =
		{
			displayname = "Controls.Digital.TOGGLE_WHISPER",
		},
		TOGGLE_SLASH_COMMAND =
		{
			displayname = "Controls.Digital.TOGGLE_SLASH_COMMAND",
		},
		TOGGLE_PLAYER_STATUS =
		{
			displayname = "Controls.Digital.TOGGLE_PLAYER_STATUS",
		},
		SHOW_PLAYER_STATUS =
		{
			displayname = "Examine Powers",
		},
		SHOW_EMOTE_RING =
		{
			displayname = "Emotes",
		},
		SHOW_PLAYERS_LIST =
		{
			displayname = "Show Players",
		},

		-- misc controls
		MENU_MISC_11 =  -- X
		{
			displayname = "Controls.Digital.MENU_MISC_11",
		},
		MENU_MISC_12 =  -- Y
		{
			displayname = "Controls.Digital.MENU_MISC_12",
		},
		MENU_MISC_13 =  -- L
		{
			displayname = "Controls.Digital.MENU_MISC_13",
		},
		MENU_MISC_14 =  -- R
		{
			displayname = "Controls.Digital.MENU_MISC_14",
		},

		SLIDESHOW_FORWARD =
		{
			displayname = "Skip",
		},
		SLIDESHOW_REWIND =
		{
			displayname = "Rewind",
		},
		SLIDESHOW_SELECT =
		{
			displayname = "Slideshow Select", -- This is so we can click buttons with mouse
		},
	},

	Analog =
	{
		MOVE_LEFT =
		{
			displayname = "Analog Move Left",
		},
		MOVE_RIGHT =
		{
			displayname = "Analog Move Right",
		},
		MOVE_UP =
		{
			displayname = "Analog Move Up",
		},
		MOVE_DOWN =
		{
			displayname = "Analog Move Down",
		},
		-- for radial menus
		RADIAL_UP =  -- RS up
		{
			displayname = "Controls.Analog.RADIAL_UP",
		},
		RADIAL_DOWN = -- RS down
		{
			displayname = "Controls.Analog.RADIAL_DOWN",
		},
		RADIAL_LEFT = -- RS left
		{
			displayname = "Controls.Analog.RADIAL_LEFT",
		},
		RADIAL_RIGHT = -- RS right
		{
			displayname = "Controls.Analog.RADIAL_RIGHT",
		},

		MENU_SCROLL_FWD = -- Scroll down or to the right.
		{
			displayname = "Controls.Analog.MENU_SCROLL_FWD",
		},
		MENU_SCROLL_BACK = -- Scroll up or to the left.
		{
			displayname = "Controls.Analog.MENU_SCROLL_BACK",
		},
	}
}

-- Define a key so we can look them up in in Input:GetTexForControlName.
for kind_name,kind in pairs(t) do
	for ctrl_name,ctrl in pairs(kind) do
		ctrl.key = string.format("Controls.%s.%s", kind_name, ctrl_name)
	end
end

strict.strictify(t.Digital, "Controls.Digital")
strict.strictify(t.Analog,  "Controls.Analog")

return t
