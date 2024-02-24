MultiCallback = Class(function(self)
	self.remaining = 1 -- wait for WhenAllComplete in case functions aren't async
	local successall = true
	self.fn = function(success)
		--~ assert(success) -- Uncomment to debug failures.
		successall = successall and success
		self.remaining = self.remaining - 1
		if self.remaining == 0 and self.cb ~= nil then
			self.cb(successall)
		end
	end
end)

function MultiCallback:AddInstance()
	self.remaining = self.remaining + 1
	return self.fn
end

function MultiCallback:WhenAllComplete(cb)
	dbassert(self.cb == nil, "Only supports one callback and it's already set.")
	self.cb = cb
	self.fn(true)
end
