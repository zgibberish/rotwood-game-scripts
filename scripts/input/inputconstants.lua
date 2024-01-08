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

InputConstants.RawKeyConversionTable =
{
	BACKSPACE = InputConstants.Keys.BACKSPACE,
	TAB = InputConstants.Keys.TAB,
	ENTER = InputConstants.Keys.ENTER,
	PAUSE = InputConstants.Keys.PAUSE,
	ESCAPE = InputConstants.Keys.ESCAPE,
	SPACE = InputConstants.Keys.SPACE,
	QUOTE = InputConstants.Keys.QUOTE,

	COMMA = InputConstants.Keys.COMMA,
	MINUS = InputConstants.Keys.MINUS,
	PERIOD = InputConstants.Keys.PERIOD,
	SLASH = InputConstants.Keys.SLASH,

	NUM_0 = InputConstants.Keys.NUM_0,
	NUM_1 = InputConstants.Keys.NUM_1,
	NUM_2 = InputConstants.Keys.NUM_2,
	NUM_3 = InputConstants.Keys.NUM_3,
	NUM_4 = InputConstants.Keys.NUM_4,
	NUM_5 = InputConstants.Keys.NUM_5,
	NUM_6 = InputConstants.Keys.NUM_6,
	NUM_7 = InputConstants.Keys.NUM_7,
	NUM_8 = InputConstants.Keys.NUM_8,
	NUM_9 = InputConstants.Keys.NUM_9,

	SEMICOLON = InputConstants.Keys.SEMICOLON,

	EQUALS = InputConstants.Keys.EQUALS,

	LEFTBRACKET	= InputConstants.Keys.LEFTBRACKET,
	BACKSLASH	= InputConstants.Keys.BACKSLASH,
	RIGHTBRACKET= InputConstants.Keys.RIGHTBRACKET,
	TILDE = InputConstants.Keys.TILDE,

	A = InputConstants.Keys.A,
	B = InputConstants.Keys.B,
	C = InputConstants.Keys.C,
	D = InputConstants.Keys.D,
	E = InputConstants.Keys.E,
	F = InputConstants.Keys.F,
	G = InputConstants.Keys.G,
	H = InputConstants.Keys.H,
	I = InputConstants.Keys.I,
	J = InputConstants.Keys.J,
	K = InputConstants.Keys.K,
	L = InputConstants.Keys.L,
	M = InputConstants.Keys.M,
	N = InputConstants.Keys.N,
	O = InputConstants.Keys.O,
	P = InputConstants.Keys.P,
	Q = InputConstants.Keys.Q,
	R = InputConstants.Keys.R,
	S = InputConstants.Keys.S,
	T = InputConstants.Keys.T,
	U = InputConstants.Keys.U,
	V = InputConstants.Keys.V,
	W = InputConstants.Keys.W,
	X = InputConstants.Keys.X,
	Y = InputConstants.Keys.Y,
	Z = InputConstants.Keys.Z,

	DELETE = InputConstants.Keys.DELETE,

	KP_DIVIDE = InputConstants.Keys.KP_DIVIDE,
	KP_MULTIPLY = InputConstants.Keys.KP_MULTIPLY,
	KP_MINUS = InputConstants.Keys.KP_MINUS,
	KP_PLUS	 = InputConstants.Keys.KP_PLUS,
	KP_ENTER = InputConstants.Keys.KP_ENTER,
	KP_PERIOD = InputConstants.Keys.KP_PERIOD,
	KP_EQUALS = InputConstants.Keys.KP_EQUALS,
	KP_COMMA = 105, --TODO_KAJ OSX

	KP_0 = InputConstants.Keys.KP_0,
	KP_1 = InputConstants.Keys.KP_1,
	KP_2 = InputConstants.Keys.KP_2,
	KP_3 = InputConstants.Keys.KP_3,
	KP_4 = InputConstants.Keys.KP_4,
	KP_5 = InputConstants.Keys.KP_5,
	KP_6 = InputConstants.Keys.KP_6,
	KP_7 = InputConstants.Keys.KP_7,
	KP_8 = InputConstants.Keys.KP_8,
	KP_9 = InputConstants.Keys.KP_9,

	F1 = InputConstants.Keys.F1,
	F2 = InputConstants.Keys.F2,
	F3 = InputConstants.Keys.F3,
	F4 = InputConstants.Keys.F4,
	F5 = InputConstants.Keys.F5,
	F6 = InputConstants.Keys.F6,
	F7 = InputConstants.Keys.F7,
	F8 = InputConstants.Keys.F8,
	F9 = InputConstants.Keys.F9,
	F10 = InputConstants.Keys.F10,
	F11 = InputConstants.Keys.F11,
	F12 = InputConstants.Keys.F12,

	UP = InputConstants.Keys.UP,
	DOWN = InputConstants.Keys.DOWN,
	RIGHT = InputConstants.Keys.RIGHT,
	LEFT = InputConstants.Keys.LEFT,
	INSERT = InputConstants.Keys.INSERT,
	HOME = InputConstants.Keys.HOME,
	END = InputConstants.Keys.END,
	PAGEUP = InputConstants.Keys.PAGEUP,
	PAGEDOWN = InputConstants.Keys.PAGEDOWN,
	PRINT = InputConstants.Keys.PRINT,

	CAPSLOCK = InputConstants.Keys.CAPSLOCK,
	SCROLLLOCK = InputConstants.Keys.SCROLLLOCK,
	NUMLOCK = InputConstants.Keys.NUMLOCK,

	LALT = InputConstants.Keys.LALT,
	RALT = InputConstants.Keys.RALT,
	LSHIFT = InputConstants.Keys.LSHIFT,
	RSHIFT = InputConstants.Keys.RSHIFT,
	LCTRL = InputConstants.Keys.LCTRL,
	RCTRL = InputConstants.Keys.RCTRL,
	LSUPER = InputConstants.Keys.LSUPER,
	RSUPER = InputConstants.Keys.RSUPER,
}

-- Notify users when they try to use invalid constants.
strict.strictify(InputConstants, "InputConstants", true)
