local t = {
  decor_rock={ { variation=1, x=7.72, z=4.62,}, { variation=2, x=0.83, z=-6.01,},},
  flower_coralbell={ { x=-11.0, z=8.0,}, { x=-8.0, z=-11.0,}, { x=9.0, z=8.0,},},
  forest_floor_grass={
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=-9.65,
      z=6.61,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=-6.53,
      z=-8.48,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=1,
      x=-7.65,
      z=1.63,
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
      x=7.81,
      z=-7.86,
    },
  },
  forest_grid_berryshrub={
    { x=-6.0, z=-9.0,},
    { x=-12.0, z=4.0,},
    { x=-4.0, z=-11.0,},
    { x=6.0, z=-12.0,},
  },
  forest_grid_grass={
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=2,
      x=-1.54,
      z=-11.73,
    },
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=2,
      x=9.83,
      z=4.91,
    },
    {
      color_variant={ brightness=-2.0, hue=-27.0, saturation=30.0,},
      hsb=nil,
      variation=3,
      x=-7.5,
      z=5.16,
    },
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=1,
      x=0.16,
      z=-12.12,
    },
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=3,
      x=5.28,
      z=-9.46,
    },
  },
  forest_grid_tree_owl={ { x=-9.0, z=7.0,}, { x=11.0, z=6.0,},},
  specialevent_host={ { flip=true, x=-2.0, z=-7.0,},},
  specialeventroom={ { x=1.19, z=0.63,},},
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