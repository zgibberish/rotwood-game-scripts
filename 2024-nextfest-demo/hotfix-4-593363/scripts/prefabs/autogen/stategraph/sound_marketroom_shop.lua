-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="sound_marketroom_shop",
  isfinal=true,
  needSoundEmitter=true,
  prefab={ "marketroom_shop",},
  stategraphs={
    marketroom_shop={
      events={
        idle={
          {
            eventtype="playsound",
            frame=1,
            param={ autostop=true, soundevent="building_marketroom_shop_LP",},
          },
        },
      },
    },
  },
}
