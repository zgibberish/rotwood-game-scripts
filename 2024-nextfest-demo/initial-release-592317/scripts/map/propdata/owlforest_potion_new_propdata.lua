local t = {
  flower_coralbell={ { x=-11.0, z=6.0,}, { x=9.0, z=8.0,}, { x=-8.0, z=-10.0,}, { x=8.0, z=-11.0,},},
  forest_floor_grass={
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=-4.5,
      z=-2.8,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=-3.79,
      z=-9.38,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=1,
      x=-9.97,
      z=4.54,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=10.15,
      z=5.69,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=5.44,
      z=-3.17,
    },
  },
  forest_grid_berryshrub={
    { x=-10.0, z=-9.0,},
    { x=10.0, z=-12.0,},
    { x=12.0, z=4.0,},
    { x=-12.0, z=4.0,},
  },
  forest_grid_tree_owl={ { x=-9.0, z=7.0,}, { x=11.0, z=6.0,},},
  spawner_npc_dungeon={ { x=-6.0, z=3.0,},},
  traveling_potion_box={ { flip=true, x=5.0, z=-11.5,},},
  traveling_potion_carpet={ { x=5.0, z=-1.0,},},
  traveling_potion_cauldron={ { x=-5.0, z=-8.0,},},
  traveling_potion_chest={ { x=-9.0, z=4.5,},},
  traveling_potion_ladder={ { x=6.0, z=-10.5,},},
  traveling_potion_lamp={ { x=-9.5, z=-7.5,}, { x=10.5, z=4.5,},},
  traveling_potion_shop={ { x=5.0, z=1.0,},},
  traveling_potion_table={ { x=-1.0, z=-11.0,},},
}
t.forest_floor_grass[1].hsb = t.forest_floor_grass[1].color_variant
t.forest_floor_grass[2].hsb = t.forest_floor_grass[2].color_variant
t.forest_floor_grass[3].hsb = t.forest_floor_grass[3].color_variant
t.forest_floor_grass[4].hsb = t.forest_floor_grass[4].color_variant
t.forest_floor_grass[5].hsb = t.forest_floor_grass[5].color_variant
return t