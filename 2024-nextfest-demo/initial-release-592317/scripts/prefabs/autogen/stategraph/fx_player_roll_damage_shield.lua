-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_player_roll_damage_shield",
  isfinal=true,
  prefab={ "fx_player_roll_damage_shield",},
  stategraphs={
    fx_player_roll_damage_shield={
      events={
        idle={
          {
            eventtype="spawnparticles",
            frame=0,
            param={
              detachatexitstate=true,
              duration=30.0,
              ischild=true,
              name="roll1",
              particlefxname="roll_shield_trail",
              stopatexitstate=true,
            },
          },
        },
      },
    },
  },
}