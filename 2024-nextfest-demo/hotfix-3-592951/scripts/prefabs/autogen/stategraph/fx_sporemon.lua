-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_sporemon",
  isfinal=true,
  prefab={ "sporemon",},
  stategraphs={
    sg_sporemon={
      sg_events={
        {
          eventtype="spawnparticles",
          name="vfx-shoot",
          param={
            duration=60.0,
            offx=-0.40000000596046,
            offy=4.0,
            offz=0.0,
            particlefxname="sporemon_spore_burst",
            use_entity_facing=true,
          },
        },
      },
    },
  },
}