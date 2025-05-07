
-- p0 = start point
-- p1 = control point
-- p2 = end point
function BezierEvaluate(t, p0_x, p0_y, p1_x, p1_y, p2_x, p2_y)
	local z = t;
	local zsqr = z * z;
	local z_min_one = 1.0 - t;
	local z_min_one_sqr = z_min_one * z_min_one;

	return (z_min_one_sqr * p0_x) + (2.0 * z * z_min_one * p1_x) + (zsqr * p2_x), (z_min_one_sqr * p0_y) + (2.0 * z * z_min_one * p1_y) + (zsqr * p2_y);
end
