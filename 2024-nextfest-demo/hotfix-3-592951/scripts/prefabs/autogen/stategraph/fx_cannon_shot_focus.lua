-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_cannon_shot_focus",
  isfinal=true,
  prefab={ "projectile_cannon_focus",},
  stategraphs={
    projectile_cannon_focus={
      events={
        idle={
          {
            eventtype="spawnparticles",
            frame=1,
            param={
              duration=60.0,
              ischild=true,
              particlefxname="cannon_shot_trail_focus",
              use_entity_facing=true,
            },
          },
        },
      },
    },
  },
}