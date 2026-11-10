--!strict
-- 오후네컷 motion video (D-1126, user 2026-11-10: "오후네컷에서 사진 찍은 거 ...
-- 사진 찍을 때 움직임 동영상으로 남겨서 그거 저장할 수 있게 하자. 실제 인생네컷도
-- 사진 인화되는 동안 자기가 선택한 사진 찍을 때 찍기 몇 초 전 영상 다운받을 수
-- 있거든. 몇 초 전 움직임들 카메라가 보는 뷰로.").
-- While the booth shoots, this client keeps the last CLIP seconds of how
-- everyone in the booth moved (every part, 15 times a second) and of the booth
-- camera. At each shot those seconds are kept for that cut, with a copy of each
-- person as they looked then (props included). "🎬 영상 저장" replays the
-- picked cuts in order on the spot, from the booth camera: CLIP seconds of
-- moving, then the shot (a flash) held still for HOLD seconds; the real
-- characters and the screen guis are hidden meanwhile. The replay is recorded
-- with CaptureService (a video capture, at most 30 s: 4 cuts x (5 + 1) = 24 s)
-- and offered to the device gallery, from where it can be shared.

local CaptureService = game:GetService("CaptureService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PhotoConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("PhotoConfig"))

local Reel = {}

local CLIP = (PhotoConfig :: any).MotionClipSeconds or 5
local HOLD = 1.0
local RATE = 1 / 15
local RANGE = 18 -- studs from the booth: the people in the shot

local player = Players.LocalPlayer

type Frame = { t: number, cam: CFrame, fov: number, people: {[number]: {[string]: CFrame}} }
type Clip = { frames: {Frame}, copies: {[number]: Model} }
type Bound = { userId: number, part: BasePart, key: string }

local buffer: {Frame} = {}
local clips: {[number]: Clip} = {}
local recording = false
local center: Vector3? = nil
local lastSample = 0
local playing = false

-- a part's place inside its character, as a key (cached)
local paths: {[Instance]: string} = setmetatable({}, { __mode = "k" }) :: any
local function pathOf(part: BasePart, character: Model): string
	local p = paths[part]
	if p then return p end
	local full = part:GetFullName()
	p = string.sub(full, #character:GetFullName() + 2)
	paths[part] = p
	return p
end

local function inBooth(): {Player}
	local list = {}
	if not center then return list end
	for _, other in ipairs(Players:GetPlayers()) do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - center).Magnitude <= RANGE then
			table.insert(list, other)
		end
	end
	return list
end

-- a still copy of a character (no scripts, sounds, name tags; anchored)
local function copyOf(character: Model): Model?
	local was = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(function() return character:Clone() end)
	character.Archivable = was
	if not ok or not copy then return nil end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("ProximityPrompt")
			or d:IsA("ForceField") or d:IsA("IKControl") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	return copy
end

local function sample()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local frame: Frame = { t = os.clock(), cam = cam.CFrame, fov = cam.FieldOfView, people = {} }
	for _, other in ipairs(inBooth()) do
		local character = other.Character :: Model
		local poses = {}
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("BasePart") then poses[pathOf(d, character)] = d.CFrame end
		end
		frame.people[other.UserId] = poses
	end
	table.insert(buffer, frame)
	-- keep a little more than one clip
	while #buffer > 0 and frame.t - buffer[1].t > CLIP + 0.5 do table.remove(buffer, 1) end
end

RunService.RenderStepped:Connect(function()
	if not recording or playing then return end
	local now = os.clock()
	if now - lastSample < RATE then return end
	lastSample = now
	sample()
end)

local function dropClips()
	for _, clip in pairs(clips) do
		for _, copy in pairs(clip.copies) do copy:Destroy() end
	end
	table.clear(clips)
end

-- the booth starts shooting (its middle)
function Reel.begin(boothCenter: Vector3)
	dropClips()
	table.clear(buffer)
	center = boothCenter
	recording = true
	lastSample = 0
end

-- shot number `index` was just taken: keep the seconds before it
function Reel.shot(index: number)
	if not recording then return end
	sample()
	local now = os.clock()
	local frames = {}
	for _, f in ipairs(buffer) do
		if now - f.t <= CLIP then table.insert(frames, f) end
	end
	local copies = {}
	for _, other in ipairs(inBooth()) do
		local copy = other.Character and copyOf(other.Character)
		if copy then copies[other.UserId] = copy end
	end
	local old = clips[index]
	if old then for _, copy in pairs(old.copies) do copy:Destroy() end end
	clips[index] = { frames = frames, copies = copies }
end

-- shooting is over (the picking starts)
function Reel.stop()
	recording = false
	table.clear(buffer)
end

function Reel.has(picks: {number}): boolean
	for _, index in ipairs(picks) do
		if clips[index] and #clips[index].frames > 0 then return true end
	end
	return false
end

-- (D-1139, user 2026-11-10: "동그라미 속 발판 부스 안 공간에는 있지만 사진 찍기 시작하면 저
-- 화면에서 안 보이게 해. 사진 찍을 때까지 기다리는 처음 10초에는 공간 다 보이지만 찍기
-- 시작하면 안 보이게.") the booth's two stools (StoolTop / StoolLeg / StoolRail) are
-- hidden on this screen while it shoots (and in the motion video), shown again after
local hiddenStools: {[BasePart]: boolean} = {}
local stoolBooth: Instance? = nil -- (the booth last shot in: the video hides its stools too)
local stoolWatch: RBXScriptConnection? = nil
local function hideStool(p: Instance)
	if p:IsA("BasePart") and string.match(p.Name, "^Stool") and not hiddenStools[p] then
		hiddenStools[p] = true
		p.LocalTransparencyModifier = 1
	end
end
function Reel.hideStools(booth: Instance?, hide: boolean)
	if booth then stoolBooth = booth end
	if hide and booth then
		-- (D-1181: descendants, so the 키높이 발판's stool inside BoothStep goes too,
		-- and one put down while shooting)
		for _, p in ipairs(booth:GetDescendants()) do hideStool(p) end
		if stoolWatch then stoolWatch:Disconnect() end
		stoolWatch = booth.DescendantAdded:Connect(hideStool)
	elseif not hide then
		if stoolWatch then stoolWatch:Disconnect() stoolWatch = nil end
		for p in pairs(hiddenStools) do
			if p.Parent then p.LocalTransparencyModifier = 0 end
		end
		table.clear(hiddenStools)
	end
end

-- replays the picked cuts and records them; onDone(message) when finished
function Reel.play(picks: {number}, onDone: (string?) -> ())
	if playing then return end
	local list: {Clip} = {}
	for _, index in ipairs(picks) do
		local clip = clips[index]
		if clip and #clip.frames > 0 then table.insert(list, clip) end
	end
	if #list == 0 then onDone("영상으로 남은 컷이 없어요.") return end
	playing = true
	local playerGui = player:WaitForChild("PlayerGui")
	-- off: the screen guis, the real characters (for this player only)
	local hiddenGuis = {}
	for _, g in ipairs(playerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			table.insert(hiddenGuis, g)
		end
	end
	local hiddenParts: {[BasePart]: number} = {}
	local hiddenTags: {BillboardGui} = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			for _, d in ipairs(other.Character:GetDescendants()) do
				if d:IsA("BasePart") then
					hiddenParts[d] = d.LocalTransparencyModifier
					d.LocalTransparencyModifier = 1
				elseif d:IsA("BillboardGui") and d.Enabled then
					-- (the name tags would float over the empty spot)
					d.Enabled = false
					table.insert(hiddenTags, d)
				end
			end
		end
	end
	Reel.hideStools(stoolBooth, true) -- (D-1139)
	local cam = workspace.CurrentCamera
	local oldType, oldCFrame, oldFov = cam.CameraType, cam.CFrame, cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	-- (D-1266, user 2026-11-10: "오후네컷 동영상 전체 화면으로 보여 주지 말고 팝업으로 보여 줘")
	-- the replay shows in a window in the middle (WIN of the screen, the same
	-- shape), dark around it, a light pink frame, a title and X; the booth
	-- camera's view is fitted into the window by a wider field of view (below),
	-- so the window shows what the full screen showed. The video records the
	-- screen, so it has the window too (like a photo frame).
	local WIN = 0.72
	local flashGui = Instance.new("ScreenGui")
	flashGui.Name = "PhotoReelFlash"
	flashGui.IgnoreGuiInset = true
	flashGui.DisplayOrder = 100
	local DIM = Color3.fromRGB(24, 20, 30)
	local m = (1 - WIN) / 2
	for _, r in ipairs({
		{ UDim2.fromScale(0, 0), UDim2.fromScale(1, m) }, -- top
		{ UDim2.fromScale(0, 1 - m), UDim2.fromScale(1, m) }, -- bottom
		{ UDim2.fromScale(0, m), UDim2.fromScale(m, WIN) }, -- left
		{ UDim2.fromScale(1 - m, m), UDim2.fromScale(m, WIN) }, -- right
	}) do
		local d = Instance.new("Frame")
		d.Position, d.Size = r[1], r[2]
		d.BackgroundColor3 = DIM
		d.BackgroundTransparency = 0
		d.BorderSizePixel = 0
		d.Active = true -- (taps around it do not reach the game)
		d.Parent = flashGui
	end
	local window = Instance.new("Frame")
	window.Position = UDim2.fromScale(m, m)
	window.Size = UDim2.fromScale(WIN, WIN)
	window.BackgroundTransparency = 1
	window.Parent = flashGui
	local border = Instance.new("UIStroke")
	border.Color = Color3.fromRGB(255, 182, 206)
	border.Thickness = 5
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = window
	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 1)
	title.Position = UDim2.new(0.5, 0, 0, -8)
	title.Size = UDim2.new(1, 0, 0, 26)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(255, 200, 220)
	title.Text = "🎬 오후네컷"
	title.Parent = window
	local cancelled = false
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 1)
	close.Position = UDim2.new(1, 0, 0, -6)
	close.Size = UDim2.fromOffset(30, 30)
	close.BackgroundColor3 = Color3.fromRGB(255, 182, 206)
	close.TextColor3 = Color3.fromRGB(60, 30, 45)
	close.Font = Enum.Font.BuilderSansExtraBold
	close.TextSize = 18
	close.Text = "X" -- (✕ has no glyph in the game fonts)
	close.Parent = window
	Instance.new("UICorner", close).CornerRadius = UDim.new(1, 0)
	close.Activated:Connect(function() cancelled = true end)
	-- the flash, part of the video, inside the window only
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = window
	flashGui.Parent = playerGui
	-- the recorded field of view, widened so the window holds the whole view
	local function fit(fov: number): number
		return math.min(120, 2 * math.deg(math.atan(math.tan(math.rad(fov) / 2) / WIN)))
	end
	local stage = Instance.new("Folder")
	stage.Name = "PhotoReel"
	stage.Parent = workspace

	local videoDone = false
	local message: string? = nil
	local recordingVideo = false
	-- (D-1180, user 2026-11-10: "영상 저장 > 다 보고 난 뒤에 공유하기 보여 주면서 공유하기로만
	-- 저장할 수 있다고 알려주기. 공유해야 저장되게 해 지금 걍 저장되네") the video is kept
	-- here, not saved; after the replay the share sheet comes up (see the end)
	local video: any = nil
	local ok, started = pcall(function()
		return CaptureService:StartVideoCaptureAsync(function(result, capture)
			videoDone = true
			if (result == Enum.VideoCaptureResult.Success or result == Enum.VideoCaptureResult.TimeLimitReached) and capture then
				video = capture
			else
				message = "영상을 저장하지 못했어요. (" .. tostring(result) .. ")"
			end
		end, {})
	end)
	recordingVideo = ok and started == Enum.VideoCaptureStartedResult.Success
	if not recordingVideo then
		message = "이 기기에서는 영상 녹화를 할 수 없어요." .. (if RunService:IsStudio() then " (Studio에서는 미리보기만)" else "")
	end

	-- each copy's parts with their keys, once per clip
	local function bind(copies: {[number]: Model}): {Bound}
		local out = {}
		for userId, copy in pairs(copies) do
			for _, d in ipairs(copy:GetDescendants()) do
				if d:IsA("BasePart") then table.insert(out, { userId = userId, part = d, key = pathOf(d, copy) }) end
			end
		end
		return out
	end
	-- the pose between two recorded frames (a = 0..1), every rendered frame
	local function pose(bound: {Bound}, f0: Frame, f1: Frame, a: number)
		for _, b in ipairs(bound) do
			local p0 = f0.people[b.userId]
			local p1 = f1.people[b.userId]
			local c0 = p0 and p0[b.key]
			local c1 = p1 and p1[b.key]
			if c0 and c1 then b.part.CFrame = c0:Lerp(c1, a)
			elseif c0 or c1 then b.part.CFrame = (c0 or c1) :: CFrame end
		end
		cam.CFrame = f0.cam:Lerp(f1.cam, a)
		cam.FieldOfView = fit(f0.fov + (f1.fov - f0.fov) * a)
	end

	for _, clip in ipairs(list) do
		for _, copy in pairs(clip.copies) do copy.Parent = stage end
		local bound = bind(clip.copies)
		local frames = clip.frames
		local start = frames[1].t
		local length = frames[#frames].t - start
		local began = os.clock()
		local k = 1
		pose(bound, frames[1], frames[1], 0)
		RunService.RenderStepped:Wait()
		began = os.clock()
		while not cancelled do
			local e = os.clock() - began
			if e >= length then break end
			while k < #frames and frames[k + 1].t - start <= e do k += 1 end
			local f0, f1 = frames[k], frames[math.min(k + 1, #frames)]
			local span = f1.t - f0.t
			pose(bound, f0, f1, if span > 0 then math.clamp((e - (f0.t - start)) / span, 0, 1) else 0)
			RunService.RenderStepped:Wait()
		end
		pose(bound, frames[#frames], frames[#frames], 0)
		-- the shot: a flash, then still
		flash.BackgroundTransparency = 0.1
		local flashStart = os.clock()
		while os.clock() - flashStart < HOLD and not cancelled do
			flash.BackgroundTransparency = math.min(1, 0.1 + (os.clock() - flashStart) / 0.35)
			RunService.RenderStepped:Wait()
		end
		flash.BackgroundTransparency = 1
		for _, copy in pairs(clip.copies) do copy.Parent = nil end
		if cancelled then break end
	end

	if recordingVideo then
		pcall(function() CaptureService:StopVideoCapture() end)
		local waited = 0
		-- (D-1266: closed with X = no video to wait for, the window goes at once)
		while not videoDone and waited < 5 and not cancelled do waited += task.wait(0.1) end
	end
	-- back as it was
	stage:Destroy()
	flashGui:Destroy()
	cam.CameraType = oldType
	cam.CFrame = oldCFrame
	cam.FieldOfView = oldFov
	for part, value in pairs(hiddenParts) do
		if part.Parent then part.LocalTransparencyModifier = value end
	end
	for _, g in ipairs(hiddenGuis) do g.Enabled = true end
	for _, tag in ipairs(hiddenTags) do if tag.Parent then tag.Enabled = true end end
	Reel.hideStools(nil, false)
	playing = false
	-- (D-1266) closed with X before the end: nothing to share
	if cancelled then
		onDone("영상을 닫았어요. 🎬 영상 저장을 누르면 다시 볼 수 있어요.")
		return
	end
	-- (D-1180) the whole replay seen: the share sheet, and the note that sharing
	-- is the only way to keep the video (pick 저장 there)
	if video then
		onDone("🎬 영상은 공유하기로만 저장할 수 있어요. 공유 화면에서 저장을 골라 주세요.")
		local shared = pcall(function()
			CaptureService:PromptShareCapture(Content.fromObject(video), "", function()
				onDone("🎬 영상을 공유했어요!")
			end, function()
				onDone("공유하지 않아서 영상이 저장되지 않았어요. 🎬 영상 저장을 다시 눌러 주세요.")
			end)
		end)
		if not shared then onDone("이 기기에서는 영상을 공유할 수 없어요.") end
		return
	end
	onDone(message)
end

function Reel.isPlaying(): boolean
	return playing
end

return Reel
