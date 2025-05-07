local t = {
  flower_coralbell={ { x=2.0, z=-11.0,}, { x=8.0, z=7.0,}, { x=-11.0, z=8.0,}, { x=8.0, z=-12.0,},},
  forest_floor_grass={
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=-4.51,
      z=-2.8,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=-8.31,
      z=6.48,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=1,
      x=-6.57,
      z=-7.59,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=10.42,
      z=7.53,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=8.45,
      z=-8.67,
    },
  },
  forest_grid_berryshrub={ { x=-12.0, z=4.0,}, { x=-9.0, z=-10.0,},},
  forest_grid_tree_owl_upgrader={ { x=-9.0, z=7.0,}, { x=11.0, z=6.0,},},
  power_upgrader={ { x=-1.0, z=-6.0,},},
  powerupgrader_cart={ { x=-6.0, z=7.0,}, { x=-7.0, z=-11.0,},},
  powerupgrader_machine={ { x=8.5, z=3.5,},},
  powerupgrader_pipe={ { x=-10.0, z=4.0,}, { x=8.0, z=-8.0,},},
  powerupgrader_well={ { x=5.0, z=-10.0,},},
  spawner_npc_dungeon={ { x=-7.0, z=4.0,},},
}
t.forest_floor_grass[1].hsb = t.forest_floor_grass[1].color_variant
t.forest_floor_grass[2].hsb = t.forest_floor_grass[2].color_variant
t.forest_floor_grass[3].hsb = t.forest_floor_grass[3].color_variant
t.forest_floor_grass[4].hsb = t.forest_floor_grass[4].color_variant
t.forest_floor_grass[5].hsb = t.forest_floor_grass[5].color_variant
return t