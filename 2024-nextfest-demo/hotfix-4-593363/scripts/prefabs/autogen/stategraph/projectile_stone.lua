-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="projectile_stone",
  isfinal=true,
  prefab={ "projectile_stone",},
  stategraphs={
    projectile_stone={
      events={
        idle={
          {
            eventtype="spawnparticles",
            frame=0,
            param={
              duration=115.0,
              ischild=true,
              offx=0.0,
              offy=1.25,
              offz=0.0,
              particlefxname="stone_projectile_trail",
            },
          },
        },
      },
    },
  },
}
