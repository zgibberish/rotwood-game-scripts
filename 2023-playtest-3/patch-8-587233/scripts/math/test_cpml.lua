
local tests = {
	"bound2_spec",
	"bound3_spec",
	"color_spec",
	--~ "intersect_spec",
	--~ "mat4_spec",
	--~ "mesh_spec",
	--~ "octree_spec",
	--~ "quat_spec",
	"utils_spec",
	"vec2_spec",
	"vec3_spec",
}

-- Test with testy instead of busted.
local function test_cpml()
	-- Don't require until testy has loaded so we use testy asserts.
	local fakebusted = require "math.fakebusted"
	fakebusted.dump_globals()
	fakebusted.assert(assert.is.equal)

	package.path = package.path .. ";math/?.lua"
	for _,test_file in ipairs(tests) do
		require("math.spec.".. test_file)
	end
end
