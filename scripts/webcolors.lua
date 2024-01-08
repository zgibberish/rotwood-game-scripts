require "util.colorutil"

-- standard html colours: https://en.wikipedia.org/wiki/web_colors#x11_color_names
local WEBCOLORS = {

	-- !!!!
	-- DON'T CHANGE THESE COLORS. Copy them to UICOLORS and rename them
	-- according to how you're using them.
	-- !!!!

	-- pinks
	MEDIUMVIOLETRED      = RGB(199, 21, 133),
	DEEPPINK             = RGB(255, 20, 147),
	PALEVIOLETRED        = RGB(219, 112, 147),
	HOTPINK              = RGB(255, 105, 180),
	LIGHTPINK            = RGB(255, 182, 193),
	PINK                 = RGB(255, 192, 203),

	-- reds
	DARKRED              = RGB(139, 0, 0),
	RED                  = RGB(255, 0, 0),
	FIREBRICK            = RGB(178, 34, 34),
	CRIMSON              = RGB(220, 20, 60),
	INDIANRED            = RGB(205, 92, 92),
	LIGHTCORAL           = RGB(240, 128, 128),
	SALMON               = RGB(250, 128, 114),
	DARKSALMON           = RGB(233, 150, 122),
	LIGHTSALMON          = RGB(255, 160, 122),

	-- oranges
	ORANGERED            = RGB(255, 69, 0),
	TOMATO               = RGB(255, 99, 71),
	DARKORANGE           = RGB(255, 140, 0),
	CORAL                = RGB(255, 127, 80),
	ORANGE               = RGB(255, 165, 0),

	-- yellows
	DARKKHAKI            = RGB(189, 183, 107),
	GOLD                 = RGB(255, 215, 0),
	KHAKI                = RGB(240, 230, 140),
	PEACHPUFF            = RGB(255, 218, 185),
	YELLOW               = RGB(255, 255, 0),
	PALEGOLDENROD        = RGB(238, 232, 170),
	MOCCASIN             = RGB(255, 228, 181),
	PAPAYAWHIP           = RGB(255, 239, 213),
	LIGHTGOLDENRODYELLOW = RGB(250, 250, 210),
	LEMONCHIFFON         = RGB(255, 250, 205),
	LIGHTYELLOW          = RGB(255, 255, 224),

	-- browns
	MAROON               = RGB(128, 0, 0),
	BROWN                = RGB(165, 42, 42),
	SADDLEBROWN          = RGB(139, 69, 19),
	SIENNA               = RGB(160, 82, 45),
	CHOCOLATE            = RGB(210, 105, 30),
	DARKGOLDENROD        = RGB(184, 134, 11),
	PERU                 = RGB(205, 133, 63),
	ROSYBROWN            = RGB(188, 143, 143),
	GOLDENROD            = RGB(218, 165, 32),
	SANDYBROWN           = RGB(244, 164, 96),
	TAN                  = RGB(210, 180, 140),
	BURLYWOOD            = RGB(222, 184, 135),
	WHEAT                = RGB(245, 222, 179),
	NAVAJOWHITE          = RGB(255, 222, 173),
	BISQUE               = RGB(255, 228, 196),
	BLANCHEDALMOND       = RGB(255, 235, 205),
	CORNSILK             = RGB(255, 248, 220),

	-- greens
	DARKGREEN            = RGB(0, 100, 0),
	GREEN                = RGB(0, 128, 0),
	DARKOLIVEGREEN       = RGB(85, 107, 47),
	FORESTGREEN          = RGB(34, 139, 34),
	SEAGREEN             = RGB(46, 139, 87),
	OLIVE                = RGB(128, 128, 0),
	OLIVEDRAB            = RGB(107, 142, 35),
	MEDIUMSEAGREEN       = RGB(60, 179, 113),
	LIMEGREEN            = RGB(50, 205, 50),
	LIME                 = RGB(0, 255, 0),
	SPRINGGREEN          = RGB(0, 255, 127),
	MEDIUMSPRINGGREEN    = RGB(0, 250, 154),
	DARKSEAGREEN         = RGB(143, 188, 143),
	MEDIUMAQUAMARINE     = RGB(102, 205, 170),
	YELLOWGREEN          = RGB(154, 205, 50),
	LAWNGREEN            = RGB(124, 252, 0),
	CHARTREUSE           = RGB(127, 255, 0),
	LIGHTGREEN           = RGB(144, 238, 144),
	GREENYELLOW          = RGB(173, 255, 47),
	PALEGREEN            = RGB(152, 251, 152),

	-- cyans
	TEAL                 = RGB(0, 128, 128),
	DARKCYAN             = RGB(0, 139, 139),
	LIGHTSEAGREEN        = RGB(32, 178, 170),
	CADETBLUE            = RGB(95, 158, 160),
	DARKTURQUOISE        = RGB(0, 206, 209),
	MEDIUMTURQUOISE      = RGB(72, 209, 204),
	TURQUOISE            = RGB(64, 224, 208),
	AQUA                 = RGB(0, 255, 255),
	CYAN                 = RGB(0, 255, 255),
	AQUAMARINE           = RGB(127, 255, 212),
	PALETURQUOISE        = RGB(175, 238, 238),
	LIGHTCYAN            = RGB(224, 255, 255),

	-- blues
	NAVY                 = RGB(0, 0, 128),
	DARKBLUE             = RGB(0, 0, 139),
	MEDIUMBLUE           = RGB(0, 0, 205),
	BLUE                 = RGB(0, 0, 255),
	MIDNIGHTBLUE         = RGB(25, 25, 112),
	ROYALBLUE            = RGB(65, 105, 225),
	STEELBLUE            = RGB(70, 130, 180),
	DODGERBLUE           = RGB(30, 144, 255),
	DEEPSKYBLUE          = RGB(0, 191, 255),
	CORNFLOWERBLUE       = RGB(100, 149, 237),
	SKYBLUE              = RGB(135, 206, 235),
	LIGHTSKYBLUE         = RGB(135, 206, 250),
	LIGHTSTEELBLUE       = RGB(176, 196, 222),
	LIGHTBLUE            = RGB(173, 216, 230),
	POWDERBLUE           = RGB(176, 224, 230),

	-- purple, violet, and magentas
	INDIGO               = RGB(75, 0, 130),
	PURPLE               = RGB(128, 0, 128),
	DARKMAGENTA          = RGB(139, 0, 139),
	DARKVIOLET           = RGB(148, 0, 211),
	DARKSLATEBLUE        = RGB(72, 61, 139),
	BLUEVIOLET           = RGB(138, 43, 226),
	DARKORCHID           = RGB(153, 50, 204),
	FUCHSIA              = RGB(255, 0, 255),
	MAGENTA              = RGB(255, 0, 255),
	SLATEBLUE            = RGB(106, 90, 205),
	MEDIUMSLATEBLUE      = RGB(123, 104, 238),
	MEDIUMORCHID         = RGB(186, 85, 211),
	MEDIUMPURPLE         = RGB(147, 112, 219),
	ORCHID               = RGB(218, 112, 214),
	VIOLET               = RGB(238, 130, 238),
	PLUM                 = RGB(221, 160, 221),
	THISTLE              = RGB(216, 191, 216),
	LAVENDER             = RGB(230, 230, 250),

	-- whites
	MISTYROSE            = RGB(255, 228, 225),
	ANTIQUEWHITE         = RGB(250, 235, 215),
	LINEN                = RGB(250, 240, 230),
	BEIGE                = RGB(245, 245, 220),
	WHITESMOKE           = RGB(245, 245, 245),
	LAVENDERBLUSH        = RGB(255, 240, 245),
	OLDLACE              = RGB(253, 245, 230),
	ALICEBLUE            = RGB(240, 248, 255),
	SEASHELL             = RGB(255, 245, 238),
	GHOSTWHITE           = RGB(248, 248, 255),
	HONEYDEW             = RGB(240, 255, 240),
	FLORALWHITE          = RGB(255, 250, 240),
	AZURE                = RGB(240, 255, 255),
	MINTCREAM            = RGB(245, 255, 250),
	SNOW                 = RGB(255, 250, 250),
	IVORY                = RGB(255, 255, 240),
	WHITE                = RGB(255, 255, 255),

	-- gray and blacks
	BLACK                = RGB(0, 0, 0),
	DARKSLATEGRAY        = RGB(47, 79, 79),
	DIMGRAY              = RGB(105, 105, 105),
	SLATEGRAY            = RGB(112, 128, 144),
	GRAY                 = RGB(128, 128, 128),
	LIGHTSLATEGRAY       = RGB(119, 136, 153),
	DARKGRAY             = RGB(169, 169, 169),
	SILVER               = RGB(192, 192, 192),
	LIGHTGRAY            = RGB(211, 211, 211),
	GAINSBORO            = RGB(220, 220, 220),

	-- Not really a webcolor, but similarly immutable.
    TRANSPARENT_BLACK    = HexToRGB(0x00000000),

}

return WEBCOLORS
