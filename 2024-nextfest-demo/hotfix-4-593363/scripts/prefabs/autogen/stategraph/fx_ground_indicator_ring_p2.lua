-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_ground_indicator_ring_p2",
  isfinal=true,
  prefab={ "ground_indicator_ring_p2",},
  stategraphs={
    ground_indicator_ring_p1={
      events={
        idle={
          {
            eventtype="spawnparticles",
            frame=1,
            param={
              offx=0.0,
              offy=0.10000000149012,
              offz=0.0,
              particlefxname="fx_ground_indicator_particle_p1",
              stopatexitstate=true,
            },
          },
        },
      },
    },
    ground_indicator_ring_p2={
      events={
        idle={
          {
            eventtype="spawneffect",
            frame=13,
            param={ fxname="ground_indicator_beam_p2", ischild=true, stopatexitstate=true,},
          },
        },
      },
    },
  },
}
