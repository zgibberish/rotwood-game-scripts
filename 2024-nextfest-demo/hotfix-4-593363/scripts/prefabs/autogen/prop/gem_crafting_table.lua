-- Generated by PropEditor and loaded by prop_autogen.lua
return {
  __displayName="gem_crafting_table",
  clickable=true,
  gridsize={ { h=3, w=3,},},
  group="town_decor",
  isminimal=true,
  networked=1,
  parallax={
    { anim="front", dist=-0.20000000298023, shadow=true,},
    { anim="mid", shadow=true,},
    { anim="back", dist=0.10000000149012, shadow=true,},
    { anim="tools", dist=0.20000000298023, shadow=true,},
  },
  parallax_use_baseanim_for_idle=true,
  physicssize=2,
  physicstype="dec",
  placer=true,
  script="screenopener",
  script_args={ screen_require="screens.town.gemscreen", },
  variations=1,
}
