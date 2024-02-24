-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_groak",
  isfinal=true,
  prefab={ "groak",},
  stategraphs={
    sg_groak={
      events={
        groundpound={  },
        spawn_swallow={
          {
            eventtype="spawnparticles",
            frame=2,
            param={
              duration=94.0,
              offx=0.0,
              offy=0.0,
              offz=-0.0049999998882413,
              particlefxname="liquid_burst_groak",
            },
          },
        },
        swallow_loop={  },
      },
      sg_events={
        {
          eventtype="spawnimpactfx",
          frame=0,
          name="vfx-spawn_swallow",
          param={ impact_size=3, impact_type=1, offx=0.0, offz=-0.0099999997764826,},
        },
        {
          eventtype="spawnimpactfx",
          frame=0,
          name="vfx-spawn",
          param={ impact_size=3, impact_type=1, offx=0.0, offz=-0.0099999997764826,},
        },
        {
          eventtype="spawnimpactfx",
          frame=0,
          name="vfx-spawn_none",
          param={ impact_size=3, impact_type=1, offx=0.0, offz=-0.0099999997764826,},
        },
        {
          eventtype="shakecamera",
          name="vfx-groundpound",
          param={
            dist=50,
            duration=10.0,
            mode="FULL",
            scale=0.10000000149012,
            speed=0.050000000745058,
          },
        },
        {
          eventtype="spawnimpactfx",
          frame=0,
          name="vfx-groundpound",
          param={ impact_size=3, impact_type=1, offx=1.7000000476837, offz=-0.019999999552965,},
        },
        {
          eventtype="spawnimpactfx",
          frame=0,
          name="vfx-groundpound",
          param={ impact_size=3, impact_type=1, offx=-1.7000000476837, offz=-0.019999999552965,},
        },
        {
          eventtype="spawneffect",
          name="vfx-groundpound",
          param={
            fxname="groak_slam_groundring",
            offx=0.0,
            offy=0.0,
            offz=0.0,
            scalex=3.0,
            scalez=3.0,
          },
        },
        {
          eventtype="spawneffect",
          name="vfx-swallow_no",
          param={
            fxname="fx_groak_swallow_pst",
            inheritrotation=true,
            ischild=true,
            stopatexitstate=true,
          },
        },
        {
          eventtype="spawneffect",
          name="vfx-swallow_yes",
          param={
            fxname="fx_groak_swallow_pst",
            inheritrotation=true,
            ischild=true,
            stopatexitstate=true,
          },
        },
        {
          eventtype="spawneffect",
          name="vfx-swallow",
          param={
            fxname="fx_groak_swallow_pre",
            inheritrotation=true,
            ischild=true,
            stopatexitstate=true,
          },
        },
        {
          eventtype="spawnimpactfx",
          name="vfx-groundpound_loop1",
          param={ impact_size=1, impact_type=1, offx=-2.5, offz=0.0,},
        },
        {
          eventtype="spawnimpactfx",
          name="vfx-groundpound_loop2",
          param={ impact_size=1, impact_type=1, offx=2.5, offz=0.0,},
        },
        {
          eventtype="spawnparticles",
          name="vfx-groundpound_loop1",
          param={
            duration=30.0,
            offx=-2.3499999046326,
            offy=0.0,
            offz=0.0,
            particlefxname="impact_swamp_ring_groak_sml",
          },
        },
        {
          eventtype="spawnparticles",
          name="vfx-groundpound_loop2",
          param={
            duration=30.0,
            offx=2.5099999904633,
            offy=0.0,
            offz=0.0,
            particlefxname="impact_swamp_ring_groak_sml",
          },
        },
        {
          eventtype="spawnparticles",
          name="vfx-groundpound",
          param={ duration=90.0, particlefxname="impact_swamp_ring_groak_sml",},
        },
        {
          eventtype="spawneffect",
          name="vfx-swallow_loop",
          param={
            fxname="fx_groak_swallow_loop",
            inheritrotation=true,
            ischild=true,
            offx=0.0,
            offy=0.0,
            offz=-0.10000000149012,
            stopatexitstate=true,
          },
        },
      },
    },
  },
}
