local t = {
  flower_coralbell={
    { x=9.0, z=7.0,},
    { x=-5.0, z=7.0,},
    { x=-9.0, z=-8.0,},
    { x=13.0, z=-6.0,},
    { x=15.0, z=2.0,},
  },
  forest_floor_grass={
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=-1.81,
      z=3.6,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=10.23,
      z=7.06,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
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
  },
  forest_grid_berryshrub={ { x=-12.0, z=-8.0,}, { x=9.0, z=-8.0,}, { x=11.0, z=-8.0,},},
  forest_grid_tree_owl={ { x=-1.0, z=4.0,}, { x=4.0, z=7.0,}, { x=11.0, z=7.0,}, { x=15.0, z=4.0,},},
  kitchen={ { x=11.5, z=1.5,},},
  kitchen_barrel={
    { variation=1, x=15.0, z=-2.0,},
    { variation=1, x=16.0, z=-4.0,},
    { variation=2, x=5.0, z=4.0,},
  },
  kitchen_chair={ { x=3.0, z=4.0,}, { x=7.0, z=4.0,},},
  kitchen_sign={ { x=-7.5, z=6.5,},},
  street_lamp={ { x=-12.5, z=-3.5,},},
  tree_hangings={ { x=7.5, z=6.5,},},
  tree_hangings_diag1={ { x=1.5, z=5.5,},},
  tree_hangings_diag2={ { x=12.5, z=5.5,},},
}
t.forest_floor_grass[1].hsb = t.forest_floor_grass[1].color_variant
t.forest_floor_grass[2].hsb = t.forest_floor_grass[2].color_variant
t.forest_floor_grass[3].hsb = t.forest_floor_grass[3].color_variant
t.forest_floor_grass[4].hsb = t.forest_floor_grass[4].color_variant
return t