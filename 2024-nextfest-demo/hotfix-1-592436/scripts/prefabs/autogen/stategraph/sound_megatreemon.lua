-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="sound_megatreemon",
  group="sound_creature",
  isfinal=true,
  needSoundEmitter=true,
  prefab="megatreemon",
  stategraphs={
    sg_megatreemon={
      events={
        death={  },
        defend_pre={
          { eventtype="playsound", frame=1, param={ soundevent="megatreemon_defend_pre",},},
          { eventtype="playsound", frame=27, param={ soundevent="megatreemon_snap",},},
          { eventtype="playsound", frame=29, param={ soundevent="megatreemon_snap",},},
        },
        dormant_idle={  },
        hit={  },
        hit_actual={  },
        room_attack_loop={  },
        room_attack_pre={  },
        swipe={  },
        swipe_hold={  },
        taunt={  },
      },
      sg_events={
        {
          eventtype="playsound",
          name="sfx-death",
          param={ soundevent="megatreemon_death",},
        },
        {
          eventtype="playsound",
          name="sfx-swipe_pre",
          param={ soundevent="megatreemon_swipe_pre",},
        },
        {
          eventtype="playsound",
          name="sfx-eye",
          param={ soundevent="megatreemon_eye_move",},
        },
        {
          eventtype="playsound",
          name="sfx-death_yell",
          param={ soundevent="megatreemon_death_yell",},
        },
        {
          eventtype="playsound",
          name="sfx-death_eye",
          param={ soundevent="megatreemon_death_eye",},
        },
        {
          eventtype="playsound",
          name="sfx-death_fall",
          param={ soundevent="megatreemon_death_fall",},
        },
        {
          eventtype="playsound",
          name="sfx-defend",
          param={ soundevent="megatreemon_defend",},
        },
        {
          eventtype="playsound",
          name="sfx-foley",
          param={ soundevent="megatreemon_foley", volume=73.0,},
        },
        {
          eventtype="playsound",
          name="sfx-foley_quiet",
          param={ soundevent="megatreemon_foley", volume=14.0,},
        },
        {
          eventtype="playsound",
          name="sfx-intro_foley",
          param={ soundevent="megatreemon_intro_foley",},
        },
        {
          eventtype="playsound",
          name="sfx-intro_root_pst",
          param={ soundevent="megatreemon_intro_root_pst", volume=62.0,},
        },
        {
          eventtype="playsound",
          name="sfx-intro_snap",
          param={ soundevent="megatreemon_intro_snap",},
        },
        {
          eventtype="playsound",
          name="sfx-intro_spike_impact",
          param={ soundevent="megatreemon_intro_root_attack",},
        },
        {
          eventtype="playsound",
          name="sfx-intro_spike_pre",
          param={ soundevent="megatreemon_intro_root_spike_pre",},
        },
        {
          eventtype="playsound",
          name="sfx-intro_swipe_pre",
          param={ soundevent="megatreemon_intro_swipe_pre", volume=52.0,},
        },
        {
          eventtype="playsound",
          name="sfx-pick",
          param={ soundevent="megatreemon_pick",},
        },
        {
          eventtype="playsound",
          name="sfx-roar",
          param={ soundevent="megatreemon_roar",},
        },
        {
          eventtype="playsound",
          name="sfx-snap",
          param={ soundevent="megatreemon_snap",},
        },
        {
          eventtype="playsound",
          name="sfx-swipe",
          param={ soundevent="megatreemon_swipe",},
        },
        { eventtype="playsound", name="sfx-vo", param={ soundevent="megatreemon_VO",},},
        {
          eventtype="playsound",
          name="sfx-vo-uproot_gurgle",
          param={ soundevent="megatreemon_uproot_gurgle", stopatexitstate=true,},
        },
        {
          eventtype="playsound",
          name="sfx-vo-uproot_warn",
          param={ soundevent="megatreemon_uproot_warn",},
        },
        {
          eventtype="playsound",
          name="sfx-vo_quiet",
          param={ soundevent="megatreemon_VO_2", volume=17.0,},
        },
        {
          eventtype="playsound",
          name="sfx-vo_hit",
          param={ soundevent="megatreemon_hit",},
        },
      },
    },
  },
}
