-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="sound_cabbageroll_elite_alt",
  group="sound_creature",
  isfinal=true,
  needSoundEmitter=true,
  prefab={ "cabbageroll_elite",},
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
            param={ soundevent="cabbageroll_elite_spin_start",},
          },
        },
        elite_roll_hold={
          {
            eventtype="playsound",
            frame=1,
            param={ soundevent="cabbageroll_elite_spin_LP", stopatexitstate=true,},
          },
        },
        elite_roll_pre={  },
        hit={  },
        idle={  },
        knockback={  },
        knockdown={  },
        knockdown_btm={  },
        knockdown_getup={  },
        knockdown_hit={  },
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
          name="sfx-slap",
          param={ soundevent="cabbagerolls_slap",},
        },
        {
          eventtype="playsound",
          name="sfx-vo",
          param={ soundevent="cabbageroll_Elite_VO",},
        },
        {
          eventtype="playsound",
          name="sfx-bite",
          param={ soundevent="cabbageroll_Elite_bite",},
        },
        {
          eventtype="playsound",
          name="sfx-gather",
          param={ soundevent="cabbageroll_Elite_gather",},
        },
        {
          eventtype="playsound",
          name="sfx-ground_hit",
          param={ soundevent="cabbageroll_Elite_ground_hit",},
        },
        {
          eventtype="playsound",
          name="sfx-twirl",
          param={ soundevent="cabbageroll_Elite_twirl",},
        },
        {
          eventtype="playsound",
          name="sfx-whoosh",
          param={ soundevent="cabbageroll_Elite_whoosh",},
        },
        {
          eventtype="playsound",
          name="sfx-whoosh_q",
          param={ soundevent="cabbageroll_Elite_whoosh", volume=31,},
        },
        {
          eventtype="playsound",
          name="sfx-bodyfall",
          param={ soundevent="cabbageroll_bodyfall",},
        },
        {
          eventtype="playsound",
          name="sfx-whistle",
          param={
            autostop=true,
            name="cabbageroll_elite_vo_whistle",
            param={
              sound_max_count=10.0,
              soundevent="cabbageroll_Elite_behaviour_3",
              stopatexitstate=true,
            },
            soundevent="cabbageroll_Elite_behaviour_3",
          },
        },
        {
          eventtype="playfoleysound",
          name="sfx-footstep",
          param={ soundtag="Footstep", volume=12.0,},
        },
        {
          eventtype="playsound",
          name="sfx-twirl_LP",
          param={ autostop=true, soundevent="cabbageroll_Elite_twirl_LP", stopatexitstate=true,},
        },
        {
          eventtype="playsound",
          name="sfx-behaviour2",
          param={
            name="cabbageroll_elite_vo_behaviour_2",
            param={
              sound_max_count=10.0,
              soundevent="cabbageroll_Elite_behaviour_2",
              stopatexitstate=true,
            },
            soundevent="cabbageroll_Elite_behaviour_2",
          },
        },
        {
          eventtype="playsound",
          name="x-sfx-knock",
          param={ soundevent="cabbageroll_Elite_knockdown",},
        },
        {
          eventtype="playsound",
          name="x-sfx-hit",
          param={ soundevent="cabbageroll_Elite_hit",},
        },
      },
    },
  },
}
