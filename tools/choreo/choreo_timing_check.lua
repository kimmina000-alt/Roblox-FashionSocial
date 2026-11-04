-- Choreography timing check (D-876, docs/01_SYSTEMS/CHOREOGRAPHY.md §12).
-- Run in Studio (Edit) after changing any choreography list in ClubConfig.
-- For every song with a choreography it prints the song's clock (lab tempo x
-- file speed, ClubConfig.songRate) and the timing problems that made dances
-- run early or late before:
--   NO_AT   a piece after the first without `at`: it starts where the piece
--           before ends, and captures run a little shorter than their clips,
--           so every piece after it comes earlier and earlier (BAD, IVE)
--   GAP     more than 1.5 s between a piece's end and the next `at`: the
--           dancer drops to the idle pose (fill it with `slowOut` / `slowIn`)
--   OVERLAP a piece still has more than its next piece's blend left when the
--           next one starts: its end is cut off
--   PAST    a piece ends after the song does
--   CLOCK   the heard song runs more than 0.05 % off the original: fine now
--           that ChoreoController follows ClubConfig.songRate, listed so a
--           new `fileSpeed` or tempo is noticed
-- Times are in the original song's seconds (the video's clock).

-- (a clone: the command bar keeps the first copy it required, edits or not)
local ClubConfig = require(game:GetService("ReplicatedStorage").FashionGame.Shared.ClubConfig:Clone())
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local lengths: {[number]: number} = {}
local function lengthOf(id: number): number
	if lengths[id] then return lengths[id] end
	local ok, seq = pcall(function() return KeyframeSequenceProvider:GetKeyframeSequenceAsync("rbxassetid://" .. id) end)
	local last = 0
	if ok and seq then
		for _, kf in ipairs((seq :: KeyframeSequence):GetKeyframes()) do last = math.max(last, (kf :: Keyframe).Time) end
	end
	lengths[id] = last
	return last
end

local out = {}
for _, track in ipairs(ClubConfig.Playlist) do
	if track.choreo then
		local rate = ClubConfig.songRate(track, 1)
		local songLength = track.length * ClubConfig.fileSpeed(track)
		table.insert(out, string.format("== %s  (song %.1f s, clock %.4f%s)", track.title, songLength, rate,
			if math.abs(rate - 1) > 0.0005 then string.format("  CLOCK %+.2f %%", (rate - 1) * 100) else ""))
		local clock, problems = 0, 0
		local entries = track.choreo
		for i, e in ipairs(entries) do
			local id = if typeof(e) == "table" then e.id else e
			local at = if typeof(e) == "table" then e.at else nil
			local from = if typeof(e) == "table" and e.from then e.from else 0
			local slowIn = if typeof(e) == "table" and e.slowIn then e.slowIn[2] else 0
			local slowOut = if typeof(e) == "table" and e.slowOut then e.slowOut[2] else 0
			if i > 1 and not at then
				table.insert(out, string.format("  NO_AT   #%d %d starts where #%d ends (%.2f)", i, id, i - 1, clock))
				problems += 1
			end
			local start = (at or clock) - slowIn
			local finish = start + slowIn + math.max(lengthOf(id) - from, 0) + slowOut
			if typeof(e) == "table" and e.stop then finish = math.min(finish, e.stop) end
			local nextE = entries[i + 1]
			if nextE then
				local nextAt = if typeof(nextE) == "table" then nextE.at else nil
				local nextSlow = if typeof(nextE) == "table" and nextE.slowIn then nextE.slowIn[2] else 0
				local nextBlend = if typeof(nextE) == "table" and nextE.blend then nextE.blend else 0.25
				if nextAt then
					local gap = nextAt - nextSlow - finish
					if gap > 1.5 then
						table.insert(out, string.format("  GAP     %.2f s idle between #%d (ends %.2f) and #%d (%.2f)", gap, i, finish, i + 1, nextAt))
						problems += 1
					elseif gap < -nextBlend then
						table.insert(out, string.format("  OVERLAP #%d still has %.2f s left when #%d starts at %.2f (blend %.2f)", i, -gap, i + 1, nextAt, nextBlend))
						problems += 1
					end
				end
			elseif finish > songLength + 0.5 then
				table.insert(out, string.format("  PAST    #%d ends at %.2f, the song at %.2f", i, finish, songLength))
				problems += 1
			end
			clock = finish
		end
		table.insert(out, if problems == 0 then "  ok" else string.format("  %d problem(s)", problems))
	end
end
print(table.concat(out, "\n"))
return table.concat(out, "\n")
