local t = {
  flower_coralbell={
    { x=15.0, z=2.0,},
    { x=-5.0, z=6.0,},
    { x=-11.0, z=-7.0,},
    { x=12.0, z=5.0,},
    { x=14.0, z=-7.0,},
  },
  forest_floor_grass={
    { variation=3, x=-6.81, z=6.26,},
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=10.23,
      z=7.06,
    },
    {
      color_variant={ brightness=-14.0, hue=-11.0, saturation=-12.0,},
      hsb=nil,
      variation=1,
      x=9.58,
      z=-8.66,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=-7.63,
      z=-5.85,
    },
  },
  forest_grid_berryshrub={
    { x=-15.0, z=6.0,},
    { x=-13.0, z=-8.0,},
    { x=15.0, z=-5.0,},
    { x=11.0, z=-8.0,},
    { x=2.0, z=8.0,},
  },
  forest_grid_tree_owl={ { x=11.0, z=7.0,}, { x=15.0, z=4.0,}, { z=7.0,}, { x=-4.0, z=4.0,},},
  spawner_npc_dungeon={ { x=-2.0, z=4.0,},},
  traveling_potion_box={ { x=14.0, z=6.5,},},
  traveling_potion_carpet={ { x=7.0, z=1.0,},},
  traveling_potion_cauldron={ { x=-9.0, z=-5.0,},},
  traveling_potion_chest={ { x=9.5, z=-6.0,},},
  traveling_potion_ladder={ { x=12.0, z=-4.5,},},
  traveling_potion_lamp={ { x=-12.5, z=-4.5,},},
  traveling_potion_shop={ { x=7.0, z=3.0,},},
  traveling_potion_table={ { x=1.0, z=5.0,},},
  traveling_potion_trailer={ { x=-9.5, z=6.0,},},
  tree_hangings={ { x=7.5, z=6.5,},},
  tree_hangings_diag1={ { x=-1.5, z=5.5,},},
  tree_hangings_diag2={ { x=12.5, z=5.5,},},
}
t.forest_floor_grass[2].hsb = t.forest_floor_grass[2].color_variant
t.forest_floor_grass[3].hsb = t.forest_floor_grass[3].color_variant
t.forest_floor_grass[4].hsb = t.forest_floor_grass[4].color_variant
return t