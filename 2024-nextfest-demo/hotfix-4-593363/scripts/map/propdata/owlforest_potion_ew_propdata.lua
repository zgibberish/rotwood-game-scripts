local t = {
  flower_coralbell={ { x=8.0, z=-8.0,}, { x=12.0, z=4.0,}, { x=-6.0, z=-7.0,}, { x=-10.0, z=6.0,},},
  flower_violet={ { x=2.0, z=8.0,},},
  forest_floor_grass={
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=4.14,
      z=5.48,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=-12.28,
      z=6.27,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=1,
      x=-0.38,
      z=-5.34,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=-7.36,
      z=-8.54,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=-3.81,
      z=-4.59,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=1,
      x=-2.83,
      z=-7.49,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=6.47,
      z=4.85,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      flip=true,
      hsb=nil,
      variation=2,
      x=8.21,
      z=7.8,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=-3.08,
      z=3.5,
    },
  },
  forest_grid_berryshrub={
    { x=-13.0, z=7.0,},
    { x=-8.0, z=5.0,},
    { x=-4.0, z=-8.0,},
    { x=7.0, z=-6.0,},
    { x=10.0, z=-8.0,},
    { x=4.0, z=-8.0,},
  },
  forest_grid_tree_owl={ { x=-5.0, z=6.0,}, { z=7.0,},},
  spawner_npc_dungeon={ { x=-5.0, z=-4.0,},},
  traveling_potion_box={ { x=1.0, z=-7.5,},},
  traveling_potion_carpet={ { x=7.0, z=3.0,},},
  traveling_potion_cauldron={ { x=-9.0, z=-5.0,},},
  traveling_potion_chest={ { x=11.0, z=-4.5,},},
  traveling_potion_ladder={ { x=-2.0, z=-5.5,},},
  traveling_potion_lamp={ { x=-11.5, z=-7.5,}, { x=12.5, z=-4.5,},},
  traveling_potion_shop={ { x=7.0, z=5.0,},},
  traveling_potion_table={ { x=-4.0, z=3.0,},},
  traveling_potion_trailer={ { x=0.5, z=4.0,},},
  tree_hangings_diag1={ { x=-2.5, z=5.5,},},
}
t.forest_floor_grass[1].hsb = t.forest_floor_grass[1].color_variant
t.forest_floor_grass[2].hsb = t.forest_floor_grass[2].color_variant
t.forest_floor_grass[3].hsb = t.forest_floor_grass[3].color_variant
t.forest_floor_grass[4].hsb = t.forest_floor_grass[4].color_variant
t.forest_floor_grass[5].hsb = t.forest_floor_grass[5].color_variant
t.forest_floor_grass[6].hsb = t.forest_floor_grass[6].color_variant
t.forest_floor_grass[7].hsb = t.forest_floor_grass[7].color_variant
t.forest_floor_grass[8].hsb = t.forest_floor_grass[8].color_variant
t.forest_floor_grass[9].hsb = t.forest_floor_grass[9].color_variant
return t