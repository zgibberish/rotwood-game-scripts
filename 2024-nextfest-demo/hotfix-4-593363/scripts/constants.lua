-- This file is used by exportprefabs.lua, so don't use global functions from main here.
require "util.colorutil"
require "util"
local Enum = require "util.enum"
local strict = require "util.strict"

HACK_FOR_4K = 2 -- TODO(4k): Remove all instances once they're known to look good.

SECONDS = 60 -- victorc: 60Hz, const for converting values expressed in seconds to game update ticks
TICKS = 1 / 60 -- victorc: 60Hz, const for converting values expressed in game update ticks to time (seconds).  Length of a tick expressed in seconds.  Should match TheSim:GetTickTime() (SIMTICK in native)
ANIM_FRAMES = (SECONDS == 60) and 2 or 1 -- victorc: 60Hz, const for converting values expressed in anim frames (1/30s) to game update ticks
PI = 3.14159265359
DEGREES = PI/180

function SecondsToAnimFrames(sec)
	local ticks = sec * SECONDS
	return ticks / ANIM_FRAMES
end

function AnimFramesToSeconds(frames)
	return frames * ANIM_FRAMES / SECONDS
end

TILE_SCALE = 4 --deprecate this one
TILE_SIZE = 4

MAX_FE_SCALE = 3 --Default if you don't call SetMaxPropUpscale
MAX_HUD_SCALE = 1.25

MAX_PLAYER_COUNT = 4 -- Exists for lua convenience. Network doesn't rely on this limit.

----------- Global Quest Variables -----------
TOWN_CHAT_BUDGET = 100
DEFAULT_CHAT_COST = 33
MAX_CHATS_PER_TOWN_VISIT = 3

QUEST_IMPORTANCE = Enum{
    "LOW", -- Convos related to this objective or quest will not be marked
    "DEFAULT", -- Convos related to this objective or quest will be marked
    "HIGH", -- Convos related to this objective or quest will be marked with a special marker
}

QUEST_OBJECTIVE_STATE = Enum{
    "ACTIVE",
    "INACTIVE",
    "COMPLETED",
    "FAILED",
    "CANCELED"
}

QUEST_PRIORITY = {
    LOWEST = -100,
    LOW = -10,
    NORMAL = 0,
    HIGH = 10,
    HIGHEST = 100
}

----------- -----------

FACING_RIGHT = 0
FACING_UP = 1
FACING_LEFT = 2
FACING_DOWN = 3
FACING_UPRIGHT = 4
FACING_UPLEFT = 5
FACING_DOWNRIGHT = 6
FACING_DOWNLEFT = 7
FACING_NONE = 8

-- Careful inserting into here. You will have to update game\render\RenderLayer.h
LAYER_BACKDROP = 0
LAYER_BELOW_OCEAN = 1
LAYER_BELOW_GROUND = 2
LAYER_BACKGROUND = 3
LAYER_WORLD_BACKGROUND = 4
LAYER_WORLD = 5
-- client-only layers go below here --
LAYER_WORLD_DEBUG = 6
LAYER_FRONTEND = 7
LAYER_FRONTEND_DEBUG = 8

LAYER_WIP_BELOW_OCEAN = 2 --1


ANCHOR_MIDDLE = 0
ANCHOR_LEFT = 1
ANCHOR_RIGHT = 2
ANCHOR_TOP = 1
ANCHOR_BOTTOM = 2

SCALEMODE_NONE = 0
SCALEMODE_FILLSCREEN = 1 --stretch art to fit/fill window
SCALEMODE_PROPORTIONAL = 2 --preserve aspect ratio (picks the smaller of horizontal/vertical scale)
SCALEMODE_FIXEDPROPORTIONAL = 3 --same as SCALEMODE_FIXEDSCREEN_NONDYNAMIC, except for safe area on consoles
SCALEMODE_FIXEDSCREEN_NONDYNAMIC = 4 --scale same amount as window scaling from 1280x720

PHYSICS_TYPE_ANIMATION_CONTROLLED = 0
PHYSICS_TYPE_PHYSICS_CONTROLLED = 1

MOVE_UP = "up"
MOVE_DOWN = "down"
MOVE_LEFT = "left"
MOVE_RIGHT = "right"

NUM_CRAFTING_RECIPES = 10

--push priorities
STATIC_PRIORITY = 10000

GESTURE_ZOOM_IN = 900
GESTURE_ZOOM_OUT = 901
GESTURE_ROTATE_LEFT = 902
GESTURE_ROTATE_RIGHT = 903
GESTURE_MAX = 904

SCREEN_FLASH_SCALING =
{
	0.9, -- default
	0.6, -- dim
	0.3, -- dimmest
}

-- These exists mostly to set root prefabs for updateprefabs.
BACKEND_PREFABS = {
	"dungeon",
	-- Do the below need to be here?
	"grid_cell",
	"debug_draggable", -- fx and particle editor
	"debug_worldtext",
}
FRONTEND_PREFABS = { "frontend" }

