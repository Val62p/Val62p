--!strict
-- Signal minimal en Luau pur (connexions déconnectables, appel synchrone).
local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (self: Connection) -> () }

function Signal.new()
	return setmetatable({ handlers = {} :: { [number]: (...any) -> () }, nextId = 0 }, Signal)
end

function Signal:Connect(handler: (...any) -> ()): Connection
	self.nextId += 1
	local id = self.nextId
	self.handlers[id] = handler
	local handlers = self.handlers
	return {
		Disconnect = function()
			handlers[id] = nil
		end,
	} :: any
end

function Signal:Fire(...: any)
	local ids = {}
	for id in self.handlers do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local handler = self.handlers[id]
		if handler then
			handler(...)
		end
	end
end

return Signal
