-- Generated by ParticleEditor and loaded by particles_autogen_data
return {
  __displayName="upgrade_gas_3",
  emitters={
    {
      blendmode=1,
      bloom=0.52700001001358,
      burst_amt=0.0,
      curves={
        color={
          data={ 1962802947, 2161049394, 2986409732,},
          num=3,
          time={ 0, 0.18226600985222, 1,},
        },
        emission_rate={ data={ -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,}, enabled=false,},
        scale={
          data={
            0.0,
            0.019999980926514,
            0.056666668504477,
            0.33999997377396,
            0.12166666984558,
            0.60000002384186,
            0.25499999523163,
            0.82499998807907,
            0.37000000476837,
            0.93000000715256,
            0.51333332061768,
            0.99000000953674,
            1.0,
            0.99500000476837,
            -1.0,
            0.99500000476837,
          },
          enabled=true,
          max=2.0,
          min=0.0,
        },
        velocityAspect={
          data={
            0.0,
            0.9099999666214,
            1.0,
            1.0,
            -1.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
          },
          enabled=false,
          max=0.0,
          min=1.1890000104904,
          speedMax=10.0,
        },
      },
      emission_rate_time=5,
      emit_rate=20.0,
      emit_world_space=true,
      erode_bias=0.0,
      max_particles=100.0,
      name="BG_smoke",
      spawn={
        aspect=1.0,
        box={ 0.0, 0.0, 0.0, 0.0,},
        color=4294967295,
        emit_grid_colums=10.0,
        emit_grid_rows=10.0,
        emit_on_grid=true,
        rot={ -0.17453292519943, 0.17453292519943,},
        rotvel={ 0.0, 0.0,},
        size={ 3.0, 5.0,},
        ttl={ 1.0, 2.0,},
        vel={ 0, 0, 2.0, 3.0, 0, 0,},
      },
      texture={ "particles.xml", "totoro.tex",},
      x=0.0,
      y=0.0,
      z=0.0,
    },
    {
      blendmode=1,
      bloom=0.0,
      burst_amt=0.0,
      curves={
        color={
          data={ 4294967043, 234155262, 16776441, 3170959107,},
          num=4,
          time={ 0.0, 0.32512315270936, 0.66995073891626, 1,},
        },
        emission_rate={ data={ -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,}, enabled=false,},
        scale={
          data={
            0.0,
            0.0049999952316284,
            0.15833333134651,
            0.68000000715256,
            0.2816666662693,
            0.89499998092651,
            0.43999999761581,
            0.95999997854233,
            0.5616666674614,
            0.86000001430511,
            0.68500000238419,
            0.66499996185303,
            0.83999997377396,
            0.36000001430511,
            1.0,
            0.0099999904632568,
          },
          enabled=true,
          max=1.0,
        },
        velocityAspect={ data={ -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,}, enabled=false,},
      },
      emission_rate_time=5,
      emit_rate=10.0,
      emit_world_space=true,
      erode_bias=1.0,
      max_particles=100.0,
      name="highlight_dots",
      spawn={
        aspect=1.0,
        box={ -0.5, 0.5, 0.0, 0.0,},
        color=4294967295,
        emit_grid_colums=10.0,
        emit_grid_rows=10.0,
        emit_on_grid=true,
        rot={ -6.2831853071796, 6.2831853071796,},
        rotvel={ -3.1415926535898, 3.1415926535898,},
        size={ 0.25, 0.75,},
        ttl={ 0.5, 1.0,},
        vel={ 0, 0, 1.0, 3.0, 0, 0,},
      },
      texture={ "particles.xml", "circle_ringed_alpha2.tex",},
    },
  },
  group="testing",
  mode_2d=false,
}