FADE_OUT = false
FADE_IN = true

PLAYER_PREFABS = {
	-- Rotwood has a single side-perspective player prefab. NPC prefabs are
	-- defined by NpcEditor and loaded via placements.
	"player_side",
}

require("prefabskins")

---------------------------------------------------------

-- keep up to date with MapSampleStyle in MapDefines.h
MAP_SAMPLE_STYLE =
{
	NINE_SAMPLE = 0,
	MARCHING_SQUARES = 1, -- Note to modders: this approach is still a prototype
}


-- keep up to date with COLLISION_GROUP in simconstants.h
COLLISION =
{
    GROUND            = 32,
	WORLD_LIMITS      = 64,              -- physics wall between land and outside of playable space
	HOLE_LIMITS       = 128,             -- physics wall between land and holes in the playable space
    LIMITS            = 128 + 64,        -- WORLD_LIMITS + HOLE_LIMITS
    WORLD             = 128 + 64 + 32,   -- WORLD_LIMITS + HOLE_LIMITS + GROUND
    ITEMS             = 256,
    OBSTACLES         = 512,
    CHARACTERS        = 1024,
    FLYERS            = 2048,
    SANITY            = 4096,
    SMALLOBSTACLES    = 8192,	-- collide with characters but not giants
    GIANTS            = 16384,	-- collide with obstacles but not small obstacles
}

-- Must match BlendMode ids in rendertypes.h
BlendMode = Enum{
	"AlphaBlended", -- first value has id 1
	"Additive",
	"Premultiplied",
	"InverseAlpha",
	"AlphaAdditive",
	"Max",
	"Min",
	"VFXTest",
	"PremultipliedAdditive",
}
BlendMode:SetIdZero("Disabled")

ANIM_ORIENTATION =
{
    BillBoard = 0,
    OnGround = 1,
    OnGroundFixed = 2,
}
ANIM_ORIENTATION.Default = ANIM_ORIENTATION.BillBoard

RENDERPASS =
{
	SHADOW = 0,
	RIM = 1,
	DEFAULT = 2,
}

RENDER_QUALITY =
{
	LOW = 0,
	DEFAULT = 1,
	HIGH = 2,
}

BGCOLORS =
{
    RED =          RGB(255, 89,  46 ),
    BLUE =         RGB(  0,  0,  255 ),
    PURPLE =       RGB(184, 87,  198),
    YELLOW =       RGB(255, 196, 45 ),
    GREY =         RGB(75,  75,  75 ),
    HALF =         RGB(128, 128, 128 ),
    FULL =         RGB(255, 255, 255),
    CYAN =         RGB(0, 255,  255 ),
}

WEBCOLORS = require "webcolors"
-- Strict gives obvious error when you use a nonexistent color (GRAY vs GREY).
strict.strictify(WEBCOLORS, "WEBCOLORS", false)

SAY_COLOR =         RGB(255, 255, 255)
WHISPER_COLOR =     RGB(153, 153, 153)

FRONTEND_PORTAL_COLOR = {245/255, 232/255, 204/255, 255/255}
FRONTEND_SMOKE_COLOR = {245/255, 232/255, 204/255, 153/255}
PORTAL_TEXT_COLOR = {243/255, 244/255, 243/255, 255/255}
FADE_WHITE_COLOR = {237/255, 224/255, 189/255, 255/255}


ANNOUNCEMENT_ICONS =
{
    ["default"] =           { atlas = "images/button_icons.xml", texture = "announcement.tex" },
    ["afk_start"] =         { atlas = "images/button_icons.xml", texture = "AFKstart.tex" },
    ["afk_stop"] =          { atlas = "images/button_icons.xml", texture = "AFKstop.tex" },
    ["death"] =             { atlas = "images/button_icons.xml", texture = "death.tex" },
    ["resurrect"] =         { atlas = "images/button_icons.xml", texture = "resurrect.tex" },
    ["join_game"] =         { atlas = "images/button_icons.xml", texture = "join.tex" },
    ["leave_game"] =        { atlas = "images/button_icons.xml", texture = "leave.tex" },
    ["kicked_from_game"] =  { atlas = "images/button_icons.xml", texture = "kicked.tex" },
    ["banned_from_game"] =  { atlas = "images/button_icons.xml", texture = "banned.tex" },
    ["item_drop"] =         { atlas = "images/button_icons.xml", texture = "item_drop.tex" },
    ["vote"] =              { atlas = "images/button_icons.xml", texture = "vote.tex" },
    ["dice_roll"] =         { atlas = "images/button_icons.xml", texture = "diceroll.tex" },
    ["mod"] =               { atlas = "images/button_icons.xml", texture = "mod_announcement.tex" },
}

RESET_ACTION =
{
	LOAD_FRONTEND = 0,
	LOAD_TOWN_ROOM = 1,
	LOAD_DUNGEON_ROOM = 2,
	DEV_LOAD_ROOM = 3,
	JOIN_GAME = 4,
}

VIBRATION_CAMERA_SHAKE = 0

