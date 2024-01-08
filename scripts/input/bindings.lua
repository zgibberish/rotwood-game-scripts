return
{
    keyboard=
    {
        {key="A", control=Controls.Analog.MOVE_LEFT, ANYMOD = true,},
        {key="D", control=Controls.Analog.MOVE_RIGHT, ANYMOD = true,},
        {key="W", control=Controls.Analog.MOVE_UP, ANYMOD = true,},
        {key="S", control=Controls.Analog.MOVE_DOWN, ANYMOD = true,},

        {key="A", control=Controls.Digital.MOVE_LEFT, ANYMOD = true,},
        {key="D", control=Controls.Digital.MOVE_RIGHT, ANYMOD = true,},
        {key="W", control=Controls.Digital.MOVE_UP, ANYMOD = true,},
        {key="S", control=Controls.Digital.MOVE_DOWN, ANYMOD = true,},

		-- Menu nav
        {key="DOWN",  ANYMOD = true, control=Controls.Digital.MENU_DOWN},
        {key="UP",    ANYMOD = true, control=Controls.Digital.MENU_UP},
        {key="LEFT",  ANYMOD = true, control=Controls.Digital.MENU_LEFT},
        {key="RIGHT", ANYMOD = true, control=Controls.Digital.MENU_RIGHT},
        
        {key="S", ANYMOD = true, control=Controls.Digital.MENU_DOWN},
        {key="W", ANYMOD = true, control=Controls.Digital.MENU_UP},
        {key="A", ANYMOD = true, control=Controls.Digital.MENU_LEFT},
        {key="D", ANYMOD = true, control=Controls.Digital.MENU_RIGHT},

		-- Non repeating menu nav
        {key="DOWN",  ANYMOD = true, control=Controls.Digital.MENU_ONCE_DOWN},
        {key="UP",    ANYMOD = true, control=Controls.Digital.MENU_ONCE_UP},
        {key="LEFT",  ANYMOD = true, control=Controls.Digital.MENU_ONCE_LEFT},
        {key="RIGHT", ANYMOD = true, control=Controls.Digital.MENU_ONCE_RIGHT},

        {key="Q", control=Controls.Digital.MENU_TAB_PREV},
        {key="E", control=Controls.Digital.MENU_TAB_NEXT},
        {key="Z", control=Controls.Digital.MENU_SUB_TAB_PREV},
        {key="C", control=Controls.Digital.MENU_SUB_TAB_NEXT},

        {key="PAGEUP", control=Controls.Digital.MENU_PAGE_UP},
        {key="PAGEDOWN", control=Controls.Digital.MENU_PAGE_DOWN},


        {key="F", control=Controls.Digital.ACTION },

        {key="ENTER", control=Controls.Digital.ACCEPT},
        {key="KP_ENTER", control=Controls.Digital.ACCEPT},
        --{key="SPACE", control=Controls.Digital.ACCEPT},

        {key="ENTER", control=Controls.Digital.MENU_ACCEPT},
        {key="KP_ENTER", control=Controls.Digital.MENU_ACCEPT},
        --{key="SPACE", control=Controls.Digital.MENU_ACCEPT},

        {key="SPACE", control=Controls.Digital.CINE_HOLD_SKIP},

        {key="ESCAPE", control=Controls.Digital.PAUSE},
        {key="ESCAPE", control=Controls.Digital.CANCEL},
        {key="ESCAPE", control=Controls.Digital.MENU_CANCEL_INPUT_BINDING},

        {key="ENTER", control=Controls.Digital.ACTIVATE_INPUT_DEVICE},
        {key="ESCAPE", control=Controls.Digital.ACTIVATE_INPUT_DEVICE},
        {key="SPACE", control=Controls.Digital.ACTIVATE_INPUT_DEVICE},

        {key="L", CTRL=true, control=Controls.Digital.TOGGLE_LOG},
        {key="TILDE", control=Controls.Digital.OPEN_DEBUG_CONSOLE},

        {key="B", control=Controls.Digital.OPEN_CRAFTING},
        {key="I", control=Controls.Digital.OPEN_INVENTORY},
        {key="TAB", control=Controls.Digital.SHOW_PLAYER_STATUS},
        {key="P", control=Controls.Digital.SHOW_PLAYERS_LIST},

        {key="E", control=Controls.Digital.SHOW_EMOTE_RING},

        {key="J", control=Controls.Digital.ATTACK_LIGHT},
        {key="K", control=Controls.Digital.ATTACK_HEAVY},
        {key="LSHIFT", control=Controls.Digital.SKILL},
        {key="Q", control=Controls.Digital.USE_POTION},
        {key="SPACE", control=Controls.Digital.DODGE},

		-- List arrows first since they mentally map better to directions and
		-- we'll use these icons.
        {key="DOWN",  control=Controls.Digital.MINIGAME_SOUTH},
        {key="UP",    control=Controls.Digital.MINIGAME_NORTH},
        {key="LEFT",  control=Controls.Digital.MINIGAME_WEST},
        {key="RIGHT", control=Controls.Digital.MINIGAME_EAST},

        {key="S", control=Controls.Digital.MINIGAME_SOUTH},
        {key="W", control=Controls.Digital.MINIGAME_NORTH},
        {key="A", control=Controls.Digital.MINIGAME_WEST},
        {key="D", control=Controls.Digital.MINIGAME_EAST},

        {key="LSHIFT", control=Controls.Digital.INVENTORY_EXAMINE},

        {key="F8", control=Controls.Digital.FEEDBACK},
    },

    mouse=
    {
        {button="LEFT", ANYMOD = true, control=Controls.Digital.ACCEPT, skip_for_display = true},
        {button="LEFT", ANYMOD = true, control=Controls.Digital.MENU_ACCEPT, skip_for_display = true},

        {button="LEFT", ANYMOD = true, control=Controls.Digital.CLICK_PRIMARY},
        {button="RIGHT", ANYMOD = true, control=Controls.Digital.CLICK_SECONDARY},

        {button="LEFT", ANYMOD = true, control=Controls.Digital.ATTACK_LIGHT},
        {button="RIGHT", ANYMOD = true, control=Controls.Digital.ATTACK_HEAVY},

        {button="MIDDLE", ANYMOD = true, control=Controls.Digital.DODGE, skip_for_display=true, },
        {button="LEFT",   ANYMOD = true, control=Controls.Digital.ACTION, skip_for_display = true},

        {button="LEFT", ANYMOD = true, control=Controls.Digital.SLIDESHOW_SELECT},

        {button="SCROLL_UP", ANYMOD = true, control=Controls.Digital.MENU_SCROLL_BACK},
        {button="SCROLL_DOWN", ANYMOD = true, control=Controls.Digital.MENU_SCROLL_FWD},
    },

    gamepad=
    {
        {button="LS_LEFT", control=Controls.Analog.MOVE_LEFT},
        {button="LS_RIGHT", control=Controls.Analog.MOVE_RIGHT},
        {button="LS_UP", control=Controls.Analog.MOVE_UP},
        {button="LS_DOWN", control=Controls.Analog.MOVE_DOWN},

        {button="DPAD_LEFT", control=Controls.Digital.MOVE_LEFT},
        {button="DPAD_RIGHT", control=Controls.Digital.MOVE_RIGHT},
        {button="DPAD_UP", control=Controls.Digital.MOVE_UP},
        {button="DPAD_DOWN", control=Controls.Digital.MOVE_DOWN},

		-- Menu nav
        {button="LS_UP", control=Controls.Digital.MENU_UP},
        {button="LS_DOWN", control=Controls.Digital.MENU_DOWN},
        {button="LS_LEFT", control=Controls.Digital.MENU_LEFT},
        {button="LS_RIGHT", control=Controls.Digital.MENU_RIGHT},
        {button="DPAD_DOWN", control=Controls.Digital.MENU_DOWN},
        {button="DPAD_UP", control=Controls.Digital.MENU_UP},
        {button="DPAD_LEFT", control=Controls.Digital.MENU_LEFT},
        {button="DPAD_RIGHT", control=Controls.Digital.MENU_RIGHT},

		-- Non repeating menu nav
        {button="LS_UP", control=Controls.Digital.MENU_ONCE_UP},
        {button="LS_DOWN", control=Controls.Digital.MENU_ONCE_DOWN},
        {button="LS_LEFT", control=Controls.Digital.MENU_ONCE_LEFT},
        {button="LS_RIGHT", control=Controls.Digital.MENU_ONCE_RIGHT},
        {button="DPAD_DOWN", control=Controls.Digital.MENU_ONCE_DOWN},
        {button="DPAD_UP", control=Controls.Digital.MENU_ONCE_UP},
        {button="DPAD_LEFT", control=Controls.Digital.MENU_ONCE_LEFT},
        {button="DPAD_RIGHT", control=Controls.Digital.MENU_ONCE_RIGHT},

        {button="RS_UP", control=Controls.Analog.RADIAL_UP},
        {button="RS_DOWN", control=Controls.Analog.RADIAL_DOWN},
        {button="RS_LEFT", control=Controls.Analog.RADIAL_LEFT},
        {button="RS_RIGHT", control=Controls.Analog.RADIAL_RIGHT},
        {button="RS", control=Controls.Digital.RADIAL_ACTION},

        {button="START", control=Controls.Digital.PAUSE},
        {button="BACK", control=Controls.Digital.SHOW_PLAYER_STATUS},

        {button="START", control=Controls.Digital.MENU_SCREEN_ADVANCE}, -- for confirming the whole screen. probably gamepad-only.
        {button="START", control=Controls.Digital.MENU_CANCEL_INPUT_BINDING},
        {button="B", control=Controls.Digital.NON_MODAL_CLICK}, -- activate non modal UI. doesn't overlap with most gameplay actions.

        {button="A", control=Controls.Digital.ACTIVATE_INPUT_DEVICE},
        {button="START", control=Controls.Digital.ACTIVATE_INPUT_DEVICE},

        {button="A", control=Controls.Digital.ACCEPT},
        {button="A", control=Controls.Digital.MENU_ACCEPT},
        {button="B", control=Controls.Digital.MENU_REJECT}, -- unlike CANCEL, this is a destructive action.

        {button="A", control=Controls.Digital.CINE_HOLD_SKIP},
        {button="B", control=Controls.Digital.CANCEL},

        {button="RB", control=Controls.Digital.ACTION},
        {button="A", control=Controls.Digital.DODGE},
        {button="B", control=Controls.Digital.SKILL},
        {button="LB", control=Controls.Digital.USE_POTION},
        {button="X", control=Controls.Digital.ATTACK_LIGHT},
        {button="Y", control=Controls.Digital.ATTACK_HEAVY},

        {button="RT", control=Controls.Digital.SHOW_EMOTE_RING},

        {button="LT", control=Controls.Digital.OPEN_INVENTORY},
        {button="RS", control=Controls.Digital.OPEN_CRAFTING},

        {button="LB", control=Controls.Digital.MENU_TAB_PREV},
        {button="RB", control=Controls.Digital.MENU_TAB_NEXT},

        {button="LT", control=Controls.Digital.MENU_SUB_TAB_PREV},
        {button="RT", control=Controls.Digital.MENU_SUB_TAB_NEXT},

        {button="LT", control=Controls.Digital.MENU_PAGE_UP},
        {button="RT", control=Controls.Digital.MENU_PAGE_DOWN},
        {button="RS_UP",   control=Controls.Analog.MENU_SCROLL_BACK},
        {button="RS_DOWN", control=Controls.Analog.MENU_SCROLL_FWD},

        {button="LB", control=Controls.Digital.SLIDESHOW_REWIND},
        {button="RB", control=Controls.Digital.SLIDESHOW_FORWARD},

        {button="A", control=Controls.Digital.MINIGAME_SOUTH},
        {button="Y", control=Controls.Digital.MINIGAME_NORTH},
        {button="X", control=Controls.Digital.MINIGAME_WEST},
        {button="B", control=Controls.Digital.MINIGAME_EAST},

        {button="A", control=Controls.Digital.A},
        {button="Y", control=Controls.Digital.Y},
        {button="X", control=Controls.Digital.X},
        {button="B", control=Controls.Digital.B},

    }
}
