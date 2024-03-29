-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_gnarlic",
  isfinal=true,
  prefab={ "gnarlic",},
  stategraphs={
    sg_gnarlic={
      sg_events={
        {
          eventtype="spawnimpactfx",
          name="vfx-spawn_impact",
          param={ impact_size=1, impact_type=1, offx=0.0, offz=0.0,},
        },
        {
          eventtype="spawnparticles",
          name="vfx-poke_run_pre_impact",
          param={
            duration=90.0,
            offx=0.0,
            offy=0.0,
            offz=-0.18999999761581,
            particlefxname="impact_gnarlic_faceplant",
          },
        },
        {
          eventtype="spawnparticles",
          name="vfx-poke_run_loop_dust",
          param={
            ischild=true,
            name="dust_loop",
            offx=0.0,
            offy=0.0,
            offz=-0.20000000298023,
            particlefxname="dust_footstep_run_forest",
            stopatexitstate=true,
          },
        },
        {
          eventtype="spawneffect",
          name="vfx-poke_run_pre_impact",
          param={
            fxname="fx_gnarlic_ground_faceplant",
            inheritrotation=true,
            scalex=0.60000002384186,
            scalez=0.60000002384186,
          },
        },
        {
          eventtype="spawneffect",
          name="vfx-poke_pst_ring",
          param={
            fxname="fx_gnarlic_ground_faceplant",
            inheritrotation=true,
            offx=0.76999998092651,
            offy=0.0,
            offz=0.0,
            scalex=0.60000002384186,
            scalez=0.60000002384186,
          },
        },
      },
    },
  },
}
