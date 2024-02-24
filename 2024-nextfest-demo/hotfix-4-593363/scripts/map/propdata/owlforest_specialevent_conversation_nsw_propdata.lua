local t = {
  decor_rock={
    { variation=2, x=8.0, z=4.82,},
    { variation=3, x=-10.37, z=-8.24,},
    { variation=3, x=-8.12, z=-9.91,},
  },
  flower_coralbell={
    { x=9.0, z=8.0,},
    { x=5.0, z=-4.0,},
    { x=12.0, z=-5.0,},
    { x=12.0, z=5.0,},
    { x=-9.0, z=-9.0,},
    { x=-11.0, z=7.0,},
  },
  forest_floor_grass={
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=-6.77,
      z=-6.06,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=-10.72,
      z=-9.45,
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
      x=9.77,
      z=-8.73,
    },
    {
      color_variant={ brightness=-14.0, hue=-11.0, saturation=-12.0,},
      hsb=nil,
      variation=2,
      x=-9.79,
      z=6.65,
    },
  },
  forest_grid_berryshrub={
    { x=-7.0, z=7.0,},
    { x=-12.0, z=5.0,},
    { x=-12.0, z=-11.0,},
    { x=9.0, z=-8.0,},
    { x=10.0, z=-12.0,},
    { x=12.0, z=-10.0,},
    { x=11.0, z=8.0,},
  },
  forest_grid_grass={
    {
      color_variant={ brightness=-2.0, hue=-27.0, saturation=30.0,},
      hsb=nil,
      variation=1,
      x=11.26,
      z=-3.55,
    },
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=3,
      x=7.28,
      z=-7.26,
    },
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=1,
      x=-10.38,
      z=-12.35,
    },
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=3,
      x=-0.33,
      z=-0.32,
    },
  },
  forest_grid_tree_owl={ { x=11.0, z=3.0,}, { x=7.0, z=7.0,}, { x=-9.0, z=7.0,},},
  specialevent_host={ { flip=true, x=4.0, z=-1.0,},},
  specialeventroom={ { x=-3.31, z=-1.93,},},
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
return t