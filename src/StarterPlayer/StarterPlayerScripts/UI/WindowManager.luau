--!strict
--[[
	WindowManager
	Makes sure only one major window is open at a time.
	Each window controller registers open/close functions; the HUD buttons call
	WindowManager.toggle(name). Opening a window closes whatever was open.
]]

local WindowManager = {}

type Entry = { open: () -> (), close: () -> () }

local windows: { [string]: Entry } = {}
local current: string? = nil

function WindowManager.register(name: string, open: () -> (), close: () -> ())
	windows[name] = { open = open, close = close }
end

function WindowManager.isRegistered(name: string): boolean
	return windows[name] ~= nil
end

function WindowManager.isOpen(name: string): boolean
	return current == name
end

function WindowManager.open(name: string)
	local entry = windows[name]
	if entry == nil or current == name then
		return
	end
	if current then
		WindowManager.close(current)
	end
	current = name
	entry.open()
end

function WindowManager.close(name: string)
	local entry = windows[name]
	if entry and current == name then
		current = nil
		entry.close()
	end
end

function WindowManager.toggle(name: string)
	if current == name then
		WindowManager.close(name)
	else
		WindowManager.open(name)
	end
end

return WindowManager
