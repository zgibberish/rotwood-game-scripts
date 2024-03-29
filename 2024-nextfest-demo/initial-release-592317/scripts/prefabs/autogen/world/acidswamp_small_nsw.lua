-- Generated by WorldEditor and loaded by world_autogen.lua
return {
  __displayName="acidswamp_small_nsw",
  ambient="C1BCDDFF",
  backgroundGradientCurve={
    boss={
      { 0.030965391621129, 0.44117647409439, 0.60553634166718, 1,},
      { 0.1712204007286, 0.35880389809608, 0.34921616315842, 0.63445377349854,},
      { 0.23497267759563, 0.22808794677258, 0.21894638240337, 0.32773107290268,},
      { 0.29508196721311, 0.15415577590466, 0.21481327712536, 0.24789917469025,},
      { 0.4211356466877, 0.089987408288521, 0.068067400001002, 0.093448462228655,},
    },
    entrance={
      { 0, 0.77731090784073, 0.75911456346512, 0.64993643760681,},
      { 0.1384335154827, 0.45150411128998, 0.61404067277908, 0.69327729940414,},
      { 0.22768670309654, 0.25734412670135, 0.32671818137169, 0.54201680421829,},
      { 0.28233151183971, 0.14642326533794, 0.18729476630688, 0.24369746446609,},
      { 0.39708561020036, 0.089987408288521, 0.068067400001002, 0.093448462228655,},
    },
  },
  cameralimits={ xmax=2, xmin=-2, zmax=1, zmin=-1,},
  clifflightdirection={ 0.050000000745058, -1.2000000476837, 0.40000000596046,},
  clifflightweight=0.44699999690056,
  clifframp="ramp_toni",
  colorcube={ boss="bandiforest_shop_boss_cc", entrance="bandiforest_shop_cc",},
  group="swamp_acid",
  layout="swamp/small/swamp_small_nsw",
  map_shadow={
    { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,},
    { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 3, 2, 0, 0, 0, 0, 0, 0, 0,},
    { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0,},
    { 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,},
    { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,},
    { 0, 0, 0, 0, 0, 0, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,},
    { 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,},
    { 0, 0, 0, 0, 0, 3, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0,},
    { 0, 0, 0, 0, 0, 3, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0,},
    { 0, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0,},
    { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,},
    { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0,},
    { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0,},
    { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,},
    { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,},
  },
  rimlightcolor="4EA2D6FF",
  scene_gen_overrides={  },
  scenes={
    { name="acidswamp_small_nsw",},
    { name="acidswamp_potion_nsw", roomtype="potion",},
    { name="acidswamp_powerupgrade_nsw", roomtype="powerupgrade",},
    { name="acidswamp_specialevent_conversation_nsw", roomtype="wanderer",},
  },
  shadow_tilegroup="gradient_shadow",
  water_settings={
    additive=1,
    cliff={
      bob_amplitude=0.12600000202656,
      bob_speed=0.52399998903275,
      wave_height=0.068000003695488,
      wave_outline=0.023000000044703,
      wave_period=0.94900000095367,
    },
    has_water=true,
    prop={
      bob_amplitude=0.11500000208616,
      bob_speed=0.5450000166893,
      wave_height=0.086999997496605,
      wave_outline=0.032000001519918,
      wave_period=1.095999956131,
      wave_speed=0.53500002622604,
    },
    refraction=0.24600000679493,
    water_color="0C0E15FF",
    water_height=-1.3500000238419,
  },
  worldCollisionUnlocked={
    points={
      { -4, 16.3,},
      { 4, 16.3,},
      { -4.3, 16,},
      { -4, 16.3,},
      { 4.3, 16,},
      { 4.3, 9.5,},
      { 4, 16.3,},
      { 4.3, 16,},
      { -8, 9.2,},
      { -4.6, 9.2,},
      { -9.2, 8,},
      { -8, 9.2,},
      { -4.3, 9.5,},
      { -4.3, 16,},
      { -4.6, 9.2,},
      { -4.3, 9.5,},
      { 4.6, 9.2,},
      { 8, 9.2,},
      { 4.3, 9.5,},
      { 4.6, 9.2,},
      { 9.2, 8,},
      { 9.2, 6,},
      { 8, 9.2,},
      { 9.2, 8,},
      { -11.55, 5.2,},
      { -9.5, 5.2,},
      { -12.45, 4.3,},
      { -11.55, 5.2,},
      { -9.2, 5.5,},
      { -9.2, 8,},
      { -9.5, 5.2,},
      { -9.2, 5.5,},
      { 9.2, 6,},
      { 10, 5.2,},
      { 13.2, 4,},
      { 13.2, -12,},
      { 12, 5.2,},
      { 13.2, 4,},
      { 10, 5.2,},
      { 12, 5.2,},
      { -12.6, -4.3,},
      { -12.45, 4.3,},
      { -12.3, -4.6,},
      { -12.6, -4.3,},
      { -12.3, -8,},
      { -12.3, -4.6,},
      { -12, -8.3,},
      { -12.3, -8,},
      { -8.6, -8.3,},
      { -12, -8.3,},
      { -8.3, -8.6,},
      { -8.6, -8.3,},
      { -8.3, -12,},
      { -8.3, -8.6,},
      { -8, -12.3,},
      { -8.3, -12,},
      { -1.5, -12.3,},
      { -8, -12.3,},
      { -1.2, -12.6,},
      { -1.5, -12.3,},
      { 10, -13.2,},
      { 9.2, -14,},
      { 12, -13.2,},
      { 10, -13.2,},
      { 13.2, -12,},
      { 12, -13.2,},
      { 9.2, -14,},
      { 9.2, -24,},
      { -1.2, -24,},
      { -1.2, -12.6,},
      { 0, -25.2,},
      { -1.2, -24,},
      { 8, -25.2,},
      { 0, -25.2,},
      { 9.2, -24,},
      { 8, -25.2,},
    },
  },
}
