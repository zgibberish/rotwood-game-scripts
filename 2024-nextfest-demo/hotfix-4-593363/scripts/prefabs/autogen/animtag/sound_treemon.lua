-- Generated by AnimTagger and loaded by animtag_autogen.lua
return {
  __displayName="sound_treemon",
  anim_events={
    treemon={
      attack={
        done=true,
        events={
          { frame=4, name="sfx-shake", postfix="_middle",},
          { frame=4, name="sfx-blink", postfix="_middle",},
          { frame=6, name="sfx-blink", postfix="_middle",},
          { frame=7, name="sfx-blink", postfix="_middle",},
          { frame=32, name="sfx-release", postfix="_middle",},
          { frame=4, name="vo-windUp", postfix="_middle",},
        },
      },
      hit_l={
        done=true,
        events={
          { frame=0, name="hit", postfix="_middle",},
          { frame=0, name="vo-hit", postfix="_middle",},
        },
      },
      hit_r={
        done=true,
        events={
          { frame=0, name="hit", postfix="_middle",},
          { frame=0, name="vo-hit", postfix="_middle",},
        },
      },
      idle={
        done=true,
        events={
          { frame=11, name="sfx-blink", postfix="_middle",},
          { frame=29, name="sfx-blink", postfix="_middle",},
          { frame=36, name="sfx-blink", postfix="_middle",},
        },
      },
      idle_blink={
        done=true,
        events={
          { frame=11, name="sfx-blink", postfix="_middle",},
          { frame=29, name="sfx-blink", postfix="_middle",},
          { frame=36, name="sfx-blink", postfix="_middle",},
          { frame=58, name="sfx-blink", postfix="_middle",},
          { frame=65, name="sfx-blink", postfix="_middle",},
        },
      },
    },
    treemon_bank={
      behavior1={
        events={
          { frame=4, name="sfx-shake",},
          { frame=12, name="sfx-shake",},
          { frame=15, name="sfx-shake",},
          { frame=21, name="sfx-shake",},
          { frame=26, name="sfx-shake",},
          { frame=32, name="sfx-shake",},
          { frame=36, name="sfx-shake",},
        },
      },
      hit_l_pst={ events={ { frame=2, name="sfx-shake",},},},
      hit_r_pst={ events={ { frame=1, name="sfx-shake",},},},
      idle={
        events={
          { frame=12, name="sfx-blink",},
          { frame=30, name="sfx-blink",},
          { frame=38, name="sfx-blink",},
          { frame=59, name="sfx-blink",},
          { frame=67, name="sfx-blink",},
        },
      },
      root={ events={ { frame=2, name="sfx-root",},},},
      shoot={ events={ { frame=9, name="sfx_shoot",},},},
      shoot_hold={ events={ { frame=1, name="sfx-shoot-hold",},},},
      shoot_loop={ events={ { frame=9, name="sfx_shoot",},},},
      shoot_pst={ events={ { frame=4, name="sfx-shake",},},},
      uproot={ events={ { frame=11, name="sfx-uproot",}, { frame=11, name="sfx-shake",},},},
      uproot_loop={ events={ { frame=8, name="sfx-shake",}, { frame=16, name="sfx-shake",},},},
    },
  },
  prefab={ { prefab="treemon",},},
}
