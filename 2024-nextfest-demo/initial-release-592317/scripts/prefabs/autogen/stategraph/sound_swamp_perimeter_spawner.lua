-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="sound_swamp_perimeter_spawner",
  needSoundEmitter=true,
  prefab={ "bandiforest_bg_tendrilspawner",},
  stategraphs={
    sg_spawner_perimeter={
      events={
        idle={
          { eventtype="playsound", frame=1, param={ soundevent="spawn_plant_swamp_large",},},
        },
        spawn_creature={
          { eventtype="playsound", frame=1, param={ soundevent="spawn_plant_swamp_large",},},
        },
        spawn_tell={
          {
            eventtype="playsound",
            frame=1,
            param={ autostop=true, soundevent="spawn_plant_swamp_large_LP", stopatexitstate=true,},
          },
        },
      },
    },
  },
}
