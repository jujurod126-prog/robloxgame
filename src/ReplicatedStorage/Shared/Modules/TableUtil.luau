--!strict
--[[
	TableUtil
	Small table helpers used by the data modules and DataService.
]]

local TableUtil = {}

-- Returns a full copy of a table, including nested tables.
function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value :: any do
		copy[TableUtil.deepCopy(key)] = TableUtil.deepCopy(child)
	end
	return copy :: any
end

-- Freezes a table and every table inside it so data can't be edited by accident at runtime.
function TableUtil.deepFreeze<T>(value: T): T
	if type(value) == "table" and not table.isfrozen(value :: any) then
		for _, child in value :: any do
			TableUtil.deepFreeze(child)
		end
		table.freeze(value :: any)
	end
	return value
end

--[[
	Finishes a game-data dictionary such as Flavors or Pets:
	  * checks every entry's Id matches its key (catches copy/paste mistakes)
	  * deep-freezes the whole thing
]]
function TableUtil.defineData<T>(moduleName: string, dictionary: { [string]: T }): { [string]: T }
	for key, entry in dictionary do
		local id = (entry :: any).Id
		assert(id == key, `[{moduleName}] entry "{key}" has Id "{tostring(id)}" (they must match)`)
	end
	return TableUtil.deepFreeze(dictionary)
end

-- Returns the dictionary's values as an array sorted by their Order field (ties broken by Id).
function TableUtil.sortedByOrder<T>(dictionary: { [string]: T }): { T }
	local list = {}
	for _, entry in dictionary do
		table.insert(list, entry)
	end
	table.sort(list, function(a: any, b: any)
		if a.Order == b.Order then
			return a.Id < b.Id
		end
		return a.Order < b.Order
	end)
	return list
end

return TableUtil
