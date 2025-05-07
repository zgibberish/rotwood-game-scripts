local t = {
  flower_coralbell={
    { x=12.0, z=5.0,},
    { x=-8.0, z=-12.0,},
    { x=-11.0, z=8.0,},
    { x=9.0, z=8.0,},
    { x=12.0, z=-5.0,},
  },
  forest_floor_grass={
    {
      color_variant={ brightness=-14.0, hue=-11.0, saturation=-12.0,},
      hsb=nil,
      variation=2,
      x=-5.3,
      z=-2.2,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=-10.59,
      z=-9.78,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=1,
      x=-9.77,
      z=5.05,
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
      x=9.51,
      z=-8.67,
    },
  },
  forest_grid_berryshrub={
    { x=-12.0, z=5.0,},
    { x=-12.0, z=-11.0,},
    { x=-7.0, z=8.0,},
    { x=11.0, z=8.0,},
    { x=10.0, z=-8.0,},
    { x=12.0, z=-10.0,},
  },
  forest_grid_tree_owl={ { x=11.0, z=3.0,}, { x=7.0, z=7.0,}, { x=-9.0, z=7.0,},},
  power_upgrader={ { x=4.5, z=2.5,},},
  powerupgrader_cart={ { x=10.0, z=-12.0,}, { x=-7.0, z=5.0,},},
  powerupgrader_machine={ { x=-9.5, z=-9.5,},},
  powerupgrader_pipe={ { x=-10.0, z=4.0,},},
  powerupgrader_rockstand={ { x=9.0, z=-4.0,},},
  powerupgrader_well={ { x=9.0, z=-4.0,}, { x=-4.0,},},
  shrub={ { x=5.0, z=8.0,},},
  spawner_npc_dungeon={ { x=-7.0, z=-5.0,},},
}
t.forest_floor_grass[1].hsb = t.forest_floor_grass[1].color_variant
t.forest_floor_grass[2].hsb = t.forest_floor_grass[2].color_variant
t.forest_floor_grass[3].hsb = t.forest_floor_grass[3].color_variant
t.forest_floor_grass[4].hsb = t.forest_floor_grass[4].color_variant
t.forest_floor_grass[5].hsb = t.forest_floor_grass[5].color_variant
return t