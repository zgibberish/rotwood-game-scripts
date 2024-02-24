return {
  version = "1.5",
  luaversion = "5.1",
  tiledversion = "1.7.2",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = 26,
  height = 26,
  tilewidth = 64,
  tileheight = 64,
  nextlayerid = 5,
  nextobjectid = 3,
  properties = {},
  tilesets = {
    {
      name = "startingforest",
      firstgid = 1,
      filename = "../../../../contentsrc/levels/TileGroups/startingforest.tsx"
    },
    {
      name = "zone_tiles",
      firstgid = 65,
      filename = "../../../../contentsrc/levels/TileGroups/zone_tiles.tsx"
    }
  },
  layers = {
    {
      type = "tilelayer",
      x = 0,
      y = 0,
      width = 26,
      height = 26,
      id = 1,
      name = "BG_TILES",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      encoding = "lua",
      data = {
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 3, 2, 2, 3, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 3, 3, 2, 2, 3, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 2, 2, 2, 2, 2, 3, 3, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 2, 3, 3, 3, 3, 3, 3, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 2, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 2, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 3, 3, 3, 2, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 3, 2, 2, 2, 2, 2, 2, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 2, 2, 2, 2, 3, 3, 2, 2, 2, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 3, 3, 3, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
      }
    },
    {
      type = "tilelayer",
      x = 0,
      y = 0,
      width = 26,
      height = 26,
      id = 4,
      name = "ZONE_TILES",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      encoding = "lua",
      data = {
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 77, 77, 77, 77, 77, 77, 77, 77, 77, 77, 77, 77, 77, 77, 77, 77, 77, 77, 77, 77, 77, 77, 0,
        0, 0, 0, 76, 76, 76, 76, 76, 76, 76, 76, 76, 76, 76, 76, 76, 76, 76, 76, 76, 76, 76, 76, 76, 76, 0,
        0, 0, 0, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 68, 0,
        0, 0, 0, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 0,
        0, 0, 0, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 67, 81, 81, 67, 67, 67, 67, 67, 0,
        0, 0, 0, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 66, 81, 81, 66, 66, 66, 66, 66, 0,
        0, 0, 0, 71, 71, 71, 71, 71, 71, 70, 70, 70, 69, 69, 79, 79, 79, 79, 80, 80, 79, 69, 70, 71, 71, 0,
        0, 0, 0, 71, 71, 71, 71, 71, 70, 70, 70, 69, 69, 79, 80, 80, 80, 80, 80, 80, 79, 69, 70, 71, 71, 0,
        0, 0, 0, 71, 71, 71, 71, 70, 70, 70, 69, 69, 79, 80, 80, 80, 80, 80, 80, 80, 79, 69, 70, 71, 71, 0,
        0, 0, 0, 71, 71, 71, 70, 70, 70, 70, 69, 69, 79, 80, 80, 80, 79, 78, 78, 78, 79, 69, 70, 71, 71, 0,
        0, 0, 0, 71, 71, 70, 70, 70, 69, 69, 69, 69, 79, 80, 80, 80, 79, 82, 82, 82, 69, 69, 70, 71, 71, 0,
        0, 0, 0, 71, 71, 70, 69, 69, 69, 69, 69, 79, 79, 80, 80, 79, 82, 82, 83, 69, 69, 70, 70, 71, 71, 0,
        0, 0, 0, 71, 71, 70, 69, 79, 79, 79, 79, 79, 80, 80, 80, 79, 82, 83, 83, 69, 70, 70, 70, 71, 71, 0,
        0, 0, 0, 71, 71, 70, 69, 79, 80, 80, 80, 80, 80, 80, 80, 79, 82, 83, 83, 69, 70, 70, 71, 71, 71, 0,
        0, 0, 0, 71, 70, 81, 81, 80, 80, 80, 80, 80, 80, 80, 80, 79, 82, 83, 69, 69, 70, 71, 71, 71, 71, 0,
        0, 0, 0, 71, 70, 81, 81, 80, 80, 80, 80, 80, 80, 80, 80, 79, 69, 69, 69, 70, 70, 71, 71, 71, 71, 0,
        0, 0, 0, 73, 73, 73, 73, 79, 78, 78, 78, 78, 78, 78, 78, 73, 73, 73, 73, 73, 73, 73, 73, 73, 73, 0,
        0, 0, 0, 74, 74, 74, 74, 73, 73, 73, 73, 73, 73, 73, 73, 74, 74, 74, 74, 74, 74, 75, 75, 75, 75, 0,
        0, 0, 0, 75, 75, 75, 75, 74, 74, 74, 74, 74, 74, 74, 74, 75, 75, 75, 75, 75, 75, 75, 72, 72, 72, 0,
        0, 0, 0, 72, 72, 72, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 72, 72, 72, 72, 72, 72, 72, 72, 72, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
      }
    },
    {
      type = "objectgroup",
      draworder = "topdown",
      id = 2,
      name = "PORTALS",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = {},
      objects = {
        {
          id = 1,
          name = "",
          type = "room_portal",
          shape = "rectangle",
          x = 1212.02,
          y = 638.306,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["roomportal.cardinal"] = "north"
          }
        },
        {
          id = 2,
          name = "",
          type = "room_portal",
          shape = "rectangle",
          x = 447.403,
          y = 1214.31,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          properties = {
            ["roomportal.cardinal"] = "west"
          }
        }
      }
    }
  }
}
