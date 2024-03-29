-- Generated by CineEditor and loaded by cine_autogen.lua
return {
  __displayName="cine_main_defeat_megatreemon_intro",
  leadprefab="npc_scout",
  pause_role_sg={  },
  scene_duration=190.0,
  scene_init={  },
  subactors={  },
  timelines={
    attachswipefx={  },
    blurscreen={  },
    cameradist={
      { 0, 1, { eventtype="cameradist", param={ cut=true, dist=15.0, duration=1,},},},
      {
        45,
        100,
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
        45,
        100,
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
            duration=55,
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
        160,
        190,
        {
          eventtype="cameratargetend",
          param={
            curve={
              0.0,
              0,
              0.14285714924335,
              0.14285714924335,
              0.28571429848671,
              0.28571429848671,
              0.4285714328289,
              0.4285714328289,
              0.57142859697342,
              0.57142859697342,
              0.71428573131561,
              0.71428573131561,
              0.85714286565781,
              0.85714286565781,
              1.0,
              1.0,
            },
            duration=30,
          },
          target_role="players",
        },
      },
    },
    cameratargetoverride={  },
    detachswipefx={  },
    disableplayinput={ { 0, 151.0, { eventtype="disableplayinput", param={ duration=151,},},},},
    facing={
      {
        0,
        3,
        {
          eventtype="facing",
          param={ duration=3, facing="toward_players",},
          target_role="lead",
        },
      },
    },
    fade={
      {
        0,
        60,
        { eventtype="fade", param={ duration=60, fade_in=true, fade_type="black",},},
      },
    },
    gameevent={  },
    gotostate={
      {
        170,
        190.0,
        { eventtype="gotostate", param={ statename="greet",}, target_role="lead",},
      },
    },
    letterbox={ { 0, 42, { eventtype="letterbox", param={ duration=42,},},},},
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
        10,
        {
          eventtype="playsound",
          param={
            autostop=true,
            duration=10,
            name="Snapshot_MainQuest_Intro",
            sound_max_count=1.0,
            soundevent="Snapshot_MainQuest_Intro",
            stopatexitstate=true,
          },
          target_role="lead",
        },
      },
      {
        10,
        20,
        {
          eventtype="playsound",
          param={ duration=10, soundevent="Cutscene_FadeUpFromBlack",},
          target_role="lead",
        },
      },
    },
    playsound_window={  },
    pushanim={
      {
        1,
        110,
        {
          eventtype="pushanim",
          param={ anim="knockdown_idle", duration=109, interrupt=true,},
          target_role="players",
        },
      },
      {
        110,
        115,
        {
          eventtype="pushanim",
          param={ anim="getup_pre", duration=5, interrupt=true,},
          target_role="players",
        },
      },
      {
        115,
        131,
        {
          eventtype="pushanim",
          param={ anim="getup_struggle", duration=16,},
          target_role="players",
        },
      },
      {
        131,
        139,
        {
          eventtype="pushanim",
          param={ anim="getup_pst", duration=8,},
          target_role="players",
        },
      },
      {
        139,
        151,
        {
          eventtype="pushanim",
          param={ anim="hammer_unsheathe_fast", duration=12,},
          target_role="players",
        },
      },
      {
        151,
        190.0,
        {
          eventtype="pushanim",
          param={ anim="hammer_idle", loop=true,},
          target_role="players",
        },
      },
    },
    runintoscene={  },
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
    uihidehud={  },
  },
  use_lead_actor_pos=true,
}
