-- Generated by PropEditor and loaded by prop_autogen.lua
return {
  __displayName="chemist_1",
  bloom=100.0,
  bloomtargets={ { name="BLOOM_ME", type="Layer",},},
  clickable=true,
  gridsize={ { expand={ bottom=2,}, h=3, w=3,},},
  group="town_buildings",
  nonpersist=true,
  parallax={
    { anim="step", dist=-0.8, shadow=true,},
    { anim="stepback", dist=-0.68, shadow=true,},
    { anim="sign", dist=-0.26,},
    { anim="cauldron", dist=-0.1, shadow=true,},
    { anim="fire", shadow=true,},
    { anim="back", dist=0.3,},
  },
  parallax_use_baseanim_for_idle=true,
  physicssize=1.5,
  physicstype="dec",
  script="buildings",
  script_args={
    skins={ groups={  }, sets={  }, symbols={  },},
    upgrades={ has_upgrade=true, prefab="chemist",},
  },
  sound=true,
}
