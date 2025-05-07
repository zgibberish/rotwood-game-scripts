local t = {
  flower_coralbell={
    { x=8.0, z=4.0,},
    { x=-5.0, z=5.0,},
    { x=-8.0, z=7.0,},
    { x=-12.0, z=-11.0,},
    { x=7.0, z=-11.0,},
  },
  forest_floor_grass={
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=-4.11,
      z=-0.54,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=1,
      x=8.82,
      z=-8.87,
    },
    {
      color_variant={ brightness=-14.0, hue=-11.0, saturation=-12.0,},
      hsb=nil,
      variation=2,
      x=-8.21,
      z=-10.6,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=-9.83,
      z=-11.35,
    },
    { variation=1, x=-12.19, z=-6.65,},
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      flip=true,
      hsb=nil,
      variation=2,
      x=-6.44,
      z=7.11,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=8.27,
      z=4.03,
    },
  },
  forest_grid_berryshrub={ { x=11.0, z=-10.0,}, { x=-6.0, z=8.0,}, { x=-9.0, z=-10.0,},},
  forest_grid_tree_owl_upgrader={ { x=-1.0, z=7.0,}, { x=7.0, z=7.0,},},
  power_upgrader={ { x=1.0, z=2.0,},},
  powerupgrader_cart={ { x=10.0, z=-8.0,},},
  powerupgrader_machine={ { x=5.5, z=-2.5,},},
  powerupgrader_pipe={ { x=-8.0, z=4.0,}, { x=-11.0, z=-9.0,},},
  powerupgrader_rockstand={ { x=-4.0, z=2.0,},},
  powerupgrader_well={ { x=-4.0, z=2.0,},},
  spawner_npc_dungeon={ { x=-8.0, z=-8.0,},},
}
t.forest_floor_grass[1].hsb = t.forest_floor_grass[1].color_variant
t.forest_floor_grass[2].hsb = t.forest_floor_grass[2].color_variant
t.forest_floor_grass[3].hsb = t.forest_floor_grass[3].color_variant
t.forest_floor_grass[4].hsb = t.forest_floor_grass[4].color_variant
t.forest_floor_grass[6].hsb = t.forest_floor_grass[6].color_variant
t.forest_floor_grass[7].hsb = t.forest_floor_grass[7].color_variant
return t