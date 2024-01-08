local Enum = require "util.enum"

return Enum {
	"Run", -- Currency gained and spent during dungeon run.
	"Meta", -- Currency gained and spent throughout the game, persisting across dungeon runs.
	"Cosmetic" -- Currency gained by doing dungeon runs and spent on cosmetic items only
}
