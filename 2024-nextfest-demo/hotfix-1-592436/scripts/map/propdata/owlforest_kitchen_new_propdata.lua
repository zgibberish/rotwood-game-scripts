local t = {
  flower_coralbell={ { x=-8.0, z=-11.0,}, { x=9.0, z=8.0,}, { x=-11.0, z=8.0,},},
  forest_floor_grass={
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=-4.5,
      z=-2.8,
    },
    { variation=3, x=-6.53, z=-8.48,},
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=1,
      x=-5.63,
      z=-8.79,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=10.42,
      z=7.53,
    },
    {
      color_variant={ brightness=-14.0, hue=-11.0, saturation=-12.0,},
      hsb=nil,
      variation=2,
      x=8.17,
      z=-8.24,
    },
  },
  forest_grid_berryshrub={ { x=-12.0, z=4.0,}, { x=6.0, z=-12.0,},},
  forest_grid_tree_owl={ { x=-9.0, z=7.0,}, { x=11.0, z=6.0,},},
  kitchen={ { x=-1.0, z=-6.0,},},
  kitchen_barrel={ { variation=2, x=2.0, z=-12.0,}, { variation=1, x=4.0, z=-11.0,},},
  kitchen_chair={ { z=-12.0,}, { x=-9.0, z=5.0,},},
  kitchen_sign={ { x=-6.5, z=-8.5,},},
  street_lamp={ { x=-10.5, z=4.5,}, { x=9.5, z=4.5,},},
}
t.forest_floor_grass[1].hsb = t.forest_floor_grass[1].color_variant
t.forest_floor_grass[3].hsb = t.forest_floor_grass[3].color_variant
t.forest_floor_grass[4].hsb = t.forest_floor_grass[4].color_variant
t.forest_floor_grass[5].hsb = t.forest_floor_grass[5].color_variant
return t