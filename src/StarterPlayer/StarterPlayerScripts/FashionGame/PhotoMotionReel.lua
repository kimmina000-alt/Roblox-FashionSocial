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
	-- the flash, part of the video
	local flashGui = Instance.new("ScreenGui")
	flashGui.Name = "PhotoReelFlash"
	flashGui.IgnoreGuiInset = true
	flashGui.DisplayOrder = 100
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = flashGui
	flashGui.Parent = playerGui
	local stage = Instance.new("Folder")
	stage.Name = "PhotoReel"
	stage.Parent = workspace

	local videoDone = false
	local message: string? = nil
	local recordingVideo = false
	local ok, started = pcall(function()
		return CaptureService:StartVideoCaptureAsync(function(result, capture)
			videoDone = true
			if (result == Enum.VideoCaptureResult.Success or result == Enum.VideoCaptureResult.TimeLimitReached) and capture then
				pcall(function()
					CaptureService:PromptSaveCapturesToGallery({ capture }, function() end)
				end)
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
		cam.FieldOfView = f0.fov + (f1.fov - f0.fov) * a
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
		while true do
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
		while os.clock() - flashStart < HOLD do
			flash.BackgroundTransparency = math.min(1, 0.1 + (os.clock() - flashStart) / 0.35)
			RunService.RenderStepped:Wait()
		end
		flash.BackgroundTransparency = 1
		for _, copy in pairs(clip.copies) do copy.Parent = nil end
	end

	if recordingVideo then
		pcall(function() CaptureService:StopVideoCapture() end)
		local waited = 0
		while not videoDone and waited < 5 do waited += task.wait(0.1) end
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
	onDone(message)
end

-- (D-1139, user 2026-11-10: "동그라미 속 발판 부스 안 공간에는 있지만 사진 찍기 시작하면 저
-- 화면에서 안 보이게 해. 사진 찍을 때까지 기다리는 처음 10초에는 공간 다 보이지만 찍기
-- 시작하면 안 보이게.") the booth's two stools (StoolTop / StoolLeg / StoolRail) are
-- hidden on this screen while it shoots (and in the motion video), shown again after
local hiddenStools: {[BasePart]: boolean} = {}
local stoolBooth: Instance? = nil -- (the booth last shot in: the video hides its stools too)
function Reel.hideStools(booth: Instance?, hide: boolean)
	if booth then stoolBooth = booth end
	if hide and booth then
		for _, p in ipairs(booth:GetChildren()) do
			if p:IsA("BasePart") and string.match(p.Name, "^Stool") and not hiddenStools[p] then
				hiddenStools[p] = true
				p.LocalTransparencyModifier = 1
			end
		end
	elseif not hide then
		for p in pairs(hiddenStools) do
			if p.Parent then p.LocalTransparencyModifier = 0 end
		end
		table.clear(hiddenStools)
	end
end

function Reel.isPlaying(): boolean
	return playing
end

return Reel
