-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="destructible_rock",
  needSoundEmitter=true,
  prefab={
    "destructible_rock_shorty",
    "destructible_bandiforest_stalag",
    "destructible_bandiforest_stalag_tall",
  },
  stategraphs={
    sg_prop_destructible={
      events={
        death={
          {
            eventtype="playsound",
            frame=1,
            param={ sound_max_count=1.0, soundevent="Destructible_rock",},
          },
        },
      },
    },
  },
}