SAVELOAD =
{
    OPERATION =
    {
        PREPARE = 0,
        LOAD = 1,
        SAVE = 2,
        DELETE = 3,
        NONE = 4,
    },

    STATUS =
    {
        OK = 0,
        DAMAGED = 1,
        NOT_FOUND = 2,
        NO_SPACE = 3,
        FAILED = 4,
    },
}

APPID = {
	ROTWOOD = 2015270,
	DONT_STARVE_TOGETHER = 322330,
	DONT_STARVE = 219740,
}

SWIPE_FADE_TIME = .4
SCREEN_FADE_TIME = .2
BUTTON_W = 290 * HACK_FOR_4K
BUTTON_H = 70 * HACK_FOR_4K
BUTTON_SQUARE_SIZE = 60 * HACK_FOR_4K
DOUBLE_CLICK_TIMEOUT = .5

-- A coherent palette for UI elements
UICOLORS = {
    -- Legacy DST colors. See FtF ones below.
    GOLD_CLICKABLE = RGB(215, 210, 157), -- interactive text & menu
    GOLD_FOCUS = RGB(251, 193, 92), -- menu active item
    GOLD_SELECTED = RGB(245, 243, 222), -- titles and non-interactive important text
    GOLD_UNIMPORTANT = RGB(213, 213, 203), -- non-interactive non-important text
    GOLD = RGB(202, 174, 118),
    BLUE = RGB(80, 143, 244),
    GREY = RGB(145.35, 145.35, 145.35),
    BLACK = RGB(0, 0, 0),
    WHITE = RGB(255, 255, 255),
    PURPLE = RGB(152, 86, 232),
    RED = RGB(207, 61, 61),
    GREEN = RGB(59,  222, 99),
    DIALOG_TITLE = HexToRGB(0x626D6FFF),
    DIALOG_SUBTITLE = HexToRGB(0x3C4749FF),
    DIALOG_TEXT = HexToRGB(0xFFFFFFFF),

    -- NEW COLOR THEME ------------------------

    SHIELD               = RGB(181, 181, 181),
    HEAL                 = RGB(59,  222, 99),
    ATK_FOCUS            = RGB(108, 248, 250),
    ATK_DO_DAMAGE        = RGB(238, 99,  99),
    ATK_SECONDARY_DAMAGE = RGB(255, 140, 105),
    ATK_TAKE_DAMAGE      = RGB(200, 20, 20),
    ATK_CRIT             = RGB(255, 31, 178),

    -- New backgrounds
    LIGHT_BACKGROUNDS_LIGHT =       HexToRGB(0xDFCAB3FF), -- The inner area where the content goes
    LIGHT_BACKGROUNDS_MID =         HexToRGB(0xCEB6A5FF), -- The border area near the black edge
    LIGHT_BACKGROUNDS_DARK =        HexToRGB(0xC6AE9EFF), -- Darker container elements

    BACKGROUND_LIGHT =     HexToRGB(0x584741FF),
    BACKGROUND_MID =       HexToRGB(0x3A2E27FF),
    BACKGROUND_DARK =      HexToRGB(0x221C1AFF),
    BACKGROUND_DARKEST =   HexToRGB(0x201918FF),

    ACTION =               HexToRGB(0xB54242FF),
    ACTION_PRIMARY =       HexToRGB(0x61E49EFF),

    SPEECH_TEXT =          HexToRGB(0x352827ff),
    SPEECH_BUTTON_TEXT =   HexToRGB(0x755751ff),
    SUBTITLE =             HexToRGB(0xffffffff),

    DIALOG_BUTTON_NORMAL = HexToRGB(0xE4D9A5FF),

    FOCUS =                HexToRGB(0xF6B742FF),
    FOCUS_LIGHT =          HexToRGB(0xFFEE70FF),
    FOCUS_BOLD =           HexToRGB(0xFFCB27FF),
    FOCUS_TRANSPARENT =    HexToRGB(0xF6B74200),
    FOCUS_DARK =           HexToRGB(0xD3982CFF),

    OVERLAY              = HexToRGB(0xFECE72FF),
    OVERLAY_LIGHT        = HexToRGB(0xFFE8D5FF),
    BACKGROUND_OVERLAY   = HexToRGB(0x00000064),
    OVERLAY_ATTENTION_GRAB = HexToRGB(0xFF3B3BEB),

    INFO =                 HexToRGB(0xBEEADFFF),
    INFO_DARK =            HexToRGB(0xB8DFD6FF),

	-- Light text usually on a dark background.
    LIGHT_TEXT_TITLE =     HexToRGB(0xEEEDE9FF),
    LIGHT_TEXT =           HexToRGB(0xDFCAB3FF),
    LIGHT_TEXT_DARK =      HexToRGB(0x967D71FF),
    LIGHT_TEXT_DARKER =    HexToRGB(0x77625EFF),
    LIGHT_TEXT_SELECTED =  HexToRGB(0xEEA02EFF), -- for selected widgets (SetTextSelectedColour)
    LIGHT_TEXT_WARN =      HexToRGB(0xF7B657FF), -- highlight something gone wrong

	-- Dark text usually on a light background.
    DARK_TEXT =            HexToRGB(0xA3897BFF),
    DARK_TEXT_DARKER =     HexToRGB(0x524326FF),
    DARK_TEXT_ERROR      = RGB(207, 61, 61),

    -- Button/key icon colors (showing a gamepad button). Usually appear in tooltips.
    BTNICON_DARK =         HexToRGB(0x584741FF),

    TOOLTIP_TEXT =         HexToRGB(0x584741FF),

	-- Automatic colors used within questral.
    ACTOR_NAME    = HexToRGB(0x25688AFF),
    LOCATION_NAME = HexToRGB(0x258A6DFF), -- TODO(dbriscoe): We don't use locations yet.
    JOB_NAME      = HexToRGB(0xFFCCCCFF), -- TODO(dbriscoe): We don't use jobs yet.
    QUEST_TITLE   = HexToRGB(0x611D8DFF),

    ITEM_MID =             HexToRGB(0x8D8D8DFF),
    ITEM_DARK =            HexToRGB(0x726E6EFF),

    DISABLED =             HexToRGB(0x726E6EFF),

    HEALTH =               HexToRGB(0xB4F642FF),
    HEALTH_LOW =           HexToRGB(0xF64242FF),
    HEALTH_LOW_BACK =      HexToRGB(0x511414FF),

    GEM =                  HexToRGB(0xC32152FF),

    UPGRADE =              HexToRGB(0x3FCCABFF),
    UPGRADE_DARK =         HexToRGB(0x1CA27BFF),

    BONUS =                HexToRGB(0x93DF55FF),
    PENALTY =              HexToRGB(0xEE5C5CFF),
    BONUS_LIGHT_BG =       HexToRGB(0x40AB38FF),
    PENALTY_LIGHT_BG =     HexToRGB(0xDC4444FF),

	-- Attacks
    DEFENSIVE_BRIGHT =     HexToRGB(0x6495EDFF),
    OFFENSIVE_BRIGHT =     HexToRGB(0xFFC42DFF),
	-- Reduce Sat and Value, dim, and add LIGHT_TEXT_DARK to brownify
    DEFENSIVE_DIM =        HexToRGB(0x707989FF + 0x494040FF - 0x666666FF),
    OFFENSIVE_DIM =        HexToRGB(0x9B8958FF + 0x494040FF - 0x444444FF),

    KONJUR       =         HexToRGB(0xA579E1FF), -- for text that's about konjur
    KONJUR_DARK  =         HexToRGB(0x4A2781FF), -- konjur art color
    KONJUR_LIGHT =         HexToRGB(0xA579E1FF), -- konjur art color

    -- ITEM RARITIES
    COMMON =                HexToRGB(0xBEBEBEFF),
    UNCOMMON =              HexToRGB(0x6DD186FF),
    RARE =                  HexToRGB(0x6CA1C6FF),
    EPIC =                  HexToRGB(0xB470B2FF),
    LEGENDARY =             HexToRGB(0xD1864BFF),
    TITAN =                 HexToRGB(0xE66161FF),
    SET =                   HexToRGB(0x519A60FF),

    DEBUG =                 HexToRGB(0xFF00FFFF),

    -- Colorblind-safe colors for each player slot.
    -- Large text and icons on them can be white (WCAG A).
    -- Smaller text should be black, so it has sufficient contrast (WCAG AAA)
    PLAYER_1 =              HexToRGB(0x6E97EBFF),
    PLAYER_2 =              HexToRGB(0xE3C47AFF),
    PLAYER_3 =              HexToRGB(0x53C5A1FF),
    PLAYER_4 =              HexToRGB(0x7C68DBFF),
    PLAYER_UNKNOWN =        RGB(145.35, 145.35, 145.35), -- grey

    HEALTHBARS_RGB =
    {
        RED = HexToRGB(0xCC3333),
        ORANGE = HexToRGB(0xECC598),
        YELLOW = HexToRGB(0xF5EAC2),
        GREEN = HexToRGB(0xAFEC9D),
        TURQOISE = HexToRGB(0x99D4EB),
        BLUE = HexToRGB(0xDFE4F7),
        PURPLE = HexToRGB(0xD097ED),
        GREY = HexToRGB(0x98AEAC),
        WHITE = HexToRGB(0xF3F3F1),
        PINK = HexToRGB(0xEC98CC),
    },

    HEALTHBARS_HSB =
    {
        RED = HSB(356, 67, 76),
        ORANGE = HSB(32, 69, 76),
        YELLOW = HSB(47, 71, 86),
        GREEN = HSB(106, 67, 77),
        TURQOISE = HSB(197, 67, 76),
        BLUE = HSB(227, 59, 92),
        PURPLE = HSB(280, 70, 76),
        GREY = HSB(174, 12, 64),
        WHITE = HSB(54, 8, 95),
        PINK = HSB(323, 69, 76),
    },
}
-- Strict gives obvious error when you use a nonexistent color (GRAY vs GREY).
strict.strictify(UICOLORS, "UICOLORS", false)

