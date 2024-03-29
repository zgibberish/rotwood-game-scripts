-- Generated by AnimTagger and loaded by animtag_autogen.lua
return {
  __displayName="sound_megatreemon",
  anim_events={
    megatreemon_bank={
      charge={ events={ { frame=25, name="foley",},},},
      death={
        events={
          { frame=1, name="sfx-death_yell",},
          { frame=103, name="sfx-death_eye",},
          { frame=133, name="sfx-death_fall",},
        },
      },
      defend_loop={ events={ { frame=1, name="defend",},},},
      defend_pre={
        events={
          { frame=10, name="foley",},
          { frame=28, name="foley",},
          { frame=49, name="foley",},
        },
      },
      defend_pst={ events={ { frame=5, name="foley",},},},
      defend_tell={ events={ { frame=10, name="sfx-swipe_pre",},},},
      flail_loop={
        events={
          { frame=1, name="fail",},
          { frame=7, name="foley",},
          { frame=14, name="foley",},
        },
      },
      flail_pre={ events={ { frame=8, name="foley",},},},
      hit_l={ events={ { frame=1, name="hit",}, { frame=4, name="foley",},},},
      hit_l_hold={ events={ { frame=0, name="vo-hit",},},},
      hit_r={ events={ { frame=1, name="hit",}, { frame=3, name="foley",},},},
      hit_r_hold={ events={ { frame=0, name="vo-hit",},},},
      idle={
        events={
          { frame=1, name="foley_quiet",},
          { frame=7, name="foley_quiet",},
          { frame=15, name="foley_quiet",},
          { frame=22, name="vo_quiet",},
          { frame=25, name="foley_quiet",},
        },
      },
      idle_blink={
        events={
          { frame=4, name="snap",},
          { frame=5, name="foley_quiet",},
          { frame=6, name="snap",},
          { frame=15, name="foley_quiet",},
          { frame=25, name="foley_quiet",},
        },
      },
      idle_eye={
        events={
          { frame=6, name="sfx-eye",},
          { frame=8, name="sfx-eye",},
          { frame=13, name="sfx-eye",},
          { frame=16, name="sfx-eye",},
          { frame=21, name="sfx-eye",},
          { frame=25, name="sfx-eye",},
          { frame=26, name="sfx-eye",},
        },
      },
      intro={
        events={
          { frame=10, name="intro_snap",},
          { frame=19, name="sfx-eye",},
          { frame=21, name="intro_snap",},
          { frame=25, name="sfx-eye",},
          { frame=26, name="intro_snap",},
          { frame=29, name="sfx-eye",},
          { frame=32, name="intro_snap",},
          { frame=34, name="sfx-eye",},
          { frame=45, name="sfx-eye",},
          { frame=47, name="sfx-eye",},
          { frame=60, name="intro_swipe_pre",},
          { frame=62, name="intro_foley",},
          { frame=68, name="intro_foley",},
          { frame=75, name="intro_foley",},
          { frame=81, name="intro_foley",},
          { frame=86, name="intro_foley",},
          { frame=89, name="intro_spike_pre",},
          { frame=92, name="intro_spike_impact",},
          { frame=94, name="intro_spike_pre",},
          { frame=97, name="intro_spike_impact",},
          { frame=102, name="intro_foley",},
          { frame=109, name="intro_root_pst",},
          { frame=112, name="intro_foley",},
          { frame=114, name="intro_spike_impact",},
          { frame=118, name="intro_root_pst",},
          { frame=127, name="intro_spike_impact",},
          { frame=132, name="intro_foley",},
          { frame=149, name="roar",},
        },
      },
      roar={
        events={
          { frame=1, name="roar",},
          { frame=8, name="foley",},
          { frame=35, name="foley",},
          { frame=43, name="foley",},
          { frame=56, name="foley",},
        },
      },
      swipe_l={ events={ { frame=1, name="swipe",}, { frame=5, name="foley",},},},
      swipe_l_pre={ events={ { frame=1, name="sfx-swipe_pre",}, { frame=5, name="foley",},},},
      swipe_r={
        events={
          { frame=1, name="swipe",},
          { frame=4, name="foley",},
          { frame=10, name="foley",},
        },
      },
      swipe_r_pre={ events={ { frame=1, name="sfx-swipe_pre",},},},
      throw_l={
        events={
          { frame=15, name="foley",},
          { frame=21, name="foley",},
          { frame=27, name="foley",},
          { frame=27, name="pick",},
          { frame=27, name="vo",},
        },
      },
      throw_r={
        events={
          { frame=15, name="foley",},
          { frame=21, name="foley",},
          { frame=27, name="foley",},
          { frame=27, name="pick",},
          { frame=27, name="vo",},
        },
      },
      uproot_floor_loop={
        events={
          { frame=7, name="foley",},
          { frame=17, name="foley",},
          { frame=0, name="vo-uproot_gurgle",},
        },
      },
      uproot_floor_pre={
        events={
          { frame=6, name="foley",},
          { frame=30, name="foley",},
          { frame=32, name="swipe",},
          { frame=36, name="foley",},
          { frame=8, name="vo-uproot_warn",},
        },
      },
      uproot_floor_pst={ events={ { frame=2, name="foley",},},},
      uproot_l={ events={ { frame=8, name="foley",}, { frame=24, name="foley",},},},
      uproot_l_hold={ events={ { frame=1, name="vo-uproot_warn",},},},
      uproot_l_pre={ events={ { frame=10, name="foley",},},},
      uproot_r={ events={ { frame=6, name="foley",}, { frame=24, name="foley",},},},
      uproot_r_hold={ events={ { frame=1, name="vo-uproot_warn",},},},
      uproot_r_pre={ events={ { frame=10, name="foley",},},},
    },
  },
  group="SOUND_Creature",
  prefab={ { prefab="megatreemon",},},
}
