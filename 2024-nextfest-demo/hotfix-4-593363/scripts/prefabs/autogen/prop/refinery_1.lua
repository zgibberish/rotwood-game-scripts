-- Generated by PropEditor and loaded by prop_autogen.lua
return {
  __displayName="refinery_1",
  clickable=true,
  gridsize={ { h=3, w=3,},},
  group="town_buildings",
  looping=true,
  nonpersist=true,
  parallax={
    { anim="front", dist=-0.30000001192093, shadow=true,},
    { anim="orb", dist=-0.20000000298023, shadow=true,},
    { anim="tree", shadow=true,},
    { anim="dirt", dist=0.050000000745058, shadow=true,},
    { anim="back", dist=0.20000000298023, shadow=true,},
    { anim="pipe", dist=0.40000000596046, shadow=true,},
  },
  parallax_use_baseanim_for_idle=true,
  physicssize=1.5,
  physicstype="dec",
  randomstartframe=true,
  script="buildings",
  script_args={
    skins={ groups={  }, sets={  }, symbols={  },},
    upgrades={ has_upgrade=true, prefab="refinery",},
  },
  sound=true,
}
