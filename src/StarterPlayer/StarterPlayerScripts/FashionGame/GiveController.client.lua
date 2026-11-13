--!strict
-- (D-1396, user 2026-11-14: "다른 사람한테 아이템 주는 기능") With an item in the hand, a tap /
-- click on another player near you asks "🎁 OO을 OO님에게 줄까요? [주기] [취소]"; 주기 sends
-- the offer (GiveService). The other player gets "OO님이 OO을 주려고 해요 [받기] [괜찮아요]"
-- with a countdown; both see how it ended at the top middle.
-- A whole 친구바 tapped on someone is still shared (D-1357), not given. A held drink or
-- sparkler does not sip / light on that tap (ManualActivationOnly while the press is on a
-- player).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")
local TopBar = require(script.Parent:WaitForChild("TopBar"))
local Popups = require(script.Parent:WaitForChild("Popups"))
local Hotbar = require(script.Parent:WaitForChild("Hotbar"))

local REACH = 16
local KINDS = { "Snack", "Plate", "Bottle", "Cup", "Sparkler", "SparklerSet", "HandSparkler" }

local function giveable(tool: Instance?): boolean
	if not tool or not tool:IsA("Tool") then return false end
	if tool:GetAttribute("CafeOrder") or tool:GetAttribute("Lit") or tool:GetAttribute("Drinking") then return false end
	if tool:GetAttribute("Pair") then return false end -- (a whole 친구바: tapping someone shares it)
	for _, k in ipairs(KINDS) do
		if tool:GetAttribute(k) ~= nil then return true end
	end
	return false
end

local function heldTool(): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return if tool and giveable(tool) then tool else nil
end

-- the item's name without its emoji, and 을 / 를 after it
local function itemName(raw: string): string
	local _, name = Hotbar.split(raw)
	return if name ~= "" then name else raw
end
local function object(name: string): string
	local last = utf8.codepoint(name, utf8.offset(name, -1) or 1)
	return name .. (if last >= 0xAC00 and last <= 0xD7A3 and (last - 0xAC00) % 28 ~= 0 then "을" else "를")
end

local function otherAt(screen: Vector2): Player?
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	-- (touch positions come with or without the top bar inset: both rays, as SnackController)
	for _, ray in ipairs({ camera:ScreenPointToRay(screen.X, screen.Y), camera:ViewportPointToRay(screen.X, screen.Y) }) do
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
		local node: Instance? = hit and hit.Instance
		while node and node ~= workspace do
			if node:IsA("Model") then
				local p = Players:GetPlayerFromCharacter(node)
				if p and p ~= player then return p end
			end
			node = node.Parent
		end
	end
	return nil
end
local function near(other: Player): boolean
	local a = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local b = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
	return a ~= nil and b ~= nil and ((a :: BasePart).Position - (b :: BasePart).Position).Magnitude <= REACH
end

--------------------------------------------------------------------- the window
local gui = Instance.new("ScreenGui")
gui.Name = "GiveGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 33
gui.Parent = player:WaitForChild("PlayerGui")

local function make(className: string, props: {[string]: any}, parent: Instance?): any
	local o = Instance.new(className)
	for k, v in pairs(props) do (o :: any)[k] = v end
	if parent then o.Parent = parent end
	return o
end

local card = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -130), Size = UDim2.fromOffset(300, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(18, 18, 22), BackgroundTransparency = 0.05, Visible = false,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 16) }, card)
make("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.75 }, card)
make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }, card)
make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, card)
local text = make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, TextWrapped = true,
	Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), Text = "", LayoutOrder = 1,
}, card)
local row = make("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 2 }, card)
local yes = make("TextButton", {
	Size = UDim2.new(0.5, -5, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 110, 170), Text = "", Font = Enum.Font.GothamBold,
	TextSize = 16, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = true,
}, row)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, yes)
local no = make("TextButton", {
	Position = UDim2.new(0.5, 5, 0, 0), Size = UDim2.new(0.5, -5, 1, 0), BackgroundColor3 = Color3.fromRGB(62, 62, 76), Text = "",
	Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = true,
}, row)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, no)

local onYes: (() -> ())? = nil
local onNo: (() -> ())? = nil
local shownToken = 0
local function close()
	card.Visible = false
	onYes, onNo = nil, nil
	shownToken += 1
	Popups.closed("Give")
end
local function show(message: string, yesText: string, noText: string, y: () -> (), n: () -> ()): number
	shownToken += 1
	text.Text = message
	yes.Text = yesText
	no.Text = noText
	onYes, onNo = y, n
	card.Visible = true
	Popups.opened("Give", function()
		local f = onNo
		close()
		if f then f() end
	end)
	return shownToken
end
yes.Activated:Connect(function() local f = onYes close() if f then f() end end)
no.Activated:Connect(function() local f = onNo close() if f then f() end end)

