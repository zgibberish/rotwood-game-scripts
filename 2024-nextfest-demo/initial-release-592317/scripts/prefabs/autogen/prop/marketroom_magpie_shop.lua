-- Generated by PropEditor and loaded by prop_autogen.lua
return {
  __displayName="marketroom_magpie_shop",
  children={  },
  clickable=true,
  gridsize={ { expand={ bottom=2,}, h=1, w=2,},},
  group="shop_props",
  parallax={
    { anim="1", shadow=true,},
    { anim="2", dist=0.10000000149012, shadow=true,},
    { anim="3", dist=0.20000000298023, shadow=true,},
    { anim="4", dist=0.40000000596046, shadow=true,},
  },
  parallax_use_baseanim_for_idle=true,
  physicssize=1,
  physicstype="dec",
  placer=true,
  script="buildings",
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