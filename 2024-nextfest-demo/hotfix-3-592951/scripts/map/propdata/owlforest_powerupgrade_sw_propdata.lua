local t = {
  flower_coralbell={
    { x=-4.0, z=7.0,},
    { x=2.0, z=7.0,},
    { x=-9.0, z=-7.0,},
    { x=14.0, z=6.0,},
    { x=16.0, z=-5.0,},
  },
  forest_floor_grass={
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=-11.08,
      z=-8.62,
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
      x=-9.26,
      z=-5.14,
    },
    {
      color_variant={ brightness=-14.0, hue=-11.0, saturation=-12.0,},
      hsb=nil,
      variation=2,
      x=6.93,
      z=5.92,
    },
  },
  forest_grid_berryshrub={ { x=-12.0, z=-8.0,}, { x=9.0, z=-8.0,}, { x=11.0, z=-8.0,}, { x=-2.0, z=7.0,},},
  forest_grid_tree_owl={ { z=5.0,}, { x=15.0, z=3.0,}, { x=4.0, z=6.0,},},
  power_upgrader={ { x=10.5, z=1.5,},},
  powerupgrader_cart={ { x=8.0, z=5.0,}, { x=6.0, z=6.0,}, { x=14.0, z=-7.0,},},
  powerupgrader_machine={ { x=14.5, z=-2.5,},},
  powerupgrader_pipe={ { x=-11.0, z=-4.0,}, { flip=true, x=11.0, z=-5.0,},},
  powerupgrader_rockstand={ { x=-7.0, z=6.0,},},
  powerupgrader_well={ { x=-7.0, z=6.0,}, { x=1.0, z=1.0,},},
  spawner_npc_dungeon={ { x=-4.0, z=4.0,},},
}
t.forest_floor_grass[1].hsb = t.forest_floor_grass[1].color_variant
t.forest_floor_grass[2].hsb = t.forest_floor_grass[2].color_variant
t.forest_floor_grass[3].hsb = t.forest_floor_grass[3].color_variant
t.forest_floor_grass[4].hsb = t.forest_floor_grass[4].color_variant
return t