-- Generated by CineEditor and loaded by cine_autogen.lua
return {
  __displayName="cine_town_spawn_abandon",
  pause_role_sg={  },
  scene_duration=90.0,
  scene_init={  },
  subactors={  },
  timelines={
    attachswipefx={  },
    blurscreen={  },
    cameradist={
      { 0, 1, { eventtype="cameradist", param={ cut=true, dist=22.0, duration=1,},},},
      {
        25,
        80,
        {
          eventtype="cameradist",
          param={
            curve={
              0.0,
              0,
              0.14285714924335,
              0.049515571445227,
              0.28571429848671,
              0.1882551163435,
              0.4285714328289,
              0.38873952627182,
              0.57142859697342,
              0.61126053333282,
              0.71428573131561,
              0.81174492835999,
              0.85714286565781,
              0.95048445463181,
              1.0,
              1.0,
            },
            duration=55,
          },
        },
      },
    },
    cameraoffset={  },
    camerapitch={
      { 0, 1, { eventtype="camerapitch", param={ cut=true, duration=1, pitch=16.0,},},},
      {
        37,
        80,
        {
          eventtype="camerapitch",
          param={
            curve={
              0.0,
              0,
              0.14285714924335,
              0.049515571445227,
              0.28571429848671,
              0.1882551163435,
              0.4285714328289,
              0.38873952627182,
              0.57142859697342,
              0.61126053333282,
              0.71428573131561,
              0.81174492835999,
              0.85714286565781,
              0.95048445463181,
              1.0,
              1.0,
            },
            duration=43,
            pitch=23.578178405762,
          },
        },
      },
    },
    cameratargetbegin={
      {
        0,
        1,
        {
          eventtype="cameratargetbegin",
          param={ cut=true, duration=1,},
          target_role="players",
        },
      },
    },
    cameratargetend={
      {
        25,
        90,
        {
          apply_to_all_players=true,
          eventtype="cameratargetend",
          param={
            curve={
              0.0,
              0,
              0.14285714924335,
              0.040816329419613,
              0.28571429848671,
              0.16326531767845,
              0.4285714328289,
              0.36734694242477,
              0.57142859697342,
              0.63265311717987,
              0.71428573131561,
              0.83673471212387,
              0.85714286565781,
              0.95918369293213,
              1.0,
              1.0,
            },
            duration=65,
          },
          target_role="players",
        },
      },
    },
    cameratargetoverride={  },
    detachswipefx={  },
    disableplayinput={ { 0, 90.0, { eventtype="disableplayinput", param={  },},},},
    facing={  },
    fade={
      {
        0,
        19,
        { eventtype="fade", param={ duration=19, fade_in=true, fade_type="black",},},
      },
    },
    gameevent={  },
    gotostate={
      {
        81,
        90.0,
        {
          apply_to_all_players=true,
          eventtype="gotostate",
          param={ statename="idle",},
          target_role="players",
        },
      },
    },
    letterbox={ { 0, 29, { eventtype="letterbox", param={ duration=29,},},},},
    lightintensity={  },
    movetopoint={  },
    musicbosspause={  },
    musicbossstart={  },
    musicbossstop={  },
    playcountedsound={  },
    playfoleysound={  },
    playsound={
      {
        0,
        2,
        {
          eventtype="playsound",
          param={
            autostop=true,
            duration=2,
            soundevent="flying_machine_short",
            stopatexitstate=true,
          },
        },
      },
      {
        16,
        37,
        {
          eventtype="playsound",
          param={
            autostop=true,
            duration=21,
            soundevent="flying_machine_Ratchet_LP",
            stopatexitstate=true,
          },
        },
      },
      {
        45,
        54,
        {
          eventtype="playsound",
          param={ duration=9, soundevent="flying_machine_claw_open",},
        },
      },
      {
        55,
        64,
        { eventtype="playsound", param={ duration=9, soundevent="Dirt_bodyfall",},},
      },
    },
    playsound_window={  },
    pushanim={
      {
        0,
        18,
        {
          apply_to_all_players=true,
          eventtype="pushanim",
          param={ anim="claw_blank", duration=18,},
          target_role="players",
        },
      },
      {
        19,
        72,
        {
          apply_to_all_players=true,
          eventtype="pushanim",
          param={ anim="claw_abandon_drop", duration=53,},
          target_role="players",
        },
      },
      {
        73,
        81,
        {
          apply_to_all_players=true,
          eventtype="pushanim",
          param={ anim="claw_abandon_drop_pst", duration=8,},
          target_role="players",
        },
      },
    },
    runintoscene={  },
    setsheathed={
      {
        0,
        4,
        {
          apply_to_all_players=false,
          eventtype="setsheathed",
          param={ duration=4, sheathed=true,},
          target_role="players",
        },
      },
    },
    setsoundparameter={  },
    setvisible={  },
    shakecamera={  },
    spawneffect={  },
    spawnimpactfx={  },
    spawnparticles={  },
    stopallsounds={  },
    stopparticles={  },
    stopsound={  },
    teleport={  },
    titlecard={  },
    uibosshealthbar={  },
    uihidehud={ { 0, 39, { eventtype="uihidehud", param={ duration=39,},},},},
  },
}
