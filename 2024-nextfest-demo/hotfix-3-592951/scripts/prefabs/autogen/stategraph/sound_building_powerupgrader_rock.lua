-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="sound_building_powerupgrader_rock",
  isfinal=true,
  needSoundEmitter=true,
  prefab={ "powerupgrader_rockstand",},
  stategraphs={
    powerupgrader_rockstand={
      events={
        idle={
          {
            eventtype="playsound",
            frame=1,
            param={
              autostop=true,
              soundevent="building_powerupgrader_rock_LP",
              stopatexitstate=true,
            },
          },
        },
      },
    },
  },
}
