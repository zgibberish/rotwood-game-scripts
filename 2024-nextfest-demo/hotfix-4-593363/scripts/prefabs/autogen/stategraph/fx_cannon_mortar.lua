-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_cannon_mortar",
  isfinal=true,
  needSoundEmitter=true,
  prefab={ "player_cannon_mortar_projectile",},
  stategraphs={
    projectile_cannon_mortar={
      events={
        idle={
          {
            eventtype="spawnparticles",
            frame=1,
            param={ duration=90.0, ischild=true, particlefxname="cannon_mortar_trail",},
          },
        },
      },
    },
    sg_player_cannon_mortar_projectile={
      events={
        thrown={
          {
            eventtype="spawnparticles",
            frame=1,
            param={
              duration=90.0,
              ischild=true,
              particlefxname="cannon_mortar_trail",
              use_entity_facing=true,
            },
          },
          {
            eventtype="playsound",
            frame=1,
            param={ autostop=true, sound_max_count=1.0, soundevent="Cannon_mortar_travel",},
          },
        },
      },
    },
  },
}
