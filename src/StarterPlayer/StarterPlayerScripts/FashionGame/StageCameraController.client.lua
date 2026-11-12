--!strict
-- 🎥 Stage camera (D-896, user 2026-11-05: "무대 영상 보내주면 분석해서 카메라
-- 무빙 구현"): while a club song with a shot list in Shared/ClubCamera plays,
-- a player inside the club can switch on a camera that films THEM (user's
-- pick: "나 자신") the way the TV stage was filmed: the same cuts at the same
-- moments of the song, the same shot sizes, angles and moves (zoom, pan,
-- orbit, crane), eased like the broadcast.
--
-- Switched with the 🎥 in the song banner (ClubQuickBar → UiBus.StageCamTap);
-- LocalPlayer attribute StageCamera = true while it is on. The game's own
-- camera is not changed: the stage camera takes it over only while it is on
-- AND a song with shots plays AND the player is in the club, and gives it
-- back (camera type, field of view, subject) as it was when it turns off.
--
-- Time = the song's place in ORIGINAL song seconds (D-876), worked out like
-- ChoreoController: server clock × songRate, nudged to the music this player
-- really hears, so cuts land on the same beats as the dance.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Shared = FashionGame:WaitForChild("Shared")
local ClubConfig = require(Shared:WaitForChild("ClubConfig"))
local ClubCamera = require(Shared:WaitForChild("ClubCamera"))
local UiBus = require(script.Parent:WaitForChild("UiBus"))
local player = Players.LocalPlayer

local function attr(name: string, default: number): number
	local v = FashionGame:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

local function playingTrack(): ClubConfig.Track?
	return ClubConfig.Playlist[FashionGame:GetAttribute("ClubTrack") or 0]
end

local function musicSound(): Sound?
	local dance = script.Parent:FindFirstChild("DanceController")
	local sound = dance and dance:FindFirstChild("ClubMusic")
	return if sound and sound:IsA("Sound") then sound else nil
end

-- (D-876, as ChoreoController) the song's place in original seconds
local audioLag, audioLagFor = 0, ""
local function songTime(track: ClubConfig.Track): number
	local paused = FashionGame:GetAttribute("ClubMusicPaused") == true
	local start = attr("ClubTrackStart", workspace:GetServerTimeNow())
	if paused then return attr("ClubMusicPausedAt", 0) * ClubConfig.fileSpeed(track) end
	local t = (workspace:GetServerTimeNow() - start) * ClubConfig.songRate(track, FashionGame:GetAttribute("ClubMusicSpeed"))
	local music = musicSound()
	local heardAt: number? = nil
	if music and music:GetAttribute("JoinedPlaying") == true and ClubConfig.isJoined(track) then
		local jt = music:GetAttribute("JoinedTime")
		if typeof(jt) == "number" and jt > 0.05 then heardAt = jt end
	elseif music and music.IsPlaying and music.TimePosition > 0.05 and music.SoundId == "rbxassetid://" .. tostring(track.soundId) then
		heardAt = music.TimePosition
	end
	if heardAt then
		local heard = heardAt * ClubConfig.fileSpeed(track) - t
		if math.abs(heard) < 3 then
			local key = tostring(track.soundId) .. ":" .. tostring(start)
			if audioLagFor ~= key or math.abs(heard - audioLag) > 0.5 then audioLag = heard else audioLag += (heard - audioLag) * 0.05 end
			audioLagFor = key
		end
		t += audioLag
	end
	return t
end

-- the game camera as it was before the stage camera took it
local saved: { type: Enum.CameraType, fov: number }? = nil
local front: Vector3? = nil -- (the "stage front": where the dancer faced when filming began)
local frontFor = ""
local smoothAim: Vector3? = nil
local lastShot: number? = nil
local bodyScale: number? = nil
local reach: number? = nil -- (how far the camera may go from the aim, eased)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = false

local function root(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function wanted(): (ClubConfig.Track?, ClubCamera.Song?)
	if player:GetAttribute("StageCamera") ~= true then return nil, nil end
	-- (D-1351, user 2026-11-13: "클럽 밖에서 오른쪽 상단에 음표 눌러서 노래 틀어 놓으면 카메라
	-- 무빙 자동으로 켜지는 거 수정. 안무 카메라 모두 선택해야 시작") the camera stayed switched
	-- on from before, so just listening to the club music started it: now it films only
	-- while the song's choreography is danced too (🎵 on, not a phrase from the 안무 tab)
	if player:GetAttribute("ChoreoFollowing") ~= true or player:GetAttribute("ChoreoPhrase") ~= nil then return nil, nil end
	local r = root()
	-- (D-993) wherever the club music is heard, not only in the club
	if not r or not (ClubConfig.isInClub(r.Position) or player:GetAttribute("HearsClub") == true) then return nil, nil end
	local track = playingTrack()
	local song = track and ClubCamera.forTrack(track)
	if not track or not song then return nil, nil end
	return track, song
end

local function release()
	if not saved then return end
	local camera = workspace.CurrentCamera
	camera.CameraType = saved.type
	camera.FieldOfView = saved.fov
	-- (the subject is left alone: ChoreoController may hold its own anchor)
	saved, front, smoothAim, lastShot, bodyScale, reach = nil, nil, nil, nil, nil, nil
end

RunService:BindToRenderStep("StageCamera", Enum.RenderPriority.Camera.Value + 2, function(dt)
	local track, song = wanted()
	if not track or not song then
		release()
		return
	end
	local r = root() :: BasePart
	local camera = workspace.CurrentCamera
	if not saved then
		saved = { type = camera.CameraType, fov = camera.FieldOfView }
	end
	camera.CameraType = Enum.CameraType.Scriptable
	-- the stage front: the way the dancer faced when this song's filming began
	-- (again when the dance starts, D-839 ChoreoFollowing), flat
	-- (not on a seek: a jump into the middle of a turn would turn the stage)
	local key = tostring(track.soundId) .. ":" .. tostring(player:GetAttribute("ChoreoFollowing"))
	-- (the root, not the chest: the choreography turns the body inside the
	-- pieces, e.g. ATEEZ-BAD starts with the back to the audience like the
	-- stage, and the root keeps the dance's front)
	if not front or frontFor ~= key then
		frontFor = key
		local look = r.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		front = if flatLook.Magnitude > 0.2 then flatLook.Unit else Vector3.new(0, 0, -1)
	end
	local t = songTime(track)
	local index, shot = ClubCamera.shotAt(song, t)
	if not shot then return end
	local view = ClubCamera.view(shot, t, ClubCamera.shotEnd(song, index))
	-- the shot sizes are for an avatar 5.5 studs tall: scale them to this
	-- one (feet to the top of the head, read at each cut so the dance's
	-- poses do not change it inside a shot)
	-- (feet from the root: the hip height, so a crouch in the dance does not
	-- move the frame)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local footDrop = r.Size.Y / 2 + (if humanoid then humanoid.HipHeight else 2)
	-- (a `cont` shot is the same take going on, D-898: no new cut)
	local cut = lastShot ~= index and not (shot.cont and lastShot == index - 1)
	if cut or not bodyScale then
		local head = character and character:FindFirstChild("Head") :: BasePart?
		bodyScale = 1
		if head then
			local top = head.Position.Y + head.Size.Y / 2
			bodyScale = math.clamp((top - (r.Position.Y - footDrop)) / ClubCamera.BODY, 0.5, 3)
		end
	end
	local scale = bodyScale :: number
	view.height *= scale
	-- the aim follows the dancer softly inside a shot (a camera operator's
	-- lag), and jumps at a cut
	local target = r.Position + Vector3.new(0, -footDrop + view.aim * ClubCamera.BODY * scale, 0)
	-- (D-900) close and bust shots follow the head sideways, not the root: a
	-- dancer leaning in a close-up would slide out of the frame
	local head = character and character:FindFirstChild("Head") :: BasePart?
	-- (1 at bust and closer, half at waist, 0 from a knee shot; D-915: a deep
	-- lunge in a waist shot took the head out of the frame)
	local closeness = math.clamp((5 - view.height / scale) / 2.4, 0, 1)
	if head and closeness > 0 then
		local h = head.Position
		-- (and its height: the frame's aim sits that far below the head top
		-- when standing, so a deep bend takes the frame down with it)
		local standTop = r.Position.Y - footDrop + ClubCamera.BODY * scale
		local headTop = h.Y + head.Size.Y / 2
		target = target:Lerp(Vector3.new(h.X, target.Y + (headTop - standTop), h.Z), closeness)
	end
	if cut or not smoothAim then
		smoothAim = target
		lastShot = index
	else
		lastShot = index
		smoothAim = (smoothAim :: Vector3):Lerp(target, 1 - math.exp(-dt * 6))
	end
	local aim = smoothAim :: Vector3
	local f = front :: Vector3
	local right = f:Cross(Vector3.yAxis).Unit
	-- the camera's direction from the dancer: in front (yaw 0), turned by yaw
	-- round the dancer (+ = towards the dancer's left, the viewer's right),
	-- raised by pitch (+ = from above, looking down)
	local yaw, pitch = math.rad(view.yaw), math.rad(view.pitch)
	local flat = (f * math.cos(yaw) - right * math.sin(yaw))
	local dir = (flat * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)).Unit
	local fov = view.fov
	local distance = (view.height / 2) / math.tan(math.rad(fov) / 2)
	-- pan: the frame slides sideways / up (fractions of the frame)
	-- (+ ClubCamera.UI_LIFT: the frame sits a little higher, so the song
	-- banner and the top buttons do not cover the head on a phone)
	local lookAt = aim - right * (view.panX * view.height * camera.ViewportSize.X / math.max(camera.ViewportSize.Y, 1))
		+ Vector3.new(0, (view.panY + ClubCamera.UI_LIFT) * view.height, 0)
	local pos = lookAt + dir * distance
	-- walls and ceilings between: come in front of them
	local ignore: {Instance} = { camera }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(ignore, p.Character) end
	end
	-- (club walls are often CanCollide false with collision boxes elsewhere
	-- (D-192): any visible part counts; invisible non-colliding ones, zones
	-- and triggers, do not)
	-- (D-898) thin things are filmed past, as a real camera would, not jumped
	-- in front of: poles (less than 3 studs across on the floor) and beams /
	-- light bars (thinner than 1 stud in two directions)
	local hit: RaycastResult? = nil
	for _ = 1, 12 do
		rayParams.FilterDescendantsInstances = ignore
		hit = workspace:Raycast(lookAt, pos - lookAt, rayParams)
		local part = hit and hit.Instance
		if not part or not part:IsA("BasePart") then break end
		local see = part.Transparency < 0.95 or part.CanCollide
		local s = part.Size
		local dims = { s.X, s.Y, s.Z }
		table.sort(dims)
		local thin = math.max(s.X, s.Z) < 3 or dims[2] < 1
		if see and not thin then break end
		table.insert(ignore, part)
		hit = nil
	end
	-- (D-898) how far the camera may go: the wall's distance, eased so a wall
	-- coming between in a moving take does not jump the camera (in at once
	-- only on a cut)
	local want = if hit then math.max((hit.Position - lookAt).Magnitude - 0.6, 1.5) else distance
	if cut or not reach then
		reach = want
	else
		local r = reach :: number
		reach = r + (want - r) * (1 - math.exp(-dt * (if want < r then 10 else 4)))
	end
	local d = math.min(reach :: number, distance)
	if d < distance - 0.01 then
		-- keep the framing: a closer camera needs a wider lens
		fov = math.clamp(math.deg(2 * math.atan((view.height / 2) / d)), fov, 90)
		pos = lookAt + dir * d
	end
	camera.FieldOfView = fov
	camera.CFrame = CFrame.lookAt(pos, lookAt) * CFrame.Angles(0, 0, math.rad(view.roll))
	camera.Focus = CFrame.new(lookAt)
end)

UiBus.StageCamTap.Event:Connect(function()
	player:SetAttribute("StageCamera", if player:GetAttribute("StageCamera") == true then nil else true)
end)
