-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_traveling_potion_cauldron",
  isfinal=true,
  prefab={ "traveling_potion_cauldron",},
  stategraphs={
    sg_healing_fountain={
      events={
        idle={
          {
            eventtype="spawnparticles",
            frame=1,
            param={
              followsymbol="swap_fx",
              name="idle_particle",
              offx=0.0,
              offy=0.0,
              offz=0.090000003576279,
              particlefxname="heal_cauldron_idle",
            },
          },
        },
      },
      sg_events={
        {
          eventtype="stopparticles",
          name="vfx-stop_idle_particle",
          param={ name="idle_particle",},
        },
        {
          eventtype="spawnparticles",
          name="vfx-finish",
          param={
            duration=30.0,
            offx=0.0,
            offy=1.6299999952316,
            offz=0.0,
            particlefxname="liquid_burst_traveling_potion_cauldron",
          },
        },
      },
    },
  },
}
