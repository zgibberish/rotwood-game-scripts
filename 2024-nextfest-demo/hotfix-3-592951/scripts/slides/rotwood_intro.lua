return 
{
    -- Intro slideshow
    
    music = "Music/Menus/mus_Slideshow_Sectioned_LP",
    --page_turn_sound = "FX/power_acquire",
    --slideshow_end_sound = "FX/power_acquire",
    text_fontsize = 85,
    text_speed = 25,                                    -- speed the text will spool in at (chars/sec)
    text_color = UICOLORS.LIGHT_TEXT,                      -- text color, either a table or a hex value
    background = HexToRGB(0x000000FF),                              -- background, either path to an image, or a color (table or hex value)
    slide_button = "images/slideshow/movie_pip.tex",           -- button to select slides
    movie_frame_color = UICOLORS.LIGHT_TEXT_DARK,                               -- color of the framing above and below video
    movie_frame_thickness = 2,								-- thickness of the movie frame
    animate_pip_size = true,								-- animate the slide indicator pips based on text progress
    show_pips = false,
    can_advance = true,
    can_rewind = false,
    pip_offset = -17,										-- vertical positioning of the slide indicator pips

    can_cancel = false,										-- can the player cancel out of this slideshow?

    script = {
   -- SLIDE 1
        {
            no_loop = true,                     -- don't loop the video
            advance_when_done = true,           -- Advance when the video ends
            --timeout = 1,                      -- Advance after this amount of seconds
            mov = 'movies/scene_01.ogv',
            --vo = "FX/power_acquire",
            amb = "Level/SlideShow/1_slideshow_LP",
            --img = 'images/9slice/grafts_slot_unique.tex',
            text_speed = 25,                    -- speed the text will spool in at (chars/sec)
            music_section = 1,
            text_start_delay = 0.4,
            --timeout_after_spool = 2,			-- when set the slide will advance x seconds after text spool finished

            txt = STRINGS.UI.SLIDESHOW_SCREEN.CAPTION_1
        },

    -- SLIDE 2 

        {
            no_loop = true,
            advance_when_done = true,   
            mov = 'movies/scene_02.ogv',
            --vo = "FX/power_acquire",
            amb = "Level/SlideShow/2_slideshow_LP",
            --img = 'story/sal_act4_slide_02.tex',
            text_speed = 30,                    -- speed the text will spool in at (chars/sec)
            music_section = 1,
            text_start_delay = 3.4, -- After the "POOF"

            txt = STRINGS.UI.SLIDESHOW_SCREEN.CAPTION_2
        },

-- SLIDE 3

        {
            no_loop = true,
            advance_when_done = true,   
            mov = 'movies/scene_03.ogv',
            --vo = "FX/power_acquire",
            amb = "Level/SlideShow/3_slideshow_LP",
            --img = 'story/sal_act4_slide_03.tex',
            text_speed = 25,                    -- speed the text will spool in at (chars/sec)
            music_section = 2,
            text_start_delay = 0.4,

            txt = STRINGS.UI.SLIDESHOW_SCREEN.CAPTION_3
        },

-- SLIDE 4

        {
            no_loop = true,
            advance_when_done = true,   
            mov = 'movies/scene_04.ogv',
            --vo = "FX/power_acquire",
            amb = "Level/SlideShow/4_slideshow_LP",
            --img = 'story/sal_act4_slide_04.tex',
            text_speed = 30,                    -- speed the text will spool in at (chars/sec)
            music_section = 3,

            txt = [[
            ]],
        },

-- SLIDE 5

        {
            no_loop = true,
            advance_when_done = true,   
            mov = 'movies/scene_05.ogv',
            --vo = "FX/power_acquire",
            amb = "Level/SlideShow/5_slideshow_LP",
            --img = 'story/sal_act4_slide_04.tex',
            text_speed = 25,                    -- speed the text will spool in at (chars/sec)
            music_section = 4,

            txt = [[
            ]],
        },

-- SLIDE 6

        {
            no_loop = true,
            advance_when_done = true,   
            mov = 'movies/scene_06.ogv',
            --vo = "FX/power_acquire",
            amb = "Level/SlideShow/6_slideshow_LP",
            --img = 'story/sal_act4_slide_04.tex',
            text_speed = 25,                    -- speed the text will spool in at (chars/sec)
            music_section = 4,
            text_start_delay = 0.2,

-- Spaces before line intentional for timing, please don't remove.
            txt = STRINGS.UI.SLIDESHOW_SCREEN.CAPTION_4
        },

-- SLIDE 7

        {
            no_loop = true,
            advance_when_done = true,   
            mov = 'movies/scene_07.ogv',
            --vo = "FX/power_acquire",
            amb = "Level/SlideShow/7_slideshow_LP",
            --img = 'story/sal_act4_slide_04.tex',
            text_speed = 25,                    -- speed the text will spool in at (chars/sec)
            music_section = 5,
            text_start_delay = 0.3,

-- Spaces before line intentional for timing, please don't remove.
            txt = STRINGS.UI.SLIDESHOW_SCREEN.CAPTION_5
        },

-- SLIDE 8

        {
            no_loop = true,
            advance_when_done = true,   
            mov = 'movies/scene_08.ogv',
            --vo = "FX/power_acquire",
            amb = "Level/SlideShow/8_slideshow_LP",
            --img = 'story/sal_act4_slide_04.tex',
            text_speed = 40,                    -- speed the text will spool in at (chars/sec)
            music_section = 6,
            text_start_delay = 0.2,

-- Spaces before line intentional for timing, please don't remove.
            txt = STRINGS.UI.SLIDESHOW_SCREEN.CAPTION_6
        },

-- SLIDE 9

        {
            no_loop = true,
            advance_when_done = true,   
            mov = 'movies/scene_09.ogv',
            --vo = "FX/power_acquire",
            amb = "Level/SlideShow/9_slideshow_LP",
            --img = 'story/sal_act4_slide_04.tex',
            text_speed = 15,                    -- speed the text will spool in at (chars/sec)
            music_section = 7,
            text_start_delay = 0.3,

            txt = STRINGS.UI.SLIDESHOW_SCREEN.CAPTION_7
        },

-- SLIDE 10

        {
            no_loop = true,
            advance_when_done = true,   
            mov = 'movies/scene_10.ogv',
            --vo = "FX/power_acquire",
            amb = "Level/SlideShow/10_slideshow_LP",
            --img = 'story/sal_act4_slide_04.tex',
            text_speed = 25,                    -- speed the text will spool in at (chars/sec)
            music_section = 8,

            txt = [[
            ]],
        },
    }
}    

