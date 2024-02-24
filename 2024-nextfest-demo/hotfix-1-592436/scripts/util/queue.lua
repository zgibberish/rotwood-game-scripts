require "class"


local Queue = Class(function(self)
	self.list = {}
end)

function Queue:Push(item)
	table.insert(self.list, item)
end

function Queue:Pop()
	return table.remove(self.list, 1)
end

function Queue:Peek()
	return self.list[1]
end

function Queue:Count()
	return #self.list
end

function Queue:IsEmpty()
	return self:Count() == 0
end

return Queue
