-- Generated by PropEditor and loaded by prop_autogen.lua
return {
  __displayName="power_drop_shield",
  animhistory=true,
  bank="power_drop_special",
  bankfile="power_drop_special",
  bloom=20.0,
  bloomtargets={ { name="konjur", type="Layer",}, { name="charge", type="Layer",},},
  build="power_drop_special",
  clickable=true,
  glowcolor="3700FFFF",
  group="power_drops",
  looping=true,
  nonpersist=true,
  parallax={
    { anim="shield_shadow", dist=-0.1, shadow=true,},
    { anim="shield",},
    { anim="ground", dist=0.001, onground=true,},
  },
  script="powerdrops",
  script_args={ power_category="SUSTAIN", power_family="SHIELD", power_type="FABLED_RELIC",},
}