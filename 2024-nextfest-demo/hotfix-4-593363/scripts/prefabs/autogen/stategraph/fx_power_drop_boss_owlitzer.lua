-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_power_drop_boss_owlitzer",
  group="power_drops_group",
  isfinal=true,
  prefab={ "soul_drop_boss_owlitzer",},
  stategraphs={
    sg_rotating_drop={
      events={
        idle={
          {
            eventtype="spawnparticles",
            frame=1,
            param={
              followsymbol="swap_fx",
              ischild=true,
              name="power_idle_sparkles",
              particlefxname="power_drop_generic",
              render_in_front=true,
            },
          },
        },
      },
    },
  },
}