UICOLORS.PLAYERS = {
    [1] = UICOLORS.PLAYER_1,
    [2] = UICOLORS.PLAYER_2,
    [3] = UICOLORS.PLAYER_3,
    [4] = UICOLORS.PLAYER_4,
}

FONTSIZE = {
    -- Sizes we use in many places.
    COMMON_HUD = 44,
    COMMON_OVERLAY = 44,
    BUTTON = 80,

    TOOLTIP = 55,

    SCREEN_TITLE = 80,
    SCREEN_SUBTITLE = 70,
    SCREEN_TEXT = 40,

    SPEECH_NAME = 60,
    SPEECH_TEXT = 70,
    SPEECH_HOTKEYS = 50,

    DIALOG_TITLE = 70,
    DIALOG_SUBTITLE = 60,
    DIALOG_TEXT = 60,

    CONFIRM_DIALOG_TITLE = 90,
    CONFIRM_DIALOG_SUBTITLE = 70,
    CONFIRM_DIALOG_TEXT = 60,

    OVERLAY_TITLE = 140,
    OVERLAY_SUBTITLE = 90,
    OVERLAY_TEXT = 60,

    NOTIFICATION_TITLE = 60,
    NOTIFICATION_TEXT = 40,

    MENU_BUTTON_TITLE = 70,
    MENU_BUTTON_TEXT = 40,

    DAMAGENUM_PLAYER = 70,
    DAMAGENUM_MONSTER = 66,

    ROOMBONUS_SCREEN_TITLE = 94,
    ROOMBONUS_PLAYER = 50,
    ROOMBONUS_SCREEN_SUBTITLE = 84,
    ROOMBONUS_TITLE = 72,
    ROOMBONUS_TEXT = 48,
    ROOMBONUS_STATS = 50,

    INWORLD_POWER_DESCRIPTION = 55,

    DUNGEON_MAP_TITLE = 100,
    PAUSE_SCREEN_LEGEND_TITLE = 80,
    PAUSE_SCREEN_LEGEND_TEXT = 60,

    OPTIONS_SCREEN_TAB = 68,
    OPTIONS_ROW_TITLE = 70,
    OPTIONS_ROW_SUBTITLE = 56,
    KEYBINDING_TITLE = 140,
    KEYBINDING_SUBTITLE = 100,
    KEYBINDING_TEXT = 80,

    CHARACTER_CREATOR_TAB = 60,

}
-- Strict gives obvious error when you use a nonexistent size.
strict.strictify(FONTSIZE, "FONTSIZE", false)


