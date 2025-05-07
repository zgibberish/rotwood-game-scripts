local Heart = require("defs.hearts.heart")

function Heart.AddForestHeart(id, data)
	Heart.AddHeart(Heart.Slots.FOREST, id, "forest_hearts", data)
end

Heart.AddHeartFamily("FOREST", nil, 2)

Heart.AddForestHeart("megatreemon",
{
	idx = 1,
	tooltips =
	{
	},

	power = "heart_megatreemon",
	stacks_per_level = 100, -- health added per level
})

Heart.AddForestHeart("owlitzer",
{
	idx = 2,
	tooltips =
	{
	},

	power = "heart_owlitzer",
	stacks_per_level = 10, -- amount healed per room enter

	-- There are1 16 rooms per dungeon

	-- Compare to Megatreemon Heart which gives ~100 HP per level
	-- To match Megatreemon Heart directly, we would give 6.25HP per level (16 rooms * 6.25HP = 100 HP)

	-- Since we're not getting this health all at once, we can give more HP total.

	-- 10HP per room * 16 = 160 HP total, 60% better
})

--[[

Assuming Mother Treek @ 100HP per level, Owlitzer @ 10HP per room
			Mother Treek 		Owlizter
Level 1  		100				  160
Level 2 		200				  320
Level 3 		300  			  480
Level 4 		400 			  640


Assuming Mother Treek @ 100HP per level, Owlitzer @ 9HP per room
			Mother Treek 		Owlizter
Level 1  		100				  144
Level 2 		200				  288
Level 3 		300  			  432
Level 4 		400 			  576


Assuming Mother Treek @ 100HP per level, Owlitzer @ 8HP per room
			Mother Treek 		Owlizter
Level 1  		100				  128
Level 2 		200				  256
Level 3 		300  			  384
Level 4 		400 			  512

Assuming Mother Treek @ 100HP per level, Owlitzer @ 7HP per room
			Mother Treek 		Owlizter
Level 1  		100				  112
Level 2 		200				  224
Level 3 		300  			  336
Level 4 		400 			  448

Verdict: Let's go with 9HP. It starts a bit better than Treemon, and ends up decently better later on.
]]