-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="test_megatreemon",
  group="Bosses",
  prefab="megatreemon",
  stategraphs={
    sg_megatreemon={
      events={
        death={
          {
            eventtype="lightintensity",
            frame=1,
            param={
              reset_on_exit=true,
              self_intensity=0.82499998807907,
              world_intensity=0.20000000298023,
            },
          },
        },
        taunt={
          {
            eventtype="blurscreen",
            frame=0,
            param={
              blend=0.20000000298023,
              fade=true,
              fade_ticks=5.0,
              modename="Radial",
              radius=0.5,
              reset_on_exit=true,
              strength=0.25999999046326,
            },
          },
          { eventtype="letterbox", frame=20, param={ duration=10.0,},},
          {
            eventtype="titlecard",
            frame=27,
            param={ duration=7.298999786377, titlekey="megatreemon",},
          },
          { eventtype="uihidehud", frame=18, param={  },},
          { eventtype="cameratargetoverride", frame=0, param={ dist=30.0, duration=20.0,},},
        },
      },
    },
  },
}
