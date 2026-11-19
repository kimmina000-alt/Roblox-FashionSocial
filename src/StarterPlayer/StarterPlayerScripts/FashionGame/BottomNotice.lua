--!strict
-- One line notices at the bottom middle, over the hotbar (D-1311 / D-1765: the trash pick-up
-- notice). (D-1811, user 2026-11-19: "무대 스파클러 터트렸을 때 뜨는 문구나 후원 문구 모두 쓰레기통에서 뭐
-- 주웠을 때 뜨는 문구 위치와 텍스트 크기로 통일. 대신 빨간색.") stage cold sparks and supporter gifts
-- use the same stack, in red, so the lines never overlap.
-- Bold 13 px text with a black outline and shadow; the newest line lowest; up to MAX_ROWS lines,
-- the oldest goes first.
-- (D-1812, user 2026-11-19: "콜드 스파크는 상단에 띄우고 깜빡깜빡 거리게 하자 글자 1.5배 키우고") options
-- { top = true } puts the line in a second stack under the top bar, { blink = true } blinks it,
-- { size = n } sets the text size (cold sparks: top, blinking, 20 = 13 x 1.5)

local Players = game:GetService("Players")

local BottomNotice = {}

local MAX_ROWS = 4
local player = Players.LocalPlayer

local stacks: {[string]: Frame} = {}
local order = 0
local font = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

BottomNotice.RED = Color3.fromRGB(255, 40, 60)
BottomNotice.YELLOW = Color3.fromRGB(255, 220, 40) -- (D-1813: cold sparks)

local function getStack(top: boolean): Frame
	local key = if top then "top" else "bottom"
	local found = stacks[key]
	if found and found.Parent then return found end
	local gui = Instance.new("ScreenGui")
	-- (kept name for the bottom one: the trash notice's own gui since D-1311)
	gui.Name = if top then "TopNoticeGui" else "TrashNoticeGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.Parent = player:WaitForChild("PlayerGui")
	local s = Instance.new("Frame")
	if top then
		local TopBar = require(script.Parent:WaitForChild("TopBar")) :: any
		s.AnchorPoint = Vector2.new(0.5, 0)
		s.Position = UDim2.new(0.5, 0, 0, TopBar.bottom() + 8)
	else
		s.AnchorPoint = Vector2.new(0.5, 1)
		s.Position = UDim2.new(0.5, 0, 1, -96)
	end
	s.Size = UDim2.new(1, -24, 0, 110)
	s.BackgroundTransparency = 1
	s.Parent = gui
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)
	list.VerticalAlignment = if top then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom
	list.Parent = s
	stacks[key] = s
	return s
end

export type Options = { top: boolean?, blink: boolean?, size: number? }

-- text: one line; color: the text colour (white by default); seconds: how long before it fades (4)
function BottomNotice.show(text: string, color: Color3?, seconds: number?, options: Options?)
	local top = options ~= nil and options.top == true
	local size = (options and options.size) or 13
	local s = getStack(top)
	if top then
		local TopBar = require(script.Parent:WaitForChild("TopBar")) :: any
		s.Position = UDim2.new(0.5, 0, 0, TopBar.bottom() + 8) -- (the top bar can wrap to two rows)
	end
	order += 1
	local row = Instance.new("Frame")
	row.Name = "Notice"
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, size + 3)
	row.BackgroundTransparency = 1
	row.Parent = s
	local function label(c: Color3, offset: number, z: number): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(offset, offset)
		l.Size = UDim2.fromScale(1, 1)
		l.Text = text
		l.TextSize = size
		l.FontFace = font
		l.TextColor3 = c
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.ZIndex = z
		l.Parent = row
		return l
	end
	local shadow = label(Color3.new(0, 0, 0), 1, 1)
	shadow.TextTransparency = 0.25
	local front = label(color or Color3.new(1, 1, 1), 0, 2)
	-- (user 2026-11-11: "검은색 외곽선도 넣어 잘 안 보임") a black outline as well as the shadow
	front.TextStrokeColor3 = Color3.new(0, 0, 0)
	front.TextStrokeTransparency = 0
	local rows = {}
	for _, r in ipairs(s:GetChildren()) do if r:IsA("Frame") then table.insert(rows, r) end end
	table.sort(rows, function(a, b) return a.LayoutOrder > b.LayoutOrder end) -- (newest first: the oldest go)
	for i = MAX_ROWS + 1, #rows do rows[i]:Destroy() end
	local fading = false
	if options and options.blink then
		-- on 0.45 s, faint 0.3 s, until it fades out
		task.spawn(function()
			while row.Parent and not fading do
				front.TextTransparency, front.TextStrokeTransparency, shadow.TextTransparency = 0, 0, 0.25
				task.wait(0.45)
				if not row.Parent or fading then break end
				front.TextTransparency, front.TextStrokeTransparency, shadow.TextTransparency = 0.8, 0.8, 0.9
				task.wait(0.3)
			end
		end)
	end
	task.delay(seconds or 4, function()
		fading = true
		for k = 1, 10 do
			if not row.Parent then return end
			front.TextTransparency = k / 10
			front.TextStrokeTransparency = k / 10
			shadow.TextTransparency = 0.25 + 0.75 * k / 10
			task.wait(0.05)
		end
		row:Destroy()
	end)
end

return BottomNotice
