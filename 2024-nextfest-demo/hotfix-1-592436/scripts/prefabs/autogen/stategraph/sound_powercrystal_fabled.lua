-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="sound_powercrystal_fabled",
  isfinal=true,
  needSoundEmitter=true,
  prefab={ "power_drop_electric", "power_drop_shield", "power_drop_summon",},
  stategraphs={
    sg_rotating_drop={
      events={
        despawn={ { eventtype="stopsound", frame=10, param={ name="sfx-rumble",},},},
        idle={
          {
            eventtype="playsound",
            frame=1,
            param={ soundevent="powerCrystal_idle_LP", stopatexitstate=true,},
          },
        },
        spawn={ { eventtype="stopsound", frame=34, param={ name="sfx-energy",},},},
      },
      sg_events={
        {
          eventtype="playsound",
          name="sfx-shatter_crystal",
          param={ soundevent="powerCrystal_shatter_crystal",},
        },
        {
          eventtype="playsound",
          name="sfx-crystallize",
          param={ soundevent="powerCrystal_spawn_crystallize",},
        },
        {
          eventtype="playsound",
          name="sfx-ping",
          param={ soundevent="powerCrystal_spawn_impact",},
        },
        {
          eventtype="playsound",
          name="sfx-energy",
          param={
            name="sfx-energy",
            sound_max_count=1.0,
            soundevent="powerCrystal_spawn_energy",
            stopatexitstate=true,
            stopatstateexit=true,
          },
        },
        {
          eventtype="playsound",
          name="sfx-rumble",
          param={ name="sfx-rumble", soundevent="powerCrystal_rumble",},
        },
        {
          eventtype="playsound",
          name="sfx-shatter_tail",
          param={ sound_max_count=1.0, soundevent="powerCrystal_shatter_tail",},
        },
      },
    },
  },
}
