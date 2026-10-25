--!strict
-- Cafe grand piano (user 2026-10-25): sitting on the piano bench opens an
-- on-screen keyboard (two octaves, C4–B5). Tap / click a key, or on a PC use
--   white  Z X C V B N M (C4–B4)   Q W E R T Y U (C5–B5)
--   black  S D G H J (C#4–A#4)     2 3 5 6 7 (C#5–A#5)
-- Every note sounds at the piano (one grand piano C4 sample, pitched) and is
-- sent to the server, which passes it on to the other players (PianoService).
-- Standing up (jump) closes the keyboard.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Popups = require(script.Parent:WaitForChild("Popups"))

local Remotes = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes")
local remote = Remotes:WaitForChild("PianoNote") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SAMPLE_ID = "rbxassetid://121396137137027" -- "GrandPianoC4"
local BASE_NOTE = 60 -- the sample's pitch (C4)
local FIRST_NOTE = 60 -- leftmost key (C4)

-- the piano the bench belongs to (the nearest tagged piano)
local function pianoPart(near: Vector3?): BasePart?
	local best, bestDist = nil, math.huge
	for _, model in ipairs(CollectionService:GetTagged("Piano")) do
		local body = model:FindFirstChild("PianoBody", true)
		if body and body:IsA("BasePart") then
			local d = if near then (body.Position - near).Magnitude else 0
			if d < bestDist then best, bestDist = body, d end
		end
	end
	return best
end

local function playNote(midi: number, at: BasePart?)
	if not at then return end
	local sound = Instance.new("Sound")
	sound.SoundId = SAMPLE_ID
	sound.PlaybackSpeed = 2 ^ ((midi - BASE_NOTE) / 12)
	sound.Volume = 0.9
	sound.RollOffMaxDistance = 90
	sound.RollOffMinDistance = 12
	sound.Parent = at
	sound:Play()
	Debris:AddItem(sound, 4)
end

-- notes from other players
remote.OnClientEvent:Connect(function(who: any, midi: any)
	if typeof(midi) ~= "number" then return end
	local root = typeof(who) == "Instance" and who:IsA("Player") and who.Character and who.Character:FindFirstChild("HumanoidRootPart")
	playNote(midi, pianoPart(if root and root:IsA("BasePart") then root.Position else nil))
end)

--------------------------------------------------
-- Keyboard window
--------------------------------------------------

local WHITE = { 0, 2, 4, 5, 7, 9, 11 } -- semitones of the white keys in an octave
local BLACK_AFTER = { [0] = 1, [1] = 3, [3] = 6, [4] = 8, [5] = 10 } -- white index → black semitone
local WHITE_KEYS = { Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V, Enum.KeyCode.B, Enum.KeyCode.N, Enum.KeyCode.M,
	Enum.KeyCode.Q, Enum.KeyCode.W, Enum.KeyCode.E, Enum.KeyCode.R, Enum.KeyCode.T, Enum.KeyCode.Y, Enum.KeyCode.U }
local BLACK_KEYS = { Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.G, Enum.KeyCode.H, Enum.KeyCode.J,
	Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven }

local gui: ScreenGui? = nil
local keyButtons: { [number]: GuiButton } = {}
local keyMap: { [Enum.KeyCode]: number } = {}
local currentBody: BasePart? = nil

local function flash(midi: number)
	local button = keyButtons[midi]
	if not button then return end
	local original = button:GetAttribute("Base") :: Color3
	button.BackgroundColor3 = Color3.fromRGB(255, 196, 120)
	task.delay(0.15, function()
		if button.Parent then button.BackgroundColor3 = original end
	end)
end

local function press(midi: number)
	playNote(midi, currentBody)
	flash(midi)
	remote:FireServer(midi)
end

local function close()
	if gui then gui:Destroy() gui = nil end
	keyButtons = {}
	Popups.closed("Piano")
end

local function open()
	if gui then return end
	local screen = Instance.new("ScreenGui")
	screen.Name = "PianoKeyboard"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 20
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -12)
	frame.Size = UDim2.new(0.96, 0, 0.3, 0)
	frame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	frame.BackgroundTransparency = 0.1
	frame.Parent = screen
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
	local size = Instance.new("UISizeConstraint", frame)
	size.MaxSize = Vector2.new(760, 220)
	size.MinSize = Vector2.new(280, 120)
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -110, 0, 22)
	title.Position = UDim2.fromOffset(10, 4)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(245, 240, 230)
	title.Text = if UserInputService.KeyboardEnabled then "🎹 피아노  (Z~M · Q~U 흰 건반, S D G H J · 2 3 5 6 7 검은 건반, 점프 = 일어나기)" else "🎹 피아노  (점프 = 일어나기)"
	title.Parent = frame
	-- on phones the keyboard covers the jump button: stand up from here
	-- (2P phone test 2026-10-26)
	local standUp = Instance.new("TextButton")
	standUp.Name = "StandUp"
	standUp.AnchorPoint = Vector2.new(1, 0)
	standUp.Position = UDim2.new(1, -8, 0, 3)
	standUp.Size = UDim2.fromOffset(92, 24)
	standUp.BackgroundColor3 = Color3.fromRGB(70, 70, 82)
	standUp.Font = Enum.Font.GothamBold
	standUp.TextColor3 = Color3.new(1, 1, 1)
	standUp.TextSize = 13
	standUp.Text = "일어나기"
	standUp.Parent = frame
	Instance.new("UICorner", standUp).CornerRadius = UDim.new(0, 8)
	standUp.Activated:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		-- (Jump = true is reset by the control script in the same frame; Sit = false sticks)
		if humanoid then humanoid.Sit = false end
	end)
	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.Position = UDim2.new(0, 8, 0, 30)
	keys.Size = UDim2.new(1, -16, 1, -38)
	keys.Parent = frame
	local whiteCount = 14
	keyMap = {}
	for i = 0, whiteCount - 1 do
		local midi = FIRST_NOTE + 12 * math.floor(i / 7) + WHITE[i % 7 + 1]
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Text = ""
		b.BackgroundColor3 = Color3.fromRGB(250, 250, 248)
		b:SetAttribute("Base", b.BackgroundColor3)
		b.BorderSizePixel = 0
		b.Position = UDim2.new(i / whiteCount, 1, 0, 0)
		b.Size = UDim2.new(1 / whiteCount, -2, 1, 0)
		b.ZIndex = 1
		b.Parent = keys
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
		b.Activated:Connect(function() press(midi) end)
		keyButtons[midi] = b
		keyMap[WHITE_KEYS[i + 1]] = midi
	end
	local blackIndex = 0
	for i = 0, whiteCount - 2 do
		local semis = BLACK_AFTER[i % 7]
		if semis then
			blackIndex += 1
			local midi = FIRST_NOTE + 12 * math.floor(i / 7) + semis
			local b = Instance.new("TextButton")
			b.AutoButtonColor = false
			b.Text = ""
			b.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
			b:SetAttribute("Base", b.BackgroundColor3)
			b.BorderSizePixel = 0
			b.AnchorPoint = Vector2.new(0.5, 0)
			b.Position = UDim2.new((i + 1) / whiteCount, 0, 0, 0)
			b.Size = UDim2.new(0.6 / whiteCount, 0, 0.6, 0)
			b.ZIndex = 2
			b.Parent = keys
			Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
			b.Activated:Connect(function() press(midi) end)
			keyButtons[midi] = b
			keyMap[BLACK_KEYS[blackIndex]] = midi
		end
	end
	screen.Parent = playerGui
	gui = screen
	Popups.opened("Piano", close)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not gui then return end
	local midi = keyMap[input.KeyCode]
	if midi then press(midi) end
end)

-- open while seated on the piano bench
local function watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		local seat = humanoid.SeatPart
		if seat and seat.Name == "PianoBench" then
			currentBody = pianoPart(seat.Position)
			open()
		else
			close()
		end
	end)
end
if player.Character then task.spawn(watch, player.Character) end
player.CharacterAdded:Connect(function(character)
	close()
	watch(character)
end)
