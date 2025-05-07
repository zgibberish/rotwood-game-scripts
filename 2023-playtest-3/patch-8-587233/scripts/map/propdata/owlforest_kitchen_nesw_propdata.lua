local t = {
  flower_coralbell={ { x=-9.0, z=8.0,}, { x=-8.0, z=-8.0,}, { x=-6.0, z=-3.0,}, { x=9.0, z=6.0,},},
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
      x=-9.79,
      z=-8.15,
    },
    {
      color_variant={ brightness=-14.0, hue=-11.0, saturation=-12.0,},
      hsb=nil,
      variation=1,
      x=-8.05,
      z=-1.08,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=4.69,
      z=2.43,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=9.51,
      z=-8.67,
    },
  },
  forest_grid_berryshrub={ { x=-12.0, z=-8.0,}, { x=9.0, z=-8.0,}, { x=11.0, z=-6.0,},},
  forest_grid_tree_owl={ { x=-12.0, z=7.0,}, { x=11.0, z=7.0,},},
  kitchen={ { x=3.0, z=1.0,},},
  kitchen_barrel={
    { variation=2, x=-5.0, z=-1.0,},
    { variation=1, x=7.0,},
    { variation=1, x=6.0, z=2.0,},
  },
  kitchen_chair={ { x=-3.0, z=-1.0,}, { x=-7.0, z=-1.0,},},
  kitchen_sign={ { x=-8.5, z=4.5,}, { x=11.5, z=4.5,},},
  street_lamp={ { x=-12.5, z=4.5,},},
}
t.forest_floor_grass[1].hsb = t.forest_floor_grass[1].color_variant
t.forest_floor_grass[2].hsb = t.forest_floor_grass[2].color_variant
t.forest_floor_grass[3].hsb = t.forest_floor_grass[3].color_variant
t.forest_floor_grass[4].hsb = t.forest_floor_grass[4].color_variant
t.forest_floor_grass[5].hsb = t.forest_floor_grass[5].color_variant
return t