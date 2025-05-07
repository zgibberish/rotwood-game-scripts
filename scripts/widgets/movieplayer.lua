local Widget = require "widgets.widget"

local BUFFERED_FRAMES = 4 -- How many frames are bufferd before movie playback begins.

local MoviePlayer = Class(Widget, function( self, filename, w, h, include_audio )
	Widget._ctor(self, "MovePlayer")

	local bus
	if include_audio == true and AUDIO:IsEnabled() then
--TODO_KAJ		bus = AUDIO:GetBus( "bus:/Master/sfx/movies" )
	end
	
	self.inst.entity:AddVideoWidget()

	if w and h then
		self:SetSize(w,h)
	end
	self.inst.VideoWidget:SetBufferedFrames(BUFFERED_FRAMES)

	if filename then
		if not self.inst.VideoWidget:LoadMovie(filename) then
			LOGWARN( "Could not find movie: %s", filename )
		end
		self.filename = filename
	end
end)

function MoviePlayer:OnRemoved()
	self:StopMovie()
end

function MoviePlayer:SetSize( w, h )
	self.inst.VideoWidget:SetSize(w,h)
end

function MoviePlayer:PlayMovie( filename, loop )
	if filename and filename ~= self.filename then
		if not self.inst.VideoWidget:LoadMovie(filename) then
			LOGWARN( "Could not find movie: %s", filename )
		else
			print( "MoviePlayer:PlayMovie:", filename, loop )
		end
		self.filename = filename
	end
	self.inst.VideoWidget:PlayMovie(loop)
end

function MoviePlayer:GetDuration()
	return self.inst.VideoWidget:GetDuration()
end

function MoviePlayer:StopMovie()
	self.inst.VideoWidget:StopMovie()
end

function MoviePlayer:PauseMovie()
	self.inst.VideoWidget:PauseMovie()
end

function MoviePlayer:IsDone()
	return self.inst.VideoWidget:IsDone()
end

function MoviePlayer:IsPlaying()
	return self.inst.VideoWidget:IsPlaying()
end

function MoviePlayer:IsPaused()
	return self.inst.VideoWidget:IsPaused()
end


function MoviePlayer:SetBlendTexture(texture)
	self.inst.VideoWidget:SetBlendTexture(texture)
--TODO_KAJ	self.inst.VideoWidget:SetBlendMode(BLEND_MODE.BLENDED)
end

function MoviePlayer:SetBlendFactors(factor, threshold)
	self.inst.VideoWidget:SetBlendFactorAndThreshold(factor, threshold)
end

return MoviePlayer
