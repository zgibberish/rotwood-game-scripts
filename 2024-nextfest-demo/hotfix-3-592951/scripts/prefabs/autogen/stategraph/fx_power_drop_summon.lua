-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_power_drop_summon",
  group="power_drops_group",
  isfinal=true,
  prefab={ "power_drop_summon",},
  stategraphs={
    sg_rotating_drop={
      events={
        idle={
          {
            eventtype="spawnparticles",
            frame=1,
            param={
              followsymbol="swap_fx",
              name="power_idle_sparkles",
              particlefxname="power_drop_generic",
              stopatexitstate=true,
            },
          },
        },
      },
    },
  },
}
