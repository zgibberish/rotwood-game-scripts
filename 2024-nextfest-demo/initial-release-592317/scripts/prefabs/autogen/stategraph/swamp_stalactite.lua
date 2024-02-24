-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="swamp_stalactite",
  isfinal=true,
  prefab={ "swamp_stalactite",},
  stategraphs={
    sg_swamp_stalactite={
      events={
        fall={ { eventtype="stopsound", frame=1, param={ name="rumble",},},},
        land={
          { eventtype="spawneffect", frame=11, param={ fxname="fx_stalactite_land",},},
          {
            eventtype="spawneffect",
            frame=14,
            param={
              fxname="fx_dust_ground_up2_stalactite",
              offx=1.6699999570847,
              offy=0.0,
              offz=0.0,
              scalex=0.80000001192093,
              scalez=0.80000001192093,
            },
          },
          {
            eventtype="spawneffect",
            frame=11,
            param={
              fxname="fx_dust_ground_up1_stalactite",
              offx=-1.1000000238419,
              offy=0.0,
              offz=-0.40000000596046,
              scalex=0.75,
              scalez=0.75,
            },
          },
          {
            eventtype="spawneffect",
            frame=0,
            param={ fxname="fx_dust_ground_ring_stalactite", scalex=0.75, scalez=0.75,},
          },
          {
            eventtype="spawneffect",
            frame=0,
            param={ fxname="fx_dust_ground_center_stalactite", scalex=2.0, scalez=2.0,},
          },
          {
            eventtype="spawnparticles",
            frame=0,
            param={
              offx=-0.8299999833107,
              offy=0.0,
              offz=0.0,
              particlefxname="dust_burst_up2_swamp",
              render_in_front=true,
              stopatexitstate=true,
            },
          },
          {
            eventtype="spawnparticles",
            frame=0,
            param={
              offx=1.0199999809265,
              offy=0.0,
              offz=0.0,
              particlefxname="dust_burst_up2_swamp",
              render_in_front=true,
              stopatexitstate=true,
            },
          },
          {
            eventtype="spawnparticles",
            frame=14,
            param={
              offx=-1.0299999713898,
              offy=0.0,
              offz=0.0,
              particlefxname="dust_burst_up3_swamp",
              render_in_front=true,
              stopatexitstate=true,
            },
          },
          {
            eventtype="spawnparticles",
            frame=11,
            param={
              offx=0.75,
              offy=0.0,
              offz=0.0,
              particlefxname="dust_burst_up3_swamp",
              render_in_front=true,
              stopatexitstate=true,
            },
          },
        },
      },
    },
  },
}