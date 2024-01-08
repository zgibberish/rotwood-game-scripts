-- Generated by PropEditor and loaded by prop_autogen.lua
return {
  __displayName="chemist",
  clickable=true,
  gridsize={ { expand={ bottom=2,}, h=5, w=8,},},
  group="town_buildings",
  looping=true,
  nonpersist=true,
  parallax={
    { anim="1", dist=-1.3, shadow=true,},
    { anim="2", dist=-0.6,},
    { anim="3", dist=-0.35,},
    { anim="4", dist=-0.2,},
    { anim="5", shadow=true,},
    { anim="6", dist=0.5, shadow=true,},
    { anim="7", dist=1, shadow=true,},
  },
  parallax_use_baseanim_for_idle=true,
  physicssize=2.5,
  physicstype="dec",
  randomstartframe=true,
  script="buildings",
  script_args={
    skins={
      groups={  },
      sets={ "viking",},
      symbols={ "gate", "inside", "pot", "sign", "steps",},
    },
    upgrades={  },
  },
  sound=true,
}
