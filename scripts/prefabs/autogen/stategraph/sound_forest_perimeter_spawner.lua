-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="sound_forest_perimeter_spawner",
  group="spawners",
  isfinal=true,
  needSoundEmitter=true,
  prefab="spawner_forest_perimeter",
  stategraphs={
    sg_spawner_perimeter={
      events={
        idle={  },
        spawn_creature={
          {
            eventtype="playsound",
            frame=1,
            param={ soundevent="spawn_plant_forest_large",},
          },
        },
        spawn_tell={
          {
            eventtype="spawneffect",
            frame=1,
            param={
              fxname="spawn_light_strips",
              inheritrotation=true,
              ischild=true,
              offx=0.30000001192093,
              offy=0.0,
              offz=0.0,
              scalex=1.2999999523163,
              scalez=1.2999999523163,
            },
          },
          {
            eventtype="playsound",
            frame=1,
            param={ soundevent="spawn_plant_forest_large_LP", stopatexitstate=true,},
          },
        },
      },
    },
  },
}
