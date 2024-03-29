-- Generated by AnimTagger and loaded by animtag_autogen.lua
return {
  __displayName="sound_woworm",
  anim_events={
    woworm_bank={
      idle={ events={ { frame=14, name="sfx-breath_in",}, { frame=35, name="sfx-foley",},},},
      turn_pre={ events={ { frame=4, name="sfx-foley",},},},
      turn_pre_walk_pre={ events={ { frame=4, name="sfx-foley",},},},
      turn_pst={ events={ { frame=2, name="sfx-footstep",}, { frame=1, name="sfx-breath_in",},},},
      turn_pst_walk_pre={
        events={
          { frame=4, name="sfx-footstep",},
          { frame=6, name="sfx-footstep",},
          { frame=1, name="sfx-breath_in",},
        },
      },
      walk_loop={
        events={
          { frame=8, name="sfx-footstep",},
          { frame=10, name="sfx-footstep",},
          { frame=16, name="sfx-footstep",},
          { frame=18, name="sfx-footstep",},
          { frame=19, name="sfx-foley",},
          { frame=20, name="sfx-breath_out",},
        },
      },
      walk_pre={ events={ { frame=2, name="sfx-footstep",},},},
      walk_pst={ events={ { frame=2, name="sfx-footstep",},},},
    },
  },
  prefab={ { prefab="woworm",},},
}
