local Lume = require "util.lume"

return Lume.concat(
	(require "defs.equipment.weapon.cannons"),
	(require "defs.equipment.weapon.greatswords"),
	(require "defs.equipment.weapon.hammers"),
	(require "defs.equipment.weapon.polearms"),
	(require "defs.equipment.weapon.prototypes"),
	(require "defs.equipment.weapon.shotputs")
)
