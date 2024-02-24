-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_player_swipes",
  group="fx_player",
  isfinal=true,
  prefab="player_side",
  stategraphs={
    sg_player_hammer={
      events={
        skill_hammer_thump_atk={
          {
            eventtype="spawneffect",
            frame=1,
            param={ fxname="fx_hammer_thump_dust_ring", offx=0.76999998092651, offy=0.0, offz=0.0,},
          },
          {
            eventtype="spawnparticles",
            frame=1,
            param={
              duration=75.0,
              offx=0.75,
              offy=0.0,
              offz=0.0,
              particlefxname="impact_large",
              render_in_front=true,
            },
          },
        },
        skill_hammer_thump_atk_fullycharged={
          {
            eventtype="spawneffect",
            frame=4,
            param={ fxname="fx_hammer_thump_dust_ring", offx=0.76999998092651, offy=0.0, offz=0.0,},
          },
          {
            eventtype="spawnimpactfx",
            frame=7,
            param={ impact_size=3, impact_type=1, offx=0.75, offz=-0.31999999284744,},
          },
          {
            eventtype="spawneffect",
            frame=7,
            param={
              fxname="hammer_thump_groundring_focus",
              offx=1.0,
              offy=0.0,
              offz=0.0,
              scalex=2.7000000476837,
              scalez=2.7000000476837,
            },
          },
          {
            eventtype="spawneffect",
            frame=6,
            param={
              fxname="hammer_thump_groundring_focus",
              offx=1.0,
              offy=0.0,
              offz=0.0,
              scalex=1.5,
              scalez=1.5,
            },
          },
          {
            eventtype="spawnparticles",
            frame=5,
            param={
              duration=75.0,
              offx=0.75,
              offy=-1.3999999761581,
              offz=0.0,
              particlefxname="hit_ground_focus_hammer_thump",
              render_in_front=true,
            },
          },
        },
      },
      state_events={
        fading_heavy_spin_loop={
          {
            eventtype="attachswipefx",
            name="AttachSwipeFx",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_hammer_big_atk1",
              stoponinterruptstate=true,
            },
          },
          {
            eventtype="attachswipefx",
            name="AttachSwipeFxBack",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_hammer_big_atk1_back",
              stoponinterruptstate=true,
            },
          },
          { eventtype="detachswipefx", name="DetachSwipeFx", param={  },},
        },
        fading_heavy_spin_pst={
          {
            eventtype="attachswipefx",
            name="AttachSwipeFx",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_hammer_big_atk1",
              stoponinterruptstate=true,
            },
          },
          { eventtype="detachswipefx", name="DetachSwipeFx", param={  },},
          {
            eventtype="attachswipefx",
            name="AttachSwipeFxBack",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_hammer_big_atk1_back",
              stoponinterruptstate=true,
            },
          },
        },
        fading_light_attack={
          {
            eventtype="attachswipefx",
            name="AttachSwipeFx",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_hammer_fade_atk_front",
              stoponinterruptstate=true,
            },
          },
          { eventtype="detachswipefx", name="DetachSwipeFx", param={  },},
          {
            eventtype="attachswipefx",
            name="AttachSwipeFxBack",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_hammer_fade_atk_back",
              stoponinterruptstate=true,
            },
          },
        },
        heavy_attack_air={
          {
            eventtype="attachswipefx",
            name="AttachSwipeFx",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_hammer_smash_air",
              stoponinterruptstate=true,
            },
          },
        },
        heavy_overhead_slam={
          {
            eventtype="attachswipefx",
            name="AttachSwipeFx",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_hammer_smash_air",
              stoponinterruptstate=true,
            },
          },
        },
        light_attack1={
          {
            eventtype="attachswipefx",
            name="AttachSwipeFx",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_hammer_atk1",
              stoponinterruptstate=true,
            },
          },
        },
        light_attack2={
          {
            eventtype="attachswipefx",
            name="AttachSwipeFx",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_hammer_atk2",
              stoponinterruptstate=true,
            },
          },
        },
        light_attack3={
          {
            eventtype="attachswipefx",
            name="AttachSwipeFx",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_hammer_atk3",
              stoponinterruptstate=true,
            },
          },
        },
        reverse_heavy_attack={
          {
            eventtype="attachswipefx",
            name="AttachSwipeFx",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_hammer_reverse_atk",
              stoponinterruptstate=true,
            },
          },
        },
        spinning_heavy_attack_air={
          {
            eventtype="attachswipefx",
            name="AttachSwipeFx",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_hammer_spin_air",
              stoponinterruptstate=true,
            },
          },
          {
            eventtype="attachswipefx",
            name="AttachSwipeFx2",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_hammer_smash_air",
              stoponinterruptstate=true,
            },
          },
          { eventtype="detachswipefx", name="DetachSwipeFx", param={  },},
        },
      },
    },
    sg_player_polearm={
      sg_events={
        {
          eventtype="spawneffect",
          name="vfx-polearm_shove",
          param={ fxname="fx_polearm_shove_basic", inheritrotation=true, stopatexitstate=true,},
        },
      },
      state_events={
        fading_light_attack={
          {
            eventtype="attachswipefx",
            name="AttachSwipeFx",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_polearm_roll_rev_atk",
              stoponinterruptstate=true,
            },
          },
        },
        heavy_attack={
          {
            eventtype="attachswipefx",
            name="AttachSwipeFx",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_polearm_heavy_atk",
              stoponinterruptstate=true,
            },
          },
        },
        light_attack1={
          {
            eventtype="attachswipefx",
            name="AttachSwipeFx",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_polearm_atk",
              stoponinterruptstate=true,
            },
          },
        },
        light_attack2={
          {
            eventtype="attachswipefx",
            name="AttachSwipeFx",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_polearm_atk2",
              stoponinterruptstate=true,
            },
          },
        },
        light_attack3={
          {
            eventtype="attachswipefx",
            name="AttachSwipeFx",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_polearm_atk3",
              stoponinterruptstate=true,
            },
          },
        },
        multithrust_attack={
          {
            eventtype="attachswipefx",
            name="AttachSwipeFx",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_polearm_multithrust_atk",
              stoponinterruptstate=true,
            },
          },
        },
        rolling_drill_attack={
          {
            eventtype="attachswipefx",
            name="AttachSwipeFx",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              fxname="fx_polearm_roll_atk",
              stoponinterruptstate=true,
            },
          },
          {
            eventtype="attachswipefx",
            name="AttachSwipeFxBack",
            param={
              auditionfxtype="basic",
              auditionpowertype="none",
              backgroundfx=true,
              fxname="fx_polearm_roll_atk_back",
              stoponinterruptstate=true,
            },
          },
        },
      },
    },
  },
}