-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_retaliation_player",
  isfinal=true,
  prefab={ "fx_relics_retaliation_player",},
  stategraphs={
    fx_relics_retaliation_player={
      events={
        idle={
          {
            eventtype="spawnparticles",
            frame=1,
            param={
              duration=60.0,
              offx=0.0,
              offy=1.0,
              offz=0.0,
              particlefxname="retaliation_burst_player",
              render_in_front=true,
            },
          },
        },
      },
    },
    fx_relics_retaliation_target={
      events={
        idle={
          {
            eventtype="spawnparticles",
            frame=1,
            param={ duration=60.0, particlefxname="retaliation_burst",},
          },
        },
      },
    },
  },
}