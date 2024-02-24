-- Generated by ParticleEditor and loaded by particles_autogen_data
return {
  __displayName="sticky",
  emitters={
    {
      blendmode=1,
      bloom=0.0,
      burst_amt=0.0,
      curves={
        color={ data={ 1748410367, 302717187,}, num=2, time={ 0, 1,},},
        emission_rate={ data={ -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,}, enabled=false,},
        scale={
          data={
            0.0,
            0.0,
            0.018333332613111,
            0.65499997138977,
            0.053333334624767,
            0.86000001430511,
            0.11833333224058,
            0.93000000715256,
            0.26499998569489,
            0.97000002861023,
            0.51666665077209,
            0.99000000953674,
            0.85500001907349,
            1.0,
            1.0,
            1.0,
          },
          enabled=true,
          max=1.7000000476837,
          min=0.5,
        },
        velocityAspect={
          data={
            0.0,
            0.50999999046326,
            1.0,
            0.96499997377396,
            -1.0,
            0.99000000953674,
            -1.0,
            0.99000000953674,
            -1.0,
            0.99000000953674,
            -1.0,
            0.99000000953674,
            -1.0,
            0.99000000953674,
            -1.0,
            0.0,
          },
          enabled=false,
          factor=0.0,
          max=2.0,
          speedMax=10.0,
        },
      },
      emission_rate_loops=false,
      emission_rate_time=5,
      emit_rate=10.0,
      emit_rate_mult=0.75,
      erode_bias=0.0,
      friction_max=1.0,
      friction_min=1.0,
      ground_projected=true,
      lod=255,
      max_particles=1000.0,
      name="ground_splats",
      r=0.0,
      spawn={
        aspect=1.0,
        box={ -1.0, 1.0, -1.0, 1.0,},
        color=4294967295,
        emit_arc_max=0.0,
        emit_arc_min=520.0,
        emit_arc_vel=520.0,
        emit_grid_colums=10.0,
        emit_grid_rows=10.0,
        emit_on_grid=true,
        layer=4,
        rot={ 0.0, 0.0,},
        rotvel={ -0.34906585039887, 0.34906585039887,},
        size={ 0.20000000298023, 0.69999998807907,},
        ttl={ 1.0, 2.0,},
        vel={ 0, 0, 0.0, 0.0, 0, 0,},
      },
      texture={ "particles.xml", "droplet.tex",},
      use_bounce=false,
      x=0.0,
      y=0.0,
      z=0.0,
    },
    {
      blendmode=1,
      bloom=0,
      bounce_coeff=1.0,
      burst_amt=0.0,
      burst_time=0.20000000298023,
      curves={
        color={ data={  }, num=0, time={  },},
        emission_rate={ data={ -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,}, enabled=false,},
        scale={
          data={
            0.0,
            0.0049999952316284,
            0.20166666805744,
            0.55500000715256,
            1.0,
            0.74500000476837,
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
          },
          enabled=true,
          min=0.5,
        },
        velocityAspect={ data={ -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,}, enabled=false,},
      },
      emission_rate_time=5,
      emit_rate=10.0,
      emit_rate_mult=0.75,
      erode_bias=0.0,
      gravity_x=0.0,
      gravity_y=-3.0,
      gravity_z=0.0,
      max_particles=100.0,
      name="droplets",
      spawn={
        aspect=1.414999961853,
        box={ -0.5, 0.5, -0.5, 0.5,},
        color=1546685951,
        emit_grid_colums=2.0,
        emit_grid_rows=2.0,
        emit_on_grid=true,
        size={ 0.10000000149012, 0.30000001192093,},
        ttl={ 0.30000001192093, 0.30000001192093,},
        vel={ 0.0, 0.0, 0.0, 0.0, 0, 0,},
      },
      texture={ "particles.xml", "droplet.tex",},
      use_bounce=false,
      x=0.0,
      y=1.75,
      z=0.0,
    },
  },
  group="powerup_player",
  mode_2d=false,
}
