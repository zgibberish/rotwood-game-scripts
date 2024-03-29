-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="sound_zucco",
  group="sound_creature",
  isfinal=true,
  needSoundEmitter=true,
  prefab={ "zucco", "zucco_elite",},
  stategraphs={
    sg_zucco={
      events={
        escape={
          { eventtype="playsound", frame=2, param={ soundevent="zucco_grunts_2",},},
          { eventtype="playsound", frame=11, param={ soundevent="zucco_grunts_1",},},
          { eventtype="playsound", frame=12, param={ soundevent="zucco_grunts_1",},},
          { eventtype="playsound", frame=13, param={ soundevent="zucco_grunts_1",},},
        },
        hit={
          { eventtype="playsound", frame=3, param={ soundevent="zucco_grunts_1",},},
          { eventtype="stopsound", frame=1, param={ name="zucco_taunt_1",},},
          { eventtype="stopsound", frame=1, param={ name="zucco_taunt_2",},},
          { eventtype="stopsound", frame=1, param={ name="zucco_windmill_vo",},},
          { eventtype="stopsound", frame=1, param={ name="windmill",},},
        },
        idle={
          { eventtype="playsound", frame=10, param={ soundevent="zucco_idle", volume=36,},},
        },
        knockback={ { eventtype="playsound", frame=4, param={ soundevent="zucco_hit",},},},
        knockback_pst={ { eventtype="playsound", frame=1, param={ soundevent="zucco_flinch",},},},
        knockdown={ { eventtype="playsound", frame=1, param={ soundevent="zucco_knockdown_pre",},},},
        swipe4={
          {
            eventtype="playsound",
            frame=1,
            param={
              autostop=true,
              name="windmill",
              soundevent="zucco_swipe4_LP",
              stopatexitstate=true,
            },
          },
        },
        trap={
          { eventtype="playsound", frame=5, param={ soundevent="zucco_trap_sfx",},},
          { eventtype="playsound", frame=1, param={ soundevent="zucco_trap",},},
        },
        windmill={
          {
            eventtype="playsound",
            frame=6,
            param={
              autostop=true,
              name="windmill",
              soundevent="zucco_windmill_LP",
              stopatexitstate=true,
            },
          },
        },
      },
      sg_events={
        {
          eventtype="playsound",
          name="sfx-knockdown_pre",
          param={ autostop=true, soundevent="zucco_knockdown_pre",},
        },
        {
          eventtype="playsound",
          name="sfx-knockdown",
          param={ autostop=true, soundevent="Knockdown",},
        },
        {
          eventtype="playsound",
          name="sfx-beh1",
          param={ name="zucco_taunt_1", soundevent="zucco_bahavior_1", stopatexitstate=true,},
        },
        {
          eventtype="playsound",
          name="sfx-beh2",
          param={ name="zucco_taunt_2", soundevent="zucco_bahavior_2", stopatexitstate=true,},
        },
        { eventtype="playfoleysound", name="sfx-bodyfall", param={ soundtag="Bodyfall",},},
        {
          eventtype="playsound",
          name="sfx-breathe_out",
          param={ soundevent="zucco_breath_out",},
        },
        { eventtype="playsound", name="sfx-dig", param={ soundevent="zucco_dig",},},
        { eventtype="playsound", name="sfx-foley1", param={ soundevent="zucco_foley1",},},
        { eventtype="playsound", name="sfx-foley2", param={ soundevent="zucco_foley2",},},
        { eventtype="playfoleysound", name="sfx-footstep", param={ soundtag="Footstep",},},
        {
          eventtype="playsound",
          name="sfx-grunt1",
          param={ soundevent="zucco_grunts_1", volume=54.0,},
        },
        {
          eventtype="playsound",
          name="sfx-grunt2",
          param={ soundevent="zucco_grunts_2",},
        },
        { eventtype="playsound", name="sfx-hit", param={ soundevent="zucco_hit",},},
        { eventtype="playsound", name="sfx-idle", param={ soundevent="zucco_idle",},},
        {
          eventtype="playsound",
          name="sfx-slice1",
          param={ soundevent="zucco_slice_sfx1",},
        },
        {
          eventtype="playsound",
          name="sfx-slice2",
          param={ soundevent="zucco_slice_sfx2",},
        },
        {
          eventtype="playsound",
          name="sfx-slice3",
          param={ soundevent="zucco_slice_sfx3",},
        },
        {
          eventtype="playsound",
          name="sfx-swipe_vo_1",
          param={ soundevent="zucco_swipe_1",},
        },
        {
          eventtype="playsound",
          name="sfx-swipe_vo_2",
          param={ soundevent="zucco_swipe_2",},
        },
        {
          eventtype="playsound",
          name="sfx-swipe_vo_3",
          param={ soundevent="zucco_swipe_3",},
        },
        {
          eventtype="playsound",
          name="sfx-unstuck",
          param={ soundevent="zucco_claw_unstuck",},
        },
        {
          eventtype="playsound",
          name="sfx-whoosh",
          param={ soundevent="AAAA_default_event",},
        },
        {
          eventtype="playsound",
          name="sfx-windmill_vo",
          param={ autostop=true, name="zucco_windmill_vo", soundevent="zucco_windmill_hold",},
        },
        {
          eventtype="playsound",
          name="sfx-grunt3",
          param={ soundevent="zucco_grunts_3",},
        },
      },
    },
  },
}
