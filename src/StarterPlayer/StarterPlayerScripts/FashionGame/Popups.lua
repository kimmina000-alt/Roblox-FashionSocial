--!strict
-- One popup at a time (user, 2026-10-22: opening the DJ window over the
-- catalog stacked popups). A script calls Popups.opened(name, close) when it
-- shows its window; the window that was open before is closed with its own
-- close function. Popups.closed(name) when the window closes by itself.

local Popups = {}

type Entry = { name: string, close: () -> () }
local current: Entry? = nil

-- (2026-10-31, 2P phone test: the ☰ menu stayed open over a shop window)
local listeners: {(string) -> ()} = {}
function Popups.onOpened(f: (string) -> ())
	table.insert(listeners, f)
end

function Popups.opened(name: string, close: () -> ())
	for _, f in ipairs(listeners) do task.spawn(f, name) end
	local previous = current
	current = { name = name, close = close }
	if previous and previous.name ~= name then
		local ok, err = pcall(previous.close)
		if not ok then warn("[Popups] closing " .. previous.name .. ": " .. tostring(err)) end
	end
end

function Popups.closed(name: string)
	if current and current.name == name then current = nil end
end

function Popups.isOpen(name: string): boolean
	return current ~= nil and current.name == name
end

return Popups
