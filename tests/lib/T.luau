--!nocheck
-- Mini-framework de test : test(), expect-like helpers, rapport lisible.
local T = {}

local results = { passed = 0, failed = 0, failures = {} }
local currentSuite = ""

local function describeValue(value)
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

function T.suite(name: string)
	currentSuite = name
end

function T.test(name: string, fn: () -> ())
	local ok, err = xpcall(fn, function(message)
		return tostring(message) .. "\n" .. debug.traceback(nil, 2)
	end)
	if ok then
		results.passed += 1
	else
		results.failed += 1
		table.insert(results.failures, currentSuite .. " › " .. name .. "\n    " .. tostring(err))
	end
end

function T.eq(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(
			string.format("%s : attendu %s, obtenu %s", label or "valeur", describeValue(expected), describeValue(actual)),
			2
		)
	end
end

function T.truthy(value: any, label: string?)
	if not value then
		error((label or "valeur") .. " : attendu vrai, obtenu " .. describeValue(value), 2)
	end
end

function T.falsy(value: any, label: string?)
	if value then
		error((label or "valeur") .. " : attendu faux, obtenu " .. describeValue(value), 2)
	end
end

function T.near(actual: number, expected: number, tolerance: number, label: string?)
	if math.abs(actual - expected) > tolerance then
		error(string.format("%s : attendu ≈%s, obtenu %s", label or "valeur", tostring(expected), tostring(actual)), 2)
	end
end

function T.results()
	return results
end

return T
