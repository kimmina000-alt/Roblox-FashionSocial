--!strict
-- Step-by-step tips with a pulsing outline round what they talk about (user
-- 2026-11-01, D-713). Coach.run(key, steps) shows the steps one card at a
-- time ([건너뛰기] ends them, [다음 ▶]); once finished or skipped the server
-- remembers the key (remote Guide "TipSeen") and it is not shown again.
-- One run at a time: a second waits until the first is over.
--
-- A step: { title, text, target = () -> GuiObject? | Rect?, before = () -> ()?,
-- after = () -> ()? }. The target is looked up when the step shows; a
-- missing or hidden one just shows the card without the outline.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes"):WaitForChild("Guide") :: RemoteFunction

local Coach = {}

-- camera (D-715): the camera flies there for this step, like the place tour;
-- a step without one gives the camera back to the player
-- mark (D-718): a part or model in the world to outline with an orange box
export type Step = { title: string, text: string, target: (() -> any)?, before: (() -> ())?, after: (() -> ())?, camera: (() -> CFrame?)?, mark: (() -> Instance?)? }

local PEACH = Color3.fromRGB(255, 248, 240)
local ORANGE = Color3.fromRGB(255, 140, 70)
local BROWN = Color3.fromRGB(80, 50, 35)
local GREY = Color3.fromRGB(150, 135, 125)

local function create(className: string, props: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	if parent then instance.Parent = parent end
	return instance
end

local gui = create("ScreenGui", { Name = "FashionCoachGui", ResetOnSpawn = false, DisplayOrder = 45, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))
local ring = create("Frame", { Name = "Ring", BackgroundTransparency = 1, Visible = false, ZIndex = 2 }, gui)
create("UICorner", { CornerRadius = UDim.new(0, 10) }, ring)
local ringStroke = create("UIStroke", { Color = ORANGE, Thickness = 4 }, ring)
local card = create("Frame", {
	Name = "TipCard", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 78, 1, -56),
	Size = UDim2.new(1, -188, 0, 116), BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = 3,
	BackgroundTransparency = 0.35, -- (D-717, user: black, see-through, white text)
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 18) }, card)
create("UISizeConstraint", { MaxSize = Vector2.new(520, 116) }, card)
create("UIStroke", { Color = ORANGE, Thickness = 2 }, card)
-- (D-716) the guide bunny beside the card, as if it says the tip
local GuideSpeaker = require(script.Parent:WaitForChild("GuideSpeaker"))
GuideSpeaker.attach(card)
local title = create("TextLabel", {
	Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -100, 0, 28), BackgroundTransparency = 1, ZIndex = 4,
	Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, Text = "",
}, card)
local count = create("TextLabel", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(70, 20), ZIndex = 4,
	BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(200, 200, 205),
	TextXAlignment = Enum.TextXAlignment.Right, Text = "",
}, card)
local body = create("TextLabel", {
	-- (D-717, user: the words stood out less than the buttons: 14 → 19)
	Position = UDim2.fromOffset(16, 42), Size = UDim2.new(1, -32, 0, 62), BackgroundTransparency = 1, ZIndex = 4,
	Font = Enum.Font.GothamBold, TextSize = 19, TextColor3 = Color3.new(1, 1, 1), TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "",
}, card)
local function button(text: string, color: Color3, textColor: Color3): TextButton
	local b = create("TextButton", { BackgroundColor3 = color, Text = text, TextColor3 = textColor, Font = Enum.Font.GothamBold, TextSize = 14, ZIndex = 4 }, card)
	create("UICorner", { CornerRadius = UDim.new(0, 12) }, b)
	return b
