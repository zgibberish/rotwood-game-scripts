local t = {
  decor_rock={
    { variation=2, x=11.78, z=4.06,},
    { variation=3, x=-11.08, z=-6.64,},
    { variation=1, x=14.54, z=-5.75,},
  },
  flower_coralbell={
    { x=6.0, z=7.0,},
    { x=13.0, z=3.0,},
    { x=13.0, z=-6.0,},
    { x=-5.0, z=7.0,},
    { x=-9.0, z=-8.0,},
  },
  forest_floor_grass={
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=3,
      x=-7.03,
      z=7.01,
    },
    {
      color_variant={ brightness=-14.0, hue=-11.0, saturation=-12.0,},
      hsb=nil,
      variation=3,
      x=10.41,
      z=7.46,
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
      x=-10.8,
      z=-5.07,
    },
    {
      color_variant={ brightness=-14, hue=-11, saturation=-12,},
      hsb=nil,
      variation=2,
      x=4.59,
      z=6.4,
    },
  },
  forest_grid_berryshrub={
    { x=13.0, z=7.0,},
    { x=16.0, z=-4.0,},
    { x=11.0, z=-8.0,},
    { x=9.0, z=-8.0,},
    { x=2.0, z=4.0,},
    { x=-8.0, z=7.0,},
    { x=-12.0, z=-8.0,},
  },
  forest_grid_grass={
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=2,
      x=9.59,
      z=6.58,
    },
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=3,
      x=0.27,
      z=3.24,
    },
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=1,
      x=8.66,
      z=7.74,
    },
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=1,
      x=-6.6,
      z=3.32,
    },
    {
      color_variant={ brightness=-2, hue=-27, saturation=30,},
      hsb=nil,
      variation=2,
      x=-5.47,
      z=4.35,
    },
  },
  forest_grid_tree_owl={ { x=-1.0, z=4.0,}, { x=4.0, z=7.0,}, { x=11.0, z=7.0,}, { x=15.0, z=3.0,},},
  specialevent_host={ { flip=true, x=7.0,},},
  specialeventroom={ { x=-4.66, z=-2.98,},},
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