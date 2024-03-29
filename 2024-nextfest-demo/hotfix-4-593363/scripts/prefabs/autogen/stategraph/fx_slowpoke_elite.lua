-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_slowpoke_elite",
  isfinal=true,
  prefab={ "slowpoke_elite",},
  stategraphs={
    sg_slowpoke={
      events={ body_slam={  },},
      sg_events={
        {
          eventtype="spawnimpactfx",
          name="vfx-body_slam_impact",
          param={ impact_size=3, impact_type=1, offx=0.0, offz=-0.20000000298023,},
        },
        {
          eventtype="spawneffect",
          name="vfx-spawn_pst",
          param={
            fxname="slowpoke_slam_groundring",
            offx=0.0,
            offy=0.0,
            offz=0.0,
            scalex=2.5999999046326,
            scalez=2.5,
          },
        },
        {
          eventtype="spawnimpactfx",
          name="vfx-spawn_pst",
          param={ impact_size=3, impact_type=1, offx=0.0, offz=-0.20000000298023,},
        },
        {
          eventtype="spawnparticles",
          name="vfx-spawn_pst",
          param={ duration=90.0, particlefxname="impact_swamp_thatcher_rings",},
        },
        {
          eventtype="spawnparticles",
          name="vfx-elite_body_slam_loop",
          param={ duration=90.0, particlefxname="impact_swamp_thatcher_rings",},
        },
        {
          eventtype="spawneffect",
          name="vfx-elite_body_slam_loop",
          param={
            fxname="fx_acid_footstep",
            offx=-0.03999999910593,
            offy=0.34000000357628,
            offz=0.0,
            scalex=3.25,
            scalez=2.5,
          },
        },
        {
          eventtype="spawneffect",
          name="vfx-elite_body_slam_loop",
          param={
            fxname="fx_acid_projectile_land",
            inheritrotation=true,
            offx=2.8900001049042,
            offy=0.0,
            offz=0.62000000476837,
            scalex=1.5,
            scalez=1.5,
          },
        },
        {
          eventtype="spawneffect",
          name="vfx-elite_body_slam_loop",
          param={
            fxname="fx_acid_projectile_land",
            inheritrotation=true,
            offx=-1.6900000572205,
            offy=0.0,
            offz=0.87000000476837,
            scalex=1.5,
            scalez=1.5,
          },
        },
        {
          eventtype="spawneffect",
          name="vfx-elite_body_slam_loop",
          param={
            fxname="slowpoke_slam_groundring",
            offx=0.0,
            offy=0.0,
            offz=0.0,
            scalex=2.5,
            scalez=2.5,
          },
        },
        {
          eventtype="spawneffect",
          name="vfx-elite_body_slam_loopzzz",
          param={ fxname="fx_ring_liquid", offx=0.0, offy=0.0, offz=0.0, scalex=3.5, scalez=3.5,},
        },
      },
    },
  },
}
