-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_player_common_general",
  isfinal=true,
  prefab={ "player_side",},
  sg_wildcard=true,
  stategraphs={
    ["*"]={
      sg_events={
        {
          eventtype="spawneffect",
          name="vfx-revive_loop",
          param={
            fxname="fx_player_revive_loop",
            inheritrotation=true,
            ischild=true,
            stopatexitstate=true,
          },
        },
        {
          eventtype="spawneffect",
          name="vfx-revive_pst",
          param={
            fxname="fx_player_revive_pst",
            inheritrotation=true,
            ischild=true,
            stopatexitstate=true,
          },
        },
        {
          eventtype="spawneffect",
          name="vfx-revive_pre",
          param={
            fxname="fx_player_revive_pre",
            inheritrotation=true,
            ischild=true,
            stopatexitstate=true,
          },
        },
        {
          eventtype="spawnparticles",
          name="vfx-revive_loop",
          param={
            detachatexitstate=true,
            name="revive_l",
            offx=-0.6700000166893,
            offy=1.4299999475479,
            offz=0.0,
            particlefxname="revive_hand_motes",
            stopatexitstate=true,
          },
        },
        {
          eventtype="spawnparticles",
          name="vfx-revive_loop",
          param={
            detachatexitstate=true,
            name="revive_r",
            offx=1.1499999761581,
            offy=1.3600000143051,
            offz=0.0,
            particlefxname="revive_hand_motes",
            stopatexitstate=true,
          },
        },
      },
    },
  },
}
