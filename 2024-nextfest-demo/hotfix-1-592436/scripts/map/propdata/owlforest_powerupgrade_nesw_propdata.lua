local t = {
  flower_coralbell={ { x=-10.0, z=8.0,}, { x=-8.0, z=-8.0,}, { x=8.0, z=4.0,},},
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
      x=-10.6,
      z=-7.59,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=1,
      x=-10.3,
      z=5.86,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=7.46,
      z=2.11,
    },
    {
      color_variant={ brightness=-14.0, hue=-11.0, saturation=-12.0,},
      hsb=nil,
      variation=2,
      x=9.51,
      z=-8.67,
    },
  },
  forest_grid_berryshrub={ { x=-12.0, z=-8.0,}, { x=11.0, z=-6.0,}, { x=9.0, z=-8.0,},},
  forest_grid_tree_owl_upgrader={ { x=-11.0, z=6.0,}, { x=11.0, z=7.0,},},
  power_upgrader={ { x=3.5, z=1.5,},},
  powerupgrader_cart={ { x=9.0, z=-5.0,}, { x=-8.0, z=5.0,},},
  powerupgrader_machine={ { x=6.5, z=5.5,},},
  powerupgrader_pipe={ { x=-13.0, z=4.0,}, { x=-10.0, z=-8.0,}, { flip=true, x=11.0, z=-8.0,},},
  powerupgrader_rockstand={ { x=11.0, z=3.0,},},
  powerupgrader_well={ { x=11.0, z=3.0,},},
  spawner_npc_dungeon={ { x=-9.0, z=-3.0,},},
}
t.forest_floor_grass[1].hsb = t.forest_floor_grass[1].color_variant
t.forest_floor_grass[2].hsb = t.forest_floor_grass[2].color_variant
t.forest_floor_grass[3].hsb = t.forest_floor_grass[3].color_variant
t.forest_floor_grass[4].hsb = t.forest_floor_grass[4].color_variant
t.forest_floor_grass[5].hsb = t.forest_floor_grass[5].color_variant
return t