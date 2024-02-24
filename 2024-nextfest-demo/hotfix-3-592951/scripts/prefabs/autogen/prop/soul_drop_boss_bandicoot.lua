-- Generated by PropEditor and loaded by prop_autogen.lua
return {
  __displayName="soul_drop_boss_bandicoot",
  bank="power_drop_boss_bandicoot",
  bankfile="power_drop_boss",
  bloom=30.0,
  bloomtargets={ { name="konjur", type="Layer",}, { name="charge", type="Layer",},},
  build="power_drop_boss",
  clickable=true,
  glowcolor="3700FFFF",
  group="power_drops",
  looping=true,
  nonpersist=true,
  parallax={
    { anim="shadow", dist=-0.1, shadow=true,},
    { anim="heart",},
    { anim="ground", dist=0.001, onground=true,},
  },
  script="konjursouls",
  script_args={
    power_category="SUSTAIN",
    power_type="FABLED_RELIC",
    soul_type="konjur_heart_bandicoot",
  },
}
