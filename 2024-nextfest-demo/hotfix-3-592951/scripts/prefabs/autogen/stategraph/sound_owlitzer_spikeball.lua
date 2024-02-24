-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="sound_owlitzer_spikeball",
  isfinal=true,
  needSoundEmitter=true,
  prefab={ "owlitzer_spikeball",},
  stategraphs={
    sg_owlitzer_spikeball={
      events={
        death={
          { eventtype="playsound", frame=1, param={ soundevent="owlitzer_hairball_death",},},
        },
        land={
          {
            eventtype="playsound",
            frame=1,
            param={ sound_max_count=5.0, soundevent="owlitzer_barf_spike_land",},
          },
        },
        thrown={
          {
            eventtype="playsound",
            frame=1,
            param={ autostop=true, soundevent="owlitzer_hairball_spin_LP", stopatexitstate=true,},
          },
        },
      },
    },
  },
}