MAX_CHAT_INPUT_LENGTH = 150
MAX_WRITEABLE_LENGTH = 200

--Bit flags, currently supports up to 8
--Server may use these for things that clients need to know about
--other clients whose player entities may or may not be available
--e.g. Stuff that shows on the scoreboard
-- NOTE: Keep this up to date with USERFLAGS::Enum in PlayerListingData.h
USERFLAGS =
{
    IS_GHOST			= 1,
    IS_AFK				= 2,
    CHARACTER_STATE_1	= 4,
    CHARACTER_STATE_2	= 8,
    IS_LOADING			= 16,
    CHARACTER_STATE_3   = 32,
    -- = 64,
    -- = 128,
}

--Camera shake modes
CAMERASHAKE =
{
    FULL = 0,
    SIDE = 1,
    VERTICAL = 2,
}

-- Twitch status codes
TWITCH =
{
    UNDEFINED = -1,
    CHAT_CONNECTED = 0,
    CHAT_DISCONNECTED = 1,
    CHAT_CONNECT_FAILED = 2,
}

-- How does this creature apply stunlock to the player
PLAYERSTUNLOCK =
{
    ALWAYS = nil,--0,
    OFTEN = 1,
    SOMETIMES = 2,
    RARELY = 3,
    NEVER = 4,
}

-- Server pricacy options
PRIVACY_TYPE =
{
    PUBLIC = 0,
    FRIENDS = 1,
    LOCAL = 2,
    CLAN = 3,
}

COMMAND_PERMISSION = {
    ADMIN = "ADMIN", -- only admins see and can activate
    MODERATOR = "MODERATOR", -- only admins and mods can see and activate
    USER = "USER", -- anyone can see and do instantly. Mostly for local commands, or if a mod wants to offer accessible functionality
}

COMMAND_RESULT = {
    ALLOW = "ALLOW",
    DISABLED = "DISABLED", --cannot run it right now (not related to voting)
    VOTE = "VOTE",
    DENY = "DENY", --cannot start vote right now
    INVALID = "INVALID",
}

USER_HISTORY_EXPIRY_TIME = 60*60*24*30 -- 30 days, in seconds

-- needs to be kept synchronized with InventoryProgress enum in InventoryManager.h
INVENTORY_PROGRESS =
{
	IDLE = 0,
}

