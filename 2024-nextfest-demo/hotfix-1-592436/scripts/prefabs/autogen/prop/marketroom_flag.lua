-- Generated by PropEditor and loaded by prop_autogen.lua
return {
  __displayName="marketroom_flag",
  bloom=62.0,
  bloomtargets={ { name="lamp", type="Layer",},},
  children={  },
  clickable=true,
  glowcolor="CB69C6FF",
  gridsize={ { h=1, w=1,},},
  group="shop_props",
  lightoverride=67.0,
  lighttargets={ { name="lamp", type="Layer",},},
  looping=true,
  parallax={ { anim="main", shadow=true,},},
  parallax_use_baseanim_for_idle=true,
  physicssize=0.7,
  physicstype="dec",
  placer=true,
  randomstartframe=true,
  script_args={
    skins={
      groups={
        { name="Tent", symbols={ "tentsheet",},},
        { name="Rib", symbols={ "tentplank", "flagpost", "flagbanner", "flagwave",},},
        { name="Wagon", symbols={ "wagon",},},
        { name="Front", symbols={ "sign", "stand",},},
        ["3"]={ "sign", "stand",},
        ["4"]={ "tentsheet",},
        Rib={ "flagpost", "tentplank", "flagbanner", "flagwave",},
        Wagon={ "wagon",},
      },
      sets={ "bone", "cottage", "viking", "ocean",},
      symbols={
        "flagbanner",
        "flagpost",
        "flagwave",
        "sign",
        "stand",
        "tentplank",
        "tentsheet",
        "wagon",
      },
    },
    upgrades={  },
  },
  sound=true,
}
