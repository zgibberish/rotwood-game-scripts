local lume = require "util.lume"


-- Utilities for doing camera stuff.
local camerautil = {}

camerautil.defaults = {
	-- Tune the default gameplay pitch here.
	pitchrad = math.asin(1 / 2.5),
	dist = 30,
	screen = {
		focus_dist = 25,
	},
}
camerautil.defaults.pitch = math.deg(camerautil.defaults.pitchrad)


function camerautil.ReleaseCamera(inst)
	TheCamera:SetTarget(TheFocalPoint)
	if TheCamera.camera_blender then
		TheCamera.camera_blender:Remove()
		TheCamera.camera_blender = nil
	end
	if inst.blend_tasks then
		for key,task in pairs(inst.blend_tasks) do
			task:Cancel()
		end
		inst.blend_tasks = nil
	end
	TheCamera:SetOffset(0, 0, 0)
	TheCamera:SetPitch(camerautil.defaults.pitch)
end

local function _GetBlender()
	if not TheCamera.camera_blender then
		TheCamera.camera_blender = CreateEntity("cam_blender")
		TheCamera.camera_blender.entity:AddTransform()
		TheCamera.camera_blender:AddComponent("moveto")
	end
	return TheCamera.camera_blender
end

-- Blend from current camera view to focus on target entity. Gives a lot more
-- blending control than just changing to camera's target.
function camerautil.BlendToTarget(target, param, oncomplete_fn)
	assert(param.duration)
	local blender = _GetBlender()
	local pos = TheCamera:GetCurrentPosWithoutOffset()
	blender.Transform:SetPosition(pos.x, pos.y, pos.z)

	blender.components.moveto:SetTarget(target)
		:SetOnComplete(oncomplete_fn)
		:StartMove(param.duration * ANIM_FRAMES, param.curve)
	TheCamera:SetTarget(blender)
end

function camerautil.Edit_BlendCut(ui, param, inst)
	if param.duration then
		param.cut = param.duration < 5 or nil
	end
	ui:PushDisabledStyle()
	ui:Checkbox("Snap Cut", param.cut)
	ui:PopDisabledStyle()
end

function camerautil.StartTarget(inst, param)
	TheCamera:SetTarget(inst)
	TheCamera:SetDistance(param.dist or TheFocalPoint.desired_camera_distance)
	local offset = param.offset or Vector3.zero
	TheCamera:SetOffset(Vector3.unpack(offset))
	if param.cut then
		TheCamera:Snap()
	end
end


function camerautil.BlendDist(inst, param)
	inst.blend_tasks = inst.blend_tasks or {}
	if inst.blend_tasks.dist then
		inst.blend_tasks.dist:Cancel()
	end
	local start_dist = TheCamera:GetDistance()
	local desired_dist = param.dist or TheFocalPoint.desired_camera_distance
	inst.blend_tasks.dist = inst:DoDurationTaskForAnimFrames(param.duration, function(inst_, progress)
		progress = EvaluateCurve(param.curve, progress)
		local dist = lume.lerp(start_dist, desired_dist, progress)
		TheCamera:SetDistance(dist)
	end)
end

local was_previewing = nil
function camerautil.Edit_Distance(ui, param, inst)
	-- Never store nil for dist. Nil means "gameplay default distance"
	param.dist = ui:_SliderFloat("Camera Distance", param.dist or camerautil.defaults.dist, 10, 60)
	local should_preview = ui:IsItemActive()
	if should_preview then
		TheCamera:SetDistance(param.dist)
		TheCamera:Snap()
		was_previewing = true
	elseif was_previewing then
		was_previewing = nil
		TheCamera:SetDistance(camerautil.defaults.dist)
	end
end

function camerautil.BlendOffset(inst, param)
	inst.blend_tasks = inst.blend_tasks or {}
	if inst.blend_tasks.offset then
		inst.blend_tasks.offset:Cancel()
	end
	local start_offset = TheCamera:GetOffset()
	local desired_offset = Vector3(param.offset or Vector3.zero)
	inst.blend_tasks.offset = inst:DoDurationTaskForAnimFrames(param.duration, function(inst_, progress)
		progress = EvaluateCurve(param.curve, progress)
		local offset = lume.lerp(start_offset, desired_offset, progress)
		TheCamera:SetOffset(offset:unpack())
	end)
end

function camerautil.ApplyOffset(offset)
	TheCamera:SetOffset(Vector3.unpack(offset or Vector3.zero))
end

function camerautil.Edit_Offset(ui, param, inst)
	local offset = param.offset or Vector3.zero:to_table()
	local changed = ui:DragVec3f("World Offset from Target", offset, nil, -30, 30)
	if changed then
		if Vector3.is_zero(offset) then
			offset = nil
		end
		param.offset = offset
	end

	local should_preview = ui:IsItemActive()
	if should_preview then
		camerautil.ApplyOffset(param.offset)
		TheCamera:Snap()
		was_previewing = true
	elseif was_previewing then
		was_previewing = nil
		camerautil.ApplyOffset(camerautil.defaults.offset)
	end
	return changed
end

function camerautil.BlendPitch(inst, param)
	inst.blend_tasks = inst.blend_tasks or {}
	if inst.blend_tasks.pitch then
		inst.blend_tasks.pitch:Cancel()
	end
	local start_pitch = TheCamera:GetPitch()
	local desired_pitch = param.pitch or camerautil.defaults.pitch
	inst.blend_tasks.pitch = inst:DoDurationTaskForAnimFrames(param.duration, function(inst_, progress)
		progress = EvaluateCurve(param.curve, progress)
		local pitch = lume.lerp(start_pitch, desired_pitch, progress)
		TheCamera:SetPitch(pitch)
	end)
end


function camerautil.Edit_Curve(ui, param)
	if param.cut then
		param.curve = nil
		return
	end

	param.curve = param.curve or CreateCurve(0, 1)
	local snap_to_min_max = true
	if ui:CurveEditor("Curve", param.curve, nil, nil, snap_to_min_max) then
		-- Force starting value to 0 so blend in is always smooth.
		param.curve[2] = 0
	end
end

return camerautil
