-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="sound_gourdo",
  group="sound_creature",
  isfinal=true,
  needSoundEmitter=true,
  prefab={ "gourdo", "gourdo_elite",},
  stategraphs={
    sg_gourdo={
      events={
        knockback={ { eventtype="playsound", frame=1, param={ soundevent="gourdo_knockback",},},},
        knockdown={ { eventtype="playsound", frame=1, param={ soundevent="gourdo_knockback",},},},
        knockdown_hit={ { eventtype="playsound", frame=1, param={ soundevent="gourdo_hit",},},},
      },
      sg_events={
        { eventtype="playsound", name="idle", param={ soundevent="gourdo_idle",},},
        {
          eventtype="playsound",
          name="butt_slam_land",
          param={ soundevent="gourdo_butt_slam_land",},
        },
        {
          eventtype="playsound",
          name="butt_slam_jump",
          param={ soundevent="gourdo_butt_slam_jump",},
        },
        { eventtype="playsound", name="getup_vo", param={ soundevent="gourdo_get_up",},},
        {
          eventtype="playsound",
          name="vo-knockdown",
          param={ autostop=true, soundevent="gourdo_knockback",},
        },
        {
          eventtype="playsound",
          name="gourdo_shoot",
          param={ autostop=true, soundevent="gourdo_shoot",},
        },
        {
          eventtype="playsound",
          name="vo-hold",
          param={ autostop=true, soundevent="gourdo_buff_hold", stopatexitstate=true,},
        },
        {
          eventtype="playsound",
          name="gourdo_hit",
          param={ autostop=true, sound_max_count=5.0, soundevent="gourdo_hit",},
        },
        {
          eventtype="playsound",
          name="gourdo_spawn_whistle",
          param={ soundevent="gourdo_spawn",},
        },
        {
          eventtype="playsound",
          name="gourdo_punch",
          param={ autostop=true, soundevent="gourdo_punch", stopatexitstate=true,},
        },
        {
          eventtype="playsound",
          name="foley1",
          param={ autostop=true, soundevent="gourdo_foley1",},
        },
        {
          eventtype="playsound",
          name="vo-taunt",
          param={ autostop=true, soundevent="gourdo_taunt_vo",},
        },
        {
          eventtype="playsound",
          name="sfx-chest_pound",
          param={ autostop=true, soundevent="gourdo_chest_pound", stopatexitstate=true,},
        },
        {
          eventtype="playcountedsound",
          name="vo-butt_slam",
          param={ maxcount=3.0, soundevent="gourdo_buttslam_vo",},
        },
        {
          eventtype="playfoleysound",
          name="footstep",
          param={ soundtag="Footstep", volume=64.0,},
        },
        { eventtype="playfoleysound", name="bodyfall", param={ soundtag="Bodyfall",},},
        {
          eventtype="playsound",
          name="sfx-knockdown",
          param={ autostop=true, soundevent="Knockdown",},
        },
        {
          eventtype="playsound",
          name="sfx-breath",
          param={ autostop=true, soundevent="gourdo_breath", volume=47.0,},
        },
      },
    },
  },
}