-- Generated by PropEditor and loaded by prop_autogen.lua
return {
  __displayName="power_upgrader",
  bloom=75.0,
  bloomtargets={ { name="bloom_me", type="Layer",},},
  clickable=true,
  glowcolor="FF3C00FF",
  gridsize={ { expand={ bottom=2,}, h=5, w=5,},},
  group="shop_props",
  looping=true,
  parallax={
    { anim="1", dist=-0.8,},
    { anim="2", dist=-0.6,},
    { anim="3", dist=-0.5,},
    { anim="4", dist=-0.4, shadow=true,},
    { anim="5", shadow=true,},
    { anim="6", dist=0.2, shadow=true,},
    { anim="7", dist=0.4, shadow=true,},
  },
  parallax_use_baseanim_for_idle=true,
  physicssize=2.5,
  physicstype="dec",
  placer=true,
  randomstartframe=true,
  script="buildings",
  script_args={ skins={ groups={  }, sets={  }, symbols={  },}, upgrades={  },},
  sound=true,
}
