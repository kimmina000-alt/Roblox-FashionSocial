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

-- (D-1031) any window open now (the 20-minute 의견 ask waits for none)
function Popups.anyOpen(): boolean
	return current ~= nil
end

-- (D-1260, user 2026-11-10: "가방 열린 상태에서 모든 팝업이 있는 상태에서 팝업 외 바깥
-- 공간 누르면 꺼지게") a short tap or click on the game itself (nothing of the UI
-- drawn under it) closes the open popup. A drag, a camera turn or a long press
-- is not a tap; a card being dragged out of the bag is not either.
do
	local Players = game:GetService("Players")
	local UserInputService = game:GetService("UserInputService")
	local player = Players.LocalPlayer
	local function drawn(o: GuiObject): boolean
		if o.BackgroundTransparency < 0.99 then return true end
		if (o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")) and o.Text ~= "" and o.TextTransparency < 1 then return true end
		if (o:IsA("ImageLabel") or o:IsA("ImageButton")) and o.Image ~= "" and o.ImageTransparency < 1 then return true end
		return o:IsA("ViewportFrame") or o:IsA("ScrollingFrame")
	end
	local function onUi(p: Vector3): boolean
		local pg = player:FindFirstChildOfClass("PlayerGui")
		if not pg then return true end
		for _, o in ipairs(pg:GetGuiObjectsAtPosition(p.X, p.Y)) do
			if drawn(o) then return true end
		end
		return false
	end
	-- (D-2047, user 2026-11-24: "채팅창 누르면 카탈로그 꺼지는 거 수정") Roblox's own chat window, chat
	-- input bar and top-bar buttons are drawn outside PlayerGui, so a tap on them looked like a tap
	-- on the game: they count as UI now. (Their AbsolutePosition may or may not include the top-bar
	-- inset, so both are tried.)
	local TextChatService = game:GetService("TextChatService")
	local GuiService = game:GetService("GuiService")
	local function onRobloxUi(p: Vector3): boolean
		if p.Y < 0 then return true end -- (the Roblox top bar: menu, chat button)
		local inset = GuiService:GetGuiInset()
		for _, name in ipairs({ "ChatWindowConfiguration", "ChatInputBarConfiguration" }) do
			local config = TextChatService:FindFirstChild(name) :: any
			if config and config.Enabled then
				local ok, pos, size = pcall(function() return config.AbsolutePosition, config.AbsoluteSize end)
				if ok and typeof(pos) == "Vector2" and typeof(size) == "Vector2" and size.X > 0 and size.Y > 0 then
					for _, q in ipairs({ Vector2.new(p.X, p.Y), Vector2.new(p.X, p.Y) + inset }) do
						if q.X >= pos.X - 6 and q.X <= pos.X + size.X + 6 and q.Y >= pos.Y - 6 and q.Y <= pos.Y + size.Y + 6 then
							return true
						end
					end
				end
			end
		end
		return false
	end
	local downs: {[InputObject]: { t: number, p: Vector3, open: Entry }} = {}
	UserInputService.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if current and (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) then
			downs[input] = { t = os.clock(), p = input.Position, open = current :: Entry }
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local d = downs[input]
		downs[input] = nil
		local open = current
		if not d or not open then return end
		-- (D-1763, user 2026-11-18: "춤추는 중에 불꽃판매원 누르면 자꾸 창 꺼짐") only the window that was open when the
		-- tap began: a tap that itself opened a window (a ProximityPrompt, drawn outside PlayerGui, pressed
		-- with the dance window open) closed the new window again as it lifted
		if open ~= d.open then return end
		if os.clock() - d.t > 0.4 or (input.Position - d.p).Magnitude > 12 then return end
		local Hotbar = script.Parent:FindFirstChild("Hotbar")
		if Hotbar then
			local ok, dragging = pcall(function() return (require(Hotbar) :: any).isDragging() end)
			if ok and dragging then return end
		end
		if onUi(d.p) or onUi(input.Position) then return end
		if onRobloxUi(d.p) or onRobloxUi(input.Position) then return end -- (D-2047)
		current = nil
		local ok, err = pcall(open.close)
		if not ok then warn("[Popups] outside tap closing " .. open.name .. ": " .. tostring(err)) end
	end)
end

return Popups
