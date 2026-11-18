--!strict
-- 네온 무대 (D-1792, user 2026-11-18: "여기 빈 공터에서 네온 춤 출 수 있는 기능 구현하자 무대처럼 단상
-- 만들고 올라가면 네온 노래 나오고 안무 추는 거"). A round neon stage in the middle of the round plaza in
-- front of the amusement park (the pocket park's sunken plaza, centre (-96, -128), floor y -1.98; built by
-- tools/graybox/park_neon_stage_1118.lua as Workspace["네온무대"]).
--   * Someone steps on it: the server starts A2O LITE-NEON on a shared clock (FashionGame attribute
--     NeonStageStart = server time of the song's start; it plays to the end and again from the start
--     while anyone is up there, and stops NeonStageGrace seconds after the last one steps off).
--   * Everyone in the plaza hears it (full on the stage, fading out past the tiers), the club music is
--     ducked meanwhile (LocalPlayer attribute NeonHeard, DanceController).
--   * Everyone standing on the stage dances the song's club choreography on that clock, so they are all
--     on the same beat (ChoreoController's stage mode, UiBus.ChoreoStage; other screens keep them on
--     the beat too, RemoteChoreoSync).
-- User picks (2026-11-18): same beat for all, heard in the whole plaza, round neon stage.
-- (D-1820, user 2026-11-19: "현재 네온만 나오는데 안무 있는 음원 랜덤으로 모두 나오게 / 네온 조명선 삭제 / 단상 가장
-- 넓은 원 크기에 가장 높은 높이로 한 층으로만", then "조명선 하나만 얇고 연하게 넣자. 분홍색", "1인칭 뜨는 것처럼
-- 카메라 버튼"): every club song with a choreography, one at a time at random (never the same twice in a
-- row; FashionGame attribute NeonStageTrack = its soundId, set with NeonStageStart), the stage one
-- round step of radius 18 at the old top's height, one thin pale pink line, and a 🎥 무대 카메라 button
-- on the stage (the club's stage camera, filming on the stage song's clock).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClubConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("ClubConfig"))

local NeonStageConfig = {}

NeonStageConfig.SoundId = 140713297574648 -- NEON-A2O LITE (ClubPlaylist): the song when no other is set
NeonStageConfig.Center = Vector3.new(-96, -1.98, -128) -- (the plaza floor at the stage's middle: the walked face, measured)
NeonStageConfig.Radius = 18 -- (the stage; D-1820: one step, as wide as the old low step)
NeonStageConfig.StepRadius = 18 -- (= Radius since D-1820: no low step any more)
NeonStageConfig.Height = 1.2 -- (the top over the plaza floor, the old top's height; walked up, D-1820)
NeonStageConfig.Top = NeonStageConfig.Center.Y + NeonStageConfig.Height
NeonStageConfig.HearInner = 34 -- (full plaza level inside the tiers' front edge, r 34.6)
NeonStageConfig.HearOuter = 48 -- (silent from here out)
NeonStageConfig.StageLevel = 1 -- (on the stage)
NeonStageConfig.PlazaLevel = 0.6 -- (in the plaza round it: like the club music heard outside, OUTSIDE_DANCE_LEVEL)
NeonStageConfig.Grace = 3 -- (seconds the song goes on after the last dancer steps off)

-- a root position on the stage (the top, up to a jump over it)
function NeonStageConfig.onStage(position: Vector3): boolean
	local c = NeonStageConfig.Center
	local flat = Vector3.new(position.X - c.X, 0, position.Z - c.Z).Magnitude
	return flat <= NeonStageConfig.Radius + 0.3 and position.Y >= NeonStageConfig.Top and position.Y <= NeonStageConfig.Top + 9
end

-- how loud the stage song is at a position (0..1)
function NeonStageConfig.level(position: Vector3): number
	local c = NeonStageConfig.Center
	if math.abs(position.Y - c.Y) > 30 then return 0 end
	local flat = Vector3.new(position.X - c.X, 0, position.Z - c.Z).Magnitude
	if flat <= NeonStageConfig.StepRadius then return NeonStageConfig.StageLevel end
	if flat <= NeonStageConfig.HearInner then
		local f = (flat - NeonStageConfig.StepRadius) / (NeonStageConfig.HearInner - NeonStageConfig.StepRadius)
		return NeonStageConfig.StageLevel + (NeonStageConfig.PlazaLevel - NeonStageConfig.StageLevel) * f
	end
	if flat >= NeonStageConfig.HearOuter then return 0 end
	return NeonStageConfig.PlazaLevel * (1 - (flat - NeonStageConfig.HearInner) / (NeonStageConfig.HearOuter - NeonStageConfig.HearInner))
end

-- the songs the stage plays (D-1820): every playlist song with a choreography, one file each (a song
-- joined from clips needs the club's clip player: left out)
function NeonStageConfig.tracks(): {ClubConfig.Track}
	local list = {}
	for _, t in ipairs(ClubConfig.Playlist) do
		if t.choreo and #t.choreo > 0 and typeof(t.soundId) == "number" and not ClubConfig.isJoined(t) then
			table.insert(list, t)
		end
	end
	return list
end

function NeonStageConfig.trackById(soundId: any): ClubConfig.Track?
	if typeof(soundId) ~= "number" then return nil end
	for _, t in ipairs(ClubConfig.Playlist) do
		if t.soundId == soundId and t.choreo then return t end
	end
	return nil
end

-- the stage's song now (FashionGame attribute NeonStageTrack), NEON when none is set
function NeonStageConfig.track(): ClubConfig.Track?
	local fg = ReplicatedStorage:FindFirstChild("FashionGame")
	return NeonStageConfig.trackById(fg and fg:GetAttribute("NeonStageTrack")) or NeonStageConfig.trackById(NeonStageConfig.SoundId)
end

-- the audio's PlaybackSpeed (its lab tempo or base speed; no DJ speed out here)
function NeonStageConfig.playSpeed(track: ClubConfig.Track): number
	return ClubConfig.trackRate(track, 1)
end

-- seconds of real time the song lasts (its file length at that speed)
function NeonStageConfig.realLength(track: ClubConfig.Track): number
	local length = (track :: any).length
	return (if typeof(length) == "number" then length else 210) / NeonStageConfig.playSpeed(track)
end

-- song seconds (the clock the choreography's `at` is on) at a server time
function NeonStageConfig.songTime(track: ClubConfig.Track, start: number, serverNow: number): number
	return (serverNow - start) * ClubConfig.songRate(track, 1)
end

return NeonStageConfig
