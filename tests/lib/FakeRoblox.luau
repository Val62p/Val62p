--!nocheck
-- Instances simulées pour exécuter le code CLIENT hors de Roblox.
-- Chaque objet enveloppe une vraie instance @lune/roblox : toute écriture de propriété est
-- donc validée par la base de réflexion Roblox (nom et type), tandis que les événements
-- (Activated, AttributeChanged, Triggered…) sont simulés et déclenchables par les tests.
local roblox = require("@lune/roblox")

local FakeRoblox = {}

---------------------------------------------------------------------------
-- Ordonnanceur déterministe (task.*) : rien ne tourne en arrière-plan sans pump().
---------------------------------------------------------------------------

local scheduler = { now = 0, queue = {} }
FakeRoblox.scheduler = scheduler

local function resume(thread, ...)
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		error(debug.traceback(thread, tostring(err)), 0)
	end
end

local task = {}
function task.spawn(fn, ...)
	local thread = if type(fn) == "thread" then fn else coroutine.create(fn)
	resume(thread, ...)
	return thread
end
-- Comme dans Roblox : exécuté plus tard (au prochain pump), jamais au milieu du code en cours.
function task.defer(fn, ...)
	local thread = if type(fn) == "thread" then fn else coroutine.create(fn)
	table.insert(scheduler.queue, { at = scheduler.now, thread = thread, args = table.pack(...) })
	return thread
end
function task.delay(seconds, fn, ...)
	local thread = coroutine.create(fn)
	table.insert(scheduler.queue, { at = scheduler.now + (seconds or 0), thread = thread, args = table.pack(...) })
	return thread
end
function task.wait(seconds)
	local thread = coroutine.running()
	table.insert(scheduler.queue, { at = scheduler.now + (seconds or 0), thread = thread, args = table.pack() })
	coroutine.yield()
	return seconds or 0
end
function task.cancel() end
FakeRoblox.task = task

-- Avance le temps simulé et réveille les fils échus (une fois chacun).
function FakeRoblox.pump(seconds)
	scheduler.now += seconds or 0
	local due = {}
	for i = #scheduler.queue, 1, -1 do
		if scheduler.queue[i].at <= scheduler.now then
			table.insert(due, 1, table.remove(scheduler.queue, i))
		end
	end
	for _, item in due do
		if coroutine.status(item.thread) == "suspended" then
			resume(item.thread, table.unpack(item.args, 1, item.args.n))
		end
	end
end

---------------------------------------------------------------------------
-- Signaux
---------------------------------------------------------------------------

function FakeRoblox.signal()
	local signal = { handlers = {}, waiting = {} }
	function signal:Connect(handler)
		local entry = { handler = handler, connected = true }
		table.insert(self.handlers, entry)
		return {
			Connected = true,
			Disconnect = function()
				entry.connected = false
			end,
		}
	end
	function signal:Once(handler)
		local connection
		connection = self:Connect(function(...)
			connection.Disconnect()
			handler(...)
		end)
		return connection
	end
	function signal:Wait()
		table.insert(self.waiting, coroutine.running())
		return coroutine.yield()
	end
	function signal:Fire(...)
		for _, entry in table.clone(self.handlers) do
			if entry.connected then
				task.spawn(entry.handler, ...)
			end
		end
		local waiting = self.waiting
		self.waiting = {}
		for _, thread in waiting do
			resume(thread, ...)
		end
	end
	return signal
end

---------------------------------------------------------------------------
-- Enveloppe d'instance
---------------------------------------------------------------------------

local EVENTS = {
	Activated = true,
	MouseButton1Click = true,
	MouseEnter = true,
	MouseLeave = true,
	Triggered = true,
	PromptShown = true,
	AttributeChanged = true,
	Changed = true,
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	Destroying = true,
	Died = true,
	CharacterAdded = true,
	Completed = true,
	OnClientEvent = true,
	FocusLost = true,
}

-- Lacunes connues de @lune/roblox (propriétés valides dans Roblox mais refusées ici).
local TOLERATED_WRITE = { CurrentCamera = true }

-- Valeurs par défaut pour les propriétés calculées par le moteur.
FakeRoblox.defaults = {
	AbsoluteSize = Vector2 and Vector2.new(1280, 720) or roblox.Vector2.new(1280, 720),
	AbsolutePosition = roblox.Vector2.new(0, 0),
	Health = 100,
}

local stateOf = setmetatable({}, { __mode = "k" })
local proxyOf = setmetatable({}, { __mode = "k" })
local Meta = {}

local function unwrap(value)
	local state = stateOf[value]
	if state then
		return state.real
	end
	return value
end
FakeRoblox.unwrap = unwrap

local function wrap(real)
	if real == nil then
		return nil
	end
	if typeof(real) ~= "Instance" then
		return real
	end
	local existing = proxyOf[real]
	if existing then
		return existing
	end
	local proxy = setmetatable({}, Meta)
	stateOf[proxy] = { real = real, signals = {}, propertySignals = {}, attributeSignals = {}, values = {} }
	proxyOf[real] = proxy
	return proxy
end
FakeRoblox.wrap = wrap

local function signalFor(state, key)
	local signal = state.signals[key]
	if not signal then
		signal = FakeRoblox.signal()
		state.signals[key] = signal
	end
	return signal
