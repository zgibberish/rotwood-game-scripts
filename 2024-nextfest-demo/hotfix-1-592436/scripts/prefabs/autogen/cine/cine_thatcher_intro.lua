-- Generated by CineEditor and loaded by cine_autogen.lua
return {
  __displayName="cine_thatcher_intro",
  is_skippable=true,
  leadprefab="thatcher",
  pause_role_sg={ lead={ resumestate="idle",},},
  scene_duration=260.0,
  scene_init={  },
  subactors={  },
  timelines={
    blurscreen={
      {
        190,
        201,
        {
          eventtype="blurscreen",
          param={
            blend=0.20000000298023,
            curve={
              0.0,
              0,
              0.10000000149012,
              0.68000000715256,
              0.26666668057442,
              0.43500000238419,
              0.41333332657814,
              0.95999997854233,
              0.59666669368744,
              0.57499998807907,
              0.72166669368744,
              0.99000000953674,
              0.87666666507721,
              0.51999998092651,
              1.0,
              0.014999985694885,
            },
            duration=11,
            modename="Radial",
            radius=0.5,
            strength=0.30000001192093,
          },
        },
      },
    },
    cameratargetoverride={
      {
        0,
        172,
        {
          eventtype="cameratargetoverride",
          param={ dist=40.0, duration=172, offset={ x=0, y=0, z=10,},},
          target_role="lead",
        },
      },
      {
        172,
        224,
        {
          eventtype="cameratargetoverride",
          param={ dist=40.0, duration=52,},
          target_role="lead",
        },
      },
    },
    disableplayinput={ { 0, 223, { eventtype="disableplayinput", param={ duration=223,},},},},
    facing={
      {
        0,
        224,
        { eventtype="facing", param={ duration=224, facing="left",}, target_role="lead",},
      },
    },
    gotostate={
      {
        0,
        156,
        {
          eventtype="gotostate",
          param={ duration=156, statename="introduction",},
          target_role="lead",
        },
      },
      {
        172,
        224,
        {
          eventtype="gotostate",
          param={ duration=52, statename="introduction2",},
          target_role="lead",
        },
      },
    },
    letterbox={ { 0, 224, { eventtype="letterbox", param={ duration=224,},},},},
    musicbossstart={
      {
        233,
        260.0,
        {
          eventtype="musicbossstart",
          param={ persistent_key="boss_music", soundevent="Mus_Owlitzer_LP",},
          target_role="lead",
        },
      },
    },
    playsound={
      {
        0,
        7,
        {
          eventtype="playsound",
          param={ duration=7, soundevent="sting_miniboss_intro",},
          target_role="lead",
        },
      },
      {
        7,
        11,
        {
          eventtype="playsound",
          param={ autostop=true, duration=4, soundevent="Mus_Owlitzer_intro",},
        },
      },
      {
        7,
        194,
        {
          eventtype="playsound",
          param={
            autostop=true,
            duration=187,
            name="Snapshot_BossIntro_LP",
            soundevent="Snapshot_BossIntro_LP",
            stopatexitstate=true,
          },
          target_role="lead",
        },
      },
    },
    setvisible={
      {
        0,
        1,
        { eventtype="setvisible", param={ duration=1, show=false,}, target_role="lead",},
      },
      {
        1,
        2,
        { eventtype="setvisible", param={ duration=1, show=true,}, target_role="lead",},
      },
    },
    shakecamera={ { 192, 198, { eventtype="shakecamera", param={ duration=6, mode="FULL",},},},},
    showtext={
      {
        27,
        85,
        {
          eventtype="showtext",
          param={
            duration=58,
            monster_language_id="thatcher",
            offset_y=700.0,
            textID="THATCHER_INTRO_1",
            use_monster_language=true,
          },
          target_role="lead",
        },
      },
      {
        87,
        145,
        {
          eventtype="showtext",
          param={
            duration=58,
            monster_language_id="thatcher",
            offset_y=700.0,
            textID="THATCHER_INTRO_2",
            use_monster_language=true,
          },
          target_role="lead",
        },
      },
      {
        192,
        255.0,
        {
          eventtype="showtext",
          param={
            duration=63,
            monster_language_id="thatcher",
            offset_y=700.0,
            textID="THATCHER_INTRO_3",
            use_monster_language=true,
          },
          target_role="lead",
        },
      },
    },
    stopsound={
      {
        194,
        201,
        {
          eventtype="stopsound",
          param={ duration=7, name="Snapshot_BossIntro_LP",},
          target_role="lead",
        },
      },
    },
    teleport={
      {
        2,
        156,
        {
          eventtype="teleport",
          param={ duration=154, pos={ x=0.0, y=0, z=20.0,}, target_role="scene",},
          target_role="lead",
        },
      },
      {
        157,
        224,
        {
          eventtype="teleport",
          param={ duration=67, pos={ x=0.0, y=0, z=5.0,}, target_role="scene",},
          target_role="lead",
        },
      },
    },
    titlecard={
      {
        41,
        97,
        {
          eventtype="titlecard",
          param={ duration=56, titlekey="thatcher",},
          target_role="lead",
        },
      },
    },
    uihidehud={ { 0, 224, { eventtype="uihidehud", param={ duration=224,},},},},
  },
  use_lead_actor_pos=true,
}