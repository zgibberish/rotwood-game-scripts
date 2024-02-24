-- Generated by PropEditor and loaded by prop_autogen.lua
return {
  __displayName="scout_tent",
  clickable=true,
  gridsize={ { expand={ bottom=2,}, h=5, w=8,},},
  group="town_buildings",
  looping=true,
  parallax={
    { anim="1", dist=-1.3, shadow=true,},
    { anim="2", dist=-0.95, shadow=true,},
    { anim="3", shadow=true,},
    { anim="4", dist=0.65, shadow=true,},
    { anim="5", dist=1.3, shadow=true,},
  },
  parallax_use_baseanim_for_idle=true,
  physicssize=2.5,
  physicstype="dec",
  placer=true,
  randomstartframe=true,
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