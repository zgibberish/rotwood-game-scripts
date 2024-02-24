SPACING =
{
    TITLE_DESC = 4, -- Vertical offset for text right under a title
    TITLE_SUBTITLE = 8, -- Vertical offset for a subtitle right under a screen title
    M05 = 40, -- Large spacing unit. Separating large pieces of content
    M1 = 20, -- Standard spacing unit. Padding inside list items, margin around most items, content under screen title
}

FONT_SIZE =
{
    SCREEN_TITLE = 56, -- Main title of a screen, title font, all caps
    SCREEN_SUBTITLE = 46, -- Main descriptor of a screen, title font, not caps
    SCREEN_TABS = 32, -- Navigation tab's text, title font

    ITEM_LABEL = 28, -- Small all-caps label above an item/element/option, title font
    ITEM_NAME = 44, -- Selectable item/location/agent's name on screen, title font
    ITEM_SUBTITLE = 32, -- Descriptor/type/category/rarity for an item, title font. Also list-item title, if it has no subtitle
    ITEM_DESC = 28, -- Info text about an item, body font. List-item text
    
    BUTTON = 26, -- Icon/panel buttons
    SMALL_TEXT = 24, -- Small block of text, body font. For labels, small buttons, counters
    BODY_TEXT = 28, -- Regular block of text, body font
}

SCREEN_MODE = MakeEnum{ "MONITOR", "SMALL", "TV" }
SCREEN_MODE_INDEX = {
    [1] = SCREEN_MODE.MONITOR,
    [2] = SCREEN_MODE.TV,
    [3] = SCREEN_MODE.SMALL
}
LAYOUT_SCALE =
{
    [SCREEN_MODE.MONITOR] = 1,
    [SCREEN_MODE.TV] = 1.3,
    [SCREEN_MODE.SMALL] = 1.4,
}
