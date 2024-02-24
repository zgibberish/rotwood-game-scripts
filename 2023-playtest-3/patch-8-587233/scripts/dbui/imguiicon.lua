-- Imgui packs a bunch of symbols into unicode private use area. So they won't
-- show up in text editors, but they're useful to use. Specify them here so
-- their use is obvious.
-- To see what they look like, see imgui_demo.
-- To see the total list: imgui > Help > Imgui C Demo > Tools > Style Editor > Fonts > Glyphs.
imgui.icon = {
	width = 25, -- good size click target

	add         = utf8.char(0xe910),
	remove      = utf8.char(0xe90f),
	folder      = utf8.char(0xf07c),
	search      = utf8.char(0xe935),

	arrow_up    = utf8.char(0xe942),
	arrow_right = utf8.char(0xe943),
	arrow_down  = utf8.char(0xe944),
	arrow_left  = utf8.char(0xe945),

	playback_step_back = utf8.char(0xf048), -- small jump
	playback_jump_back = utf8.char(0xf049), -- big jump
	playback_rewind    = utf8.char(0xf04a),
	playback_play      = utf8.char(0xf04b),
	playback_pause     = utf8.char(0xf04c),
	playback_stop      = utf8.char(0xf04d),
	playback_ffwd      = utf8.char(0xf04e),
	playback_jump_fwd  = utf8.char(0xf050), -- big jump
	playback_step_fwd  = utf8.char(0xf051), -- small jump

	info        = utf8.char(0xe915),
	warn        = utf8.char(0xe917),
	err         = utf8.char(0xe91a),

	done        = utf8.char(0xf00c),
	wrong       = utf8.char(0xf00d),

	lock        = utf8.char(0xe939),
	unlock      = utf8.char(0xe93a),

	undo        = utf8.char(0xe92d),
	redo        = utf8.char(0xe92c),

	star_filled = utf8.char(0xf005),
	star_empty  = utf8.char(0xf006),

	tags        = utf8.char(0xf02c),
	list	    = utf8.char(0xf03a),
	camera	    = utf8.char(0xf03d),
	image	    = utf8.char(0xf03e),
	location    = utf8.char(0xf041),

	zoom_in     = utf8.char(0xf00e),
	zoom_out    = utf8.char(0xf010),

	copy        = utf8.char(0xf0c5),
	paste       = utf8.char(0xf0ea), -- closest I could find
	save        = utf8.char(0xf0c7),

	edit        = utf8.char(0xe902),
	receive	    = utf8.char(0xf2a0),


	buddy       = utf8.char(0xe93c),
	convo	    = utf8.char(0xf086),
}
