-- Generated by CineEditor and loaded by cine_autogen.lua
return {
  __displayName="cine_bandicoot_death_old",
  leadprefab="bandicoot",
  pause_role_sg={ lead={ resumestate="death_idle",},},
  scene_duration=190.0,
  scene_init={  },
  timelines={
    attachswipefx={  },
    blurscreen={
      {
        0,
        63,
        {
          eventtype="blurscreen",
          param={
            blend=0.40999999642372,
            curve={
              0.0,
              0,
              0.14285714924335,
              0.46022492647171,
              0.28571429848671,
              0.73969179391861,
              0.4285714328289,
              0.89337778091431,
              0.57142859697342,
              0.96626406908035,
              0.71428573131561,
              0.99333614110947,
              0.85714286565781,
              0.99958348274231,
              1.0,
              1.0,
            },
            duration=63,
            modename="Radial",
            radius=0.52399998903275,
            reset_on_exit=true,
            strength=0.059999998658895,
          },
        },
      },
      {
        128,
        136,
        {
          eventtype="blurscreen",
          param={
            blend=0.20000000298023,
            curve={
              0.0,
              0,
              0.12666666507721,
              0.61500000953674,
              0.27833333611488,
              0.47500002384186,
              0.41833332180977,
              0.88499999046326,
              0.55833333730698,
              0.76499998569489,
              0.70999997854233,
              1.0,
              0.84500002861023,
              0.875,
              1.0,
              0.0049999952316284,
            },
            duration=8,
            modename="Radial",
            radius=0.5,
            strength=0.5,
          },
        },
      },
    },
    cameradist={
      {
        0,
        39,
        {
          eventtype="cameradist",
          param={
            curve={
              0.0,
              0,
              0.14285714924335,
              5.9499030612642e-05,
              0.28571429848671,
              0.0019039689796045,
              0.4285714328289,
              0.014458262361586,
              0.57142859697342,
              0.060927007347345,
              0.71428573131561,
              0.18593445420265,
              0.85714286565781,
              0.46266439557076,
              1.0,
              1.0,
            },
            dist=26.812000274658,
            duration=39,
          },
        },
      },
      {
        94,
        174,
        {
          eventtype="cameradist",
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
            duration=80,
          },
        },
      },
    },
    cameraoffset={
      {
        0,
        37,
        {
          eventtype="cameraoffset",
          param={
            curve={
              0.0,
              0,
              0.14285714924335,
              0.53733563423157,
              0.28571429848671,
              0.81406557559967,
              0.4285714328289,
              0.93907302618027,
              0.57142859697342,
              0.98554176092148,
              0.71428573131561,
              0.99809604883194,
              0.85714286565781,
              0.99994051456451,
              1.0,
              1.0,
            },
            duration=37,
            offset={ x=0.0, y=5.4000000953674, z=0.0,},
          },
        },
      },
      {
        106,
        186,
        {
          eventtype="cameraoffset",
          param={
            curve={
              0.0,
              0,
              0.14285714924335,
              0.020408164709806,
              0.28571429848671,
              0.081632658839226,
              0.4285714328289,
              0.18367347121239,
              0.57142859697342,
              0.3265306353569,
              0.71428573131561,
              0.51020407676697,
              0.85714286565781,
              0.73469388484955,
              1.0,
              1.0,
            },
            duration=80,
          },
        },
      },
    },
    camerapitch={
      {
        0,
        40,
        {
          eventtype="camerapitch",
          param={
            curve={
              0.0,
              0,
              0.14285714924335,
              0.53733563423157,
              0.28571429848671,
              0.81406557559967,
              0.4285714328289,
              0.93907302618027,
              0.57142859697342,
              0.98554176092148,
              0.71428573131561,
              0.99809604883194,
              0.85714286565781,
              0.99994051456451,
              1.0,
              1.0,
            },
            duration=40,
            pitch=10.496999740601,
          },
        },
      },
      {
        116,
        176,
        {
          eventtype="camerapitch",
          param={
            curve={
              0.0,
              0,
              0.14000000059605,
              0.035000026226044,
              0.28333333134651,
              0.12999999523163,
              0.42666667699814,
              0.3299999833107,
              0.57142859697342,
              0.68513125181198,
              0.71428573131561,
              0.90670555830002,
              0.85714286565781,
              0.98833817243576,
              1.0,
              1.0,
            },
            duration=60,
            pitch=23.578178405762,
          },
        },
      },
    },
    cameratargetbegin={
      {
        0,
        17,
        {
          eventtype="cameratargetbegin",
          param={
            curve={
              0.0,
              0,
              0.14285714924335,
              0.46022492647171,
              0.28571429848671,
              0.73969179391861,
              0.4285714328289,
              0.89337778091431,
              0.57142859697342,
              0.96626406908035,
              0.71428573131561,
              0.99333614110947,
              0.85714286565781,
              0.99958348274231,
              1.0,
              1.0,
            },
            duration=17,
          },
          target_role="lead",
        },
      },
    },
    cameratargetend={
      {
        128,
        186,
        {
          eventtype="cameratargetend",
          param={
            curve={
              0.0,
              0,
              0.14285714924335,
              0.370262414217,
              0.28571429848671,
              0.63556855916977,
              0.4285714328289,
              0.81341105699539,
              0.57142859697342,
              0.92128282785416,
              0.71428573131561,
              0.97667640447617,
              0.85714286565781,
              0.9970845580101,
              1.0,
              1.0,
            },
            duration=58,
          },
          target_role="lead",
        },
      },
    },
    cameratargetoverride={  },
    detachswipefx={  },
    disableplayinput={  },
    facing={  },
    gameevent={  },
    gotostate={
      {
        0,
        190,
        {
          eventtype="gotostate",
          param={ statename="death_cinematic",},
          target_role="lead",
        },
      },
    },
    letterbox={  },
    lightintensity={
      {
        0,
        133,
        {
          eventtype="lightintensity",
          param={ duration=133, self_intensity=1.0, world_intensity=0.19300000369549,},
          target_role="lead",
        },
      },
    },
    musicbossstart={  },
    musicbossstop={  },
    pausesg={  },
    playcountedsound={  },
    playfoleysound={  },
    playsound={  },
    playsound_window={  },
    pushanim={  },
    runintoscene={  },
    setsoundparameter={  },
    shakecamera={
      {
        132,
        176,
        {
          eventtype="shakecamera",
          param={ dist=35, duration=44, mode="FULL", scale=0.44999998807907,},
        },
      },
    },
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
}
