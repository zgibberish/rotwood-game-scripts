-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="sound_cabbageroll",
  group="sound_creature",
  isfinal=true,
  needSoundEmitter=true,
  prefab={ "cabbageroll", "cabbageroll_elite",},
  stategraphs={
    sg_cabbageroll={
      events={
        angry={  },
        bite={  },
        bite_pre={  },
        elite_roll={
          {
            eventtype="playsound",
            frame=1,
            param={
              name="cabbageroll_elite_spin_lp",
              soundevent="cabbageroll_Elite_spin_LP",
              stopatexitstate=true,
            },
          },
          {
            eventtype="playsound",
            frame=1,
            param={
              name="cabbageroll_elite_spin_tell",
              soundevent="cabbageroll_Elite_spin_tell",
              stopatexitstate=true,
            },
          },
        },
        elite_roll_hold={
          {
            eventtype="playsound",
            frame=1,
            param={
              name="cabbageroll_elite_spin_lp",
              soundevent="cabbageroll_Elite_spin_LP",
              stopatexitstate=true,
            },
          },
        },
        elite_roll_pre={
          {
            eventtype="playsound",
            frame=1,
            param={ soundevent="cabbageroll_Elite_spin_start",},
          },
        },
        elite_roll_pst={
          {
            eventtype="playsound",
            frame=1,
            param={ soundevent="cabbageroll_Elite_spin_pst", stopatexitstate=true,},
          },
        },
        hit={  },
        knockdown={  },
        knockdown_btm={  },
        knockdown_getup={  },
        knockdown_hit={  },
        knockdown_idle={  },
        knockdown_pre={  },
        roll={  },
        roll_pre={  },
        roll_pst={  },
        spawn_battlefield={  },
        taunt={  },
        walk_loop={  },
        whistle={  },
      },
      sg_events={
        {
          eventtype="playsound",
          name="sfx-twirl",
          param={ soundevent="cabbageroll_twirl",},
        },
        {
          eventtype="playsound",
          name="sfx-slap",
          param={ soundevent="cabbagerolls_slap",},
        },
        {
          eventtype="playsound",
          name="sfx-twirl_LP",
          param={ soundevent="cabbageroll_twirl_LP", stopatexitstate=true,},
        },
        {
          eventtype="playsound",
          name="sfx-roll_hit",
          param={ soundevent="cabbageroll_roll_hit",},
        },
        {
          eventtype="playsound",
          name="sfx-roll_vo",
          param={ soundevent="cabbageroll_roll_vo", stopatexitstate=true,},
        },
        {
          eventtype="playsound",
          name="sfx-vo_pitched",
          param={
            name="cabbageroll_vo_growl",
            sound_max_count=1.0,
            soundevent="cabbageroll_VO_pitched",
            stopatexitstate=true,
          },
        },
        {
          eventtype="playsound",
          name="sfx-knockdown",
          param={ autostop=true, soundevent="Knockdown",},
        },
        { eventtype="playfoleysound", name="sfx-bodyfall", param={ soundtag="Bodyfall",},},
        {
          eventtype="playfoleysound",
          name="sfx-footstep",
          param={ soundtag="Footstep", volume=11.0,},
        },
        { eventtype="playsound", name="sfx-vo", param={ soundevent="cabbageroll_VO",},},
        {
          eventtype="playsound",
          name="sfx-bite",
          param={ soundevent="cabbageroll_bite",},
        },
        {
          eventtype="playsound",
          name="sfx-whoosh",
          param={ soundevent="cabbageroll_whoosh",},
        },
        {
          eventtype="playsound",
          name="sfx-whoosh_q",
          param={ soundevent="cabbageroll_whoosh", volume=45.0,},
        },
      },
    },
  },
}
