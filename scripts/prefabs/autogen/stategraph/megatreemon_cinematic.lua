-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="megatreemon_cinematic",
  prefab={ "megatreemon",},
  stategraphs={
    sg_megatreemon={
      events={
        death={
          {
            eventtype="blurscreen",
            frame=1,
            param={
              blend=0.20000000298023,
              fade=true,
              fade_ticks=20.0,
              modename="Radial",
              radius=0.5,
              reset_on_exit=true,
              strength=0.5,
            },
          },
          { eventtype="cameratargetoverride", frame=1, param={ dist=30.0, duration=280.0,},},
          { eventtype="letterbox", frame=1, param={ duration=282.0,},},
          { eventtype="uihidehud", frame=1, param={ duration=278.0,},},
          { eventtype="shakecamera", frame=1, param={ duration=49.0, mode="FULL",},},
          {
            eventtype="lightintensity",
            frame=1,
            param={ reset_on_exit=true, self_intensity=1.0, world_intensity=0.29199999570847,},
          },
        },
        introduction={
          { eventtype="letterbox", frame=1, param={ duration=280.0,},},
          { eventtype="shakecamera", frame=10, param={ duration=59.5, mode="FULL",},},
          {
            eventtype="lightintensity",
            frame=1,
            param={ reset_on_exit=true, self_intensity=1.0, world_intensity=0.39800000190735,},
          },
          {
            eventtype="titlecard",
            frame=1,
            param={ duration=280.0, titlekey="megatreemon",},
          },
          { eventtype="cameratargetoverride", frame=1, param={ dist=30.0, duration=280.0,},},
          { eventtype="uihidehud", frame=1, param={ duration=280.0,},},
          {
            eventtype="blurscreen",
            frame=1,
            param={
              blend=0.03999999910593,
              fade=true,
              fade_ticks=20.0,
              modename="Radial",
              radius=0.5,
              reset_on_exit=true,
              strength=0.75,
            },
          },
          { eventtype="uihidehud", frame=1, param={ duration=280.0,},},
          { eventtype="disableplayinput", frame=1, param={ duration=280.0,},},
        },
      },
    },
  },
}