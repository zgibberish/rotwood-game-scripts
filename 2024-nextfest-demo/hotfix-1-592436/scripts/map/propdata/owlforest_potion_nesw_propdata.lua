local t = {
  canopy_shadow={
    { x=-12.14, z=7.73,},
    { x=-2.2, z=-3.96,},
    { x=9.6, z=-7.8,},
    { x=8.12, z=9.26,},
    { x=-17.37, z=9.09,},
  },
  flower_coralbell={ { x=12.0, z=5.0,}, { x=-14.0, z=4.0,}, { x=-5.0, z=-7.0,}, { x=6.0, z=-6.0,},},
  forest_floor_grass={
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=-8.72,
      z=-3.13,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=-7.55,
      z=-1.95,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=1,
      x=-11.63,
      z=6.38,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=6.59,
      z=0.85,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=10.34,
      z=-8.21,
    },
  },
  forest_grid_berryshrub={ { x=-11.0, z=-6.0,}, { x=-12.0, z=-8.0,}, { x=9.0, z=-8.0,},},
  forest_grid_tree_owl={ { x=-12.0, z=7.0,}, { x=11.0, z=7.0,},},
  spawner_npc_dungeon={ { x=-6.0, z=-1.0,},},
  traveling_potion_box={ { x=-5.0, z=6.5,},},
  traveling_potion_carpet={ { x=6.0, z=3.0,},},
  traveling_potion_cauldron={ { x=-8.0, z=-6.0,},},
  traveling_potion_chest={ { x=12.0, z=-7.5,},},
  traveling_potion_ladder={ { x=10.0, z=-4.5,},},
  traveling_potion_lamp={ { x=-12.5, z=3.5,},},
  traveling_potion_shop={ { x=6.0, z=4.0,},},
  traveling_potion_table={ { x=10.0, z=4.0,},},
  traveling_potion_trailer={ { x=-8.5, z=4.0,},},
}
t.forest_floor_grass[1].hsb = t.forest_floor_grass[1].color_variant
t.forest_floor_grass[2].hsb = t.forest_floor_grass[2].color_variant
t.forest_floor_grass[3].hsb = t.forest_floor_grass[3].color_variant
t.forest_floor_grass[4].hsb = t.forest_floor_grass[4].color_variant
t.forest_floor_grass[5].hsb = t.forest_floor_grass[5].color_variant
return t