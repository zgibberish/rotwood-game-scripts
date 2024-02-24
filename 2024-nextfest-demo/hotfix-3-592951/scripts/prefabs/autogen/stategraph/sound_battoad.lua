-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="sound_battoad",
  group="sound_creature",
  isfinal=true,
  needSoundEmitter=true,
  prefab={ "battoad", "battoad_elite",},
  stategraphs={
    sg_battoad={
      events={
        fly_loop={  },
        knockdown_hit={ { eventtype="playsound", frame=1, param={ soundevent="battoad_hit1",},},},
        upperwings={
          {
            eventtype="playsound",
            frame=1,
            param={ soundevent="battoad_upperwings_pre_LP", stopatexitstate=true,},
          },
        },
        upperwings_hold={  },
      },
      sg_events={
        {
          eventtype="playsound",
          name="sfx-flap_short",
          param={ soundevent="battoad_flap_short",},
        },
        { eventtype="playsound", name="sfx-flap", param={ soundevent="battoad_flap",},},
        { eventtype="playsound", name="sfx-sharp", param={ soundevent="battoad_sharp",},},
        {
          eventtype="playsound",
          name="sfx-land",
          param={ soundevent="battoad_land", volume=25,},
        },
        {
          eventtype="playsound",
          name="sfx-upperwings",
          param={ soundevent="battoad_upperwings",},
        },
        { eventtype="playsound", name="sfx-slash", param={ soundevent="battoad_swipe",},},
        {
          eventtype="playsound",
          name="sfx-tongue_hit",
          param={ soundevent="battoad_tongue_hit",},
        },
        {
          eventtype="playsound",
          name="sfx-flap2",
          param={ soundevent="battoad_flap_short",},
        },
        {
          eventtype="playsound",
          name="sfx-croak",
          param={
            autostop=true,
            sound_max_count=5.0,
            soundevent="battoad_spit_pre",
            stopatexitstate=true,
          },
        },
        {
          eventtype="playsound",
          name="sfx-hit_short",
          param={
            autostop=true,
            sound_max_count=5.0,
            soundevent="battoad_hit_short",
            stopatexitstate=true,
          },
        },
        {
          eventtype="playsound",
          name="sfx-puke",
          param={ autostop=true, soundevent="battoad_puke",},
        },
        {
          eventtype="playsound",
          name="sfx-puke_pre",
          param={
            autostop=true,
            sound_max_count=5.0,
            soundevent="battoad_puke_pre",
            stopatexitstate=true,
          },
        },
        {
          eventtype="playsound",
          name="sfx-swallow",
          param={ soundevent="battoad_swallow",},
        },
        { eventtype="playfoleysound", name="sfx-footstep", param={ soundtag="Footstep",},},
        { eventtype="playfoleysound", name="sfx-bodyfall", param={ soundtag="Bodyfall",},},
        {
          eventtype="playsound",
          name="x-sfx-knockdown_vo",
          param={ autostop=true, soundevent="battoad_knockdown",},
        },
        {
          eventtype="playsound",
          name="sfx-slash_pre",
          param={ soundevent="battoad_hit2",},
        },
        { eventtype="playsound", name="sfx-chew", param={ soundevent="battoad_chew",},},
        {
          eventtype="playsound",
          name="sfx-breath",
          param={ soundevent="battoad_breath",},
        },
        {
          eventtype="playsound",
          name="sfx-knockdown",
          param={ autostop=true, soundevent="Knockdown",},
        },
      },
      state_events={ upperwings_hold={  },},
    },
  },
}
