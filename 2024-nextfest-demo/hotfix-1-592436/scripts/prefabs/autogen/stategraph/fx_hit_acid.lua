-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_hit_acid",
  isfinal=true,
  prefab={ "hits_acid",},
  stategraphs={
    hits_acid={
      events={
        idle={
          {
            eventtype="spawnparticles",
            frame=0,
            param={ detachatexitstate=true, duration=60.0, ischild=true, particlefxname="hit_acid",},
          },
        },
      },
    },
  },
}
