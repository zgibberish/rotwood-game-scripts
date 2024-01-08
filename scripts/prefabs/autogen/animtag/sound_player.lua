-- Generated by AnimTagger and loaded by animtag_autogen.lua
return {
  __displayName="sound_player",
  anim_events={
    player_bank_basic={
      deafen_air_pre={ done=true, events={ { frame=9, name="land",}, { frame=11, name="footstep",},},},
      deafen_loop={ done=true,},
      deafen_pre={ done=true,},
      deafen_pst={ done=true, events={ { frame=12, name="footstep_quiet",},},},
      death={
        done=true,
        events={
          { frame=13, name="bodyfall",},
          { frame=16, name="weapon_bounce",},
          { frame=22, name="hand",},
          { frame=25, name="hand",},
        },
      },
      getup_pre={ done=true, events={ { frame=3, name="hand",}, { frame=4, name="hand",},},},
      getup_pst={ done=true, events={ { frame=4, name="hand",}, { frame=5, name="footstep",},},},
      getup_struggle={
        done=true,
        events={ { frame=7, name="footstep_stop",}, { frame=15, name="footstep",},},
      },
      hit={ done=true, events={ { frame=1, name="hit_vo",},},},
      idle={ done=true,},
      idle_blink={ done=true,},
      idle_blink_alert={ done=true,},
      interact_loop={
        done=true,
        events={
          { frame=4, name="swish",},
          { frame=12, name="swish",},
          { frame=18, name="swish",},
        },
      },
      interact_pre={ done=true,},
      interact_pst={ done=true, events={ { frame=6, name="footstep",},},},
      knockback={
        done=true,
        events={ { frame=3, name="hit_vo",}, { frame=7, name="footstep_stop",},},
      },
      knockdown={
        done=true,
        events={
          { frame=1, name="hit_vo",},
          { frame=1, name="jump",},
          { frame=12, name="bodyfall",},
        },
      },
      knockdown_hit={ done=true, events={ { frame=8, name="footstep",}, { frame=13, name="hand",},},},
      knockdown_idle={ done=true,},
      knockhigh={
        done=true,
        events={
          { frame=1, name="jump",},
          { frame=17, name="hit_vo",},
          { frame=21, name="bodyfall",},
          { frame=22, name="hand",},
        },
      },
      pickup_item={ done=true, events={ { frame=4, name="grab",},},},
      pickup_item_ctr={ events={ { frame=4, name="swish",}, { frame=7, name="grab",},},},
      potion={
        done=true,
        events={
          { frame=26, name="bottle_pop",},
          { frame=33, name="footstep_stop",},
          { frame=34, name="swish",},
          { frame=38, name="glass_smash",},
        },
      },
      potion_pre={ done=true, events={ { frame=4, name="rummage",},},},
      power_accept={ events={ { frame=15, name="jump",}, { frame=44, name="land",},},},
      run_loop={ done=true,},
      run_pre={ done=true, events={ { frame=1, name="foostep_stop",},},},
      run_pst={ done=true, events={ { frame=1, name="foostep_stop",},},},
      skill_banana_back_pst={ events={ { frame=9, name="sfx-banana_land",},},},
      skill_banana_front_pst={ events={ { frame=7, name="sfx-banana_land",},},},
      skill_banana_pre={ events={ { frame=16, name="sfx-banana_eat",},},},
      skill_crit={
        events={ { frame=4, name="sfx-buff_whoosh",}, { frame=7, name="sfx-buff_pound",},},
      },
      skill_crit_2={
        events={
          { frame=4, name="sfx-buff_whoosh",},
          { frame=7, name="sfx-buff_pound",},
          { frame=16, name="sfx-buff_pound",},
        },
      },
      skill_self_dmg={ events={ { frame=1, name="sfx-totem_slap",},},},
      throw_atk={ events={ { frame=1, name="swish",},},},
      toss_item={ done=true,},
      turn_pre={ done=true,},
      turn_pre_run_pre={ done=true,},
      turn_pst={ done=true, events={ { frame=2, name="footstep",},},},
      turn_pst_run_pre={ done=true,},
      upgrade_accept={ done=true, events={ { frame=6, name="jump",}, { frame=57, name="land",},},},
      x_death_old_x={ done=true,},
    },
    player_bank_cannon={
      cannon_H_land={ events={ { frame=1, name="land",}, { frame=4, name="sfx-cannon_run",},},},
      cannon_H_to_H_atk={ events={ { frame=16, name="land",}, { frame=17, name="sfx-cannon_run",},},},
      cannon_H_to_plant={
        events={ { frame=5, name="land-quiet",}, { frame=1, name="sfx-cannon_whoosh",},},
      },
      cannon_atk2_pre={ done=true, events={ { frame=2, name="sfx-cannon_whoosh",},},},
      cannon_atk2_pst={ done=true, events={ { frame=1, name="sfx-cannon_plant_pickup",},},},
      cannon_backfire_hold_pre={ events={ { frame=1, name="sfx-sfx-cannon_plant",},},},
      cannon_mortar_early={ events={ { frame=8, name="sfx-cannon_grab",}, { frame=1, name="sfx-slip",},},},
      cannon_mortar_heavy_atk={
        events={
          { frame=39, name="sfx-cannon_grab",},
          { frame=54, name="sfx-cannon_run",},
          { frame=19, name="sfx-cannon_drop",},
          { frame=2, name="sfx-cannon_latch",},
        },
      },
      cannon_mortar_late={
        events={
          { frame=8, name="sfx-cannon_pickup_quiet",},
          { frame=5, name="sfx-cannon_drop_quiet",},
        },
      },
      cannon_mortar_med_atk={ events={ { frame=19, name="sfx-cannon_run",},},},
      cannon_reload_early={
        done=true,
        events={
          { frame=1, name="sfx-cannon_toss",},
          { frame=29, name="sfx-cannon_reload_full",},
          { frame=10, name="sfx-cannon_ammo_fall",},
          { frame=11, name="sfx-cannon_run",},
        },
      },
      cannon_reload_fast={
        events={
          { frame=1, name="sfx-cannon_pull_back",},
          { frame=8, name="sfx-cannon_reload_full",},
        },
      },
      cannon_reload_slow={
        events={
          { frame=1, name="sfx-cannon_pull",},
          { frame=13, name="sfx-ammo_fall",},
          { frame=16, name="sfx-reload_partial_start",},
          { frame=29, name="sfx-reload_partial_end",},
        },
      },
      cannon_shockwave_heavy_atk={
        events={
          { frame=21, name="sfx-land",},
          { frame=30, name="sfx-sfx-hand_shake",},
          { frame=19, name="sfx-cannon_drop_quiet",},
          { frame=60, name="sfx-cannon_pull",},
          { frame=74, name="sfx-cannon_plant_pickup",},
        },
      },
      cannon_shockwave_hold_loop={ done=true, events={ { frame=1, name="sfx-cannon_plug",},},},
      cannon_shockwave_late={
        events={
          { frame=10, name="sfx-cannon_pickup",},
          { frame=5, name="sfx-cannon_drop_quiet",},
        },
      },
      cannon_skill_whip={ events={ { frame=2, name="sfx-cannon_butt",},},},
    },
    player_bank_cannon_basic={
      cannon_aim_rev_run_loop={
        events={ { frame=9, name="sfx-cannon_run",}, { frame=21, name="sfx-cannon_run",},},
      },
      cannon_aim_run_loop={
        events={ { frame=9, name="sfx-cannon_run",}, { frame=21, name="sfx-cannon_run",},},
      },
      cannon_death={
        events={
          { frame=7, name="sfx-cannon_drop",},
          { frame=15, name="sfx-cannon_drop_quiet",},
        },
      },
      cannon_fatigue_run_loop={
        events={ { frame=9, name="sfx-cannon_run",}, { frame=21, name="sfx-cannon_run",},},
      },
      cannon_fatigue_run_side_loop={
        events={ { frame=9, name="sfx-cannon_run",}, { frame=21, name="sfx-cannon_run",},},
      },
      cannon_fatigue_run_up_loop={
        events={ { frame=9, name="sfx-cannon_run",}, { frame=21, name="sfx-cannon_run",},},
      },
      cannon_getup_pst={ events={ { frame=3, name="sfx-cannon_pickup_quiet",},},},
      cannon_knockback={ events={ { frame=7, name="sfx-cannon_run",},},},
      cannon_knockdown={ events={ { frame=8, name="sfx-cannon_drop",},},},
      cannon_knockdown_pst={
        events={
          { frame=8, name="sfx-cannon_drop_quiet",},
          { frame=12, name="sfx-cannon_bodyfall",},
        },
      },
      cannon_knockhigh={
        events={
          { frame=15, name="sfx-cannon_drop",},
          { frame=26, name="sfx-cannon_drop_quiet",},
        },
      },
      cannon_knockhigh_pst={
        events={
          { frame=16, name="sfx-cannon_drop_quiet",},
          { frame=25, name="sfx-cannon_drop_quiet",},
        },
      },
      cannon_run_loop={
        events={ { frame=9, name="sfx-cannon_run",}, { frame=21, name="sfx-cannon_run",},},
      },
      cannon_run_side_loop={
        events={ { frame=9, name="sfx-cannon_run",}, { frame=21, name="sfx-cannon_run",},},
      },
      cannon_run_up_loop={
        events={ { frame=9, name="sfx-cannon_run",}, { frame=21, name="sfx-cannon_run",},},
      },
      cannon_sheathe_fast={ events={ { frame=3, name="sfx-cannon_sheathe",},},},
      cannon_skill_unsheathe={ events={ { frame=1, name="sfx-cannon_unsheathe",},},},
    },
    player_bank_emotes={
      emote_amphibee_bubble_kiss={
        events={
          { frame=7, name="sfx-smooch",},
          { frame=17, name="sfx-bubbles",},
          { frame=38, name="footstep",},
          { frame=10, name="sfx-mvmt_med",},
          { frame=2, name="sfx-mvmt_sm",},
          { frame=44, name="sfx-pop",},
          { frame=15, name="sfx-kiss",},
        },
      },
      emote_no_thx={
        events={
          { frame=5, name="sfx-mvmt_sm",},
          { frame=39, name="sfx-mvmt_sm",},
          { frame=32, name="sfx-no",},
          { frame=17, name="sfx-no",},
        },
      },
      emote_ogre_charged_jump={
        done=true,
        events={
          { frame=2, name="sfx-ogre_dash",},
          { frame=13, name="sfx-ogre_dash",},
          { frame=22, name="sfx-ogre_dash",},
          { frame=35, name="sfx-mvmt_lg",},
          { frame=36, name="jump",},
          { frame=39, name="sfx-shout",},
          { frame=54, name="sfx-pant_inhale",},
          { frame=62, name="sfx-pant_exhale",},
          { frame=67, name="sfx-mvmt_med",},
        },
      },
      emote_pump={
        events={
          { frame=9, name="sfx-cheer",},
          { frame=22, name="sfx-cheer",},
          { frame=4, name="sfx-mvmt_sm",},
          { frame=18, name="sfx-mvmt_sm",},
        },
      },
    },
    player_bank_flying_machine={
      claw_drop={
        events={
          { frame=5, name="sfx-claw_pully",},
          { frame=32, name="sfx-claw_open",},
          { frame=48, name="sfx-claw_close",},
          { frame=36, name="sfx-claw_bodyfall",},
        },
      },
      claw_pickup={
        events={
          { frame=1, name="sfx-claw_pully",},
          { frame=9, name="sfx-claw_close",},
          { frame=23, name="sfx-claw_pully",},
        },
      },
    },
    player_bank_hammer={
      OLD_hammer_roll_reverse_atk_pst={
        events={
          { frame=16, name="sfx-hammer_drop1_quiet",},
          { frame=20, name="sfx-hammer_drop1",},
          { frame=25, name="sfx-hammer_drop1_quiet",},
          { frame=27, name="sfx-hammer_drop1_quiet",},
        },
      },
      hammer_atk1={ done=true,},
      hammer_atk1_pst={ done=true, events={ { frame=4, name="footstep_quiet",},},},
      hammer_atk2={ done=true, events={ { frame=0, name="jump",},},},
      hammer_atk2_pst={ done=true, events={ { frame=1, name="footstep",},},},
      hammer_atk2_pst_OLD={ done=true,},
      hammer_atk3={ done=true, events={ { frame=1, name="land",},},},
      hammer_atk3_pre={ done=true,},
      hammer_atk4={
        done=true,
        events={
          { frame=5, name="footstep",},
          { frame=1, name="footstep",},
          { frame=4, name="footstep",},
          { frame=2, name="sfx-Hammer_atk_reverse",},
          { frame=5, name="sfx-Hammer_atk_overhead_impact",},
        },
      },
      hammer_atk4_pre={ done=true, events={ { frame=6, name="footstep_stop",},},},
      hammer_big_atk1_loop={
        done=true,
        events={ { frame=1, name="sfx-spin",}, { frame=5, name="footstep_stop",},},
      },
      hammer_big_atk1_pre={ done=true, events={ { frame=28, name="footstep",},},},
      hammer_big_atk1_pre_short={ done=true, events={ { frame=1, name="sfx-hammer_drop1",},},},
      hammer_big_atk1_sheathe2_pst={
        events={
          { frame=2, name="sfx-spin_pst",},
          { frame=5, name="footstep_stop",},
          { frame=9, name="hammer_drop2",},
          { frame=18, name="footstep",},
        },
      },
      hammer_big_atk1_sheathe3_pst={
        events={
          { frame=2, name="sfx-spin_pst",},
          { frame=5, name="footstep_stop",},
          { frame=9, name="hammer_drop2",},
          { frame=19, name="footstep",},
          { frame=28, name="struggle",},
        },
      },
      hammer_big_atk1_sheathe_pst={
        events={
          { frame=1, name="sfx-spin_pst",},
          { frame=5, name="footstep_stop",},
          { frame=9, name="hammer_drop2",},
        },
      },
      hammer_equip={ events={ { frame=3, name="hand",}, { frame=9, name="hand",},},},
      hammer_fade_to_roll_atk3_pre={ done=true,},
      hammer_fade_to_smash_jump={ done=true, events={ { frame=0, name="sfx-jump",},},},
      hammer_roll_atk3_pre={ done=true,},
      hammer_roll_fade_atk={
        events={
          { frame=1, name="hand",},
          { frame=4, name="jump",},
          { frame=12, name="hammer_drop1",},
          { frame=12, name="hand",},
        },
      },
      hammer_roll_fade_atk_pst={ events={ { frame=6, name="footstep_stop",},},},
      hammer_roll_loop={ done=true,},
      hammer_roll_pre={ done=true,},
      hammer_roll_pst={ events={ { frame=0, name="hand",}, { frame=9, name="footstep",},},},
      hammer_roll_reverse_atk={
        done=true,
        events={ { frame=1, name="footstep",}, { frame=4, name="footstep",},},
      },
      hammer_roll_reverse_atk_pre={
        done=true,
        events={ { frame=4, name="footstep",}, { frame=4, name="hammer_drop1",},},
      },
      hammer_roll_reverse_atk_pst={ done=true, events={ { frame=8, name="footstep",},},},
      hammer_roll_up_loop={ done=true,},
      hammer_skill_thump_atk={ done=true,},
      hammer_skill_thump_pre={ events={ { frame=1, name="sfx-ground_thrust_charge",},},},
      hammer_smash_air={ events={ { frame=1, name="yell",}, { frame=3, name="land",},},},
      hammer_smash_air_alt={ events={ { frame=1, name="whoosh-heavy",},},},
      hammer_smash_air_pre={ done=true,},
      hammer_smash_jump={ done=true, events={ { frame=0, name="sfx-jump",},},},
      hammer_smash_jump_pre={ done=true, events={ { frame=0, name="jump-heavy",}, { frame=0, name="jump",},},},
      hammer_smash_pst={ done=true, events={ { frame=0, name="footstep",},},},
    },
    player_bank_hammer_basic={
      hammer_death={
        done=true,
        events={
          { frame=1, name="deathvoice",},
          { frame=11, name="bodyfall",},
          { frame=6, name="sfx-hammer_drop1",},
          { frame=12, name="sfx-hammer_drop1",},
          { frame=18, name="sfx-hammer_drop1",},
        },
      },
      hammer_death_hit={ done=true, events={ { frame=1, name="hit_vo",},},},
      hammer_death_idle={ done=true,},
      hammer_fatigue_idle={ done=true, events={ { frame=28, name="breath_out",},},},
      hammer_fatigue_idle_pre={ done=true, events={ { frame=8, name="breath_out",},},},
      hammer_fatigue_run_loop={
        done=true,
        events={ { frame=9, name="footstep",}, { frame=21, name="footstep",},},
      },
      hammer_fatigue_run_pre={ done=true,},
      hammer_fatigue_run_pst={ done=true, events={ { frame=1, name="footstep_stop",},},},
      hammer_getup_pre={ done=true, events={ { frame=3, name="hand",},},},
      hammer_getup_pst={ done=true, events={ { frame=3, name="footstep",},},},
      hammer_getup_struggle={ done=true, events={ { frame=9, name="struggle",},},},
      hammer_hit={ done=true, events={ { frame=3, name="hit_vo",},},},
      hammer_idle={ done=true,},
      hammer_idle_blink={ done=true,},
      hammer_idle_blink_alert={ done=true,},
      hammer_knockback={ done=true, events={ { frame=1, name="yell",}, { frame=7, name="footstep",},},},
      hammer_knockback_pst={ events={ { frame=1, name="yell",},},},
      hammer_knockdown={
        done=true,
        events={
          { frame=10, name="bodyfall",},
          { frame=13, name="hand",},
          { frame=15, name="hand",},
          { frame=9, name="sfx-hammer_drop1",},
          { frame=12, name="sfx-hammer_drop1",},
        },
      },
      hammer_knockdown_hit={ done=true, events={ { frame=8, name="slump",},},},
      hammer_knockdown_idle={ done=true,},
      hammer_knockdown_pst={ events={ { frame=12, name="bodyfall",},},},
      hammer_knockhigh={
        done=true,
        events={
          { frame=1, name="jump",},
          { frame=14, name="yell",},
          { frame=19, name="bodyfall",},
          { frame=22, name="hand",},
          { frame=30, name="slump",},
          { frame=15, name="sfx-hammer_drop1",},
          { frame=20, name="sfx-hammer_drop1",},
          { frame=25, name="sfx-hammer_drop1",},
        },
      },
      hammer_knockhigh_pst={
        events={
          { frame=15, name="sfx-hammer_drop1_quiet",},
          { frame=21, name="sfx-hammer_drop1",},
          { frame=25, name="sfx-hammer_drop1_quiet",},
          { frame=27, name="sfx-hammer_drop1_quiet",},
        },
      },
      hammer_konjur_accept={ done=true, events={ { frame=1, name="sfx-konjur_accept",},},},
      hammer_pickup_item={ done=true, events={ { frame=1, name="grab",},},},
      hammer_power_no_pst={
        done=true,
        events={ { frame=1, name="footstep",}, { frame=3, name="footstep",},},
      },
      hammer_power_yes_pst={
        done=true,
        events={ { frame=21, name="footstep",}, { frame=23, name="footstep",},},
      },
      hammer_sheathe_fast={ events={ { frame=1, name="sfx-sheath_hammer",},},},
      hammer_turn_pre={ done=true,},
      hammer_turn_pst={ done=true,},
      hammer_unsheathe_fast={ events={ { frame=1, name="sfx-unsheath_hammer",},},},
      hammer_upgrade={ events={ { frame=39, name="yell",}, { frame=1, name="sfx-power_up",},},},
      konjur_accept={ events={ { frame=10, name="ha",},},},
      power_accept={ done=true, events={ { frame=1, name="sfx-power_up",},},},
      turn_pre_hammer_fatigue_run_pre={ done=true,},
      turn_pre_hammer_run_pre={ done=true,},
      turn_pst_hammer_fatigue_run_pre={ done=true, events={ { frame=1, name="footstep",},},},
      turn_pst_hammer_run_pre={ done=true,},
      upgrade={ events={ { frame=39, name="yell",},},},
    },
    player_bank_polearm={
      X_polearm_atk2_X={ done=true,},
      X_polearm_atk_pst_X={ done=true,},
      X_polearm_roll_rev_atk_X={ done=true,},
      polearm_atk={ done=true, events={ { frame=2, name="footstep_stop",},},},
      polearm_atk2={ done=true, events={ { frame=16, name="footstep_quiet",},},},
      polearm_atk3={ done=true, events={ { frame=8, name="footstep_quiet",},},},
      polearm_atk_pre={ done=true,},
      polearm_atk_pst={ done=true, events={ { frame=1, name="footstep",},},},
      polearm_atk_pst_OLD={ done=true,},
      polearm_combo_heavy_atk_pre={ done=true,},
      polearm_heavy_atk={ done=true, events={ { frame=1, name="jump",}, { frame=20, name="land",},},},
      polearm_heavy_atk_pre={ done=true,},
      polearm_multithrust_atk={ done=true, events={ { frame=13, name="footstep_stop",},},},
      polearm_rev_heavy_atk={ done=true, events={ { frame=1, name="jump",}, { frame=20, name="land",},},},
      polearm_roll={
        done=true,
        events={
          { frame=10, name="hand",},
          { frame=19, name="footstep",},
          { frame=1, name="roll",},
        },
      },
      polearm_roll_OLD={ done=true,},
      polearm_roll_atk={
        done=true,
        events={
          { frame=0, name="jump",},
          { frame=12, name="land",},
          { frame=16, name="footstep",},
        },
      },
      polearm_roll_atk2_pre={ done=true,},
      polearm_roll_loop={ done=true,},
      polearm_roll_rev_atk={
        done=true,
        events={
          { frame=7, name="footstep",},
          { frame=12, name="footstep",},
          { frame=20, name="footstep",},
        },
      },
      polearm_shove={ events={ { frame=1, name="sfx-shove",},},},
      polearm_skill_vault_pre={
        events={ { frame=13, name="sfx-vault_jump",}, { frame=7, name="sfx-vault_plant",},},
      },
      polearm_skill_vault_pst={ events={ { frame=8, name="sfx-vault_land",},},},
      x_polearm_roll_rev_heavy_atk_pre_x={ done=true,},
    },
    player_bank_polearm_basic={
      polearm_death={
        done=true,
        events={
          { frame=1, name="deathvoice",},
          { frame=9, name="sfx-polearm_drop",},
          { frame=12, name="sfx-polearm_drop",},
          { frame=13, name="bodyfall",},
          { frame=14, name="sfx-polearm_drop",},
          { frame=22, name="hand",},
          { frame=25, name="hand",},
        },
      },
      polearm_death_hit={ done=true, events={ { frame=1, name="yell",},},},
      polearm_death_idle={ done=true,},
      polearm_fatigue_idle={ done=true, events={ { frame=27, name="breath_out",},},},
      polearm_fatigue_idle_pre={ done=true, events={ { frame=1, name="breath_out",},},},
      polearm_fatigue_run_loop={
        done=true,
        events={ { frame=9, name="footstep",}, { frame=21, name="footstep",},},
      },
      polearm_fatigue_run_pre={ done=true,},
      polearm_fatigue_run_pst={ done=true, events={ { frame=1, name="footstep_stop",},},},
      polearm_getup_pre={ done=true,},
      polearm_getup_pst={ done=true, events={ { frame=5, name="footstep",},},},
      polearm_getup_struggle={ done=true, events={ { frame=4, name="struggle",},},},
      polearm_hit={ done=true, events={ { frame=1, name="hit_vo",},},},
      polearm_idle={ done=true,},
      polearm_idle_blink={ done=true,},
      polearm_idle_blink_alert={ done=true,},
      polearm_knockback={ done=true, events={ { frame=1, name="yell",}, { frame=7, name="footstep",},},},
      polearm_knockdown={
        done=true,
        events={
          { frame=6, name="sfx-polearm_drop",},
          { frame=10, name="bodyfall",},
          { frame=10, name="sfx-polearm_drop",},
          { frame=12, name="sfx-polearm_drop",},
        },
      },
      polearm_knockdown_hit={ done=true, events={ { frame=8, name="slump",},},},
      polearm_knockdown_idle={ done=true,},
      polearm_knockdown_pst={
        events={
          { frame=12, name="bodyfall",},
          { frame=6, name="sfx-polearm_drop_quiet",},
          { frame=10, name="sfx-polearm_drop_quiet",},
          { frame=12, name="sfx-polearm_drop_quiet",},
        },
      },
      polearm_knockhigh={
        done=true,
        events={
          { frame=1, name="jump",},
          { frame=14, name="sfx-polearm_drop",},
          { frame=14, name="yell",},
          { frame=18, name="sfx-polearm_drop",},
          { frame=21, name="bodyfall",},
          { frame=22, name="sfx-polearm_drop",},
          { frame=25, name="sfx-polearm_drop",},
        },
      },
      polearm_knockhigh_pst={
        events={
          { frame=13, name="sfx-polearm_drop_quiet",},
          { frame=19, name="sfx-polearm_drop_quiet",},
          { frame=22, name="sfx-polearm_drop_quiet",},
          { frame=24, name="sfx-polearm_drop_quiet",},
        },
      },
      polearm_konjur_accept={ events={ { frame=1, name="sfx-konjur_accept",},},},
      polearm_pickup_item={ done=true, events={ { frame=1, name="grab",},},},
      polearm_potion={ events={ { frame=1, name="potion",},},},
      polearm_power_loop={ done=true,},
      polearm_power_no_pst={
        done=true,
        events={ { frame=1, name="footstep",}, { frame=3, name="footstep",},},
      },
      polearm_power_yes_pst={
        done=true,
        events={ { frame=21, name="footstep",}, { frame=23, name="footstep",},},
      },
      polearm_run_loop={
        done=true,
        events={ { frame=9, name="footstep",}, { frame=21, name="footstep",},},
      },
      polearm_run_pre={ done=true,},
      polearm_run_pst={ done=true, events={ { frame=1, name="footstep_stop",},},},
      polearm_sheathe_fast={ events={ { frame=1, name="sfx-sheath_polearm",},},},
      polearm_turn_pre={ done=true,},
      polearm_turn_pst={ done=true,},
      polearm_unsheathe_fast={ events={ { frame=1, name="sfx-unsheath_polearm",},},},
      polearm_upgrade={ done=true,},
      turn_pre_polearm_fatigue_run_pre={ done=true,},
      turn_pre_polearm_run_pre={ done=true,},
      turn_pst_polearm_fatigue_run_pre={ done=true,},
      turn_pst_polearm_run_pre={ done=true,},
    },
    player_bank_shotput={
      shotput_H_atk={ events={ { frame=4, name="footstep",},},},
      shotput_H_atk2={ events={ { frame=12, name="footstep_quiet",}, { frame=14, name="land",},},},
      shotput_H_atk3={ events={ { frame=9, name="footstep",},},},
      shotput_focus_atk1={
        done=true,
        events={ { frame=11, name="footstep",}, { frame=0, name="land-quiet",},},
      },
      shotput_focus_atk2={ events={ { frame=11, name="footstep",}, { frame=0, name="land-quiet",},},},
      shotput_roll_loop={ events={ { frame=1, name="roll",},},},
      shotput_roll_up_loop={ events={ { frame=1, name="roll",},},},
      shotput_tackle={ events={ { frame=10, name="footstep",}, { frame=1, name="dash",},},},
    },
    player_bank_shotput_basic={ shotput_knockdown_pst={ events={ { frame=12, name="bodyfall",},},},},
    player_bank_skills={
      skill_banana_front_pst={ events={ { frame=9, name="banana_land",},},},
      skill_banana_pre={ events={ { frame=16, name="banana_eat",}, { frame=6, name="banana_toss",},},},
      skill_throw_stone_hold={ events={ { frame=2, name="throw_stone_charge",},},},
      skill_throw_stone_pre={ events={ { frame=2, name="throw_stone_grab",},},},
      skill_throw_stone_pst={ events={ { frame=1, name="throw_stone_throw",},},},
    },
  },
  group="SOUND_player",
  prefab={ { prefab="player_side",},},
}
