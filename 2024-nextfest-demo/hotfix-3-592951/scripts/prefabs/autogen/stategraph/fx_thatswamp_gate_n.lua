-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_thatswamp_gate_n",
  isfinal=true,
  prefab={ "thatforest_gate_n",},
  sg_wildcard=true,
  stategraphs={
    ["*"]={
      events={
        idle={  },
        open={
          {
            eventtype="spawnparticles",
            frame=1,
            param={
              offx=0.0,
              offy=0.0,
              offz=5.7199997901917,
              particlefxname="forest_gate_fog_n",
              render_in_front=true,
              stopatexitstate=true,
            },
          },
        },
      },
      sg_events={  },
    },
  },
}
