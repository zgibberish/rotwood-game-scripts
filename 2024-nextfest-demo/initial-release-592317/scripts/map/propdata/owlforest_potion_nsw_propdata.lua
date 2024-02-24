local t = {
  flower_coralbell={
    { x=-11.0, z=8.0,},
    { x=-8.0, z=-11.0,},
    { x=9.0, z=8.0,},
    { x=12.0, z=1.0,},
    { x=12.0, z=-5.0,},
  },
  forest_floor_grass={
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=-9.29,
      z=-4.67,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=-11.29,
      z=-9.71,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=1,
      x=-8.73,
      z=6.22,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=10.42,
      z=7.53,
    },
    {
      color_variant={ brightness=-14.0, hue=-11.0, saturation=-12.0,},
      hsb=nil,
      variation=2,
      x=10.62,
      z=-7.66,
    },
  },
  forest_grid_berryshrub={
    { x=-12.0, z=-11.0,},
    { x=-12.0, z=5.0,},
    { x=11.0, z=8.0,},
    { x=10.0, z=-7.0,},
    { x=12.0, z=-10.0,},
    { x=-7.0, z=8.0,},
  },
  forest_grid_tree_owl={ { x=-9.0, z=7.0,}, { x=7.0, z=7.0,}, { x=11.0, z=3.0,},},
  shrub={ { x=5.0, z=8.0,},},
  spawner_npc_dungeon={ { x=-6.0, z=3.0,},},
  traveling_potion_box={ { x=10.0, z=-0.5,},},
  traveling_potion_carpet={ { x=5.0,},},
  traveling_potion_cauldron={ { flip=true, x=8.0, z=-9.0,},},
  traveling_potion_chest={ { x=-5.5, z=-10.0,},},
  traveling_potion_ladder={ { x=-7.0, z=4.5,},},
  traveling_potion_lamp={ { x=-11.5, z=-9.5,},},
  traveling_potion_shop={ { x=5.0, z=2.0,},},
  traveling_potion_table={ { x=11.0, z=-2.0,},},
  traveling_potion_trailer={ { x=-8.5, z=-7.5,},},
  tree_hangings_diag2={ { x=8.5, z=5.5,},},
}
t.forest_floor_grass[1].hsb = t.forest_floor_grass[1].color_variant
t.forest_floor_grass[2].hsb = t.forest_floor_grass[2].color_variant
t.forest_floor_grass[3].hsb = t.forest_floor_grass[3].color_variant
t.forest_floor_grass[4].hsb = t.forest_floor_grass[4].color_variant
t.forest_floor_grass[5].hsb = t.forest_floor_grass[5].color_variant
return t