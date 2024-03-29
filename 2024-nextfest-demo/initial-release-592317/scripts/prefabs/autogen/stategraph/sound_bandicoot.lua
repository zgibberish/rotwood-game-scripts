-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="sound_bandicoot",
  isfinal=true,
  needSoundEmitter=true,
  prefab={ "bandicoot", "bandicoot_clone",},
  stategraphs={
    sg_bandicoot={
      events={
        bite={  },
        peek_a_boom_fall_pre={
          {
            eventtype="playsound",
            frame=3,
            param={ soundevent="Destructible_Stalactite_snap", stopatexitstate=true,},
          },
        },
      },
      sg_events={
        {
          eventtype="playfoleysound",
          name="sfx-footstep_q",
          param={ soundtag="Footstep", volume=39.0,},
        },
        { eventtype="playfoleysound", name="sfx-footstep", param={ soundtag="Footstep",},},
        { eventtype="playfoleysound", name="sfx-bodyfall", param={ soundtag="Bodyfall",},},
        {
          eventtype="playsound",
          name="sfx-taunt_hit",
          param={ soundevent="bandicoot_taunt_hit",},
        },
        {
          eventtype="playsound",
          name="sfx-teleport",
          param={ soundevent="bandicoot_teleport",},
        },
        { eventtype="playsound", name="sfx-bite", param={ soundevent="bandicoot_bite",},},
        {
          eventtype="playsound",
          name="sfx-bite_pre",
          param={ soundevent="bandicoot_pre_bite",},
        },
        {
          eventtype="playsound",
          name="sfx-whoosh",
          param={ soundevent="bandicoot_whoosh",},
        },
        { eventtype="playsound", name="sfx-wing", param={ soundevent="bandicoot_flap",},},
        {
          eventtype="playsound",
          name="sfx-howl",
          param={ autostop=true, soundevent="bandicoot_howl",},
        },
        {
          eventtype="playsound",
          name="sfx-vo1",
          param={ soundevent="bandicoot_vo_bits",},
        },
        {
          eventtype="playsound",
          name="sfx-vo2",
          param={ autostop=true, soundevent="bandicoot_vo_bits2",},
        },
        {
          eventtype="playsound",
          name="sfx-breaths2",
          param={ soundevent="bandicoot_breaths2",},
        },
        {
          eventtype="playsound",
          name="sfx-breaths1",
          param={ soundevent="bandicoot_breaths1",},
        },
        { eventtype="playsound", name="sfx-hit", param={ soundevent="bandicoot_hit",},},
        {
          eventtype="playsound",
          name="sfx-laugh",
          param={ soundevent="bandicoot_laugh",},
        },
        {
          eventtype="playsound",
          name="sfx-laugh2",
          param={ autostop=true, soundevent="bandicoot_laugh2",},
        },
        {
          eventtype="playsound",
          name="sfx-snarl1",
          param={ soundevent="bandicoot_snarl1",},
        },
        { eventtype="playsound", name="sfx-be4", param={ soundevent="bandicoot_be4",},},
        { eventtype="playsound", name="sfx-be5", param={ soundevent="bandicoot_be5",},},
        {
          eventtype="playsound",
          name="sfx-vo1q",
          param={ soundevent="bandicoot_vo_bits", volume=16.0,},
        },
        { eventtype="playsound", name="sfx-knockdown", param={ soundevent="Knockdown",},},
        {
          eventtype="playsound",
          name="sfx-tailspin",
          param={ autostop=true, soundevent="bandicoot_tailspin",},
        },
        {
          eventtype="playsound",
          name="sfx-snarl_short",
          param={ soundevent="bandicoot_snarl_short",},
        },
        {
          eventtype="playsound",
          name="sfx-tailspin_short",
          param={ soundevent="bandicoot_tailspin_short",},
        },
        { eventtype="playsound", name="sfx-fart", param={ soundevent="bandicoot_fart",},},
        {
          eventtype="playsound",
          name="sfx-swipe_pre",
          param={ soundevent="bandicoot_swipe_pre",},
        },
        {
          eventtype="playsound",
          name="sfx-swipe_impact",
          param={ soundevent="bandicoot_swipe_hit",},
        },
        {
          eventtype="playsound",
          name="sfx-clone",
          param={ soundevent="bandicoot_clone_cast",},
        },
        {
          eventtype="playsound",
          name="sfx-clone_split",
          param={ soundevent="bandicoot_clone_split",},
        },
        {
          eventtype="playsound",
          name="sfx-death",
          param={ soundevent="bandicoot_death",},
        },
        {
          eventtype="playsound",
          name="sfx-taunt",
          param={ autostop=true, soundevent="bandicoot_taunt",},
        },
        { eventtype="playsound", name="sfx-rage", param={ soundevent="bandicoot_rage",},},
        {
          eventtype="playsound",
          name="sfx-taunt_pre",
          param={ autostop=true, soundevent="bandicoot_taunt_pre",},
        },
        {
          eventtype="playsound",
          name="sfx-howl_intro",
          param={ soundevent="bandicoot_howl_intro",},
        },
        {
          eventtype="playsound",
          name="sfx-knock",
          param={ soundevent="bandicoot_knock_intro",},
        },
        {
          eventtype="playsound",
          name="sfx-hands_intro",
          param={ soundevent="mus_Bandicoot_intro",},
        },
        {
          eventtype="playsound",
          name="sfx-hit_intro",
          param={ soundevent="bandicoot_hit_intro",},
        },
        {
          eventtype="playsound",
          name="sfx-snarl2",
          param={ name="snarl2", soundevent="bandicoot_snarl2",},
        },
        {
          eventtype="playsound",
          name="sfx-foley",
          param={ soundevent="bandicoot_foley", volume=52.0,},
        },
        { eventtype="playsound", name="sfx-tell", param={ soundevent="bandicoot_tell",},},
      },
    },
  },
}
