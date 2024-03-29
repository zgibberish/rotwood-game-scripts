-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_power_player_drop",
  group="power_drops_group",
  prefab="power_drop_player_aalegacy",
  stategraphs={
    sg_rotating_drop={
      events={
        despawn={
          {
            eventtype="spawnparticles",
            frame=1,
            param={
              duration=0.10000000149012,
              ischild=true,
              particlefxname="burst_bounce_rare",
              render_in_front=true,
            },
          },
        },
        idle={
          {
            eventtype="spawnparticles",
            frame=1,
            param={
              detachatexitstate=true,
              ischild=true,
              particlefxname="power_drop_crack_emitter",
              stopatexitstate=true,
            },
          },
          {
            eventtype="spawnparticles",
            frame=1,
            param={
              detachatexitstate=true,
              ischild=true,
              particlefxname="double_helix_bugtest",
              stopatexitstate=true,
            },
          },
        },
        spawn={
          {
            eventtype="spawnparticles",
            frame=8,
            param={
              duration=0.10000000149012,
              ischild=true,
              particlefxname="power_drop_finish_spark_burst",
              render_in_front=true,
            },
          },
        },
      },
    },
  },
}
