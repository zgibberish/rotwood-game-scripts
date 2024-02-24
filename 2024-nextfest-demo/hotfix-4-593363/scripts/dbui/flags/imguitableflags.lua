-- Generated by tools/imgui_upgrader/build_enums.lua

local ImGuiTableFlags_None                       = 0
local ImGuiTableFlags_Resizable                  = 1         -- 1 << 0
local ImGuiTableFlags_Reorderable                = 2         -- 1 << 1
local ImGuiTableFlags_Hideable                   = 4         -- 1 << 2
local ImGuiTableFlags_Sortable                   = 8         -- 1 << 3
local ImGuiTableFlags_NoSavedSettings            = 16        -- 1 << 4
local ImGuiTableFlags_ContextMenuInBody          = 32        -- 1 << 5
local ImGuiTableFlags_RowBg                      = 64        -- 1 << 6
local ImGuiTableFlags_BordersInnerH              = 128       -- 1 << 7
local ImGuiTableFlags_BordersOuterH              = 256       -- 1 << 8
local ImGuiTableFlags_BordersH                   = 384       -- ImGuiTableFlags_BordersInnerH | ImGuiTableFlags_BordersOuterH
local ImGuiTableFlags_BordersInnerV              = 512       -- 1 << 9
local ImGuiTableFlags_BordersInner               = 640       -- ImGuiTableFlags_BordersInnerV | ImGuiTableFlags_BordersInnerH
local ImGuiTableFlags_BordersOuterV              = 1024      -- 1 << 10
local ImGuiTableFlags_BordersOuter               = 1280      -- ImGuiTableFlags_BordersOuterV | ImGuiTableFlags_BordersOuterH
local ImGuiTableFlags_BordersV                   = 1536      -- ImGuiTableFlags_BordersInnerV | ImGuiTableFlags_BordersOuterV
local ImGuiTableFlags_Borders                    = 1920      -- ImGuiTableFlags_BordersInner | ImGuiTableFlags_BordersOuter
local ImGuiTableFlags_NoBordersInBody            = 2048      -- 1 << 11
local ImGuiTableFlags_NoBordersInBodyUntilResize = 4096      -- 1 << 12
local ImGuiTableFlags_SizingFixedFit             = 8192      -- 1 << 13
local ImGuiTableFlags_SizingFixedSame            = 16384     -- 2 << 13
local ImGuiTableFlags_SizingStretchProp          = 24576     -- 3 << 13
local ImGuiTableFlags_SizingStretchSame          = 32768     -- 4 << 13
local ImGuiTableFlags_NoHostExtendX              = 65536     -- 1 << 16
local ImGuiTableFlags_NoHostExtendY              = 131072    -- 1 << 17
local ImGuiTableFlags_NoKeepColumnsVisible       = 262144    -- 1 << 18
local ImGuiTableFlags_PreciseWidths              = 524288    -- 1 << 19
local ImGuiTableFlags_NoClip                     = 1048576   -- 1 << 20
local ImGuiTableFlags_PadOuterX                  = 2097152   -- 1 << 21
local ImGuiTableFlags_NoPadOuterX                = 4194304   -- 1 << 22
local ImGuiTableFlags_NoPadInnerX                = 8388608   -- 1 << 23
local ImGuiTableFlags_ScrollX                    = 16777216  -- 1 << 24
local ImGuiTableFlags_ScrollY                    = 33554432  -- 1 << 25
local ImGuiTableFlags_SortMulti                  = 67108864  -- 1 << 26
local ImGuiTableFlags_SortTristate               = 134217728 -- 1 << 27

