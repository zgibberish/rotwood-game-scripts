--require "widgets/screen"
--require "widgets/label"
--require "widgets/image"
--require "widgets/movieplayer"
--require "widgets/panelbutton"
--require "widgets/solidbox"

local Widget = require "widgets.widget"
local Screen = require "widgets.screen"
local Text = require "widgets.text"
local Image = require "widgets.image"
local SolidBox = require "widgets.solidbox"
local MoviePlayer = require "widgets.movieplayer"
local Clickable = require "widgets.clickable"
local fmodtable = require "defs.sound.fmodtable"

local easing = require "util.easing"

local audioid = require "defs.sound.audioid"

---------------------------------------------------------------------------------
-- Plays a slideshow of movies and still frames.

local FADE_HOLD = .5 -- Time to hold at black before fading into the next slide.
local FADE_DURATION = .5 -- Time to fade to or from black (therefore, full duration is 2*FADE_DURATION + FADE_HOLD)
local MAX_SLIDES = 16 -- How many MoviePlayers to preallocate.
local BLEND_THRESHOLD = 0.5

local assets = 
{
	pip = "images/slideshow/movie_pip.tex",
}

local SlideshowScreen = Class(Screen, function( self, content_id, ondone, flags)
    Screen._ctor(self, "SlideshowScreen")
	assert(content_id)
    self:SetAudioEnterOverride(nil)
    self:SetAudioExitOverride(nil)

	--TODO_KAJ    AUDIO:FinalizeVoiceLoad()

    local data = require ("slides."..content_id)
    self.content = data

    flags = flags or table.empty
    self.script = {}
    for k,v in ipairs(data.script) do
        if v.flag == nil or
            (type(v.flag) == "string" and flags[v.flag]) or
            (type(v.flag) == "function" and v.flag( flags )) then

            local slide = shallowcopy(v)
			--TODO_KAJ            slide.txt = self.content:GetLocalizedTxt( k )
            slide.txt = v.txt
            table.insert(self.script, slide)
        end
    end

    self.music_name = data.music
    self.tutorial_mode = data.is_tutorial
    self.text_speed = data.text_speed
    self.text_start_delay = data.text_start_delay -- How long to wait before starting to spool out.
    self.ondone = ondone
    self.auto_advance = true
    self.page_turn_sound = data.page_turn_sound
    self.slideshow_end_sound = data.slideshow_end_sound
    self.slide_button = data.slide_button
    self.movie_frame_thickness = data.movie_frame_thickness or 3
    self.animate_pip_size = data.animate_pip_size
    self.show_pips = data.show_pips
	self.pip_offset = data.pip_offset
    self.can_advance = data.can_advance
    self.can_rewind = data.can_rewind
    self.can_cancel = data.can_cancel

	local fontsize = data.text_fontsize

    if self.tutorial_mode then
		--TODO_KAJ        self.screen_mix_event = "event:/mix_events/TutorialMusicDown"
    end

    self:SetAnchors( "center", "center" )

    -- Get a standard slideshow image to calculate the proper size for the movie
    local defaultimage = "images/white.tex"
    
    self.lastimg = defaultimage

    local MOVIE_ASPECT = 3840/1300
    self.movie_width = 3840
    self.movie_height = 3840 / MOVIE_ASPECT

    local panel_padding = 60
    self.text_width = RES_X*.6

	if data.background then
		if type(data.background) == "string" then
			self.underlay = Image( data.background )
		else
			self.underlay = SolidBox( 1, 1, data.background )
		end
		self.underlay:SetAnchors( "fill", "fill" )
		self:AddChild( self.underlay )
	end

    self.next = Text("body", 48):SetAnchors("right", "bottom"):SetPos(-200, 60):Hide()
    -- Click-to-skip widget
--[[
    self.next = Widget()
    self.next.bg = self.next:AddChild( Image( "images/large/conversation_banner.tex")):SetHiddenBoundingBox( true )
        :Bloom( 0.05 )
        :SetSize( 650, 250 )
    self.next.text = self.next:AddChild( Text() )
	:SetText( string.format(STRINGS.UI.SLIDESHOW_SCREEN.SKIP, Controls.Digital.SKIP)) 
        :SetFont("title")
        :SetFontSize( FONT_SIZE.SCREEN_SUBTITLE )
        :SetGlyphColor(UICOLORS.SUBTITLE)
        :SetPos( 0, 1 )
    self.next:Hide()
]]
    self.body_text = Text( FONTFACE.DEFAULT, fontsize )
        :SetAutoSize(self.text_width)
        :SetWordWrap(true)
        :SetGlyphColor(data.text_color or 0xcbffefff)
        :LeftAlign()
        :TopAlign()
--TODO_KAJ        :SetBloom(.05)
    self.progress_root = Widget()

    self.movie_root = Widget()
    self.panel_bg = self.movie_root:AddChild( SolidBox( self.movie_width, self.movie_height, 0x00000000 ) )

    self.framing_elements = Widget()
    self.panel_glow_top = self.framing_elements:AddChild( Image( "images/glow.tex" ) )
        :SetHiddenBoundingBox( true )
        :SetMultColor( UICOLORS.LIGHT_TEXT_DARK )
        :SetMultColorAlpha( 0.3 )
    self.panel_glow_bottom = self.framing_elements:AddChild( Image( "images/glow.tex"  ) )
        :SetHiddenBoundingBox( true )
        :SetMultColor( UICOLORS.LIGHT_TEXT_DARK )
        :SetMultColorAlpha( 0.2 )

    self.panel_border_top = self.framing_elements:AddChild( SolidBox( RES_X, 6, data.movie_frame_color or 0xffffffff) )
        :SetMultColor( UICOLORS.SUBTITLE )
        :Bloom( 0.1 )
    self.panel_border_bottom = self.framing_elements:AddChild( SolidBox( RES_X, 3, data.movie_frame_color or 0xffffffff ) )
        :SetMultColor( UICOLORS.SUBTITLE )
        :Bloom( 0.1 )

    self.image_widget = self.movie_root:AddChild(Image( defaultimage ))
    self.image_widget:SetSize( self.movie_width, self.movie_height )

    self.movie_widgets = {}
    for i=1, MAX_SLIDES do
        local movie_widget = self.movie_root:AddChild( MoviePlayer( nil, self.movie_width, self.movie_height ))
        movie_widget:SetBlendTexture("images/inkbleed.tex")
        movie_widget:Hide()
        table.insert(self.movie_widgets, movie_widget)
    end

    self.text_bg = Image( "images/slideshow/teammember_gradient.tex"  )

    self:AddChildren{
        self.framing_elements,
        self.movie_root,
        self.text_bg,
        self.body_text,
        self.progress_root,
        self.next,
    }

    self.progress_pips = {}

    for k = 1, #self.script do
        local w = Clickable()
        w.hitbox = w:AddChild( SolidBox( 110, 80, 0xff00ff00 ) )
        w.back = w:AddChild( Image(data.slide_button or assets.pip) )
            :SetMultColorAlpha(0.1)
        w.img = w:AddChild( Image(data.slide_button or assets.pip) )
        w:SetHighlightWidget(w.img)
        w:Bloom(.1)
        w:SetOnClickFn( function()
            self:ChangeSlide( k )
        end )
        w:SetScale(2,2)
        table.insert(self.progress_pips, w)
        self.progress_root:AddChild(w)
        w:LayoutBounds("after", "center"):Offset(0, 0)
		w.animate_scales = false

		w:SetOnHighlight( function(down, hover, selected, focus )
							if w ~= self.progress_pips[self.step] then
								if hover then
						            self.progress_pips[k]:SetMultColorAlpha(0.5)
								else
						            self.progress_pips[k]:SetMultColorAlpha(0.3)
								end
							end
						end)
		-- dedicated control, because we don't want the joypad to do this (it snaps), but we do want to be able to click buttons with mouse
		w:SetControl(Controls.Digital.SLIDESHOW_SELECT)	
    end
   

--[[
    for i=1,#self.progress_pips do
		local pip1 = self.progress_pips[i-1]
		local pip2 = self.progress_pips[i]
		if pip1 and pip2 then
			pip1:SetFocusChangeDir(MOVE_RIGHT, nil)
			pip2:SetFocusChangeDir(MOVE_LEFT, nil)
		end
	end
]]
    self:DoLayout()

	self.default_focus = self.progress_pips[1]

    self:StartMusic()
	-- TODO(luca): Replace StartFMODSnapshot+StopFMODSnapshot with override that's an event.
    TheAudio:StartFMODSnapshot(fmodtable.Snapshot.Slideshow)
end)