-- a short line at the top middle (how a gift ended)
local note = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = Color3.fromRGB(18, 18, 22), BackgroundTransparency = 0.15, Font = Enum.Font.GothamBold, TextSize = 14,
	TextColor3 = Color3.new(1, 1, 1), Text = "", Visible = false,
}, gui)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, note)
make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, note)
local noteToken = 0
local function toast(message: string)
	noteToken += 1
	local my = noteToken
	note.Position = UDim2.new(0.5, 0, 0, TopBar.bottom() + 8)
	note.Text = message
	note.Visible = true
	task.delay(3, function() if noteToken == my then note.Visible = false end end)
end

--------------------------------------------------------------------- remote
local remote = Remotes:WaitForChild("Give", 60) :: RemoteFunction?
local event = Remotes:WaitForChild("GiveEvent", 60) :: RemoteEvent?
if not remote or not event then return end

local function ask(action: string, a: any, b: any)
	local ok, done, message = pcall(function() return (remote :: RemoteFunction):InvokeServer(action, a, b) end)
	if ok and not done and typeof(message) == "string" then toast(message) end
	return ok and done
end

local function offerTo(other: Player, tool: Tool)
	local name = itemName(tool.Name)
	show(("🎁 %s %s님에게 줄까요?"):format(object(name), other.DisplayName), "주기", "취소", function()
		if heldTool() ~= tool then toast("줄 아이템을 손에 들어 주세요.") return end
		if ask("Offer", other) then toast(("%s님에게 물어봤어요…"):format(other.DisplayName)) end
	end, function() end)
end

local incoming: string? = nil
event.OnClientEvent:Connect(function(kind: any, a: any, b: any, c: any, d: any)
	if kind == "Offer" and typeof(a) == "string" and typeof(b) == "string" and typeof(c) == "string" then
		local id, from, name = a, b, itemName(c)
		local seconds = if typeof(d) == "number" then d else 15
		incoming = id
		local token = show(("🎁 %s님이 %s 주려고 해요"):format(from, object(name)), "받기", "괜찮아요", function()
			incoming = nil
			if ask("Respond", id, true) then toast(("🎁 %s 받았어요!"):format(object(name))) end
		end, function()
			if incoming == id then
				incoming = nil
				ask("Respond", id, false)
			end
		end)
		-- the countdown on the button
		task.spawn(function()
			for left = seconds, 1, -1 do
				if shownToken ~= token then return end
				yes.Text = ("받기 (%d)"):format(left)
				task.wait(1)
			end
			if shownToken == token then close() incoming = nil end
		end)
	elseif kind == "Withdrawn" then
		if incoming == a and card.Visible then close() end
		if incoming == a then incoming = nil end
	elseif kind == "Result" and typeof(b) == "string" and typeof(c) == "string" then
		local name = itemName(c)
		if a == "yes" then
			toast(("🎁 %s님이 %s 받았어요!"):format(b, object(name)))
		elseif a == "no" then
			toast(("%s님이 이번엔 받지 않았어요."):format(b))
		else
			toast("선물을 전하지 못했어요.")
		end
	end
end)

--------------------------------------------------------------------- the tap
type Press = { input: InputObject, at: number, start: Vector2, other: Player?, tool: Tool?, manual: boolean? }
local press: Press? = nil
local function pointOf(input: InputObject): Vector2
	return if input.UserInputType == Enum.UserInputType.Touch then Vector2.new(input.Position.X, input.Position.Y) else UserInputService:GetMouseLocation()
end
local function letGo(p: Press)
	-- (the tool's own click comes back a moment later, after this press)
	local tool = p.tool
	if tool and p.manual ~= nil then
		local before = p.manual
		task.delay(0.1, function() if tool.Parent then tool.ManualActivationOnly = before :: boolean end end)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local tool = heldTool()
	if not tool then return end
	local screen = pointOf(input)
	local other = otherAt(screen)
	local p: Press = { input = input, at = os.clock(), start = screen, other = other, tool = tool }
	if other then
		-- (a press on a player with a drink or sparkler: no sip / light this time)
		p.manual = tool.ManualActivationOnly
		tool.ManualActivationOnly = true
	end
	press = p
end)
UserInputService.InputChanged:Connect(function(input)
	local p = press
	if not p then return end
	if input ~= p.input and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
	if (pointOf(input) - p.start).Magnitude > 14 then p.other = nil end
end)
UserInputService.InputEnded:Connect(function(input)
	local p = press
	if not p or input ~= p.input then return end
	press = nil
	letGo(p)
	local other, tool = p.other, p.tool
	if not other or not tool or os.clock() - p.at > 0.5 then return end
	if heldTool() ~= tool or other.Parent ~= Players then return end
	if not near(other) then toast("더 가까이 가서 눌러 주세요.") return end
	offerTo(other, tool)
end)
