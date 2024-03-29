-- Generated by AnimTagger and loaded by animtag_autogen.lua
return {
  __displayName="sound_cabbagerolls2",
  anim_events={
    cabbagerolls_double_bank={
      behavior={
        done=true,
        events={
          { frame=20, name="footstep",},
          { frame=32, name="bodyfall",},
          { frame=32, name="footstep",},
          { frame=34, name="vo_pitched",},
        },
      },
      catapult_pst={
        done=true,
        events={ { frame=1, name="vo_pitched",}, { frame=9, name="footstep",},},
      },
      combine={
        done=true,
        events={ { frame=1, name="bodyfall",}, { frame=4, name="vo_pitched",},},
      },
      flinch_hold={ done=true, events={ { frame=1, name="sfx-knockdown",},},},
      flinch_pst={ done=true, events={ { frame=1, name="vo_pitched",}, { frame=5, name="hit",},},},
      hit_back_hold={ done=true, events={ { frame=0, name="sfx-knockdown",},},},
      hit_back_pst={ done=true,},
      hit_hold={ done=true, events={ { frame=0, name="hit",},},},
      knockdown={ done=true, events={ { frame=1, name="sfx-knockdown",},},},
      slam={
        done=true,
        events={
          { frame=7, name="sfx-ground_hit",},
          { frame=28, name="sfx-ground_hit",},
          { frame=48, name="bodyfall",},
          { frame=51, name="vo_pitched",},
        },
      },
      slam_hold={ events={ { frame=1, name="sfx-hold",},},},
      slam_pre={ done=true, events={ { frame=1, name="sfx-vo",},},},
      spawn2={
        done=true,
        events={
          { frame=16, name="bodyfall",},
          { frame=21, name="bodyfall",},
          { frame=24, name="vo_pitched",},
        },
      },
      throw={ done=true, events={ { frame=3, name="hit",},},},
      throw_hold={ events={ { frame=1, name="sfx-hold",},},},
      turn_pre={ done=true,},
      turn_pre_walk_pre={ done=true,},
      turn_pst={ done=true,},
      turn_pst_walk_pre={ done=true,},
      walk_loop={
        done=true,
        events={ { frame=4, name="footstep",}, { frame=12, name="footstep",},},
      },
      walk_pre={ done=true,},
      walk_pst={ done=true,},
    },
  },
  prefab={ { prefab="cabbagerolls2",},},
}
