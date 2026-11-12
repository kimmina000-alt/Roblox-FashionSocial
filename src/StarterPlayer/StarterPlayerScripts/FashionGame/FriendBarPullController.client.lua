--!strict
-- (D-1357, user 2026-11-13: "친구바 ... 누르면 둘이 아이스크림 막대기 잡고 서로 당기는 모션")
-- While two players share a 친구바 (FriendBar.share sets the character attributes
-- FriendBarPull = the other one's UserId and FriendBarPullSide = 1 buyer / 2 friend), each
-- one's right hand goes to the bar between them (an IKControl on the right arm, on every
-- client) and they tug it to and fro, harder towards the end, until the server snaps it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

type Pull = { ik: IKControl, goal: Attachment, holder: Part, t: number }
local pulls: {[Model]: Pull} = {}

local function stop(character: Model)
	local p = pulls[character]
	if not p then return end
	pulls[character] = nil
	p.ik:Destroy()
	p.holder:Destroy()
end

local function chest(character: Model): Vector3?
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	return if torso and torso:IsA("BasePart") then torso.Position else nil
end

local function start(character: Model): Pull?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local upper = character:FindFirstChild("RightUpperArm")
	local hand = character:FindFirstChild("RightHand")
	if not humanoid or not upper or not hand then return nil end -- (R15 only)
	local holder = Instance.new("Part")
	holder.Name = "FriendBarPullGoal"
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.1, 0.1, 0.1)
	holder.Parent = workspace
	local goal = Instance.new("Attachment")
	goal.Parent = holder
	local ik = Instance.new("IKControl")
	ik.Name = "FriendBarPull"
	ik.Type = Enum.IKControlType.Position
	ik.ChainRoot = upper :: Instance
	ik.EndEffector = hand :: Instance
	ik.Target = goal
	ik.Weight = 0
	ik.Parent = humanoid
	local p = { ik = ik, goal = goal, holder = holder, t = 0 }
	pulls[character] = p
	return p
end

RunService.Heartbeat:Connect(function(dt)
	local seen: {[Model]: boolean} = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local otherId = character and character:GetAttribute("FriendBarPull")
		local other = typeof(otherId) == "number" and Players:GetPlayerByUserId(otherId) or nil
		local otherChar = other and other.Character
		if character and otherChar then
			local a, b = chest(character), chest(otherChar)
			local p = pulls[character] or start(character)
			if p and a and b then
				seen[character] = true
				p.t += dt
				local side = character:GetAttribute("FriendBarPullSide")
				local toMe = (a - b)
				toMe = Vector3.new(toMe.X, 0, toMe.Z)
				toMe = if toMe.Magnitude > 0.05 then toMe.Unit else Vector3.zAxis
				-- the bar in the middle at chest height, a little lower; my hand on my end of it
				local mid = (a + b) / 2 + Vector3.new(0, -0.6, 0)
				-- the tug: both hands move together, one pulls, then the other (harder near the end)
				local swing = math.sin(p.t * math.pi * 2 * 2.2) * (0.15 + 0.25 * math.clamp(p.t / 1.4, 0, 1))
				local myEnd = mid + toMe * (0.35 + (if side == 1 then swing else -swing))
				p.holder.CFrame = CFrame.new(myEnd)
				p.ik.Weight = math.min(1, p.ik.Weight + dt / 0.2)
			end
		end
	end
	for character in pairs(pulls) do
		if not seen[character] then stop(character) end
	end
end)
