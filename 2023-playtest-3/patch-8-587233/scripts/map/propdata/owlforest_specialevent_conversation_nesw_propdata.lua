local t = {
  decor_rock={ { variation=2, x=8.55, z=-5.68,}, { variation=1, x=7.23, z=4.64,},},
  flower_coralbell={
    { x=10.0, z=7.0,},
    { x=13.0, z=4.0,},
    { x=9.0, z=-7.0,},
    { x=-10.0, z=-7.0,},
    { x=10.0, z=-5.0,},
  },
  forest_floor_grass={
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=8.95,
      z=4.12,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=1,
      x=10.26,
      z=-5.77,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=10.98,
      z=-5.92,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=-11.76,
      z=-5.96,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      flip=true,
      hsb=nil,
      variation=2,
      x=7.0,
      z=1.14,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=10.95,
      z=5.28,
    },
  },
  forest_grid_berryshrub={
    { x=-7.0, z=7.0,},
    { x=12.0, z=-6.0,},
    { x=-11.0, z=-5.0,},
    { x=-8.0, z=-7.0,},
    { x=-11.0, z=5.0,},
  },
  forest_grid_grass={
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=2,
      x=-9.06,
      z=4.81,
    },
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=3,
      x=-8.04,
      z=3.79,
    },
    {
      color_variant={ brightness=-2.0, hue=-27.0, saturation=30.0,},
      hsb=nil,
      variation=1,
      x=-12.04,
      z=7.03,
    },
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=1,
      x=8.41,
      z=7.72,
    },
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=3,
      x=11.34,
      z=-7.89,
    },
  },
  forest_grid_tree_owl={ { x=-9.0, z=6.0,}, { x=12.0, z=6.0,},},
  specialevent_host={ { x=3.0, z=2.0,},},
  specialeventroom={ { x=0.74, z=-1.73,},},
}
t.forest_floor_grass[1].hsb = t.forest_floor_grass[1].color_variant
t.forest_floor_grass[2].hsb = t.forest_floor_grass[2].color_variant
t.forest_floor_grass[3].hsb = t.forest_floor_grass[3].color_variant
t.forest_floor_grass[4].hsb = t.forest_floor_grass[4].color_variant
t.forest_floor_grass[5].hsb = t.forest_floor_grass[5].color_variant
t.forest_floor_grass[6].hsb = t.forest_floor_grass[6].color_variant
t.forest_grid_grass[1].hsb = t.forest_grid_grass[1].color_variant
t.forest_grid_grass[2].hsb = t.forest_grid_grass[2].color_variant
t.forest_grid_grass[3].hsb = t.forest_grid_grass[3].color_variant
t.forest_grid_grass[4].hsb = t.forest_grid_grass[4].color_variant
t.forest_grid_grass[5].hsb = t.forest_grid_grass[5].color_variant
return t