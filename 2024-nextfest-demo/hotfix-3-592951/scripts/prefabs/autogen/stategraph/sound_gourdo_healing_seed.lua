-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="sound_gourdo_healing_seed",
  isfinal=true,
  needSoundEmitter=true,
  prefab={ "gourdo_healing_seed", "gourdo_elite_seed",},
  stategraphs={
    sg_gourdo_healing_seed={
      events={
        death={  },
        heal={  },
        land={ { eventtype="playsound", frame=1, param={ soundevent="gourdo_seed_land",},},},
      },
      sg_events={
        {
          eventtype="playsound",
          name="sfx-eye",
          param={ soundevent="gourdo_seed_eyeball",},
        },
        {
          eventtype="playsound",
          name="sfx-gourdo_seed_heal",
          param={ soundevent="gourdo_seed_heal",},
        },
      },
    },
  },
}
