local t = {
  decor_rock={ { variation=1, x=10.36, z=2.45,}, { variation=3, x=-5.89, z=-4.73,},},
  flower_bush={ { x=15.0, z=-8.0,},},
  flower_coralbell={ { x=-10.0, z=-8.0,}, { x=12.0, z=5.0,}, { x=9.0, z=8.0,}, { x=-12.0, z=4.0,},},
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
      x=-9.43,
      z=7.52,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=1,
      x=-10.22,
      z=3.1,
    },
    {
      color_variant={ brightness=-14.0, hue=-11.0, saturation=-12.0,},
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
    { x=-8.0, z=4.0,},
    { x=4.0, z=-6.0,},
    { x=14.0, z=7.0,},
    { x=15.0, z=5.0,},
    { x=13.0, z=-7.0,},
    { x=15.0, z=-4.0,},
  },
  forest_grid_grass={
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=1,
      x=10.59,
      z=-7.19,
    },
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=2,
      x=-4.71,
      z=-7.63,
    },
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=3,
      x=-6.22,
      z=-8.5,
    },
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=1,
      x=-3.42,
      z=-8.39,
    },
    {
      color_variant={ brightness=-2.0, hue=-27.0, saturation=30.0,},
      hsb=nil,
      variation=2,
      x=13.59,
      z=3.56,
    },
  },
  forest_grid_tree_owl={ { x=-10.0, z=7.0,}, { x=-7.0, z=-7.0,}, { x=11.0, z=7.0,}, { x=15.0, z=2.0,},},
  specialevent_host={ { flip=true, x=4.0, z=-4.0,},},
  specialeventroom={ { x=1.79, z=-0.77,},},
}
t.forest_floor_grass[1].hsb = t.forest_floor_grass[1].color_variant
t.forest_floor_grass[2].hsb = t.forest_floor_grass[2].color_variant
t.forest_floor_grass[3].hsb = t.forest_floor_grass[3].color_variant
t.forest_floor_grass[4].hsb = t.forest_floor_grass[4].color_variant
t.forest_floor_grass[5].hsb = t.forest_floor_grass[5].color_variant
t.forest_grid_grass[1].hsb = t.forest_grid_grass[1].color_variant
t.forest_grid_grass[2].hsb = t.forest_grid_grass[2].color_variant
t.forest_grid_grass[3].hsb = t.forest_grid_grass[3].color_variant
t.forest_grid_grass[4].hsb = t.forest_grid_grass[4].color_variant
t.forest_grid_grass[5].hsb = t.forest_grid_grass[5].color_variant
return t