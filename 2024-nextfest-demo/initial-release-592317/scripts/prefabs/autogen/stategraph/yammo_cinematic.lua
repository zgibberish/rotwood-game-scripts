-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="yammo_cinematic",
  prefab={ "yammo", "yammo_elite",},
  stategraphs={
    sg_yammo={
      events={
        introduction={
          { eventtype="letterbox", frame=1, param={ duration=250.0,},},
          {
            eventtype="blurscreen",
            frame=1,
            param={
              blend=0.20000000298023,
              modename="Radial",
              radius=0.5,
              reset_on_exit=true,
              strength=0.25,
            },
          },
          { eventtype="shakecamera", frame=116, param={ duration=45.5, mode="FULL",},},
          { eventtype="shakecamera", frame=100, param={ duration=17.5, mode="FULL",},},
          { eventtype="shakecamera", frame=86, param={ duration=16.0, mode="FULL",},},
          { eventtype="titlecard", frame=1, param={ duration=180.0, titlekey="yammo",},},
          {
            eventtype="cameratargetoverride",
            frame=1,
            param={ dist=25.145999908447, duration=250.0, offsetx=0.0, offsety=9.4890003204346,},
          },
          { eventtype="uihidehud", frame=1, param={ duration=250.0,},},
          { eventtype="disableplayinput", frame=1, param={ duration=464.0,},},
        },
      },
    },
  },
}
