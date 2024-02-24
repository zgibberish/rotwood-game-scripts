-- A SceneGen generates prop placements at runtime. Its member data specializes it for a particular dungeon.

local scenegenutil = require "prefabs.scenegenutil"


-- This module returns a tuple (NOT a table!) of all the SceneGen prefabs.
return table.unpack(scenegenutil.GetAllPrefabs())