SlideshowScreen.CONTROL_MAP = 
{
    {
        control = Controls.Digital.CANCEL,
        test = function(self)
            return self.can_cancel
        end,
        fn = function(self) 
            self:Finish()
        end,
        hint = function(self, left, right) 
            table.insert( right, loc.format( self.step < #self.script and LOC"UI.CONTROLS.NEXT_SLIDE" or LOC"UI.CONTROLS.DONE_SLIDES", Controls.Digital.CANCEL))
        end,
    },
    {
        control = Controls.Digital.MENU_ACCEPT,
        test = function(self)
            return self.can_advance
        end,
        fn = function(self)
            self:Snap()
        end,
        hint = function(self, left, right) 
            if self.can_advance then
                table.insert( right, loc.format( self.step < #self.script and LOC"UI.CONTROLS.NEXT_SLIDE" or LOC"UI.CONTROLS.DONE_SLIDES", Controls.Digital.MENU_ACCEPT))
            end
        end,
    },
    {
        control = Controls.Digital.SLIDESHOW_REWIND,
        test = function(self)
            return self.step > 1
        end,
        fn = function(self) 
            self:Rewind()
        end,
        
        hint = function(self, left, right) 
            table.insert( left, loc.format( LOC"UI.CONTROLS.REWIND", Controls.Digital.REWIND))
        end,
    },
    {
        control = Controls.Digital.SLIDESHOW_FORWARD,
        test = function(self)
            return self.step < #self.script
        end,
        fn = function(self) 
            self:Advance()
        end,
        
        hint = function(self, left, right) 
            table.insert( left, loc.format( LOC"UI.CONTROLS.REWIND", Controls.Digital.SLIDESHOW_FORWARD))
        end,
    },
    {
        control = Controls.Digital.MENU_SCREEN_ADVANCE,
        test = function(self)
            return true	-- can even click out of last slide
        end,
        fn = function(self) 
            self:Advance()
        end,
        
        hint = function(self, left, right) 
            table.insert( left, loc.format( LOC"UI.CONTROLS.REWIND", Controls.Digital.SLIDESHOW_FORWARD))
        end,
    },
    {
        control = Controls.Digital.MENU_ONCE_LEFT,
        test = function(self)
            return self.step > 1 and self.can_rewind
        end,
        fn = function(self) 
            self:Rewind()
        end,
        
        hint = function(self, left, right) 
            table.insert( left, loc.format( LOC"UI.CONTROLS.REWIND", Controls.Digital.MENU_ONCE_LEFT))
        end,
    },
    {
        control = Controls.Digital.MENU_ONCE_RIGHT,
        test = function(self)
            return self.step < #self.script and self.can_advance
        end,
        fn = function(self) 
            self:Advance()
        end,
        
        hint = function(self, left, right) 
            table.insert( left, loc.format( LOC"UI.CONTROLS.REWIND", Controls.Digital.MENU_ONCE_RIGHT))
        end,
    },
--[[
    {
        control = Controls.Digital.SKIP,
        
        fn = function(self) 
            if self.showing_quit then
                self:Finish()
            else
                self.showing_quit = true
                if self.vo_sound then
                    self.vo_sound:SetPaused( true )
                end
                self.next:Show():SetTintAlpha(1.0)
            end
           return true
        end,
        
        hint = function(self, left, right) 
            if self.step < #self.script then
                table.insert( right, loc.format( LOC"UI.CONTROLS.SKIP_SLIDES", Controls.Digital.SKIP))
            end
        end,
    }
]]
}

function SlideshowScreen:StartMusic()
	if self.music_name then
		if TheWorld then
			TheLog.ch.Audio:print("***///***slideshowscreen.lua: Stopping level music.")
			TheWorld.components.ambientaudio:StopWorldMusic()
		else
			-- stop the menu sound
			self.menu_audio = TheAudio:GetPersistentSound(audioid.persistent.ui_music)
			TheAudio:StopPersistentSound(audioid.persistent.ui_music)        
		end
		TheAudio:PlayPersistentSound(audioid.persistent.slideshow_music, self.music_name)
	end
end

function SlideshowScreen:SetMusicSlideParameter(slide)
    if self.music_name then
        local skip_param = self.skip_requested and 1 or 0
        TheAudio:SetPersistentSoundParameter(audioid.persistent.slideshow_music, "Music_SlideShow_SkipRequested", skip_param) -- tell the FMOD event that a skip was requested.
        TheAudio:SetPersistentSoundParameter(audioid.persistent.slideshow_music, "Music_SlideShow_Section", slide)
    end
end

function SlideshowScreen:StopWorldMusic()
	if self.music_name then
		TheAudio:StopPersistentSound(audioid.persistent.slideshow_music)        
		if TheWorld then
			TheWorld.components.ambientaudio:StartMusic()
		else
			TheAudio:PlayPersistentSound(audioid.persistent.ui_music, self.menu_audio)        
		end
	end
end

function SlideshowScreen:SetAutoAdvance( auto )
    self.auto_advance = auto
    return self
end

function SlideshowScreen:OnUpdate(dt)
    
    SlideshowScreen._base.OnUpdate(self, dt)

    if self.slide_elapsed_time then
        self.slide_elapsed_time = self.slide_elapsed_time + dt
    end

    if self.ignore_input_time then
        self.ignore_input_time = self.ignore_input_time - dt
        if self.ignore_input_time <= 0 then
            self.ignore_input_time = nil
        end
    end


    if self.vo_sound then
        if TheAudio:GetPersistentSoundPlaybackState("slideshow_voiceover") == Sound_PlaybackMode.Stopped then
            if self.auto_advance then self.auto_advance_timer = 1 end
			TheAudio:StopPersistentSound("slideshow_voiceover")
            self.vo_sound = nil
        end
    end

    if self.auto_advance_timer then
        self.auto_advance_timer = self.auto_advance_timer - dt
        if self.auto_advance_timer <= 0 then -- and self.step < #self.script then
            self.auto_advance_timer = nil
            self.slide_elapsed_time = 0
            self:Advance()
        end
    end

    if self.script[self.step].advance_when_done then
        if self.movie_widgets[self.step]:IsDone() then
            self:Advance()
        end
    end

    if self.timeout then
        self.timeout = self.timeout - dt
        if self.timeout <= 0 then
            self:Advance()
        end
    end

    if self.script[self.step].timeout_after_spool then
		local spool = self.body_text:GetSpool()
		print("spool = ",spool)
		if spool == 1 then
			self.timeout = self.timeout or self.script[self.step].timeout_after_spool
		end
    end

	if self.animate_pip_size then
		for i,v in pairs(self.progress_pips) do
			v.img:SetScissor(nil)
		end
		local curpip = self.progress_pips[self.step]
		local spool = self.body_text:GetSpool()
		local w, h = curpip:GetSize()
		curpip.img:SetScissor(-w/2, -h/2, w * spool, h)
	end

--TODO_KAJ    if TheGame:GetLocalSettings().ROBOTICS then
--TODO_KAJ        self:Advance()
--TODO_KAJ    end

end

function SlideshowScreen:DoLayout()
    
    local sw, sh = self.panel_bg:GetSize()
    
    local base_scale = TheFrontEnd:GetBaseWidgetScale()
    local screen_ratio = sw/sh
    local normal_ratio = 16/9
    local wide_ratio = 21/9
    local tall_ratio = 4/3

    local scale
    
    if screen_ratio > normal_ratio then
        scale = math.min( sw/sh, wide_ratio) / wide_ratio
    elseif screen_ratio < normal_ratio then
        scale = tall_ratio/normal_ratio
    else
        scale = normal_ratio/wide_ratio
    end

    self.panel_bg:SetScale( scale, scale )
    self.image_widget:LayoutBounds("center", "center", self.panel_bg):SetScale(scale, scale)
    for k, v in ipairs(self.movie_widgets) do
        v:LayoutBounds("center", "center", self.panel_bg):SetScale(scale, scale)
    end

    -- Size up the framing elements
    local screen_w, screen_h = TheFrontEnd:GetScreenDims()
    self.screen_w = math.ceil( screen_w / TheFrontEnd:GetBaseWidgetScale() )
    self.panel_glow_top:SetSize( self.screen_w*1.3, 300 )
    self.panel_glow_bottom:SetSize( self.screen_w*0.9, 300 )
    self.panel_border_top:SetSize( self.screen_w, self.movie_frame_thickness )
    self.panel_border_bottom:SetSize( self.screen_w, self.movie_frame_thickness )
    
    self.text_bg:Hide()

    --special layouts for different aspect ratios
--    if false and (scale*self.movie_height*base_scale) > (sh - 300) then
--        self.movie_root:LayoutBounds("center", "center", 0, 0)
--        self.body_text:SetFontSize( FONT_SIZE.BODY_TEXT )
--        self.body_text:LayoutBounds("center", "bottom", self.image_widget):Offset(0,46)
--        local w,h = self.body_text:GetSize()
--        self.text_bg:SetSize(self.screen_w , h+200):Show():LayoutBounds("center", "bottom", self.image_widget )

--    else
        local PADDING = 100
--        local text_height = (sh - scale*self.movie_height*base_scale) - 100 - PADDING -- Accomodate for bottom bar height
--        self:FitBodyText( text_height )

--        if screen_ratio < normal_ratio then
            self.movie_root:LayoutBounds("center", "center", 0, 200)
--        else
--            self.movie_root:LayoutBounds("center", "top", 0, (sh/2-50)*(1/base_scale))
--        end

        self.body_text:LayoutBounds("center", "below", self.movie_root):Offset(0,-PADDING)
--    end

    self.panel_border_top:LayoutBounds( nil, "above", self.panel_bg ):SetScale(1,2)
    self.panel_glow_top:LayoutBounds( nil, "top", self.panel_bg ):Offset( 0, 100 )
    self.panel_glow_bottom:LayoutBounds( nil, "bottom", self.panel_bg ):Offset( 0, -150 )
    self.panel_border_bottom:LayoutBounds( nil, "below", self.panel_bg ):SetScale(1,2)
    self.progress_root:LayoutBounds("center", "center", self.panel_border_bottom):Offset( 0, self.pip_offset )
    self.next:LayoutBounds("center", "above", self.progress_root ):Offset( 0, 60 )
end

function SlideshowScreen:OnScreenResize(w, h)
    SlideshowScreen._base.OnScreenResize(self, w, h)
    self:DoLayout()
end

function SlideshowScreen:OnOpen()
    SlideshowScreen._base.OnOpen(self)
    
--TODO_KAJ    TheGame:SetVignetteStrength( 0 )

    self:ChangeSlide( 1 )
    self.slide_elapsed_time = 0
    self.ignore_input_time = .75
end

function SlideshowScreen:GetMusicEvent()
    return self.music_name
end

function SlideshowScreen:Finish(time_override)
    if not self.closing then
        self.closing = true
        self.slide_elapsed_time = nil

        if self.vo_sound then
			TheAudio:StopPersistentSound("slideshow_voiceover")
	    end

		local duration = time_override or FADE_DURATION
		TheFrontEnd:Fade(FADE_OUT, duration, function()
										TheFrontEnd:PopScreen()
										if self.ondone then
										    if self.slideshow_end_sound then
												TheFrontEnd:GetSound():PlaySound(self.slideshow_end_sound)
											end
											self.ondone()
										end
										TheFrontEnd:Fade(FADE_IN, duration)
									end)
	end
end

function SlideshowScreen:OnClose()
	SlideshowScreen._base.OnClose(self)

	if self.vo_sound then
		TheAudio:StopPersistentSound("slideshow_voiceover")
	end

	if self.amb_sound then
		TheAudio:StopPersistentSound("slideshow_ambient")
	end
	self:StopWorldMusic()
    TheAudio:StopFMODSnapshot(fmodtable.Snapshot.Slideshow)
--TODO_KAJ    TheGame:SetVignetteStrength( UI_VIGNETTE )
end

function SlideshowScreen:RefreshPips()
    for k = 1, #self.script do
        if self.show_pips then
            if self.step == k then
                self.progress_pips[k]:SetMultColorAlpha(1)
    			self.progress_pips[k]:SetFocus()
            else
                self.progress_pips[k]:SetMultColorAlpha(0.3)
            end
        else
            self.progress_pips[k]:Hide()
        end
    end
end

function SlideshowScreen:ChangeSlide( idx )
    if idx == self.step then
        return
    end
    self.auto_advance_timer = nil

	self.step = idx

	local txt = self.script[self.step].txt 
	local img = self.script[self.step].img
	local mov = self.script[self.step].mov
	local vo = self.script[self.step].vo
	local amb = self.script[self.step].amb
	self:RefreshPips()

	if self.vo_sound then
		TheAudio:StopPersistentSound("slideshow_voiceover")
	end

	if vo then
		TheAudio:PlayPersistentSound("slideshow_voiceover", vo)
		self.vo_sound = vo
	end

	if self.amb_sound then
		TheAudio:StopPersistentSound("slideshow_ambient")
	end
    
	if amb then
		TheAudio:PlayPersistentSound("slideshow_ambient", amb)
		self.amb_sound = amb
	end

	self.timeout = self.script[self.step].timeout

    if self.lastimg ~= img then
        if img then
            self.image_widget:Show():SendToFront()
            self.image_widget:SetTexture( img )
        else
            self.image_widget:Hide()
        end
    end
    -- Put the activating movie on top 
    -- Stop the updaters on the other movies
    -- Blend in the activating movie
    -- When it is done blending in, stop and hide all the other movies.
    if self.lastmov ~= mov then
        if mov then
            if self.movie_widgets[idx] then
                self.movie_widgets[idx]:SendToFront()
            end

            for k, v in ipairs(self.movie_widgets) do
                if v.blend_updater then
                    v.blend_updater:Stop()
                end

                if v:IsPlaying() then
                    v:SetBlendFactors(1.0, BLEND_THRESHOLD)
                end
            end

            self.movie_widgets[idx]:Show()
            self.movie_widgets[idx]:SetBlendFactors(0.0, BLEND_THRESHOLD)
            
            local loop = not self.script[self.step].no_loop
            self.movie_widgets[idx]:PlayMovie( mov, loop )
        end

    
        self.movie_widgets[idx].blend_updater = self.movie_widgets[idx]:RunUpdater(
                Updater.Series{
                    Updater.Ease( function(v) self.movie_widgets[idx]:SetBlendFactors(v, BLEND_THRESHOLD) end, 0, 1, 1.0, easing.linear),
                    Updater.Do( 
                        function() 
                            for k, v in ipairs(self.movie_widgets) do 
                                if k ~= idx then 
                                    v:StopMovie() 
                                    v:Hide() 
                                end 
                            end 
                        end )
                }
            )
    end

    self.lastimg = img
    self.lastmov = mov

    self.next:Hide():SetMultColorAlpha(0)

    self.showing_quit = false

    self.body_text:SetText( txt )
    self.body_text:SetHAlign(ANCHOR_MIDDLE)

    -- Delay spooling if necessary.
    local text_start_delay = self.script[self.step].text_start_delay or 0
    if self.script[self.step].text_start_delay then
        -- If we're supposed to delay, then set its spool to 0 then start spooling after the delay.
        self.body_text.inst.TextWidget:SetSpool(0)
        self.body_text:RunUpdater(
                Updater.Series{
                    Updater.Wait(self.script[self.step].text_start_delay),
                    Updater.Do( 
                        function() 
                            self.body_text:Spool(self.script[self.step].text_speed or self.text_speed)
                        end )
                }
            )
    else
        -- Otherwise, just start spooling.
        self.body_text:Spool(self.script[self.step].text_speed or self.text_speed)
    end
    
    if self.script[self.step].music_section then
        self:SetMusicSlideParameter( self.script[self.step].music_section )
    end
    self.skip_requested = false -- Must be AFTER MusicSlideParameter call 

    if self.page_turn_sound then
		TheFrontEnd:GetSound():PlaySound(self.page_turn_sound)
	end
    collectgarbage()
    self:DoLayout()
end


function SlideshowScreen:FitBodyText( text_height )
    local smallest_text_size, largest_text_size = 20, 48

    local size = math.round( (smallest_text_size + largest_text_size)/2)
    while smallest_text_size < largest_text_size do
        self.body_text:SetFontSize(size)

        local textw, texth = self.body_text:GetScaledSize()

        local new_size
        if texth > text_height then
            largest_text_size = size
            new_size = math.floor( (smallest_text_size + size)/2)

        else
            smallest_text_size = size
            new_size = math.floor( (largest_text_size + size)/2)
        end
        if new_size == size then
            break
        else
            size = new_size
        end
    end
end

function SlideshowScreen:Snap()
	if self.body_text:GetSpool() < 1 then
		self.body_text:SnapSpool()
	else
        self.skip_requested = true
		self:Advance()
	end
end

function SlideshowScreen:Advance()
    if self.step == #self.script then
        self:Finish()
    else
        self.body_text:SetMultColorAlpha( 1.0 )
        self:ChangeSlide( self.step + 1 )
    end
--TODO_KAJ    self.fe:RequestControlRefresh()
end

function SlideshowScreen:Rewind()
    if self.step == 1 then
        -- At beginning.
    else
        self.body_text:SetMultColorAlpha( 1.0 )
        self:ChangeSlide( self.step - 1 )
    end
--TODO_KAJ    self.fe:RequestControlRefresh()
end

return SlideshowScreen