CURRENT_BETA = 1 -- set to 0 if there is no beta. Note: release builds wont use this so only staging and dev really care
BETA_INFO =
{
    {
		NAME = "ROTBETA",
		SERVERTAG = "return_of_them_beta",
		VERSION_MISMATCH_STRING = "VERSION_MISMATCH_ROTBETA",
		URL = "https://forums.kleientertainment.com/forums/topic/106156-how-to-opt-in-to-return-of-them-beta-for-dont-starve-together/ ",
	},

    {
		NAME = "ANRBETA",
		SERVERTAG = "a_new_reign_beta",
		VERSION_MISMATCH_STRING = "VERSION_MISMATCH_ARNBETA",
		URL = "http://forums.kleientertainment.com/topic/69487-how-to-opt-in-to-a-new-reign-beta-for-dont-starve-together/",
	},

	-- THE GENERIC PUBLIC BETA INFO MUST BE LAST --
	-- This is added to all beta servers as a fallback
	{
		NAME = "PUBLIC_BETA",
		SERVERTAG = "public_beta",
		VERSION_MISMATCH_STRING = "VERSION_MISMATCH_PUBLIC_BETA",
		URL = "http://forums.kleientertainment.com/forum/66-dont-starve-together-general-discussion/",
	},
}
PUBLIC_BETA = #BETA_INFO


TEMP_ITEM_ID = "0"

--matches enum eIAPType
IAP_TYPE_REAL = 0
IAP_TYPE_VIRTUAL = 1

------------------------------------------------- GL -------------------------

RES_X = 3840
RES_Y = 2160 -- 4k

Axis =
{
   None = 0,
   X = 1,
   Y = 2,
   XY = 3,
   All = 3,
}

MARKUP_COLOR  	 = 0
MARKUP_BOLD	 = 2
MARKUP_ITALIC	 = 1
MARKUP_UNDERLINE = 3
MARKUP_LINK	 = 4
MARKUP_IMAGE	 = 6
MARKUP_SHADOW	 = 7
MARKUP_TEXTSIZE = 8

DEVICE_MAP = {
	-- See all platform implementations of PlatformManager::GetGamepadAppearance
	-- and https://github.com/gabomdq/SDL_GameControllerDB
	["nxjoycon"] = "icons_nxpro",
	["nxpro"] = "icons_nxpro",
	["ps4"] = "icons_ps4",
	["ps5"] = "icons_ps5",
	["xbox"] = "icons_xbox360",

	-- If platform doesn't recognize the device, it gives the name from SDL.
	-- See Input:GetGamepadAppearance.

	DEFAULT = "icons_xbox360",
}

global_shaders =
{
	UI = "shaders/ui.ksh",
	UI_NOMIP = "shaders/ui_nomip.ksh",
 	FX = "shaders/particle_new.ksh",
	FX_ERODE = "shaders/particle_new_erosion.ksh",
 	FX_RIM = "shaders/particle_new_rim.ksh",
	FX_ERODE_RIM = "shaders/particle_new_erosion_rim.ksh",
	UI_MASK = "shaders/ui_mask.ksh",
	UI_ANIM = "shaders/ui_anim.ksh",
	UI_ALPHA_MASK = "shaders/ui_alpha_mask.ksh",
	UI_ANIM_MASK = "shaders/ui_anim_mask.ksh",
}

global_images =
{
	circle = "data/images/circle.tex",
}

LEVEL_OF_DETAIL_LOW = 1
LEVEL_OF_DETAIL_HIGH = 4

LightLayer = 
{
	CanopyLight = 0,
 	CanopyShadow = 1,
	WorldLight = 2,
}

STENCIL_MODES =
{
    OFF = 0,
    SET = 1,
    CLEAR = 2,
}

DEFAULT_TT_WIDTH = 365 * HACK_FOR_4K

PropType = 
{
	Grid = 0,
	Decor = 1,
	Lighting = 2,
	Particles = 3
}

ELITE_MOB_SCALE = 1.2

SilhouetteMode =
{
	None = 0,
	Show = 1,
	Have = 2,
}

Sound_PlaybackMode =
{
    Invalid = -1,
    Playing = 0,
    Sustaining = 1,
    Stopped = 2,
    Starting = 3,
    Stopping = 4,
}

TOWN_LEVEL = "town_plots_base"

NORMAL_FRENZY_LEVELS = 3
SUPER_FRENZY_STARTING_LEVEL = 4

-- Equipment.WeaponTag is generated from this
WEAPON_TYPES = {
    ["HAMMER"] = "HAMMER",
    ["POLEARM"] = "POLEARM",
    ["GREATSWORD"] = "CLEAVER",
    ["CANNON"] = "CANNON",
    ["SHOTPUT"] = "SHOTPUT",
    ["PROTOTYPE"] = "HAMMER",                       --MIKERproto: replace with whatever bank you want to test
}

ARMOUR_TYPES = Enum{
    "CLOTH",
    "FUR",
    "GRASS",
    "HIDE",
    "LEATHER",
    "PLATE",
    "SCALES",
    "SQUISHY",
}

