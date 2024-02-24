local strict = require "util.strict"

local audioid = {
	persistent = strict.strictify({
		ui_music = "music_UI",
		world_ambient = "ambience",
		world_birds = "ambience_birds",
		world_music = "world_music",
		room_music = "room_music",
		boss_music = "boss_music",
		slideshow_music = "slideshow",
		interactable_snapshot = "interactable_snapshot",
		wanderer_snapshot = "wanderer_snapshot",
	}, "audioid.persistent"),
	oneshot = strict.strictify({
		stinger = "music_stinger",
	}, "audioid.oneshot")
}

return audioid