end

local function wrapList(list)
	local out = {}
	for _, item in list do
		table.insert(out, wrap(item))
	end
	return out
end

local methods = {}

function methods:FindFirstChild(name, recursive)
	return wrap(stateOf[self].real:FindFirstChild(name, recursive))
end
function methods:WaitForChild(name)
	local child = stateOf[self].real:FindFirstChild(name)
	if not child then
		error("WaitForChild bloquerait indéfiniment : " .. tostring(name))
	end
	return wrap(child)
end
function methods:FindFirstChildOfClass(className)
	return wrap(stateOf[self].real:FindFirstChildOfClass(className))
end
function methods:FindFirstChildWhichIsA(className)
	for _, child in stateOf[self].real:GetChildren() do
		if child:IsA(className) then
			return wrap(child)
		end
	end
	return nil
end
function methods:GetChildren()
	return wrapList(stateOf[self].real:GetChildren())
end
function methods:GetDescendants()
	return wrapList(stateOf[self].real:GetDescendants())
end
function methods:IsA(className)
	return stateOf[self].real:IsA(className)
end
function methods:IsDescendantOf(other)
	return stateOf[self].real:IsDescendantOf(unwrap(other))
end
function methods:Destroy()
	local state = stateOf[self]
	if state.signals.Destroying then
		state.signals.Destroying:Fire()
	end
	state.real:Destroy()
end
function methods:ClearAllChildren()
	stateOf[self].real:ClearAllChildren()
end
function methods:Clone()
	return wrap(stateOf[self].real:Clone())
end
function methods:SetAttribute(name, value)
	local state = stateOf[self]
	state.real:SetAttribute(name, value)
	if state.attributeSignals[name] then
		state.attributeSignals[name]:Fire()
	end
	if state.signals.AttributeChanged then
		state.signals.AttributeChanged:Fire(name)
	end
end
function methods:GetAttribute(name)
	return stateOf[self].real:GetAttribute(name)
end
function methods:GetAttributeChangedSignal(name)
	local state = stateOf[self]
	local signal = state.attributeSignals[name]
	if not signal then
		signal = FakeRoblox.signal()
		state.attributeSignals[name] = signal
	end
	return signal
end
function methods:GetPropertyChangedSignal(name)
	local state = stateOf[self]
	local signal = state.propertySignals[name]
	if not signal then
		signal = FakeRoblox.signal()
		state.propertySignals[name] = signal
	end
	return signal
end
function methods:GetPivot()
	local real = stateOf[self].real
	if real:IsA("Model") then
		return real.WorldPivot
	end
	return real.CFrame
end
function methods:PivotTo(cframe)
	local real = stateOf[self].real
	if real:IsA("Model") then
		local pivot = real.WorldPivot
		for _, part in real:GetDescendants() do
			if part:IsA("BasePart") then
				part.CFrame = cframe * pivot:ToObjectSpace(part.CFrame)
			end
		end
		real.WorldPivot = cframe
	else
		real.CFrame = cframe
	end
end
function methods:GetFullName()
	return stateOf[self].real:GetFullName()
end

Meta.__index = function(proxy, key)
	local state = stateOf[proxy]
	local method = methods[key]
	if method then
		return method
	end
	if EVENTS[key] then
		return signalFor(state, key)
	end
	if key == "Parent" then
		return wrap(state.real.Parent)
	end
	if state.values[key] ~= nil then
		return state.values[key]
	end
	local ok, value = pcall(function()
		return state.real[key]
	end)
	if ok then
		return wrap(value)
	end
	if key == "Position" and state.real:IsA("BasePart") then
		return state.real.CFrame.Position
	end
	if FakeRoblox.defaults[key] ~= nil then
		return FakeRoblox.defaults[key]
	end
	local child = state.real:FindFirstChild(key)
	if child then
		return wrap(child)
	end
	error(tostring(key) .. " is not a valid member of " .. state.real.ClassName, 2)
end

Meta.__newindex = function(proxy, key, value)
	local state = stateOf[proxy]
	local raw = unwrap(value)
	local ok, err = pcall(function()
		state.real[key] = raw
	end)
	if not ok and not TOLERATED_WRITE[key] then
		error(err, 2)
	end
	if typeof(raw) ~= "Instance" then
		state.values[key] = value
	end
	local signal = state.propertySignals[key]
	if signal then
		signal:Fire()
	end
end

Meta.__tostring = function(proxy)
	return stateOf[proxy].real.Name
end

FakeRoblox.Instance = {
	new = function(className, parent)
		local proxy = wrap(roblox.Instance.new(className))
		if parent then
			proxy.Parent = parent
		end
		return proxy
	end,
}

-- Déclenche un événement simulé sur un objet (ex. clic : fire(bouton, "Activated")).
function FakeRoblox.fire(proxy, eventName, ...)
	signalFor(stateOf[proxy], eventName):Fire(...)
end

-- Recherche récursive d'un descendant par prédicat.
function FakeRoblox.find(proxy, predicate)
	for _, descendant in proxy:GetDescendants() do
		if predicate(descendant) then
			return descendant
		end
	end
	return nil
end

return FakeRoblox
