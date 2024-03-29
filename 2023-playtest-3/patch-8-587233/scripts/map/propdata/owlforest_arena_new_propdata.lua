return {
  lightspot_circle={
    {
      script_args={
        animate=false,
        intensity=0.75400000810623,
        light_color="4D453FFF",
        max_rotation=20,
        max_translation=0.5,
        rot_speed=0.66666666666667,
        rotation=0,
        scale=8.53600025177,
        shimmer=false,
        shimmer_speed=3,
        shimmer_strength=0.5,
        trans_speed=0.5,
      },
      variation=1,
      x=-14.69,
      z=-5.46,
    },
    { script_args={ light_color="4D453FFF",}, variation=1, x=-2.44, z=-9.14,},
    { script_args={ light_color="4D453FFF",}, variation=2, x=13.22, z=-1.74,},
    { script_args={ light_color="4D453FFF",}, variation=1, x=0.32, z=2.24,},
    { script_args={ light_color="4D453FFF",}, variation=1, x=7.71, z=-3.56,},
    { script_args={ light_color="4D453FFF",}, variation=1, x=-7.82, z=-0.79,},
  },
  room_loot={ { x=-3.5, z=-5.5,}, { x=-0.5, z=-0.5,},},
  spawner_creature={
    { script_args={ creature_spawner_type="perimeter",}, x=-7.29, z=18.87,},
    { script_args={ creature_spawner_type="perimeter",}, x=16.08, z=6.92,},
    { script_args={ creature_spawner_type="perimeter",}, x=-16.27, z=6.82,},
    { script_args={ creature_spawner_type="battlefield",}, x=-10.2, z=0.17,},
    { script_args={ creature_spawner_type="battlefield",}, x=6.25, z=1.77,},
    { script_args={ creature_spawner_type="battlefield",}, x=6.99, z=-5.41,},
    { script_args={ creature_spawner_type="battlefield",}, x=-6.74, z=-10.31,},
    { script_args={ creature_spawner_type="battlefield",}, x=-7.0, z=9.0,},
    { script_args={ creature_spawner_type="battlefield",}, x=-6.03, z=9.85,},
    { script_args={ creature_spawner_type="battlefield",}, x=5.39, z=2.79,},
    { script_args={ creature_spawner_type="battlefield",}, x=-7.97, z=-9.31,},
    { script_args={ creature_spawner_type="battlefield",}, x=-6.39, z=1.88,},
  },
  spawner_propdestructible={
    { x=-2.0, z=-9.0,},
    { x=4.0, z=-10.0,},
    { x=13.0, z=-4.0,},
    { x=5.0, z=8.0,},
    { x=-13.0, z=-3.0,},
  },
  spawner_stationaryenemy={
    { script_args={ spawn_areas={ "battlefield", "center",},}, x=-2.0, z=1.0,},
    { script_args={ spawn_areas={ "battlefield", "center",},}, x=3.0, z=4.0,},
    { script_args={ spawn_areas={ "battlefield", "center",},}, x=8.0, z=-9.0,},
    { script_args={ spawn_areas={ "bottom", "perimeter",},}, x=1.0, z=-8.0,},
    { script_args={ spawn_areas={ "bottom", "perimeter",},}, x=-7.0, z=-9.0,},
    { script_args={ spawn_areas={ "perimeter", "top",},}, x=9.0, z=1.0,},
    { script_args={ spawn_areas={ "perimeter", "top",},}, x=-8.0, z=5.0,},
  },
  spawner_trap={
    { script_args={ trap_types={ "trap_spike",},}, x=-8.0, z=-1.0,},
    { script_args={ trap_types={ "trap_thorns",},}, x=-9.5, z=-14.5,},
    { script_args={ trap_types={ "trap_thorns",},}, x=-6.5, z=-14.5,},
    { script_args={ trap_types={ "trap_spike",},}, x=2.5, z=-4.5,},
    {
      place_anywhere=true,
      script_args={ trap_directions={ 1,}, trap_types={ "trap_windtotem",},},
      x=-1.5,
      z=-18.5,
    },
    { script_args={ trap_types={ "trap_thorns",},}, x=-12.5, z=-14.5,},
    {
      place_anywhere=true,
      script_args={ trap_directions={ 3,}, trap_types={ "trap_windtotem",},},
      x=-12.5,
      z=6.5,
    },
    {
      place_anywhere=true,
      script_args={ trap_directions={ 3,}, trap_types={ "trap_windtotem",},},
      x=9.5,
      z=6.5,
    },
    { script_args={ trap_types={ "trap_thorns",},}, x=2.5, z=-14.5,},
    { script_args={ trap_types={ "trap_spike",},}, x=-2.5, z=-2.5,},
    {
      place_anywhere=true,
      script_args={ trap_types={ "trap_thorns",},},
      x=-20.5,
      z=-10.5,
    },
    {
      place_anywhere=true,
      script_args={ trap_types={ "trap_thorns",},},
      x=16.5,
      z=-10.5,
    },
    {
      place_anywhere=true,
      script_args={ trap_types={ "trap_thorns",},},
      x=16.5,
      z=2.5,
    },
    {
      place_anywhere=true,
      script_args={ trap_types={ "trap_thorns",},},
      x=-20.5,
      z=2.5,
    },
    { script_args={ trap_types={ "trap_thorns",},}, x=5.5, z=-14.5,},
    {
      place_anywhere=true,
      script_args={ trap_types={ "trap_thorns",},},
      x=8.5,
      z=-14.5,
    },
  },
}