ITEM_RARITY = Enum{
    "COMMON",
    "UNCOMMON",
    "RARE",
    "EPIC",
    "LEGENDARY",
    "TITAN",
    "SET",
}

EQUIPMENT_STATS = Enum{
    "HP",
    "DMG",-- the sum of base_damage and bonus_damage, only used for UI
    "ARMOUR",-- % damage reduction based on a formula
    "CRIT",
    "CRIT_MULT",
    "FOCUS_MULT",
    "LUCK",-- is also added to crit chance, but does other things too
    "SPEED",
    "RARITY",
    "WEIGHT",
}

EQUIPMENT_MODIFIER_NAMES = {}
for _, modifier_name in ipairs(EQUIPMENT_STATS:Ordered()) do
	-- RARITY is not numerically modifiable
	if modifier_name ~= EQUIPMENT_STATS.s.RARITY then
		table.insert(EQUIPMENT_MODIFIER_NAMES, modifier_name)
	end
end
strict.strictify(EQUIPMENT_MODIFIER_NAMES)

-- Multipliers default to 1; additives default to 0.
EQUIPMENT_MODIFIER_DEFAULTS = {}
for _, modifier in ipairs(EQUIPMENT_MODIFIER_NAMES) do
	EQUIPMENT_MODIFIER_DEFAULTS[modifier] = 0
end
strict.strictify(EQUIPMENT_MODIFIER_DEFAULTS)

BASE_ARMOUR_VAL = 1500

-- Dungeon run states
RunStates = Enum{
    "ACTIVE",
    "VICTORY",
    "DEFEAT",
    "ABANDON",
}

INGREDIENTS = Enum{
    "CURRENCY",
    "GLOBAL",
    "BIOME",
    "MONSTER",
    "COOKING",
}

FOOD_TYPES = Enum{
    "MEAT",
    "VEG",
}

LOOT_TYPE = Enum{
    "GLOBAL",
    "BIOME",
    "MONSTER",
}

LOOT_TAGS =
{
    GLOBAL = "drops_global",
    BIOME = "drops_biome",
    NORMAL = "drops_normal",
    ELITE = "drops_elite",

    COOKING = "drops_cooking",
    EQUIPMENT = "drops_equipment",

    [FOOD_TYPES.s.MEAT] = "meat", -- must match FOOD_TYPES
    [FOOD_TYPES.s.VEG] = "veg", -- must match FOOD_TYPES
}

POWER_TAGS =
{
    -- Relic Powers
    PROVIDES_ELECTRIC = "pwr_provides_electric",
    PROVIDES_SUMMON = "pwr_provides_summon",
    PROVIDES_SHIELD = "pwr_provides_shield",
    PROVIDES_SHIELD_SEGMENTS = "pwr_provides_shield_segments",
    PROVIDES_SEED = "pwr_provides_seeded",
    SHIELD = "pwr_shield",

    -- Boosts a certain stat
    PROVIDES_CRITCHANCE = "pwr_provides_critchance",
    PROVIDES_FREQUENT_HEALING = "pwr_provides_frequent_healing",
    PROVIDES_HEALING = "pwr_provides_healing",
    PROVIDES_MOVESPEED = "pwr_provides_movespeed",

    -- Makes frequent use of a mechanic
    USES_HITSTREAK = "pwr_uses_hitstreak",

    -- Uses a specific weapon
    POLEARM = "pwr_polearm",
    HAMMER = "pwr_hammer",
    SHOTPUT = "pwr_shotput",
    CANNON = "pwr_cannon",

    -- Has a specific skill
    PARRY = "pwr_parry",
    HAMMER_THUMP = "pwr_hammer_thump",

    -- Power edge cases
    ROLL_BECOMES_ATTACK = "pwr_roll_becomes_attack",


    DO_NOT_DROP = "pwr_do_not_drop", -- Because currently Skills are *all* can_drop = false, so they don't show up in power drops. Add this to skills you don't want to drop in any skill drop.

}

NPC_SPAWN_PRIORITY =
{
    NONE = 0,
    DEFAULT = 10,
    FORCE = 999,
}

UNLOCKABLE_CATEGORIES = Enum{
    "RECIPE",
	"ENEMY",
	"CONSUMABLE",
	"ARMOUR",
	"WEAPON_TYPE",
	"POWER",
    "UNLOCKABLE_COSMETIC",
    "PURCHASABLE_COSMETIC",
	"FLAG",
    "REGION",
    "LOCATION",
    "ASCENSION_LEVEL",
}

CHARACTER_SPECIES = 
{
    CANINE = "canine",
    MER = "mer",
    OGRE = "ogre",
}

