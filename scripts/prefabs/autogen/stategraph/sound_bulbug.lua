-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="sound_bulbug",
  group="sound_creature",
  isfinal=true,
  needSoundEmitter=true,
  prefab={ "bulbug", "bulbug_elite",},
  stategraphs={
    sg_bulbug={
      sg_events={
        {
          eventtype="playsound",
          name="sfx-knockdown",
          param={ autostop=true, soundevent="Knockdown",},
        },
        {
          eventtype="playsound",
          name="sfx-whoosh",
          param={ autostop=true, soundevent="bulbug_jump",},
        },
        {
          eventtype="playsound",
          name="sfx-vo",
          param={ autostop=true, soundevent="bulbug_vo",},
        },
        { eventtype="playsound", name="sfx-sheild", param={ soundevent="bulbug_sheild",},},
        { eventtype="playsound", name="sfx-chat", param={ soundevent="bulbug_chat",},},
        {
          eventtype="playfoleysound",
          name="sfx-footstep",
          param={ soundtag="Footstep", volume=27.0,},
        },
      },
    },
  },
}
