local strict = require "util.strict"

InputConstants =
{
	-- synced with kiln/inputevent.h!!
	Keys=
	{
		BACKSPACE = 5,
		TAB = 3,
		ENTER = 2,
		PAUSE = 86,
		ESCAPE = 1,
		SPACE = 4,
		QUOTE = 22,

		COMMA = 23,
		MINUS = 18,
		PERIOD = 24,
		SLASH = 25, -- TODO: rename to FWDSLASH

		NUM_0 = 50,
		NUM_1 = 51,
		NUM_2 = 52,
		NUM_3 = 53,
		NUM_4 = 54,
		NUM_5 = 55,
		NUM_6 = 56,
		NUM_7 = 57,
		NUM_8 = 58,
		NUM_9 = 59,

		SEMICOLON = 21,

		EQUALS = 87,

		LEFTBRACKET	= 19,
		BACKSLASH	= 26,
		RIGHTBRACKET= 20,
		TILDE = 27, -- TODO: backtick? Doesn't ~ require shift?

		A = 60,
		B = 61,
		C = 62,
		D = 63,
		E = 64,
		F = 65,
		G = 66,
		H = 67,
		I = 68,
		J = 69,
		K = 70,
		L = 71,
		M = 72,
		N = 73,
		O = 74,
		P = 75,
		Q = 76,
		R = 77,
		S = 78,
		T = 79,
		U = 80,
		V = 81,
		W = 82,
		X = 83,
		Y = 84,
		Z = 85,

		DELETE = 11,

		KP_DIVIDE = 98,
		KP_MULTIPLY = 99,
		KP_MINUS = 100,
		KP_PLUS	 = 101,
		KP_ENTER = 102,
		KP_PERIOD = 103,
		KP_EQUALS = 104,
		KP_COMMA = 105,

		KP_0 = 40,
		KP_1 = 41,
		KP_2 = 42,
		KP_3 = 43,
		KP_4 = 44,
		KP_5 = 45,
		KP_6 = 46,
		KP_7 = 47,
		KP_8 = 48,
		KP_9 = 49,

		F1 = 28,
		F2 = 29,
		F3 = 30,
		F4 = 31,
		F5 = 32,
		F6 = 33,
		F7 = 34,
		F8 = 35,
		F9 = 36,
		F10 = 37,
		F11 = 38,
		F12 = 39,

		UP = 6,
		DOWN = 7,
		RIGHT = 9,
		LEFT = 8,
		INSERT = 10,
		HOME = 12,
		END = 13,
		PAGEUP = 14,
		PAGEDOWN = 15,
		PRINT = 16,

		CAPSLOCK = 88,
		SCROLLLOCK = 89,
		NUMLOCK = 106,

		LALT = 90,
		RALT = 91,
		LSHIFT = 92,
		RSHIFT = 93,
		LCTRL = 94,
		RCTRL = 95,
		LSUPER = 96, -- SDL calls it LGUI. The Windows key
		RSUPER = 97, -- SDL calls it RGUI. The Windows key

		-- meta keys
		SHIFT = 1024,
		CTRL = 1025,
		ALT = 1026,
	},

	MouseButtons=
	{
		LEFT = 0,
		MIDDLE = 1,
		RIGHT = 2,
		-- meta buttons
		SCROLL_UP = 1003,
		SCROLL_DOWN = 1004,
	},

	GamepadButtons=
	{
		A = 3,
		B = 4,
		X = 5,
		Y = 6,
		LB = 7,
		RB = 8,
		BACK = 9,
		START = 10,
		LS = 11,
		RS = 12,

		LT = 13,
		RT = 14,

		DPAD_UP = 15,
		DPAD_RIGHT = 16,
		DPAD_DOWN = 17,
		DPAD_LEFT = 18,

		LS_UP = 19,
		LS_DOWN = 20,
		LS_LEFT = 21,
		LS_RIGHT = 22,

		RS_UP = 23,
		RS_DOWN = 24,
		RS_LEFT = 25,
		RS_RIGHT = 26,
	}
}


InputConstants.MouseButtonById = {}
for k,v in pairs(InputConstants.MouseButtons) do
	InputConstants.MouseButtonById[v] = k
end

InputConstants.KeyById = {}
for k,v in pairs(InputConstants.Keys) do
	InputConstants.KeyById[v] = k
end

InputConstants.GamepadButtonById = {}
for k,v in pairs(InputConstants.GamepadButtons) do
	InputConstants.GamepadButtonById[v] = k
end



-- Notify users when they try to use invalid constants.
strict.strictify(InputConstants, "InputConstants", true)
