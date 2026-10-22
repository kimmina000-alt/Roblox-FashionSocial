-- Prints the building moves made in Studio as LAYOUT_MOVES lines for
-- build_main_social_graybox.lua (run in the Studio command bar, Edit mode).
-- Paste the output into LAYOUT_MOVES so the moves are kept in GitHub too.
local root = workspace:FindFirstChild("Graybox_MainSocial")
if not root then return "no Graybox_MainSocial" end
local function key(z, m)
	local n = 0
	for _, c in ipairs(z:GetChildren()) do
		if c:IsA("Model") and c.Name == m.Name then
			n += 1
			if c == m then break end
		end
	end
	return z.Name .. "/" .. m.Name .. "#" .. n
end
local function fmt(cf: CFrame): string
	local parts = { cf:GetComponents() }
	for i, v in ipairs(parts) do parts[i] = string.format("%.4f", v):gsub("%.?0+$", "") end
	return "CFrame.new(" .. table.concat(parts, ",") .. ")"
end
local lines = {}
for _, z in ipairs(root:GetChildren()) do
	if z:IsA("Model") then
		local zb = z:GetAttribute("BuiltPivot")
		local Z = if typeof(zb) == "CFrame" then z:GetPivot() * zb:Inverse() else CFrame.new()
		if Z ~= CFrame.new() then table.insert(lines, string.format(' ["%s"]=%s,', z.Name, fmt(Z))) end
		for _, c in ipairs(z:GetChildren()) do
			local b = c:IsA("Model") and c:GetAttribute("BuiltPivot")
			if typeof(b) == "CFrame" then
				local L = Z:Inverse() * c:GetPivot() * b:Inverse()
				if (L.Position.Magnitude > 0.01) or (L.LookVector - Vector3.new(0, 0, -1)).Magnitude > 0.001 then
					table.insert(lines, string.format(' ["%s"]=%s,', key(z, c), fmt(L)))
				end
			end
		end
	end
end
return if #lines == 0 then "no moves" else table.concat(lines, "\n")
