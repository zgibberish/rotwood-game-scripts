-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="sound_trap_acid_pool",
  isfinal=true,
  needSoundEmitter=true,
  prefab={ "trap_acid",},
  stategraphs={
    sg_trap_acid={
      events={
        loop={
          {
            eventtype="playsound",
            frame=1,
            param={ autostop=true, name="acid_LP", soundevent="acid_LP", stopatexitstate=true,},
          },
        },
      },
    },
    sg_trap_exploding={
      events={
        init={  },
        loop={
          { eventtype="playsound", frame=1, param={ autostop=true, soundevent="acid_LP",},},
        },
      },
    },
  },
}
