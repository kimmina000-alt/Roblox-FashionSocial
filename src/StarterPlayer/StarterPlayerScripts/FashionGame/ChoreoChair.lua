--!strict
-- (D-1321, user 2026-11-12: "의자 안무는 백화요란 안무에만 의자 추가해서 영상처럼 의자 사용해서 추는 걸로
-- 구현해") The chair of a song's chair part (its ClubPlaylist track has `chair = { to, drop }`): while the
-- player follows the choreography and the song is before `to`, a chair stands under where they began, its
-- seat as high as their hips come down in the sit. The server builds it so everyone sees it
-- (ChoreoChairService).
-- `drop` = how far the captured sit lowers the hips, in the animation's studs. The animator scales a
-- capture's moves to the avatar (a big Rthro body sank 2.47 studs for a 1.91 keyframe), so that scale is
-- measured on this avatar (the root joint's height against the keyframe's) and the seat is set again
-- once it is known.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Remotes"):WaitForChild("ChoreoChair", 30) :: RemoteEvent?

local ChoreoChair = {}

local placedFor: string? = nil -- (the song start the chair is up for)
local placedSeat: number? = nil -- (its seat height above the ground)
local refined = false -- (set again once, with the measured scale)
local scale: number? = nil -- (this avatar's animation scale, once measured)
local scaleFor: Model? = nil
local hipsY: {[string]: { times: {number}, y: {number} } | false} = {}

local function loadHips(id: string)
	if hipsY[id] ~= nil then return end
	hipsY[id] = false
	task.spawn(function()
		local ok, seq = pcall(function() return KeyframeSequenceProvider:GetKeyframeSequenceAsync(id) end)
		if not ok or not seq then return end
		local times, ys = {}, {}
		local keyframes = (seq :: KeyframeSequence):GetKeyframes()
		table.sort(keyframes, function(a, b) return (a :: Keyframe).Time < (b :: Keyframe).Time end)
		for _, kf in ipairs(keyframes) do
			for _, p in ipairs(kf:GetDescendants()) do
				if p:IsA("Pose") and p.Name == "LowerTorso" then
					table.insert(times, (kf :: Keyframe).Time)
					table.insert(ys, (p :: Pose).CFrame.Y)
					break
				end
			end
		end
		hipsY[id] = { times = times, y = ys }
	end)
end

local function keyY(id: string, t: number): number?
	local s = hipsY[id]
	if not s or #s.times == 0 then return nil end
	local times, ys = s.times, s.y
	if t <= times[1] then return ys[1] end
	for i = 2, #times do
		if times[i] >= t then
			local f = (t - times[i - 1]) / math.max(times[i] - times[i - 1], 1e-3)
			return ys[i - 1] + (ys[i] - ys[i - 1]) * f
		end
	end
	return ys[#ys]
end

-- the animation scale: a piece playing alone, its hips well down in the keyframes, against the root joint
local function measure(character: Model, joint: Motor6D)
	if scaleFor ~= character then scale, scaleFor = nil, character end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		local id = track.Animation and track.Animation.AnimationId
		if id and track.WeightCurrent > 0.99 then
			loadHips(id)
			local ky = keyY(id, track.TimePosition)
			if ky and ky < -0.4 then
				local k = math.clamp(joint.Transform.Position.Y / ky, 0.4, 2.5)
				scale = if scale then scale + (k - scale) * 0.3 else k
			end
		end
	end
end

function ChoreoChair.off()
	if placedFor and remote then remote:FireServer("Off") end
	placedFor, placedSeat = nil, nil
end

-- every frame while following: `key` = this play of the song, `songTime` = the song's own seconds
function ChoreoChair.update(cfg: any, key: string, songTime: number)
	local want = typeof(cfg) == "table" and songTime >= (cfg.from or 0) - 0.5 and songTime < (cfg.to or 0)
	if not want then
		if placedFor then ChoreoChair.off() end
		return
	end
	if not remote then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local lt = character and character:FindFirstChild("LowerTorso") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local joint = lt and lt:FindFirstChild("Root") :: Motor6D?
	if not (character and root and lt and humanoid and joint) then return end
	measure(character, joint)
	local ground = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
	-- the hips at rest (the root joint without the animation), then lowered by the sit
	local rest = (joint.C0 * joint.C1:Inverse()).Position
	local sitY = root.Position.Y + rest.Y - (cfg.drop or 1.85) * (scale or 1)
	local seatY = sitY - lt.Size.Y * 0.5 - (cfg.under or 0.1)
	local height = seatY - ground
	-- put up once, then once more at `refine` (just before the first sit) if the scale measured on the way
	-- down moved the seat
	if placedFor == key then
		if refined or songTime < (cfg.refine or 1.75) then return end
		refined = true
		if not placedSeat or math.abs(placedSeat - height) < 0.05 then return end
	else
		refined = false
	end
	placedFor, placedSeat = key, height
	-- the root's facing, flat
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	-- the seat's front edge just behind the standing legs (the capture sits straight down where it
	-- stands, so a seat under the root would cut through the legs while standing): the hips sit on its
	-- front part. (ChoreoChairService's seat is 1.8 deep.)
	local at = Vector3.new(root.Position.X, seatY, root.Position.Z) - look * (lt.Size.Z * (cfg.back or 0.3) + 0.9)
	remote:FireServer("On", CFrame.lookAt(at, at + look), height)
end

return ChoreoChair
