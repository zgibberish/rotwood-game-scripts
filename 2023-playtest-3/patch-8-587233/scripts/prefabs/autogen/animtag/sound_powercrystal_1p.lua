-- Generated by AnimTagger and loaded by animtag_autogen.lua
return {
  __displayName="sound_powercrystal_1p",
  anim_events={
    power_drop_generic={
      idle={
        done=true,
        events={
          { frame=0, name="sfx-rattle", postfix="_1",},
          { frame=15, name="sfx-rattle", postfix="_1",},
          { frame=45, name="sfx-rattle", postfix="_1",},
          { frame=84, name="sfx-rattle", postfix="_1",},
          { frame=119, name="sfx-rattle", postfix="_1",},
        },
      },
      shatter={
        done=true,
        events={
          { frame=1, name="sfx-rumble", postfix="_1",},
          { frame=10, name="sfx-shatter_crystal", postfix="_1",},
          { frame=10, name="sfx-shatter_tail", postfix="_1",},
        },
      },
      spawn={
        done=true,
        events={
          { frame=1, name="sfx-energy", postfix="_1",},
          { frame=5, name="sfx-crystallize", postfix="_1",},
          { frame=34, name="sfx-ping", postfix="_1",},
        },
      },
    },
  },
  prefab={
    { baseanim="1", prefab="power_drop_generic_1p",},
    { baseanim="2", prefab="power_drop_generic_2p",},
    { baseanim="3", prefab="power_drop_generic_3p",},
    { baseanim="4", prefab="power_drop_generic_4p",},
  },
}