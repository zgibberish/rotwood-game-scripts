-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_battoad",
  isfinal=true,
  prefab={ "battoad",},
  stategraphs={
    sg_battoad={
      sg_events={
        {
          eventtype="spawneffect",
          name="vfx-slash",
          param={ fxname="fx_battoad_slash", inheritrotation=true, ischild=true,},
        },
        {
          eventtype="spawneffect",
          name="vfx-slash2",
          param={ fxname="fx_battoad_slash_2", inheritrotation=true, ischild=true,},
        },
        {
          eventtype="spawnparticles",
          name="vfx-swallow_loop",
          param={
            detachatexitstate=true,
            duration=30.0,
            ischild=true,
            particlefxname="battoad_konjur_spit",
            stopatexitstate=true,
            use_entity_facing=true,
          },
        },
        {
          eventtype="spawneffect",
          name="vfx-upperwings",
          param={ fxname="fx_battoad_upperwings", inheritrotation=true, ischild=true,},
        },
        {
          eventtype="spawneffect",
          name="vfx-upperwings_to_float",
          param={ fxname="fx_battoad_upperwings_to_float", inheritrotation=true, ischild=true,},
        },
        {
          eventtype="spawnparticles",
          name="vfx-upperwings",
          param={ duration=40.0, particlefxname="battoad_upperwings_ground_aoe",},
        },
        {
          eventtype="spawnparticles",
          name="vfx-upperwings_to_float",
          param={ duration=40.0, particlefxname="battoad_upperwings_ground_aoe",},
        },
      },
    },
  },
}
