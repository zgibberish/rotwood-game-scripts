local t = {
  flower_coralbell={
    { x=12.0, z=5.0,},
    { x=-12.0, z=4.0,},
    { x=-6.0, z=-5.0,},
    { x=9.0, z=8.0,},
    { x=15.0, z=-8.0,},
    { x=-11.0, z=-7.0,},
  },
  forest_floor_grass={
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=-1.22,
      z=-6.02,
    },
    {
      color_variant={ brightness=-14.0, hue=-11.0, saturation=-12.0,},
      hsb=nil,
      variation=3,
      x=11.08,
      z=6.46,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=1,
      x=-10.98,
      z=6.23,
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
      x=9.81,
      z=-7.15,
    },
  },
  forest_grid_berryshrub={
    { x=-7.0, z=-7.0,},
    { x=13.0, z=-7.0,},
    { x=15.0, z=-4.0,},
    { x=14.0, z=7.0,},
    { x=15.0, z=5.0,},
  },
  forest_grid_tree_owl={ { x=15.0, z=2.0,},},
  forest_grid_tree_owl_upgrader={ { x=-10.0, z=7.0,}, { x=-9.0, z=-6.0,}, { x=11.0, z=7.0,},},
  power_upgrader={ { x=5.0, z=-1.0,},},
  powerupgrader_cart={ { z=-6.0,}, { x=13.0,}, { x=2.0, z=-7.0,},},
  powerupgrader_machine={ { x=-8.5, z=3.5,},},
  powerupgrader_pipe={ { flip=true, x=-12.0, z=-4.0,},},
  powerupgrader_rockstand={ { x=9.0, z=-5.0,},},
  powerupgrader_well={ { x=9.0, z=-5.0,},},
  spawner_npc_dungeon={ { x=-5.0, z=5.0,},},
}
t.forest_floor_grass[1].hsb = t.forest_floor_grass[1].color_variant
t.forest_floor_grass[2].hsb = t.forest_floor_grass[2].color_variant
t.forest_floor_grass[3].hsb = t.forest_floor_grass[3].color_variant
t.forest_floor_grass[4].hsb = t.forest_floor_grass[4].color_variant
t.forest_floor_grass[5].hsb = t.forest_floor_grass[5].color_variant
return t