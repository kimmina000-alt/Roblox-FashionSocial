--!nocheck
-- 겹친 면 정리 (D-1453, user 2026-11-15: "깜빡일 수 있는 곳은 쓸데없는 레이어가 겹쳐져 있다는 거니까
-- 눈에 안 보여도 정리해"). Two parts whose faces lie on the same plane, facing the same way and
-- overlapping, with a different colour / material / transparency, fight over which one is drawn
-- (flicker, "z-fighting"). A map check on 2026-11-15 found 1,471 such pairs among the 6,027 block
-- parts that are square to the world (club 481, OH24 215, ParkRaise 182 …).
-- For every such pair the SMALLER part's face is moved 0.02 out of the plane (its size grows 0.02
-- on that side): the smaller one is the detail (a trim, a marking, a step, a sign plate) and now
-- always wins; nothing moves by more than 0.02 per pass. A few passes run until no pair is left
-- (a part may meet several others on the same plane).
-- Only plain block Parts that are square to the world and not (almost) invisible; characters and
-- the map's invisible boundary walls are left out. LAST chain step (after the user snapshot and
-- every other step: rebuilt parts are fixed again). Idempotent: a second run finds nothing.

local Players = game:GetService("Players")
-- (D-1468, user 2026-11-16, a screenshot with a red line across the park: "빨간 선 부분 번쩍거림") two
-- faces of the SAME colour and material fight too when the material has a pattern (Slate, Sandstone,
-- Concrete, …): the pattern is laid from each part's own size and place, so the two do not line up
-- (the park's floor slabs overlapped 106 × 18.5 at y 16). Only plain materials are left alone.
local PLAIN = { [Enum.Material.SmoothPlastic] = true, [Enum.Material.Neon] = true, [Enum.Material.Glass] = true, [Enum.Material.ForceField] = true }
local EPS = 0.02
local MAX_PASSES = 16

local function skip(p: Instance): boolean
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character and p:IsDescendantOf(plr.Character) then return true end
	end
	return p:FindFirstAncestor("MapBoundary") ~= nil or p:FindFirstAncestorOfClass("Tool") ~= nil
end

local AX = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }
local OTHER = { X = { "Y", "Z" }, Y = { "X", "Z" }, Z = { "X", "Y" } }

local function collect()
	local items = {}
	local n = 0
	for _, p in ipairs(workspace:GetDescendants()) do
		n += 1
		if n % 30000 == 0 then task.wait() end
		if p:IsA("Part") and p.Shape == Enum.PartType.Block and p.Transparency < 0.95 and not skip(p) then
			local cf = p.CFrame
			local square = true
			for _, v in ipairs({ cf.RightVector, cf.UpVector, cf.LookVector }) do
				if math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z)) < 0.9999 then square = false end
			end
			if square then
				local s = p.Size
				local e = (cf.RightVector * s.X):Abs() + (cf.UpVector * s.Y):Abs() + (cf.LookVector * s.Z):Abs()
				table.insert(items, { p = p, lo = p.Position - e / 2, hi = p.Position + e / 2, vol = s.X * s.Y * s.Z })
			end
		end
	end
	return items
end

-- grow part p by d on the world side (axis ax, sign sgn)
local function grow(p: Part, ax: string, sgn: number, d: number)
	local cf = p.CFrame
	local w = AX[ax]
	local local_ = cf:VectorToObjectSpace(w) -- (one of ±x, ±y, ±z of the part)
	local a = Vector3.new(math.abs(local_.X), math.abs(local_.Y), math.abs(local_.Z))
	p.Size += a * d
	p.CFrame = cf + w * (sgn * d / 2)
end

local total = 0
for pass = 1, MAX_PASSES do
	local items = collect()
	local buckets = {}
	for i, it in ipairs(items) do
		for ax in pairs(AX) do
			for _, side in ipairs({ { "+", it.hi[ax] }, { "-", it.lo[ax] } }) do
				local key = ax .. side[1] .. math.floor(side[2] * 200 + 0.5)
				local b = buckets[key]
				if not b then b = {} buckets[key] = b end
				table.insert(b, i)
			end
		end
	end
	local done = {} -- (a part grows once per pass)
	local fixed = 0
	for key, b in pairs(buckets) do
		if #b > 1 then
			local ax, sgn = string.sub(key, 1, 1), if string.sub(key, 2, 2) == "+" then 1 else -1
			local o = OTHER[ax]
			for i = 1, #b do
				for j = i + 1, #b do
					local A, B = items[b[i]], items[b[j]]
					local o1 = math.min(A.hi[o[1]], B.hi[o[1]]) - math.max(A.lo[o[1]], B.lo[o[1]])
					local o2 = math.min(A.hi[o[2]], B.hi[o[2]]) - math.max(A.lo[o[2]], B.lo[o[2]])
					if o1 > 0.05 and o2 > 0.05 and (A.p.Color ~= B.p.Color or A.p.Material ~= B.p.Material or A.p.Transparency ~= B.p.Transparency or not PLAIN[A.p.Material]) then
						local S = if A.vol <= B.vol then A else B
						if not done[S.p] then
							done[S.p] = true
							grow(S.p, ax, sgn, EPS)
							fixed += 1
						end
					end
				end
			end
		end
	end
	total += fixed
	print(("[zfight_fix_1115] pass %d: %d faces moved"):format(pass, fixed))
	if fixed == 0 then break end
	task.wait()
end
return total
