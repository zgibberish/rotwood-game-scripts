-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="sound_spawnplant_tundra",
  group="sound_spawn",
  isfinal=true,
  needSoundEmitter=true,
  prefab={ "tundra_spawner_plant2", "tundra_spawner_plant1",},
  stategraphs={
    sg_spawner_battlefield={
      events={
        spawn_creature={
          { eventtype="playsound", frame=1, param={ soundevent="spawn_plant_swamp_spawn",},},
        },
        spawn_tell={
          {
            eventtype="playsound",
            frame=1,
            param={ soundevent="spawn_plant_swamp_LP", stopatexitstate=true,},
          },
        },
      },
    },
  },
}
