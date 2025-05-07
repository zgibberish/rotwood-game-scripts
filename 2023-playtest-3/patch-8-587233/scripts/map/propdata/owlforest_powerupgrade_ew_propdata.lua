local t = {
  flower_coralbell={
    { x=-7.0, z=-7.0,},
    { x=14.0, z=7.0,},
    { x=-2.0, z=8.0,},
    { x=-9.0, z=8.0,},
    { x=8.0, z=-8.0,},
  },
  forest_floor_grass={
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=-8.39,
      z=4.58,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=5.78,
      z=3.61,
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
      x=-2.84,
      z=-7.47,
    },
    {
      color_variant={ brightness=-14.0, hue=-11.0, saturation=-12.0,},
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
    {
      color_variant={ brightness=-14.0, hue=-11.0, saturation=-12.0,},
      flip=true,
      hsb=nil,
      variation=3,
      x=11.97,
      z=3.79,
    },
  },
  forest_grid_berryshrub={
    { x=4.0, z=-8.0,},
    { x=7.0, z=-6.0,},
    { x=10.0, z=-8.0,},
    { x=-7.0, z=6.0,},
    { x=-6.0, z=8.0,},
    { x=-5.0, z=-8.0,},
  },
  forest_grid_tree_owl_upgrader={ { x=-5.0, z=4.0,}, { z=7.0,},},
  power_upgrader={ { x=4.5, z=4.5,},},
  powerupgrader_cart={ { x=2.0, z=6.0,}, { x=-3.0, z=-6.0,},},
  powerupgrader_machine={ { x=-9.5, z=-4.5,},},
  powerupgrader_pipe={ { x=-11.5, z=4.5,}, { x=-7.0, z=-4.0,}, { x=1.0, z=-4.0,},},
  powerupgrader_rockstand={ { x=11.0, z=6.0,},},
  powerupgrader_well={ { x=10.5, z=5.5,},},
  spawner_npc_dungeon={ { x=-2.0, z=-3.0,},},
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