local t = {
  flower_coralbell={
    { x=12.0, z=5.0,},
    { x=-12.0, z=4.0,},
    { x=7.0, z=-8.0,},
    { x=-11.0, z=-8.0,},
    { x=15.0, z=-8.0,},
    { x=9.0, z=8.0,},
  },
  forest_floor_grass={
    { variation=2, x=-9.29, z=-4.67,},
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=-8.24,
      z=-7.3,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=1,
      x=-11.46,
      z=5.96,
    },
    { variation=2, x=10.42, z=7.53,},
    {
      color_variant={ brightness=-14.0, hue=-11.0, saturation=-12.0,},
      hsb=nil,
      variation=2,
      x=9.51,
      z=-8.67,
    },
  },
  forest_grid_berryshrub={
    { x=-8.0, z=4.0,},
    { x=13.0, z=-7.0,},
    { x=15.0, z=-4.0,},
    { x=15.0, z=5.0,},
    { x=14.0, z=7.0,},
  },
  forest_grid_tree_owl={
    { x=-10.0, z=7.0,},
    { x=-9.0, z=-7.0,},
    { x=-4.0, z=-7.0,},
    { x=11.0, z=7.0,},
    { x=15.0, z=2.0,},
  },
  kitchen={ { x=5.0, z=-1.0,},},
  kitchen_barrel={
    { variation=1, x=9.0, z=-8.0,},
    { variation=2, x=11.0, z=-8.0,},
    { variation=2, x=11.0, z=1.0,},
  },
  kitchen_chair={ { x=13.0, z=1.0,}, { flip=true, x=9.0, z=1.0,},},
  kitchen_sign={ { x=-11.5, z=-5.5,}, { x=9.5, z=5.5,},},
  tree_hangings={ { x=-6.5, z=-7.5,},},
  tree_hangings_diag2={ { x=12.5, z=5.5,},},
}
t.forest_floor_grass[2].hsb = t.forest_floor_grass[2].color_variant
t.forest_floor_grass[3].hsb = t.forest_floor_grass[3].color_variant
t.forest_floor_grass[5].hsb = t.forest_floor_grass[5].color_variant
return t