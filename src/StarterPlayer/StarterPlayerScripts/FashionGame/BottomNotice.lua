--!strict
-- One line notices at the bottom middle, over the hotbar (D-1311 / D-1765: the trash pick-up
-- notice). (D-1811, user 2026-11-19: "무대 스파클러 터트렸을 때 뜨는 문구나 후원 문구 모두 쓰레기통에서 뭐
-- 주웠을 때 뜨는 문구 위치와 텍스트 크기로 통일. 대신 빨간색.") stage cold sparks and supporter gifts
-- use the same stack, in red, so the lines never overlap.
-- Bold 13 px text with a black outline and shadow; the newest line lowest; up to MAX_ROWS lines,
-- the oldest goes first.

local Players = game:GetService("Players")

local BottomNotice = {}

local MAX_ROWS = 4
local player = Players.LocalPlayer

local stack: Frame? = nil
local order = 0
local font = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

BottomNotice.RED = Color3.fromRGB(255, 40, 60)

local function getStack(): Frame
	if stack and stack.Parent then return stack end
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrashNoticeGui" -- (kept name: the trash notice's own gui since D-1311)
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.Parent = player:WaitForChild("PlayerGui")
	local s = Instance.new("Frame")
	s.AnchorPoint = Vector2.new(0.5, 1)
	s.Position = UDim2.new(0.5, 0, 1, -96)
	s.Size = UDim2.new(1, -24, 0, 80)
	s.BackgroundTransparency = 1
	s.Parent = gui
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.Parent = s
	stack = s
	return s
end

-- text: one line; color: the text colour (white by default); seconds: how long before it fades (4)
function BottomNotice.show(text: string, color: Color3?, seconds: number?)
	local s = getStack()
	order += 1
	local row = Instance.new("Frame")
	row.Name = "Notice"
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 16)
	row.BackgroundTransparency = 1
	row.Parent = s
	local function label(c: Color3, offset: number, z: number): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(offset, offset)
		l.Size = UDim2.fromScale(1, 1)
		l.Text = text
		l.TextSize = 13
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
	task.delay(seconds or 4, function()
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
