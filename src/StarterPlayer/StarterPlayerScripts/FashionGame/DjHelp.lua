--!strict
-- "?" next to the DJ window's X (D-734, user 2026-11-01: the turntable got
-- complicated): a window saying what every button does. ClubMusicController
-- makes the button and calls DjHelp.toggle.

local DjHelp = {}

local PANEL = Color3.fromRGB(10, 14, 32)
local CARD = Color3.fromRGB(20, 27, 56)
local TEXT = Color3.fromRGB(255, 255, 255)
local SUB = Color3.fromRGB(170, 182, 214)
local ACCENT = Color3.fromRGB(0, 190, 230)

-- { title, what it does }; a title starting with "#" is a section heading
local ENTRIES: {{ string }} = {
	{ "#🎧 DJ" },
	{ "시간 연장", "DJ 시간을 더 사요. 기다리는 사람이 있으면 연장 대신 대기 순서에 들어가요." },
	{ "⏭ 건너뛰기", "지금 곡을 넘기고 다음 곡을 틀어요." },
	{ "👥 초대", "아래 목록이 사람 목록으로 바뀌어요. 초대한 사람만 DJ 존(무대)에 올라올 수 있어요." },
	{ "⏸ 일시정지", "클럽 음악을 멈춰요. 다시 누르면 이어서 재생해요." },
	{ "📺 전광판", "DJ 부스 뒤 큰 전광판에 내 모습을 실시간으로 보여 줘요(ON/OFF)." },
	{ "🎆 무대 스파클러", "무대 앞에서 불꽃이 터져요. 90초에 한 번 쓸 수 있어요." },
	{ "#💡 조명" },
	{ "💡 조명", "무빙 라이트와 바닥·벽의 비트 조명을 켜고 꺼요." },
	{ "✳ 레이저 · ⚡x1", "레이저를 켜고 꺼요. 옆의 ⚡를 누를 때마다 레이저가 빨라져요(x0.5~x5)." },
	{ "색 칸", "조명과 레이저 색을 골라요. 🌈는 무지개(색이 계속 바뀜)예요." },
	{ "#🎛 EDM · 소리 (클럽 안 모두에게 들려요)" },
	{ "🎛 EDM", "누르면 지금 노래에 EDM 음악이 함께 겹쳐서 나와요. 다시 누르면 EDM만 꺼져요." },
	{ "🔄 초기화", "EDM 속도·노래 속도·볼륨 슬라이더를 모두 x1로 되돌려요." },
	{ "⚡ EDM 속도", "EDM 음악의 빠르기예요. 오른쪽으로 끌면 빨라지고 왼쪽은 느려져요(x0.5~x2)." },
	{ "🎵 노래 속도", "지금 노래의 빠르기예요(x0.5~x2). 빨라지면 음도 높아져요." },
	{ "🔊 노래 볼륨", "클럽 음악 소리 크기예요(x0~x3). EDM 음악에도 똑같이 적용돼요." },
	{ "#🎵 곡" },
	{ "지금 · 다음", "'지금'은 바로 틀고, '다음'은 지금 곡이 끝나면 나오게 예약해요. 🎵 표시는 안무가 있는 곡이에요." },
}

local window: Frame? = nil

local function build(gui: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = "DjHelp"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.52)
	frame.Size = UDim2.new(1, -40, 1, -90)
	frame.BackgroundColor3 = PANEL
	frame.ZIndex = 20
	frame.Visible = false
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)
	local size = Instance.new("UISizeConstraint")
	size.MaxSize = Vector2.new(460, 520)
	size.Parent = frame
	local edge = Instance.new("UIStroke")
	edge.Color = ACCENT
	edge.Thickness = 2
	edge.Parent = frame

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -60, 0, 28)
	title.BackgroundTransparency = 1
	title.Text = "❓ 턴테이블 버튼 설명"
	title.TextColor3 = TEXT
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 21
	title.Parent = frame

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(28, 28)
	close.BackgroundColor3 = CARD
	close.Text = "X"
	close.TextColor3 = TEXT
	close.Font = Enum.Font.GothamBold
	close.TextSize = 15
	close.ZIndex = 21
	close.Parent = frame
	Instance.new("UICorner", close).CornerRadius = UDim.new(1, 0)
	close.Activated:Connect(function() frame.Visible = false end)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 46)
	list.Size = UDim2.new(1, -24, 1, -56)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 21
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for i, entry in ipairs(ENTRIES) do
		local head = entry[1]
		if string.sub(head, 1, 1) == "#" then
			local section = Instance.new("TextLabel")
			section.LayoutOrder = i
			section.Size = UDim2.new(1, -6, 0, 24)
			section.BackgroundTransparency = 1
			section.Text = string.sub(head, 2)
			section.TextColor3 = ACCENT
			section.Font = Enum.Font.GothamBold
			section.TextSize = 15
			section.TextXAlignment = Enum.TextXAlignment.Left
			section.ZIndex = 22
			section.Parent = list
		else
			local card = Instance.new("Frame")
			card.LayoutOrder = i
			card.Size = UDim2.new(1, -6, 0, 0)
			card.AutomaticSize = Enum.AutomaticSize.Y
			card.BackgroundColor3 = CARD
			card.ZIndex = 22
			card.Parent = list
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
			pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
			pad.Parent = card
			local stack = Instance.new("UIListLayout")
			stack.Padding = UDim.new(0, 2)
			stack.SortOrder = Enum.SortOrder.LayoutOrder
			stack.Parent = card
			local name = Instance.new("TextLabel")
			name.LayoutOrder = 1
			name.Size = UDim2.new(1, 0, 0, 18)
			name.BackgroundTransparency = 1
			name.Text = head
			name.TextColor3 = TEXT
			name.Font = Enum.Font.GothamBold
			name.TextSize = 14
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.ZIndex = 23
			name.Parent = card
			local what = Instance.new("TextLabel")
			what.LayoutOrder = 2
			what.Size = UDim2.new(1, 0, 0, 0)
			what.AutomaticSize = Enum.AutomaticSize.Y
			what.BackgroundTransparency = 1
			what.Text = entry[2]
			what.TextColor3 = SUB
			what.Font = Enum.Font.GothamMedium
			what.TextSize = 13
			what.TextWrapped = true
			what.TextXAlignment = Enum.TextXAlignment.Left
			what.ZIndex = 23
			what.Parent = card
		end
	end
	return frame
end

function DjHelp.toggle(gui: Instance)
	if not window then window = build(gui) end
	local w = window :: Frame
	w.Visible = not w.Visible
end

function DjHelp.close()
	if window then window.Visible = false end
end

return DjHelp
