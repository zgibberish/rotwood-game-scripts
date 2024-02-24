local t = {
  flower_coralbell={
    { x=-11.0, z=7.0,},
    { x=12.0, z=5.0,},
    { x=9.0, z=8.0,},
    { x=12.0, z=-5.0,},
    { x=-8.0, z=-11.0,},
  },
  forest_floor_grass={
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=-9.75,
      z=7.38,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=-10.7,
      z=-9.45,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=1,
      x=-8.12,
      z=5.39,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=10.09,
      z=7.27,
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
    { x=-7.0, z=8.0,},
    { x=11.0, z=8.0,},
    { x=10.0, z=-8.0,},
    { x=12.0, z=-10.0,},
    { x=-12.0, z=-11.0,},
  },
  forest_grid_tree_owl={ { x=-9.0, z=7.0,}, { x=7.0, z=7.0,}, { x=11.0, z=3.0,},},
  kitchen={ { x=5.0, z=1.0,},},
  kitchen_barrel={ { variation=1, x=10.0, z=-12.0,}, { variation=2, x=-7.0, z=5.0,},},
  kitchen_chair={ { x=-9.0, z=4.0,},},
  kitchen_sign={ { x=9.5, z=-3.5,},},
  shrub={ { x=5.0, z=8.0,},},
  street_lamp={ { x=-11.5, z=-8.5,}, { x=-0.5, z=-3.5,},},
  tree_hangings_diag2={ { x=8.5, z=5.5,},},
}
t.forest_floor_grass[1].hsb = t.forest_floor_grass[1].color_variant
t.forest_floor_grass[2].hsb = t.forest_floor_grass[2].color_variant
t.forest_floor_grass[3].hsb = t.forest_floor_grass[3].color_variant
t.forest_floor_grass[4].hsb = t.forest_floor_grass[4].color_variant
t.forest_floor_grass[5].hsb = t.forest_floor_grass[5].color_variant
return t