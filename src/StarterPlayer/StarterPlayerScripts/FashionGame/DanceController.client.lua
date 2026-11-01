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
local lengthCache: {[string]: number} = {}   -- AnimationId -> 실제 길이(초)
local measuring: {[string]: boolean} = {}

--------------------------------------------------
-- Helpers
--------------------------------------------------

local getAnimator

-- 애니메이션을 한 번 로드해 실제 길이를 읽는다. 캐릭터가 없으면 잠시 기다린다.
local function measureLength(animationId: string)
	local animator = getAnimator()
	local tries = 0
	while not animator and tries < 20 do
		task.wait(0.5)
		animator = getAnimator()
		tries += 1
	end

	if animator then
		local anim = Instance.new("Animation")
		anim.AnimationId = animationId
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		anim:Destroy()

		if ok then
			local waited = 0
			while track.Length <= 0 and waited < 10 do
				task.wait(0.1)
				waited += 0.1
			end
			if track.Length > 0 then
				lengthCache[animationId] = track.Length
			else
				warn(`[DanceController] 애니메이션 길이 측정 실패: {animationId}`)
			end
			track:Destroy()
		else
			warn(`[DanceController] 애니메이션 로드 실패: {animationId}`)
		end
	end

	measuring[animationId] = nil
end

-- DurationSec이 없는 조각의 길이가 모두 준비됐는지 확인하고, 없으면 측정을 시작한다.
local function ensureLengths(entry: DanceRegistry.Entry): boolean
	local ready = true
	for _, seg in entry.Segments do
		if seg.DurationSec == nil and lengthCache[seg.AnimationId] == nil then
			ready = false
			if not measuring[seg.AnimationId] then
				measuring[seg.AnimationId] = true
				task.spawn(measureLength, seg.AnimationId)
			end
		end
	end
	return ready
end

local function getResolved(audioId: string, entry: DanceRegistry.Entry): {DanceRegistry.ResolvedSegment}?
	local cached = resolvedCache[audioId]
	if cached ~= nil then
		return cached
	end

	if not ensureLengths(entry) then
		return nil -- 길이 측정 중
	end

	local segments, reason = DanceRegistry.Resolve(entry, lengthCache)
	if not segments then
		warn(`[DanceController] {audioId} ({entry.Title}) 안무 등록 오류: {reason}`)
		return nil
	end

	resolvedCache[audioId] = segments
	return segments
end

function getAnimator(): Animator?
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