DEFAULT_CHARACTERS_SETUP = {
	[1] = {
	    bodyparts = {
	        ARMS = "canine_stripe_arms_1",
	        BROW = "bean_brow_canine_1",
	        EARS = "canine_jackal_ears_1",
	        EYES = "canine_almond_eyes_1",
	        HAIR = "canine_widow_hair_1",
			HAIR_BACK = "canine_hair_back_none",
			HAIR_FRONT = "canine_hair_front_none",
	        HEAD = "canine_head_1",
	        LEGS = "canine_stripe_legs_1",
	        MOUTH = "canine_flat_cat_mouth_1",
	        ORNAMENT = "canine_none_ornament_1",
	        OTHER = "tail_canine_slim_other_1",
	        SHIRT = "bust_tank_shirt_canine_1",
	        SMEAR = "smear_smear_1",
	        TORSO = "torso_canine_torso_1",
	        UNDIES = "plain_undies_canine_1",
	        NOSE = "canine_flat_dainty_nose_1",
	    },
	    colorgroups = {
	        EYE_COLOR = "canine_paleyellow_eye_color_1",
	        HAIR_COLOR = "canine_midnight_hair_color_1",
	        MOUTH_COLOR = "canine_mouth_color_1",
	        NOSE_COLOR = "canine_nose_color_1",
			EAR_COLOR = "canine_ear_color_1",
	        ORNAMENT_COLOR = "ornament_color_1",
	        SHIRT_COLOR = "canine_shirt_color_2",
	        SKIN_TONE = "canine_periwinkle_skin_tone_1",
	        SMEAR_SKIN_COLOR =   "smear_skin_color_1",
	        SMEAR_WEAPON_COLOR = "smear_weapon_color_1",
	        UNDIES_COLOR = "undies_color_2",
	    },
		species = "canine",
	},
	[2] = {
	    bodyparts = {
	        ARMS = "mer_arm_jaguar_arms_1",
	        BROW = "bean_brow_mer_1",
	        EARS = "mer_swimmer_ears_1",
	        EYES = "mer_oval_eyes_1",
	        HAIR = "mer_goldfish_hair_1",
			HAIR_BACK = "mer_goldfish_hair_back",
			HAIR_FRONT = "mer_goldfish_hair_front",
	        HEAD = "mer_head_1",
	        LEGS = "solid_legs_mer_1",
	        MOUTH = "mer_fishlips_mouth_1",
	        NOSE = "mer_flat_nose_1",
	        ORNAMENT = "mer_waves_ornament_1",
	        SHIRT = "flat_none_shirt_mer_1",
	        SMEAR = "smear_smear_1",
	        TORSO = "torso_mer_torso_1",
	        UNDIES = "plain_undies_mer_1",
	    },
	    colorgroups = {
	        EYE_COLOR = "mer_paleblue_eye_color_1",
	        HAIR_COLOR = "mer_raspberry_hair_color_1",
	        MOUTH_COLOR = "mer_mouth_color_1",
	        NOSE_COLOR = "mer_nose_color_1",
			EAR_COLOR = "mer_ear_color_1",
	        ORNAMENT_COLOR = "mer_green_ornament_color_1",
	        SHIRT_COLOR = "mer_shirt_color_1",
	        SKIN_TONE = "mer_turquoise_skin_tone_1",
	        SMEAR_SKIN_COLOR =   "smear_skin_color_1",
	        SMEAR_WEAPON_COLOR = "smear_weapon_color_1",
	        UNDIES_COLOR = "undies_color_1",
	    },

		species = "mer",
	},
	[3] = {
	    bodyparts = {
	        ARMS = "solid_arms_ogre_1",
	        BROW = "bean_brow_ogre_1",
	        EARS = "ogre_bat_ears_1",
	        EYES = "ogre_almond_eyes_1",
	        HAIR = "ogre_manbun_hair_1",
			HAIR_BACK = "ogre_manbun_hair_back",
			HAIR_FRONT = "ogre_hair_front_none",
	        HEAD = "ogre_head_1",
	        LEGS = "solid_legs_ogre_1",
	        MOUTH = "ogre_underbite_fang_mouth_1",
	        NOSE = "ogre_button_nose_1",
	        ORNAMENT = "ogre_horns_ornament_1",
	        SHIRT = "flat_none_shirt_ogre_1",
	        SMEAR = "smear_smear_1",
	        TORSO = "torso_ogre_torso_1",
	        UNDIES = "plain_undies_ogre_1",
	    },
	    colorgroups = {
	        EYE_COLOR = "ogre_paleyellow_eye_color_1",
	        HAIR_COLOR = "ogre_darkbrown_hair_color_1",
	        MOUTH_COLOR = "ogre_mouth_color_1",
	        NOSE_COLOR = "ogre_nose_color_1",
			EAR_COLOR = "ogre_ear_color_1",
	        ORNAMENT_COLOR = "ogre_ornament_color_1",
	        SHIRT_COLOR = "shirt_color_1",
	        SKIN_TONE = "ogre_orange_skin_tone_1",
	        SMEAR_SKIN_COLOR =   "smear_skin_color_1",
	        SMEAR_WEAPON_COLOR = "smear_weapon_color_1",
	        UNDIES_COLOR = "undies_color_1",
	    },

		species = "ogre",
	},
}
