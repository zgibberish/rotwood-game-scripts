local EntityFrameData = Class(function(self)
	self._data = {}
end)

function EntityFrameData:Clear()
	table.clear(self._data)
end

function EntityFrameData:IsEmpty()
	return #self._data == 0
end

function EntityFrameData:AddData(...)
	local count = select("#", ...)
	for i = 1,count do
		self._data[i] = select(i, ...)
	end
end

function EntityFrameData:ForceSetData(data)
	self._data = data
end

function EntityFrameData:GetData()
	return self._data
end

return EntityFrameData
