local Heart = require("defs.hearts.heart")

function Heart.AddSwampHeart(id, data)
	Heart.AddHeart(Heart.Slots.SWAMP, id, "swamp_hearts", data)
end

Heart.AddHeartFamily("SWAMP", nil, 2)

Heart.AddSwampHeart("bandicoot",
{
	idx = 1,
	tooltips =
	{
	},

	power = "heart_bandicoot",
	stacks_per_level = 10, -- % roll distance per level
})

Heart.AddSwampHeart("thatcher",
{
	idx = 2,
	tooltips =
	{
	},

	power = "heart_thatcher",
	stacks_per_level = 10, -- % roll distance per level
})