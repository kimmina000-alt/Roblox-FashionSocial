--!strict
-- 인생네컷 "몇 장 저장할까요?" step (user, 2026-10-22): after the host chose
-- the frame, each person picks how many prints to keep with  < 1 >  (minimum
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
		Text = "몇 장 저장할까요?",
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
	-- <  1  >
	local row = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(220, 64),
		BackgroundColor3 = Color3.fromRGB(40, 38, 50),
		ZIndex = zIndex,
	}, panel)
	round(row, 32)
	local function arrow(text: string, x: number): TextButton
		local b = make("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(x, 0, 0.5, 0),
			Size = UDim2.fromOffset(48, 48),
			BackgroundColor3 = Color3.fromRGB(255, 120, 180),
			Font = Enum.Font.GothamBlack,
			TextSize = 26,
			TextColor3 = Color3.new(1, 1, 1),
			Text = text,
			ZIndex = zIndex + 1,
		}, row)
		round(b, 24)
		return b
	end
	local minus = arrow("<", 0.16)
	minus.Name = "Less"
	local plus = arrow(">", 0.84)
	plus.Name = "More"
	local number = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(80, 48),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 34,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "1",
		ZIndex = zIndex + 1,
	}, row)
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
		BackgroundColor3 = Color3.fromRGB(255, 214, 90),
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = Color3.fromRGB(60, 40, 10),
		Text = "",
		ZIndex = zIndex,
	}, panel)
	round(save, 14)
	local function refresh()
		number.Text = tostring(count)
		local price = (count - 1) * info.price
		cost.Text = if price > 0 then string.format("%d장 · 추가 %s %d", count, EconomyConfig.Icon, price) else string.format("%d장 · 무료", count)
		save.Text = "🖨 프린트하기" -- (the count shows above; the print happens only here, user 2026-10-30)
		minus.BackgroundTransparency = if count <= 1 then 0.6 else 0
		plus.BackgroundTransparency = if count >= maxCount then 0.6 else 0
	end
	minus.MouseButton1Click:Connect(function()
		if count > 1 then count -= 1 refresh() end
	end)
	plus.MouseButton1Click:Connect(function()
		if count < maxCount then count += 1 refresh() end
	end)
	local busy = false
	save.MouseButton1Click:Connect(function()
		if busy then return end
		busy = true
		save.Text = "프린트 중..."
		onSave(count)
		busy = false
		if outer.Parent then refresh() end
	end)
	refresh()
	return outer
end

return PhotoCopiesPanel
