-- Generated by ParticleEditor and loaded by particles_autogen_data
return {
  __displayName="fog_wavy_billboard",
  blendmode=1,
  bloom=0,
  curves={  },
  emit_rate=4.0,
  emit_world_space=true,
  emitters={
    {
      bake_time=5.0,
      blendmode=1,
      bloom=0.5,
      burst_amt=0.0,
      burst_time=0.0,
      curves={
        color={
          data={ 3445358341, 2688804912, 2941452032,},
          num=3,
          time={ 0, 0.4991789819376, 0.99671592775041,},
        },
        emission_rate={
          data={
            0.0,
            0.49500000476837,
            0.14666666090488,
            0.82499998807907,
            0.31833332777023,
            0.48500001430511,
            0.52833330631256,
            0.89499998092651,
            0.69166666269302,
            0.49000000953674,
            0.86500000953674,
            0.875,
            1.0,
            0.5,
            -1.0,
            0.5,
          },
          enabled=true,
        },
        scale={
          data={
            0.0,
            0.43999999761581,
            0.068333335220814,
            0.73000001907349,
            0.16333332657814,
            0.8400000333786,
            0.24666666984558,
            0.83499997854233,
            0.41499999165535,
            0.64999997615814,
            0.65333330631256,
            0.50499999523163,
            0.84833335876465,
            0.39499998092651,
            1.0,
            0.35500001907349,
          },
          enabled=false,
          max=1.0,
          min=0.10000000149012,
        },
        velocityAspect={ data={ -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,}, enabled=false,},
      },
      emission_rate_loops=true,
      emission_rate_time=5.0,
      emit_rate=3.0,
      emit_world_space=false,
      erode_bias=0.0,
      friction_max=0.0,
      friction_min=0.0,
      gravity_x=0.0,
      gravity_y=0.0,
      gravity_z=0.0,
      max_particles=200.0,
      name="fog1",
      r=0.0,
      spawn={
        aspect=0.25,
        box={ -20.815000534058, 20.815000534058, -0.52200001478194, 2.4779999852181,},
        color=4294967295,
        emit_grid_colums=10.0,
        emit_grid_rows=10.0,
        emit_on_grid=true,
        fps=30.0,
        layer=5,
        rot={ 0.0, 0.0,},
        rotvel={ 0.0, 0.0,},
        size={ 30.0, 40.0,},
        ttl={ 5.0, 10.0,},
        vel={ 0.5, 1.0, 0.0, 0.0, 0, 0,},
      },
      texture={ "particles2.xml", "fog.tex",},
      use_bounce=false,
      use_local_ref_frame=true,
      velocity_inherit=0.0,
      x=0.0,
      y=0.0,
      z=0.0,
    },
  },
  group="fog",
  max_particles=100,
  spawn={
    box={ 0, 0, 0, 0,},
    color=16777215,
    size={ 10, 10,},
    ttl={ 4, 4,},
    vel={ 0, 0, 10, 10, 0, 0,},
  },
  texture={ "particles.xml", "circle.tex",},
}
