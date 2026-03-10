--[[
	Library/Component: AMAPP
	Copyright (c) 2026 Mount West Music AB
	All rights reserved.

	Description:
	Centralized constants for the AMAPP application.
	Extracted from codebase to improve maintainability and reduce magic numbers.

	Note:
	- Import this file early in initialization
	- All constants are read-only after initialization
	- Update this file when adding new constants

	(c) 2026 Mount West Music AB. All rights reserved.
--]]

local AMAPP_CONSTANTS = {}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

AMAPP_CONSTANTS.COLORS = {
	
	DARK_BG = 0x11191c00,
	ACCENT_RED = 0x921925ff,
	LIGHT_OFF_WHITE = 0xf9f9f9ff,
	DARK_GRAY = 0x333333ff,
	CYAN_ACCENT = 0x0099ccff,
	DARK_TEAL = 0x202f34ff,
	SUCCESS_GREEN = 0x5cb85cff,
	MUTED_TEAL = 0x4c707eff,
	WHITE = 0xffffffff,
	BLACK = 0x000000ff,
	DISABLED_GRAY = 0xa1a1a1ff,
	MEDIUM_GRAY = 0x888888ff,

	
	BUTTON_NORMAL = 0x606060D0,
	BUTTON_HOVERED = 0x909090FF,
	BUTTON_PRESSED = 0x404040FF,

	
	DEFAULT_CLUSTER = 0x888888,

	
	WARNING_ORANGE = 0xFFAA66FF,
	OK_GREEN = 0x66FF66FF,
	ERROR_RED = 0xFF6666FF,

	
	PARENT_HIGHLIGHT = 0x88AAFFFF,

	
	SHADOW_DARK = 0x00000030,
}

AMAPP_CONSTANTS.ALPHA = {
	FULL = 0xFF,        
	HIGH = 0xE0,        
	MEDIUM_HIGH = 0xC0, 
	MEDIUM = 0x90,      
	LOW_MEDIUM = 0x60,  
	LOW = 0x50,         
	VERY_LOW = 0x40,    
	SUBTLE = 0x30,      
	FAINT = 0x20,       
	MINIMAL = 0x10,     
	TRANSPARENT = 0x00, 
}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

AMAPP_CONSTANTS.REAPER_ACTIONS = {
	
	RENUMBER_MARKERS = 40898,  

	
	RENDER_PROJECT = 41824,    

	
	UNSOLO_ALL_ITEMS = 41185,  
	SOLO_ITEMS = 41559,        
	DUPLICATE_TAKE = 40639,    

	
	UNSOLO_ALL_TRACKS = 40340, 
	UNSELECT_ALL_TRACKS = 40297, 
	SELECT_ALL_TRACKS = 40290, 
	SCROLL_TRACKS_INTO_VIEW = 40913, 

	
	SEND_ALL_NOTES_OFF = 40345, 

	
	PROJECT_TABS_FORCE_VISIBLE = 42072, 

	
	SNAP_TOGGLE_STATE = 1157,  
}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

AMAPP_CONSTANTS.REAPER_FLAGS = {
	
	MARKER_COLOR_FLAG = 0x1000000,

	
	TRACK_VIEW_WINDOW_ID = 0x3E8,

	
	PIN_MAPPING_ZERO = 0x0000000,
	PIN_MAPPING_ONE = 0x0000001,
}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

AMAPP_CONSTANTS.AUDIO = {
	
	SAMPLE_RATES = {44100, 48000, 88200, 96000, 176400, 192000},
	DEFAULT_SAMPLE_RATE = 48000,

	
	CHANNELS = {1, 2, 4, 6, 8},
	DEFAULT_CHANNELS = 2,

	
	BIT_DEPTH = {
		PCM_8 = 0,
		PCM_16 = 1,
		PCM_24 = 2,  
		FP_32 = 3,
		FP_64 = 4,
		ADPCM_IMA_4 = 5,
		CADPCM_2 = 6,
		PCM_32 = 7,
		ULAW_8 = 8,
	},
	DEFAULT_BIT_DEPTH = 2, 

	
	BIT_DEPTH_NAMES = {
		[0] = "8-bit PCM",
		[1] = "16-bit PCM",
		[2] = "24-bit PCM",
		[3] = "32-bit FP",
		[4] = "64-bit FP",
		[5] = "4-bit IMA ADPCM",
		[6] = "2-bit cADPCM",
		[7] = "32-bit PCM",
		[8] = "8-bit u-Law",
	},

	
	FLAC_BIT_DEPTHS = {"16-bit", "24-bit"},
	FLAC_DEFAULT_BIT_DEPTH = 1, 
	FLAC_COMPRESSION_MIN = 0,
	FLAC_COMPRESSION_MAX = 8,
	FLAC_COMPRESSION_DEFAULT = 5,

	
	EXT_WAV = ".wav",
	EXT_FLAC = ".flac",
	EXT_JSON = ".json",

	
	RENDER_SOURCE_MASTER = 8,
	RENDER_BOUNDS_CUSTOM = 5,

	
	DEFAULT_TAIL_MS = 1000,
}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

