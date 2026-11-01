--!strict

--[[
	DANCE REGISTRY

	Key: 음원 Audio asset ID (숫자 문자열). 예: "91762270038050" = RIIZE - Get A Guitar

	Segments: 안무 조각을 음원 시간 순서대로 나열한다.
	  AnimationId : "rbxassetid://..."  (애니메이션 에셋 ID)
	  DurationSec : 이 조각의 길이(초). 생략하면 애니메이션 실제 길이를 재생 시 자동으로 읽는다.
	  StartSec    : 음원 기준 시작 시각(초). 생략하면 이전 조각이 끝나는 시점에 자동으로 붙는다.
	                첫 조각을 생략하면 0초부터 시작한다.

	이어붙이기 예 (조각 길이만 알면 된다):
	  { AnimationId = "rbxassetid://A", DurationSec = 8.0 },   -- 0.0 ~ 8.0
	  { AnimationId = "rbxassetid://B", DurationSec = 6.5 },   -- 8.0 ~ 14.5 (자동)
	  { AnimationId = "rbxassetid://C", StartSec = 20.0, DurationSec = 5 }, -- 음원 20초에 맞춰 시작 (앞 구간은 무동작)

	DurationSec을 생략한 조각은 다음 조각이 시작할 때까지(또는 애니메이션이 끝날 때까지) 재생된다.
	조각끼리 겹치면 안 된다. Resolve()가 겹침/순서 오류를 잡아 경고한다.
]]

export type Segment = {
	AnimationId: string,
	StartSec: number?,
	DurationSec: number?,
}

export type Entry = {
	Title: string,
	Segments: {Segment},
}

export type ResolvedSegment = {
	AnimationId: string,
	Start: number,
	Duration: number?,
}

local Registry: {[string]: Entry} = {
	["91762270038050"] = {
		Title = "RIIZE - Get A Guitar",
		Segments = {
			{ AnimationId = "rbxassetid://119819611123433" },
			{ AnimationId = "rbxassetid://97097804325917" },
			{ AnimationId = "rbxassetid://119200924904137" },
			{ AnimationId = "rbxassetid://77403973851668" },
			{ AnimationId = "rbxassetid://73939357849033" },
			{ AnimationId = "rbxassetid://137390866303201" },
		},
	},
}

local DanceRegistry = {}

--- 사운드 SoundId 문자열("rbxassetid://91762270038050" 등)에서 음원 ID를 꺼낸다.
function DanceRegistry.ParseSoundId(soundId: string): string?
	return string.match(soundId, "(%d+)")
end

function DanceRegistry.GetEntry(soundId: string): (string?, Entry?)
	local id = DanceRegistry.ParseSoundId(soundId)
	if not id then
		return nil, nil
	end
	return id, Registry[id]
end

--- 조각 목록을 음원 타임라인 값으로 확정한다. 실패하면 (nil, 사유)를 돌려준다.
--- lengths: AnimationId -> 실제 길이(초). DurationSec이 없는 조각의 길이로 쓴다.
function DanceRegistry.Resolve(entry: Entry, lengths: {[string]: number}?): ({ResolvedSegment}?, string?)
	local out: {ResolvedSegment} = {}

	for i, seg in entry.Segments do
		if type(seg.AnimationId) ~= "string" or not string.match(seg.AnimationId, "^rbxassetid://%d+$") then
			return nil, `조각 {i}: AnimationId는 "rbxassetid://숫자" 형식이어야 합니다`
		end

		local start = seg.StartSec
		if start == nil then
			if i == 1 then
				start = 0
			else
				local prev = out[i - 1]
				if prev.Duration == nil then
					return nil, `조각 {i}: StartSec 생략 시 이전 조각에 DurationSec이 필요합니다`
				end
				start = prev.Start + prev.Duration
			end
		end

		if start < 0 then
			return nil, `조각 {i}: StartSec은 0 이상이어야 합니다`
		end

		if i > 1 then
			local prev = out[i - 1]
			if start < prev.Start then
				return nil, `조각 {i}: 이전 조각보다 앞선 시각입니다 (순서를 맞춰 주세요)`
			end
			if prev.Duration ~= nil and start < prev.Start + prev.Duration then
				return nil, `조각 {i}: 이전 조각과 겹칩니다`
			end
		end

		local duration = seg.DurationSec
		if duration == nil and lengths then
			duration = lengths[seg.AnimationId]
		end

		out[i] = {
			AnimationId = seg.AnimationId,
			Start = start,
			Duration = duration,
		}
	end

	return out, nil
end

--- 음원 재생 시각 t에 재생해야 할 조각 인덱스와 조각 내부 오프셋을 돌려준다. 없으면 nil.
function DanceRegistry.FindSegment(segments: {ResolvedSegment}, t: number): (number?, number?)
	local index: number? = nil
	for i, seg in segments do
		if seg.Start <= t then
			index = i
		else
			break
		end
	end

	if index == nil then
		return nil, nil
	end

	local seg = segments[index]
	local offset = t - seg.Start
	if seg.Duration ~= nil and offset >= seg.Duration then
		return nil, nil
	end

	return index, offset
end

return DanceRegistry
