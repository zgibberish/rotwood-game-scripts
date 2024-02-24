-- TODO: once all code stategraph-driven foley sound calls are removed, this file can be removed entirely
-- this is only used to support legacy stategraph foley tags, which Dany is currently in the process of moving to the embellisher

function PlayFootstep(inst, volume, ispredicted)
	inst.components.foleysounder:PlayFootstep(volume, ispredicted)
end

function PlayFootstepStop(inst, volume, ispredicted)
	inst.components.foleysounder:PlayFootstepStop(volume, ispredicted)
end

function PlayFootstepJump(inst, volume, ispredicted)
	inst.components.foleysounder:PlayJump(volume, ispredicted)
end

function PlayFootstepLand(inst, volume, ispredicted)
	inst.components.foleysounder:PlayLand(volume, ispredicted)
end

function PlayBodyfall(inst, volume, ispredicted)
	inst.components.foleysounder:PlayBodyfall(volume, ispredicted)
end

function PlayHand(inst, volume, ispredicted)
	inst.components.foleysounder:PlayHand(volume, ispredicted)
end