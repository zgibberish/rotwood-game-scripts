-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_ground_indicator_ring_p1",
  isfinal=true,
  prefab={ "ground_indicator_ring_p1",},
  stategraphs={
    ground_indicator_ring_p1={
      events={
        idle={
          {
            eventtype="spawneffect",
            frame=13,
            param={ fxname="ground_indicator_beam_p1", ischild=true, stopatexitstate=true,},
          },
        },
      },
    },
  },
}
