-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_death_floracrane_elite",
  isfinal=true,
  prefab={ "death_floracrane_elite_frnt",},
  stategraphs={
    death_floracrane_elite_frnt={
      events={
        idle={
          {
            eventtype="spawnparticles",
            frame=1,
            param={
              detachatexitstate=true,
              duration=90.0,
              name="feathers",
              offx=0.059999998658895,
              offy=1.2400000095367,
              offz=0.0,
              particlefxname="hit_floracrane_elite",
            },
          },
        },
      },
    },
    death_floracrane_frnt={
      events={
        idle={
          {
            eventtype="spawnparticles",
            frame=1,
            param={ detachatexitstate=true, duration=90.0, particlefxname="hit_floracrane",},
          },
        },
      },
    },
  },
}
