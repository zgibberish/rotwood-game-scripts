-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="sound_town_crystal",
  isfinal=true,
  needSoundEmitter=true,
  prefab={ "town_grid_cryst",},
  stategraphs={
    sg_town_pillar={
      events={
        activate={
          {
            eventtype="playsound",
            frame=1,
            param={ autostop=true, soundevent="town_crystal_activate",},
          },
        },
        closed={
          { eventtype="stopsound", frame=1, param={ name="town_crystal_idle_LP",},},
          {
            eventtype="playsound",
            frame=3,
            param={ autostop=true, soundevent="town_crystal_close",},
          },
        },
        idle={  },
        open={
          {
            eventtype="playsound",
            frame=1,
            param={
              autostop=true,
              name="town_crystal_idle_LP",
              sound_max_count=1.0,
              soundevent="town_crystal_idle_LP",
            },
          },
          {
            eventtype="playsound",
            frame=1,
            param={ autostop=true, soundevent="town_crystal_open",},
          },
        },
      },
    },
  },
}