end
-- (D-718, the user's mock-up) a small 건너뛰기 tag over the top right, a small
-- 다음 button under the bottom right
local skip = button("건너뛰기 >", Color3.fromRGB(40, 40, 46), Color3.new(1, 1, 1))
skip.AnchorPoint = Vector2.new(1, 1)
skip.Position = UDim2.new(1, -10, 0, -4)
skip.Size = UDim2.fromOffset(84, 24)
skip.TextSize = 13
local nextButton = button("다음 ▶", ORANGE, Color3.new(1, 1, 1))
nextButton.AnchorPoint = Vector2.new(1, 0)
nextButton.Position = UDim2.new(1, -6, 1, 6)
nextButton.Size = UDim2.fromOffset(76, 34)

-- (D-718) the world box of a step's mark
local markBox = create("SelectionBox", { Name = "CoachMark", Color3 = ORANGE, LineThickness = 0.25, SurfaceTransparency = 1, Visible = false }, gui)
-- the card waits for its place before it shows (it flashed at the bottom
-- middle for a frame, D-718)
local placed = false

local function seen(key: string): boolean
	local raw = player:GetAttribute("TipsSeen")
	if typeof(raw) ~= "string" then return true end -- (not loaded yet: wait, don't show)
	local ok, list = pcall(function() return HttpService:JSONDecode(raw) end)
	return ok and typeof(list) == "table" and table.find(list, key) ~= nil
end

-- Whether tips can be shown now (the player's data has loaded) and this one
-- has not been seen.
-- (done here at once: the server's TipsSeen comes back a moment later, and a
-- place tip skipped in the middle of the place came straight back, D-715)
local doneHere: {[string]: boolean} = {}
function Coach.wants(key: string): boolean
	return typeof(player:GetAttribute("TipsSeen")) == "string" and not seen(key) and not doneHere[key]
end

local running: string? = nil
local queue: {{ key: string, steps: {Step}, turn: boolean?, onEnd: (() -> ())? }} = {}
local endHook: (() -> ())? = nil -- (D-731) run when the tip ends, skipped or not
-- (D-729) the camera turns round when this tip ends: the club tip leaves the
-- camera facing the way its first view looked (at the lift, from the door)
local turnAtEnd = false
local steps: {Step} = {}
local index = 0
local target: any = nil

-- (D-714) the rest of the screen goes dark and the target pulses once
local Spotlight = require(script.Parent:WaitForChild("Spotlight"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local rectOf = Spotlight.rectOf

local finish: (boolean, boolean?) -> ()

-- camera flights (as GuideController's tour)
local TweenService = game:GetService("TweenService")
local flight: Tween? = nil
local flown = false
local flightTo: CFrame? = nil
local function flyTo(cf: CFrame)
	flightTo = cf
	task.spawn(function()
		pcall(function() player:RequestStreamAroundAsync(cf.Position + cf.LookVector * 20, 2) end)
	end)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	Sfx.play("whoosh") -- (a whoosh as the camera flies, D-717)
	if flight then flight:Cancel() end
	flight = TweenService:Create(camera, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = cf })
	;(flight :: Tween):Play()
	flown = true
end
local function cameraBack()
	if not flown then return end
	flown = false
	flightTo = nil
	if flight then flight:Cancel() flight = nil end
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then camera.CameraSubject = humanoid end
end

local function show()
	local step = steps[index]
	if not step then finish(true) return end
	if step.before then pcall(step.before) end
	title.Text = step.title
	body.Text = step.text
	count.Text = string.format("%d / %d", index, #steps)
	nextButton.Text = if index == #steps then "확인" else "다음 ▶"
	target = nil
	Spotlight.set(nil)
	-- hidden until the frame loop has put it next to its button
	placed = false
	card.Visible = false
	markBox.Adornee = nil
	markBox.Visible = false
	if step.mark then
		local ok, m = pcall(step.mark :: () -> Instance?)
		if ok and m and (m:IsA("BasePart") or m:IsA("Model")) then
			markBox.Adornee = m :: any
			markBox.Visible = true
		end
	end
	local waitTarget = step.target ~= nil
	local view: CFrame? = nil
	if step.camera then
		local ok, cf = pcall(step.camera :: () -> CFrame?)
		if ok then view = cf end
	end
	if view then flyTo(view) else cameraBack() end
	if step.target then
		-- (a moment later: a step's `before` may open the menu it points into)
		task.delay(0.1, function()
			if steps[index] ~= step then return end
			local ok, t = pcall(step.target :: () -> any)
			if ok then
				target = t
				Spotlight.set(t)
			end
			placed = true
		end)
	end
	if not waitTarget then placed = true end
end

finish = function(done: boolean, again: boolean?)
	local key = running
	if not key then return end
	local step = steps[index]
	if step and step.after then pcall(step.after) end
	running = nil
	if not again then doneHere[key] = true end
	player:SetAttribute("GuideActive", nil)
	card.Visible = false
	ring.Visible = false
	Spotlight.set(nil)
	markBox.Adornee = nil
	markBox.Visible = false
	local wasFlown = flown
	cameraBack()
	if turnAtEnd and wasFlown then
		turnAtEnd = false
		-- half a turn round the character (the player's camera keeps the new way)
		local camera = workspace.CurrentCamera
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if camera and root then
			local look = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
			if look.Magnitude > 0.01 then
				local away = -look.Unit
				local head = root.Position + Vector3.new(0, 2, 0)
				camera.CFrame = CFrame.lookAt(head - away * 12 + Vector3.new(0, 4, 0), head)
			end
		end
	end
	turnAtEnd = false
	local hook = endHook
	endHook = nil
	if hook then pcall(hook) end
	if not again then task.spawn(function() pcall(function() remote:InvokeServer("TipSeen", key) end) end) end
	local nextRun = table.remove(queue, 1)
	if nextRun then task.defer(Coach.run, nextRun.key, nextRun.steps, nextRun.turn, nextRun.onEnd) end
end

nextButton.Activated:Connect(function()
	if not running then return end
	local step = steps[index]
	if step and step.after then pcall(step.after) end
	index += 1
	if index > #steps then
		index -= 1
		steps[index] = { title = "", text = "" } -- (its after has run)
		finish(true)
	else
		show()
	end
end)
skip.Activated:Connect(function() finish(false) end)

-- the outline follows its target every frame (windows move, scroll, open)
RunService.RenderStepped:Connect(function()
	if not running then return end
	-- (D-715) something put the camera back to the player right after a tip's
	-- first flight (seen in 오후네컷): hold the view while the step shows it
	local camera = workspace.CurrentCamera
	if flown and flightTo and camera and camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = flightTo
	end
	local position, size = rectOf(target)
	if not position or not size then
		ring.Visible = false
	else
		local pad = 6
		ring.Position = UDim2.fromOffset(position.X - pad, position.Y - pad)
		ring.Size = UDim2.fromOffset(size.X + pad * 2, size.Y + pad * 2)
		ring.Visible = true
		ringStroke.Transparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(os.clock() * 6))
	end
	-- (D-716, user) the card next to the button it talks about: below it when
	-- the button is in the upper half (room left over the card for the bunny),
	-- else above it, and as near it sideways as the screen allows. Without a
	-- button: at the bottom middle.
	if not position or not size or not camera then
		card.AnchorPoint = Vector2.new(0.5, 1)
		card.Position = UDim2.new(0.5, GuideSpeaker.Width / 2, 1, -56)
		if placed then card.Visible = true end
		return
	end
	local screen = camera.ViewportSize
	local w, h = card.AbsoluteSize.X, card.AbsoluteSize.Y
	local gap, speaker = 14, 30 -- (D-717: the bunny is beside the card; 30 for the 건너뛰기 tag over it)
	local left = GuideSpeaker.Width + 14 -- (room for the bunny left of the card)
	local x = math.clamp(position.X + size.X / 2 - w / 2, left, math.max(screen.X - w - 8, left))
	local y
	if position.Y + size.Y / 2 < screen.Y * 0.5 then
		y = position.Y + size.Y + gap + speaker
		if y + h > screen.Y - 48 then y = screen.Y - h - 48 end -- (room for 다음 under it)
	else
		y = position.Y - gap - h - 40 -- (다음 hangs under the card)
		if y < speaker + 8 then y = speaker + 8 end
	end
	card.AnchorPoint = Vector2.zero
	card.Position = UDim2.fromOffset(x, y)
	if placed then card.Visible = true end
end)

-- (D-719) no tip over the place tour (seen in the 2P guard test: walking into
-- the club during the tour put the club tip on top of the tour card). The
-- place tips are checked again every few seconds, so they come after the tour.
local held = false
function Coach.hold(on: boolean)
	held = on
end

-- turn: the camera turns round at the end (D-729); onEnd: called when the
-- tip ends, finished or skipped (D-731)
function Coach.run(key: string, list: {Step}, turn: boolean?, onEnd: (() -> ())?)
	if held or not Coach.wants(key) then return end
	if running then
		if running ~= key then
			for _, waiting in ipairs(queue) do if waiting.key == key then return end end
			table.insert(queue, { key = key, steps = list, turn = turn, onEnd = onEnd })
		end
		return
	end
	running = key
	turnAtEnd = turn == true
	endHook = onEnd
	player:SetAttribute("GuideActive", true) -- (louder ambience, SfxController)
	steps = table.clone(list)
	index = 1
	card.Visible = true
	show()
end

function Coach.isRunning(): boolean
	return running ~= nil
end

-- close the tip on screen without marking it seen (it can come again)
function Coach.finishNow()
	local key = running
	if not key then return end
	table.clear(queue)
	finish(false, true)
end

-- Every tip again (the guide's 다시 보기).
function Coach.reset()
	table.clear(doneHere)
	pcall(function() remote:InvokeServer("TipsReset") end)
end

return Coach
