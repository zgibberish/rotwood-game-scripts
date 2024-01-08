-- Generated by ParticleEditor and loaded by particles_autogen_data
return {
  __displayName="extroverted_trail",
  emitters={
    {
      blendmode=1,
      bloom=1.0,
      burst_amt=0.0,
      curves={
        color={
          data={ 4293688836, 4287826558, 4285734349, 4283826181,},
          num=4,
          time={ 0.0049261083743842, 0.32019704433498, 0.61904761904762, 0.98522167487685,},
        },
        emission_rate={ data={ -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,}, enabled=false,},
        scale={
          data={
            0.0,
            0.48000001907349,
            0.19666667282581,
            1.0,
            1.0,
            0.0099999904632568,
            -1.0,
            0.96499997377396,
            -1.0,
            0.96499997377396,
            -1.0,
            0.96499997377396,
            -1.0,
            0.96499997377396,
            -1.0,
            0.0,
          },
          enabled=true,
          max=1.0,
        },
        velocityAspect={
          data={
            0.0,
            0.0099999904632568,
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
          enabled=true,
          factor=0.0,
          max=2.0,
          speedMax=10.0,
        },
      },
      emission_rate_time=5,
      emit_rate=50.0,
      erode_bias=0.75,
      friction_max=0.0,
      friction_min=0.0,
      max_particles=500.0,
      name="OL",
      r=0.0,
      spawn={
        aspect=1.25,
        box={ 0.0, 0.0, 0.0, 0.0,},
        color=4294967295,
        emit_arc_max=0.0,
        emit_arc_min=-180.0,
        emit_arc_vel=100.0,
        emit_grid_colums=10.0,
        emit_grid_rows=10.0,
        emit_on_grid=false,
        rot={ -0.34906585039887, 0.34906585039887,},
        rotvel={ -3.1415926535898, 3.1415926535898,},
        size={ 1.0, 1.0,},
        ttl={ 0.25, 0.5,},
        vel={ 0, 0, 3.0, 5.0, 0, 0,},
      },
      texture={ "particles.xml", "fire_blob_erode_1.tex",},
      use_bounce=false,
      x=0.0,
      y=0.0,
      z=0.0,
    },
    {
      bake_time=1.0,
      blendmode=1,
      bloom=1.0,
      burst_amt=0.0,
      burst_time=0.0,
      curves={
        color={ data={ 4294246655, 4285988864,}, num=2, time={ 0, 1,},},
        emission_rate={ data={ -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,}, enabled=false,},
        scale={
          data={
            0.0,
            0.019999980926514,
            0.098333336412907,
            0.50499999523163,
            0.30500000715256,
            0.87000000476837,
            0.49833333492279,
            0.81499999761581,
            0.63999998569489,
            0.68000000715256,
            0.74500000476837,
            0.4200000166893,
            0.85714286565781,
            0.14285713434219,
            1.0,
            0.0,
          },
          enabled=true,
          max=1.0,
          min=0.0,
        },
        velocityAspect={
          data={ -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,},
          enabled=true,
          factor=0.0,
          max=10.0,
          min=1.0269999504089,
          speedMax=10.0,
        },
      },
      emission_rate_time=5.0,
      emit_rate=20.0,
      emit_world_space=false,
      erode_bias=0.0,
      friction_max=1.0,
      friction_min=0.0,
      gravity_x=0.0,
      gravity_y=0.0,
      gravity_z=0.0,
      max_particles=500.0,
      name="embers",
      r=0.0,
      spawn={
        aspect=1.0,
        box={ -0.25, 0.25, -0.25, 0.25,},
        color=4284743935,
        emit_on_grid=false,
        fps=28.0,
        rot={ 6.2831853071796, 3.5438910994377,},
        rotvel={ 0.0, 3.1415926535898,},
        size={ 0.10000000149012, 0.20000000298023,},
        ttl={ 0.30000001192093, 0.40000000596046,},
        vel={ -1.0, 1.0, 2.0, 5.0, 0, 0,},
      },
      texture={ "particles.xml", "circle.tex",},
      use_bounce=false,
      velocity_inherit=0.0,
      x=0.0,
      y=0.0,
      z=-0.10000000149012,
    },
  },
  group="trails",
}