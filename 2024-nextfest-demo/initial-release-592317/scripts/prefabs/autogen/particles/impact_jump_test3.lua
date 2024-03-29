-- Generated by ParticleEditor and loaded by particles_autogen_data
return {
  __displayName="impact_jump_test3",
  emitters={
    {
      blendmode=1,
      bloom=0.0,
      burst_amt=40.0,
      burst_time=0.050000000745058,
      curves={
        color={
          data={ 2426383860, 2224465890, 1719836192,},
          num=3,
          time={ 0, 0.22816399286988, 0.98217468805704,},
        },
        emission_rate={ data={ -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,}, enabled=false,},
        scale={
          data={
            0.0,
            0.0,
            0.035000000149012,
            0.16500002145767,
            0.14666666090488,
            0.26499998569489,
            0.32333332300186,
            0.46499997377396,
            0.53333336114883,
            0.875,
            0.70333331823349,
            0.94999998807907,
            0.84666669368744,
            0.99000000953674,
            1.0,
            1.0,
          },
          enabled=true,
          max=3.0,
          min=0.0,
        },
        velocityAspect={
          data={
            0.0,
            0.014999985694885,
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
          factor=1.0,
          max=4.8920001983643,
          min=1.0,
          speedMax=5.0,
        },
      },
      emission_rate_loops=false,
      emission_rate_time=5,
      emit_rate=0.0,
      emit_rate_mult=0.0,
      erode_bias=0.0,
      friction_max=0.0,
      friction_min=0.0,
      gravity_x=0.0,
      gravity_y=-0.20000000298023,
      gravity_z=0.0,
      ground_projected=true,
      max_particles=100.0,
      name="ring2",
      scalemult=1.0,
      spawn={
        aspect=2.0,
        box={ -2.0, 2.0, -2.0, 2.0,},
        color=4294967295,
        emit_arc_min=0.0,
        emit_arc_phase=0.0,
        emit_arc_vel=0.0,
        emit_grid_colums=10.0,
        emit_grid_rows=10.0,
        emit_on_grid=false,
        fps=24.0,
        layer=4,
        random_position=0.0,
        rot={ 0.0, 0.0,},
        rotvel={ -0.17453292519943, 0.17453292519943,},
        shape=1,
        shape_alignment=0.34999999403954,
        size={ 0.30000001192093, 1.2250000238419,},
        sort_order=1,
        ttl={ 0.30000001192093, 0.5,},
        vel={ 0.0, 0.0, 0.25, 5.923999786377, 0, 0,},
      },
      texture={ "particles2.xml", "fog_4.tex",},
      use_bounce=false,
    },
    {
      bake_time=0.10000000149012,
      blendmode=1,
      bloom=0.0,
      bounce_coeff=0.5,
      bounce_height=-0.20000000298023,
      burst_amt=1.0,
      curves={
        color={
          data={ 4294967101, 2107423603, 1331984641,},
          num=3,
          time={ 0, 0.28877005347594, 0.98752228163993,},
        },
        emission_rate={ data={ -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,}, enabled=false,},
        scale={
          data={
            0.0,
            0.0,
            0.19666667282581,
            0.66499996185303,
            0.3116666674614,
            0.84500002861023,
            0.55833333730698,
            0.9200000166893,
            0.67500001192093,
            0.94499999284744,
            0.77999997138977,
            0.96499997377396,
            0.85833334922791,
            0.98000001907349,
            1.0,
            1.0,
          },
          enabled=true,
          max=4.0,
          min=0.0,
        },
        velocityAspect={
          data={
            0.0,
            0.10500001907349,
            0.22333332896233,
            0.5,
            0.39333334565163,
            0.69999998807907,
            0.54000002145767,
            0.80000001192093,
            0.66666668653488,
            0.88999998569489,
            0.8116666674614,
            0.94499999284744,
            1.0,
            0.99000000953674,
            -1.0,
            0.0,
          },
          enabled=false,
          max=1.0,
          speedMax=10.0,
        },
      },
      emission_rate_time=5,
      emit_rate=0.0,
      erode_bias=1.0,
      friction_max=0.0,
      friction_min=0.0,
      gravity_x=0.0,
      gravity_y=0.0,
      gravity_z=0.0,
      ground_projected=true,
      max_particles=500.0,
      name="blastwave",
      spawn={
        aspect=1.0,
        box={ 0.0, 0.0, 0.0, 0.0,},
        color=2487622655,
        emit_arc_max=360.0,
        emit_grid_colums=10.0,
        emit_grid_rows=10.0,
        emit_on_grid=true,
        fps=22.0,
        layer=4,
        rot={ -3.9611993875054, 2.5610962402503,},
        rotvel={ 0.0, 0.0,},
        size={ 1.3999999761581, 1.3999999761581,},
        ttl={ 0.5, 0.5,},
        vel={ 0.0, 0.0, 0.0, 0.0, 0, 0,},
      },
      texture={ "particles2.xml", "blast_ring.tex",},
      use_bounce=false,
      x=0.0,
      y=1.0,
      z=0.0,
    },
  },
  group="impacts",
  mode_2d=false,
}
