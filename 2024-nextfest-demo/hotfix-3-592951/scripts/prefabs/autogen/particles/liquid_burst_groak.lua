-- Generated by ParticleEditor and loaded by particles_autogen_data
return {
  __displayName="liquid_burst_groak",
  emitters={
    {
      bake_time=0.0,
      blendmode=1,
      bloom=0.76300001144409,
      burst_amt=15.0,
      curves={
        color={ data={  }, num=0, time={  },},
        emission_rate={ data={ -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,}, enabled=false,},
        scale={
          data={
            0.0,
            0.93999999761581,
            0.79833334684372,
            0.81000000238419,
            0.89666664600372,
            0.62999999523163,
            1.0,
            0.035000026226044,
            -1.0,
            0.47500002384186,
            -1.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
          },
          enabled=true,
          max=1.0,
        },
        velocityAspect={
          data={
            0.0,
            0.0,
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
          enabled=true,
          factor=0.0,
          max=2.0,
          min=0.84500002861023,
          speedMax=10.0,
        },
      },
      emission_rate_loops=false,
      emission_rate_time=5,
      emit_rate=0.0,
      erode_bias=0.0489999987185,
      friction_max=2.0,
      friction_min=2.0,
      gravity_x=0.0,
      gravity_y=-2.0,
      gravity_z=0.0,
      max_particles=500.0,
      name="droplets",
      spawn={
        aspect=0.75,
        box={ -0.5, 0.5, 0.0, 0.0,},
        color=1245457151,
        emit_grid_colums=10.0,
        emit_grid_rows=10.0,
        emit_on_grid=false,
        fps=24.0,
        rot={ 0.0, 0.0,},
        rotvel={ 0.0, 0.0,},
        size={ 0.20000000298023, 0.40000000596046,},
        ttl={ 0.40000000596046, 1.0,},
        vel={ -8.0, 8.0, 6.0, 16.0, 0, 0,},
      },
      texture={ "particles.xml", "circle_ringed_alpha.tex",},
      use_bounce=false,
      x=0.0,
      y=0.0,
      z=-0.059999998658895,
    },
    {
      bake_time=0.0,
      blendmode=1,
      bloom=0.0,
      burst_amt=20.0,
      curves={
        color={ data={ 1245457018, 1161570051,}, num=2, time={ 0, 1,},},
        emission_rate={ data={ -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,}, enabled=false,},
        scale={
          data={
            0.0,
            0.0,
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
          enabled=true,
          max=2.0,
          min=0.5,
        },
        velocityAspect={
          data={
            0.0,
            0.0,
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
          enabled=false,
          factor=0.0,
          max=2.0,
          min=0.84500002861023,
          speedMax=10.0,
        },
      },
      emission_rate_loops=false,
      emission_rate_time=5,
      emit_rate=0.0,
      erode_bias=0.77100002765656,
      friction_max=2.0,
      friction_min=2.0,
      gravity_x=0.0,
      gravity_y=-2.0,
      gravity_z=0.0,
      max_particles=500.0,
      name="splash",
      spawn={
        aspect=1.0,
        box={ -0.5, 0.5, 0.0, 0.0,},
        color=4294967295,
        emit_grid_colums=10.0,
        emit_grid_rows=10.0,
        emit_on_grid=false,
        fps=24.0,
        rot={ -4.4683917592083, 3.6808992859296,},
        rotvel={ -0.5235987755983, 0.5235987755983,},
        size={ 1.0, 4.0,},
        ttl={ 0.20000000298023, 0.80000001192093,},
        vel={ -4.0, 4.0, 6.0, 16.0, 0, 0,},
      },
      texture={ "particles.xml", "PlasmaSmoke1.tex",},
      use_bounce=false,
    },
  },
  group="bursts",
  mode_2d=false,
}
