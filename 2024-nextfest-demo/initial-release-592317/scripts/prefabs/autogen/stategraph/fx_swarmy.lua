-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_swarmy",
  isfinal=true,
  prefab={ "swarmy",},
  stategraphs={
    sg_swarmy={
      sg_events={
        {
          eventtype="spawneffect",
          name="vfx-acid_burst",
          param={ fxname="fx_ring_liquid", scalex=1.8999999761581, scalez=1.8999999761581,},
        },
        {
          eventtype="spawneffect",
          name="vfx-acid_burst",
          param={ fxname="fx_swarmy_acid_burst", scalex=1.3500000238419, scalez=1.3500000238419,},
        },
        {
          eventtype="spawnparticles",
          name="vfx-acid_dash",
          param={
            ischild=true,
            particlefxname="swarmy_dash_trail",
            render_in_front=true,
            stopatexitstate=true,
            use_entity_facing=true,
          },
        },
      },
    },
  },
}