AMAPP_CONSTANTS.TIMING = {
	
	MAX_RENDER_RETRIES = 120,
	MAX_HTTP_RETRIES = 10,

	
	WINDOWS_FILETIME_DIVISOR = 10000000,
	WINDOWS_UNIX_EPOCH_OFFSET = 11644473600,

	
	MS_PER_SECOND = 1000,

	
	ANIMATION_FRAMES = 10,
}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

AMAPP_CONSTANTS.UI = {
	
	LISTBOX_WIDTH = 400,
	LISTBOX_HEIGHT = 150,

	
	BUTTON_WIDTH_PRIMARY = 300,
	BUTTON_WIDTH_SECONDARY = 200,
	BUTTON_WIDTH_CREATE = 150,
	BUTTON_WIDTH_GENERAL = 100,
	BUTTON_WIDTH_SMALL = 70,

	
	MODAL_HEADER_FOOTER_HEIGHT = 110,
	MAX_MAP_WIDTH = 500,

	
	MENU_BAR_HEIGHT = 28,

	
	SCROLLBAR_OFFSET = 16.5,

	
	ROUNDING_FACTOR = 0.25,
	EDGE_LINE_WIDTH = 1,
	EDGE_LINE_THICKNESS = 0.5,

	
	REORDER_ZONE_PERCENT = 0.3,

	
	GOLDEN_RATIO = 0.618,
	CONTENT_HEIGHT_RATIO = 0.79,
}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

AMAPP_CONSTANTS.COLOR_MATH = {
	
	LUMINANCE_R = 0.299,
	LUMINANCE_G = 0.587,
	LUMINANCE_B = 0.114,

	
	MID_GRAY_THRESHOLD = 128,

	
	NEW_SPEED_WEIGHT = 0.7,
	PREVIOUS_SPEED_WEIGHT = 0.3,
}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

AMAPP_CONSTANTS.EXTSTATE = {
	
	NAMESPACE = "AMAPP",

	
	CLUSTER_TABLE = "CLUSTER_TABLE",
	CLUSTER_LIST = "CLUSTER_LIST",
	CLUSTER_ITEMS = "CLUSTER_ITEMS",
	GROUP_TABLE = "GROUP_TABLE",
	CONNECTION_TABLE = "CONNECTION_TABLE",
	GRAPH_META = "GRAPH_META",
	SCHEMA_VERSION = "SCHEMA_VERSION",
	EXPORT_OPTIONS = "EXPORT_OPTIONS",
	DEFAULT_EXPORT_OPTIONS = "DEFAULT_EXPORT_OPTIONS",
	TCP_STATE = "TCP_STATE",

	
	LIB_PATH = "lib_path",
	VERSION = "version",
	LICENSE_ACCEPTED = "license_accepted_date",
	AUTHORIZED_DATE = "authorized_date",
	SESSION = "session",
}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

AMAPP_CONSTANTS.ENDPOINTS = {
	
	API_BASE = "https://mountwestmusic.com/wp-json/amapp/v1",

	
	INIT_TOKENS = "https://mountwestmusic.com/wp-json/amapp/v1/init_tokens",
	VERIFY_MEMBER = "https://mountwestmusic.com/wp-json/amapp/v1/verify_member",
	PATREON_AUTH = "https://mountwestmusic.com/wp-json/amapp/v1/patreon_auth_url",

	
	WEBSITE = "https://mountwestmusic.com/amapp",
	PATREON = "https://www.patreon.com/amapp/Membership",
	DISCORD = "https://discord.gg/xs8AEhx6h2",

	
	W3SCHOOLS = "https://www.w3schools.com",
	WAXML_SCHEMA = "https://momdev.se/lindetorp/waxml/scheme_1.10.xsd",
	IMUSIC_SCHEMA = "https://momdev.se/lindetorp/imusic/scheme_1.1.25.xsd",
}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

AMAPP_CONSTANTS.APP = {
	VERSION = "0.5.0",
	SCHEMA_VERSION = "2.0.0",
	ECS_SCHEMA_VERSION = "ecs-1.0.0",
	REQUIRED_IMGUI_VERSION = "0.9.3.3",

	
	XML_VERSION = "1.0",
	XML_ENCODING = "UTF-8",

	
	DEFAULT_EXPORT_PATH = "AMAPP Exports",
	DEFAULT_EXPORT_FILENAME = "$cluster",
}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

AMAPP_CONSTANTS.GROUP_TYPES = {
	HORIZONTAL = "horizontal",
	VERTICAL = "vertical",
	ONESHOT = "oneshot",
	RANDOM = "random",
	SWITCH = "switch",
}

AMAPP_CONSTANTS.CONNECTION_TYPES = {
	TRANSITION = "transition",
	STINGER = "stinger",
	SWITCH = "switch",
	BLEND = "blend",
	INTERRUPT = "interrupt",
}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


local function make_readonly(t)
	return setmetatable({}, {
		__index = t,
		__newindex = function()
			error("Attempt to modify read-only AMAPP_CONSTANTS", 2)
		end,
		__pairs = function() return pairs(t) end,
		__ipairs = function() return ipairs(t) end,
	})
end


_G.AMAPP_CONSTANTS = AMAPP_CONSTANTS

return AMAPP_CONSTANTS
