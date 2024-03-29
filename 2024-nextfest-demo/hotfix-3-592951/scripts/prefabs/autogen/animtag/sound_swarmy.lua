-- Generated by AnimTagger and loaded by animtag_autogen.lua
return {
  __displayName="sound_swarmy",
  anim_events={
    swarmy_bank={
      acid_burst2={ events={ { frame=1, name="sfx-acidburst",},},},
      acid_dash={
        events={
          { frame=5, name="sfx-vo_short",},
          { frame=9, name="sfx-footstep",},
          { frame=11, name="sfx-footstep",},
          { frame=17, name="sfx-dash",},
        },
      },
      acid_dash_hold={ events={ { frame=1, name="sfx-vo_long",},},},
      knockdown_hold={ events={ { frame=0, name="sfx-knockdown_hold",},},},
      knockdown_pre={
        events={ { frame=10, name="sfx-bodyfall",}, { frame=11, name="sfx-knockdown",},},
      },
      spawn={ events={ { frame=15, name="sfx-splat",}, { frame=1, name="sfx-vo_long",},},},
      walk_loop={
        events={ { frame=12, name="sfx-footstep",}, { frame=14, name="sfx-footstep",},},
      },
    },
  },
  prefab={ { prefab="swarmy",},},
}
