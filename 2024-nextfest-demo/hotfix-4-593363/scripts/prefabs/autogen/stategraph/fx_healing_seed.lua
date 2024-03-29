-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_healing_seed",
  isfinal=true,
  prefab={ "gourdo_healing_seed",},
  stategraphs={
    sg_gourdo_healing_seed={
      sg_events={
        {
          eventtype="spawnimpactfx",
          name="vfx-open",
          param={ impact_size=1, impact_type=1, offx=0, offz=0,},
        },
        {
          eventtype="spawnparticles",
          name="vfx-heal",
          param={
            duration=90.0,
            offx=-0.090000003576279,
            offy=0.37000000476837,
            offz=0.0,
            particlefxname="heal_liquid_burst",
          },
        },
        {
          eventtype="spawnparticles",
          name="vfx-heal",
          param={
            duration=90.0,
            offx=-0.090000003576279,
            offy=0.37000000476837,
            offz=0.0,
            particlefxname="heal_gourdo_seed",
          },
        },
        {
          eventtype="spawnparticles",
          name="vfx-heal",
          param={ duration=30.0, offx=0.0, offy=0.0, offz=0.0, particlefxname="gourdo_seed_heal",},
        },
      },
    },
  },
}
