--!strict
-- 인생네컷 "몇 장 뽑을까요?" step (user, 2026-10-22): after the host chose
-- the frame, each person picks 1장 or 2장 and presses 프린트하기 (2026-10-30; was < 1 >, minimum
-- 1). The first print is free, every extra one costs PhotoConfig coins.
-- Kept out of PhotoBoothController (local register limit).

local EconomyConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("EconomyConfig"))

local PhotoCopiesPanel = {}

export type Info = { free: number, price: number, max: number }

local function make(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end
local function round(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

-- Builds the panel inside `parent` (fills it). `onSave(count)` is called with
-- the chosen number. Returns the panel frame.
function PhotoCopiesPanel.open(parent: GuiObject, info: Info, zIndex: number, onSave: (count: number) -> ()): Frame
	local old = parent:FindFirstChild("CopiesPanel")
	if old then old:Destroy() end
	local maxCount = math.max(1, info.max)
	local count = 1
	local outer = make("Frame", {
		Name = "CopiesPanel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = zIndex,
	}, parent)
	-- Fixed 260 × 206 content, scaled down to fit small (phone) boxes
	-- (user mobile test 2026-10-22: texts overlapped).
	local panel = make("Frame", {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(260, 206),
		BackgroundTransparency = 1,
		ZIndex = zIndex,
	}, outer)
	local scale = make("UIScale", {}, panel)
	local function fit()
		local size = outer.AbsoluteSize
		scale.Scale = math.clamp(math.min(size.X / 270, size.Y / 216), 0.4, 1.3)
	end
	outer:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.defer(fit)
	make("TextLabel", {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "몇 장 뽑을까요?",
		ZIndex = zIndex,
	}, panel)
	make("TextLabel", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		Text = string.format("각자 %d장은 무료 · 2장부터 1장마다 %s %d", info.free, EconomyConfig.Icon, info.price),
		ZIndex = zIndex,
	}, panel)
	-- [ 1장 ] [ 2장 ] to choose, then 프린트하기 to finish (user 2026-10-30:
	-- the print only happens when that button is pressed)
	local row = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(240, 64),
		BackgroundTransparency = 1,
		ZIndex = zIndex,
	}, panel)
	local choices: {TextButton} = {}
	for n = 1, math.min(2, maxCount) do
		local b = make("TextButton", {
			Name = "Copies" .. n,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(if math.min(2, maxCount) == 1 then 0.5 else (n == 1 and 0.25 or 0.75), 0, 0.5, 0),
			Size = UDim2.fromOffset(104, 58),
			BackgroundColor3 = Color3.fromRGB(40, 38, 50),
			Font = Enum.Font.GothamBlack,
			TextSize = 22,
			TextColor3 = Color3.new(1, 1, 1),
			Text = n .. "장",
			ZIndex = zIndex + 1,
		}, row)
		round(b, 16)
		make("UIStroke", { Color = Color3.fromRGB(255, 120, 180), Thickness = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
		choices[n] = b
	end
	local cost = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 130),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 220, 110),
		Text = "",
		ZIndex = zIndex,
	}, panel)
	local save = make("TextButton", {
		Name = "SaveCopies",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 160),
		Size = UDim2.fromOffset(220, 44),
		BackgroundColor3 = Color3.fromRGB(255, 120, 180),
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "🖨 프린트하기",
		ZIndex = zIndex,
	}, panel)
	round(save, 14)
	local function refresh()
		for n, b in ipairs(choices) do
			local on = n == count
			b.BackgroundColor3 = if on then Color3.fromRGB(255, 120, 180) else Color3.fromRGB(40, 38, 50)
			local s = b:FindFirstChildOfClass("UIStroke")
			if s then s.Thickness = if on then 0 else 2 end
		end
		local price = (count - 1) * info.price
		cost.Text = if price > 0 then string.format("%d장 · 추가 %s %d", count, EconomyConfig.Icon, price) else string.format("%d장 · 무료", count)
		save.Text = "🖨 프린트하기"
	end
	for n, b in ipairs(choices) do
		b.MouseButton1Click:Connect(function()
			count = n
			refresh()
		end)
	end
	local busy = false
	save.MouseButton1Click:Connect(function()
		if busy then return end
		busy = true
		save.Text = "프린트 중..."
		onSave(count)
		busy = false
		if outer.Parent then refresh() end
	end)	refresh()
	return outer
end

return PhotoCopiesPanel
