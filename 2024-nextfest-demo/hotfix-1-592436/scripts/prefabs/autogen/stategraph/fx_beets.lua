-- Generated by Embellisher and loaded by stategraph_autogen.lua
return {
  __displayName="fx_beets",
  isfinal=true,
  prefab={ "beets",},
  stategraphs={
    sg_beets={
      sg_events={
        {
          eventtype="spawneffect",
          name="vfx-headslam",
          param={ fxname="beets_headslam", inheritrotation=true,},
        },
        {
          eventtype="spawneffect",
          name="vfx-headslam_elite",
          param={ fxname="beets_headslam_elite", inheritrotation=true,},
        },
        {
          eventtype="spawnimpactfx",
          name="vfx-headslam_impact",
          param={ impact_size=1, impact_type=1, offx=0.80000001192093, offz=0.0,},
        },
      },
    },
  },
}
