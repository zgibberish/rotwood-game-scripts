-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_outfit_buy",
  isfinal=true,
  prefab={ "fx_outfit_buy",},
  stategraphs={
    fx_outfit_buy={
      events={
        idle={
          {
            eventtype="spawnparticles",
            frame=1,
            param={ detachatexitstate=true, duration=90.0, particlefxname="outfit_buy_burst",},
          },
        },
      },
    },
  },
}
