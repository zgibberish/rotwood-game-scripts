local strict = require "util.strict"

local t =
{

	-- Add names to STRINGS.CONTROL_BINDINGS so they can show up in game. Get
	-- names with Input:GetControlPrettyName.
	--
	-- binding_label_key: See Input:GetControlPrettyName.
	--
	-- Each control also has:
	-- control.key: the long name like "Controls.Digital.CLICK_PRIMARY"
	-- control.shortkey: the key into the individual control table like "CLICK_PRIMARY"

	Digital =
	{
		-- player action controls
		ATTACK_LIGHT =
		{
			binding_label_key = "LIGHT_ATTACK",
		},
		ATTACK_HEAVY =
		{
			binding_label_key = "HEAVY_ATTACK",
		},
		USE_POTION =
		{
		},
		DODGE =
		{
		},
		SKILL =
		{
		},

		-- mouse-specific controls. Use these only when making mouse-only interactions!
		CLICK_PRIMARY =
		{
			-- Better to use ACTION.
		},
		CLICK_SECONDARY =
		{
			-- No gamepad equivalent.
		},

		-- Generic primary "activate a thing"
		ACTION =
		{
			binding_label_key = "INTERACT",
		},

		-- player movement controls
		MOVE_UP =
		{
		},
		MOVE_DOWN =
		{
		},
		MOVE_LEFT =
		{
		},
		MOVE_RIGHT =
		{
		},

		ZOOM_IN =
		{
		},
		ZOOM_OUT =
		{
		},

		-- system
		PAUSE =
		{
		},

		-- player HUD controls
		MAP =
		{
		},
		INV_1 =
		{
		},
		INV_2 =
		{
		},
		INV_3 =
		{
		},
		INV_4 =
		{
		},
		INV_5 =
		{
		},
		INV_6 =
		{
		},
		INV_7 =
		{
		},
		INV_8 =
		{
		},
		INV_9 =
		{
		},
		INV_10 =
		{
		},

		-- Generic minigame controls. Minigame should block player movement and
		-- use cardinal directions with button icons.
		MINIGAME_NORTH =
		{
		},
		MINIGAME_SOUTH =
		{
		},
		MINIGAME_WEST =
		{
		},
		MINIGAME_EAST =
		{
		},

		-- UI controls
		RADIAL_ACTION = -- RS-click
		{
		},

		-- Gamepad mostly uses MENU_PAGE_UP/DOWN, and not SCROLL.
		MENU_SCROLL_FWD = -- Scroll down or to the right.
		{
		},
		MENU_SCROLL_BACK = -- Scroll up or to the left.
		{
		},

		MENU_UP =  -- d-pad up
		{
			repeat_rate = 10, -- see also NAV_REPEAT_TIME
		},
		MENU_DOWN = -- d-pad down
		{
			repeat_rate = 10,
		},
		MENU_LEFT = -- d-pad left
		{
			repeat_rate = 10,
		},
		MENU_RIGHT = -- d-pad right
		{
			repeat_rate = 10,
		},

		Y =
		{
		},
		B =
		{
		},
		A =
		{
		},
		X =
		{
		},

		-- Like MENU_ but does not repeat.
		MENU_ONCE_UP =  -- d-pad up
		{
		},
		MENU_ONCE_DOWN = -- d-pad down
		{
		},
		MENU_ONCE_LEFT = -- d-pad left
		{
		},
		MENU_ONCE_RIGHT = -- d-pad right
		{
		},

		MENU_PAGE_UP =
		{
			repeat_rate = 4,
		},
		MENU_PAGE_DOWN =
		{
			repeat_rate = 4,
		},

		MENU_TAB_PREV =
		{
			repeat_rate = 4,
		},
		MENU_TAB_NEXT =
		{
			repeat_rate = 4,
		},

		MENU_SUB_TAB_PREV =
		{
			repeat_rate = 4,
		},
		MENU_SUB_TAB_NEXT =
		{
			repeat_rate = 4,
		},

		MENU_SCREEN_ADVANCE =
		{
		},
		MENU_CANCEL_INPUT_BINDING =
		{
			-- Do not display or allow rebinding of this key!
		},
		NON_MODAL_CLICK =
		{
		},
		MENU_ACCEPT =
		{
		},
		MENU_REJECT =
		{
		},
		CINE_HOLD_SKIP =
		{
		},
		MENU_CANCEL =
		{
		},
		MENU_SUBMIT =
		{
		},

		ACTIVATE_INPUT_DEVICE =
		{
		},

		ACCEPT = -- A
		{
			--repeat_rate = 5,
		},
		CANCEL = -- B
		{
		},
		PREVVALUE =
		{
		},
		NEXTVALUE =
		{
		},

		FEEDBACK =
		{
		},

		-- dev controls
		OPEN_DEBUG_CONSOLE =
		{
		},
		TOGGLE_LOG =
		{
		},
		OPEN_DEBUG_MENU =
		{
		},

		-- additional hud controls
		OPEN_INVENTORY =
		{
		},
		OPEN_CRAFTING =
		{
		},
		INVENTORY_EXAMINE = -- d-pad up
		{
		},
		UNEQUIP =
		{			
		},
		EQUIP=
		{
		},

		MAP_ZOOM_IN =
		{
		},
		MAP_ZOOM_OUT =
		{
		},

		-- mp controls
		TOGGLE_SAY =
		{
		},
		TOGGLE_WHISPER =
		{
		},
		TOGGLE_SLASH_COMMAND =
		{
		},
		TOGGLE_PLAYER_STATUS =
		{
		},
		SHOW_PLAYER_STATUS =
		{
		},
		SHOW_EMOTE_RING =
		{
		},
		SHOW_PLAYERS_LIST =
		{
		},
		SHOW_PLAYER_LOADOUT =
		{
		},

		-- misc controls
		MENU_MISC_11 =  -- X
		{
		},
		MENU_MISC_12 =  -- Y
		{
		},
		MENU_MISC_13 =  -- L
		{
		},
		MENU_MISC_14 =  -- R
		{
		},

		SLIDESHOW_FORWARD =
		{
		},
		SLIDESHOW_REWIND =
		{
		},
		SLIDESHOW_SELECT =
		{
		},
	},

	Analog =
	{
		MOVE_LEFT =
		{
		},
		MOVE_RIGHT =
		{
		},
		MOVE_UP =
		{
		},
		MOVE_DOWN =
		{
		},
		-- for radial menus
		RADIAL_UP =  -- RS up
		{
		},
		RADIAL_DOWN = -- RS down
		{
		},
		RADIAL_LEFT = -- RS left
		{
		},
		RADIAL_RIGHT = -- RS right
		{
		},

		MENU_SCROLL_FWD = -- Scroll down or to the right.
		{
		},
		MENU_SCROLL_BACK = -- Scroll up or to the left.
		{
		},
	}
}

-- Define a key so we can look them up in in Input:GetTexForControlName.
for kind_name,kind in pairs(t) do
	for ctrl_name,ctrl in pairs(kind) do
		ctrl.key = string.format("Controls.%s.%s", kind_name, ctrl_name)
		ctrl.shortkey = ctrl_name
	end
end

strict.strictify(t.Digital, "Controls.Digital")
strict.strictify(t.Analog,  "Controls.Analog")

return t
