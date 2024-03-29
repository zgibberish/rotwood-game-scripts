-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_mothball_teen_elite",
  isfinal=true,
  prefab={ "mothball_teen_elite",},
  stategraphs={
    sg_mothball_teen={
      events={
        attack={
          {
            eventtype="spawneffect",
            frame=0,
            param={
              fxname="mothball_teen_attack_loop",
              inheritrotation=true,
              scalex=1.2000000476837,
              scalez=1.2000000476837,
              stopatexitstate=true,
            },
          },
        },
        attack_pre={  },
        attack_pst={  },
        escape={  },
      },
      sg_events={
        {
          eventtype="spawneffect",
          name="vfx-attack_loopzzz",
          param={ fxname="mothball_teen_attack_loop", inheritrotation=true, stopatexitstate=true,},
        },
        {
          eventtype="spawneffect",
          name="vfx-attack_pre",
          param={
            fxname="mothball_teen_attack_pre",
            inheritrotation=true,
            scalex=1.2000000476837,
            scalez=1.2000000476837,
            stopatexitstate=true,
          },
        },
        {
          eventtype="spawneffect",
          name="vfx-attack_pst",
          param={
            fxname="mothball_teen_attack_pst",
            inheritrotation=true,
            scalex=1.2000000476837,
            scalez=1.2000000476837,
            stopatexitstate=true,
          },
        },
      },
      state_events={
        attack={  },
        attack_pst={  },
        escape={
          {
            eventtype="spawneffect",
            name="vfx-walk_loop_escape-removed",
            param={
              fxname="mothball_teen_escape",
              inheritrotation=true,
              ischild=true,
              stopatexitstate=true,
            },
          },
          {
            eventtype="spawnparticles",
            name="vfx-walk_loop_escape-removed",
            param={
              duration=60.0,
              ischild=true,
              particlefxname="projectile_magic_trail_2",
              stopatexitstate=true,
              use_entity_facing=true,
            },
          },
        },
      },
    },
  },
}