imgui.TableFlags = {
	None                       = ImGuiTableFlags_None,
	Resizable                  = ImGuiTableFlags_Resizable,                  -- Enable resizing columns.
	Reorderable                = ImGuiTableFlags_Reorderable,                -- Enable reordering columns in header row (need calling TableSetupColumn() + TableHeadersRow() to display headers)
	Hideable                   = ImGuiTableFlags_Hideable,                   -- Enable hiding/disabling columns in context menu.
	Sortable                   = ImGuiTableFlags_Sortable,                   -- Enable sorting. Call TableGetSortSpecs() to obtain sort specs. Also see ImGuiTableFlags_SortMulti and ImGuiTableFlags_SortTristate.
	NoSavedSettings            = ImGuiTableFlags_NoSavedSettings,            -- Disable persisting columns order, width and sort settings in the .ini file.
	ContextMenuInBody          = ImGuiTableFlags_ContextMenuInBody,          -- Right-click on columns body/contents will display table context menu. By default it is available in TableHeadersRow().
	RowBg                      = ImGuiTableFlags_RowBg,                      -- Set each RowBg color with ImGuiCol_TableRowBg or ImGuiCol_TableRowBgAlt (equivalent of calling TableSetBgColor with ImGuiTableBgFlags_RowBg0 on each row manually)
	BordersInnerH              = ImGuiTableFlags_BordersInnerH,              -- Draw horizontal borders between rows.
	BordersOuterH              = ImGuiTableFlags_BordersOuterH,              -- Draw horizontal borders at the top and bottom.
	BordersH                   = ImGuiTableFlags_BordersH,                   -- Draw horizontal borders.
	BordersInnerV              = ImGuiTableFlags_BordersInnerV,              -- Draw vertical borders between columns.
	BordersInner               = ImGuiTableFlags_BordersInner,               -- Draw inner borders.
	BordersOuterV              = ImGuiTableFlags_BordersOuterV,              -- Draw vertical borders on the left and right sides.
	BordersOuter               = ImGuiTableFlags_BordersOuter,               -- Draw outer borders.
	BordersV                   = ImGuiTableFlags_BordersV,                   -- Draw vertical borders.
	Borders                    = ImGuiTableFlags_Borders,                    -- Draw all borders.
	NoBordersInBody            = ImGuiTableFlags_NoBordersInBody,            -- [ALPHA] Disable vertical borders in columns Body (borders will always appear in Headers). -> May move to style
	NoBordersInBodyUntilResize = ImGuiTableFlags_NoBordersInBodyUntilResize, -- [ALPHA] Disable vertical borders in columns Body until hovered for resize (borders will always appear in Headers). -> May move to style
	SizingFixedFit             = ImGuiTableFlags_SizingFixedFit,             -- Columns default to _WidthFixed or _WidthAuto (if resizable or not resizable), matching contents width.
	SizingFixedSame            = ImGuiTableFlags_SizingFixedSame,            -- Columns default to _WidthFixed or _WidthAuto (if resizable or not resizable), matching the maximum contents width of all columns. Implicitly enable ImGuiTableFlags_NoKeepColumnsVisible.
	SizingStretchProp          = ImGuiTableFlags_SizingStretchProp,          -- Columns default to _WidthStretch with default weights proportional to each columns contents widths.
	SizingStretchSame          = ImGuiTableFlags_SizingStretchSame,          -- Columns default to _WidthStretch with default weights all equal, unless overridden by TableSetupColumn().
	NoHostExtendX              = ImGuiTableFlags_NoHostExtendX,              -- Make outer width auto-fit to columns, overriding outer_size.x value. Only available when ScrollX/ScrollY are disabled and Stretch columns are not used.
	NoHostExtendY              = ImGuiTableFlags_NoHostExtendY,              -- Make outer height stop exactly at outer_size.y (prevent auto-extending table past the limit). Only available when ScrollX/ScrollY are disabled. Data below the limit will be clipped and not visible.
	NoKeepColumnsVisible       = ImGuiTableFlags_NoKeepColumnsVisible,       -- Disable keeping column always minimally visible when ScrollX is off and table gets too small. Not recommended if columns are resizable.
	PreciseWidths              = ImGuiTableFlags_PreciseWidths,              -- Disable distributing remainder width to stretched columns (width allocation on a 100-wide table with 3 columns: Without this flag: 33,33,34. With this flag: 33,33,33). With larger number of columns, resizing will appear to be less smooth.
	NoClip                     = ImGuiTableFlags_NoClip,                     -- Disable clipping rectangle for every individual columns (reduce draw command count, items will be able to overflow into other columns). Generally incompatible with TableSetupScrollFreeze().
	PadOuterX                  = ImGuiTableFlags_PadOuterX,                  -- Default if BordersOuterV is on. Enable outermost padding. Generally desirable if you have headers.
	NoPadOuterX                = ImGuiTableFlags_NoPadOuterX,                -- Default if BordersOuterV is off. Disable outermost padding.
	NoPadInnerX                = ImGuiTableFlags_NoPadInnerX,                -- Disable inner padding between columns (double inner padding if BordersOuterV is on, single inner padding if BordersOuterV is off).
	ScrollX                    = ImGuiTableFlags_ScrollX,                    -- Enable horizontal scrolling. Require 'outer_size' parameter of BeginTable() to specify the container size. Changes default sizing policy. Because this creates a child window, ScrollY is currently generally recommended when using ScrollX.
	ScrollY                    = ImGuiTableFlags_ScrollY,                    -- Enable vertical scrolling. Require 'outer_size' parameter of BeginTable() to specify the container size.
	SortMulti                  = ImGuiTableFlags_SortMulti,                  -- Hold shift when clicking headers to sort on multiple column. TableGetSortSpecs() may return specs where (SpecsCount > 1).
	SortTristate               = ImGuiTableFlags_SortTristate,               -- Allow no sorting, disable default sorting. TableGetSortSpecs() may return specs where (SpecsCount == 0).
}
