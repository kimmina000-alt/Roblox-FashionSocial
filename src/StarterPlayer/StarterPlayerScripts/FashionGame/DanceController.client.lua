--!strict

--[[
	DanceController (client)

	음원 Sound가 재생되면, 그 음원에 등록된 안무(DanceRegistry)를 로컬 캐릭터가 음원 재생 위치에 맞춰 춘다.

	- 음악 Sound에는 CollectionService 태그 "DanceMusic"을 붙인다. (DJ 부스/스피커 등)
	- 각 클라이언트는 자기 캐릭터만 춘다. 음원 재생 상태는 replicated Sound로 따라간다.
	- 재생 위치는 Sound.TimePosition을 기준으로 맞춘다. 중간 입장/탐색(seek)에도 맞춰진다.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DanceRegistry = require(
	ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("DanceRegistry")
)

local TAG = "DanceMusic"
local RESYNC_SEC = 0.15   -- 이 이상 어긋나면 애니메이션 위치를 다시 맞춘다
local FADE_SEC = 0.05

local player = Players.LocalPlayer

type Playback = {
	sound: Sound,
	audioId: string,
	segments: {DanceRegistry.ResolvedSegment},
	tracks: {[number]: AnimationTrack},
	animator: Animator?,
	currentIndex: number?,
}

local active: Playback? = nil
local resolvedCache: {[string]: {DanceRegistry.ResolvedSegment}?} = {}

--------------------------------------------------
-- Helpers
--------------------------------------------------

local function getResolved(audioId: string, entry: DanceRegistry.Entry): {DanceRegistry.ResolvedSegment}?
	local cached = resolvedCache[audioId]
	if cached ~= nil then
		return cached
	end

	local segments, reason = DanceRegistry.Resolve(entry)
	if not segments then
		warn(`[DanceController] {audioId} ({entry.Title}) 안무 등록 오류: {reason}`)
		return nil
	end

	resolvedCache[audioId] = segments
	return segments
end

local function getAnimator(): Animator?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local animator: Animator? = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return animator
end

local function loadTrack(pb: Playback, index: number): AnimationTrack?
	local cached = pb.tracks[index]
	if cached then
		return cached
	end

	local animator = pb.animator
	if not animator then
		return nil
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = pb.segments[index].AnimationId

	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	anim:Destroy()

	if not ok then
		warn(`[DanceController] 애니메이션 로드 실패 ({pb.segments[index].AnimationId}): {track}`)
		return nil
	end

	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false
	pb.tracks[index] = track
	return track
end

local function stopCurrent(pb: Playback)
	local index = pb.currentIndex
	if index then
		local track = pb.tracks[index]
		if track and track.IsPlaying then
			track:Stop(FADE_SEC)
		end
	end
	pb.currentIndex = nil
end

local function findPlayingDanceSound(): (Sound?, string?, {DanceRegistry.ResolvedSegment}?)
	for _, inst in CollectionService:GetTagged(TAG) do
		if inst:IsA("Sound") and inst.IsPlaying then
			local audioId, entry = DanceRegistry.GetEntry(inst.SoundId)
			if audioId and entry then
				local segments = getResolved(audioId, entry)
				if segments then
					return inst, audioId, segments
				end
			end
		end
	end
	return nil, nil, nil
end

--------------------------------------------------
-- Main loop
--------------------------------------------------

RunService.Heartbeat:Connect(function()
	local pb = active

	if pb and not pb.sound.IsPlaying then
		stopCurrent(pb)
		active = nil
		pb = nil
	end

	if not pb then
		local sound, audioId, segments = findPlayingDanceSound()
		if sound and audioId and segments then
			pb = {
				sound = sound,
				audioId = audioId,
				segments = segments,
				tracks = {},
				animator = nil,
				currentIndex = nil,
			}
			active = pb
		else
			return
		end
	end

	local playback = pb :: Playback

	-- Character이 바뀌었거나 Animator가 없으면 다시 잡는다.
	if not playback.animator or not playback.animator:IsDescendantOf(workspace) then
		playback.animator = getAnimator()
		playback.tracks = {}
		playback.currentIndex = nil
	end
	if not playback.animator then
		return
	end

	local t = playback.sound.TimePosition
	local index, offset = DanceRegistry.FindSegment(playback.segments, t)

	if index ~= playback.currentIndex then
		stopCurrent(playback)

		if index and offset then
			playback.currentIndex = index
			local track = loadTrack(playback, index)
			if track then
				track:Play(FADE_SEC)
				track.TimePosition = offset
			end
		end
	elseif index and offset then
		local track = playback.tracks[index]
		if track and track.IsPlaying and math.abs(track.TimePosition - offset) > RESYNC_SEC then
			track.TimePosition = offset
		end
	end
end)

player.CharacterAdded:Connect(function()
	-- 리스폰 시 이전 캐릭터의 트랙은 무효다. 다음 프레임에 다시 로드한다.
	if active then
		active.tracks = {}
		active.animator = nil
		active.currentIndex = nil
	end
end)
