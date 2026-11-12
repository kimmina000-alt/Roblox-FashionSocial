-- (D-1333, user 2026-11-13, a photo inside OH24: "편의점 벽면에 냉장.냉동 저거 삭제해. 내가
-- 준 진열장 이미지 넣은 블록만 있어야 함..") The wall cooler build_hongdae_layout makes on the
-- store's west wall (ColdBack / ColdTop / ColdHeader / ColdInner / ColdBase / ColdDoor /
-- ColdFrame / ColdHandle / ColdShelf and the goods rows ShelfRow in front of it, all direct
-- children of Hongdae_Layout.OH24Store at x -106..-100) stood in front of the user's own
-- blocks with the cooler image (Workspace.cold, texture 93988306265362). They are taken
-- away; the gondolas' shelves (inside the Gondola models) stay.
-- Last step of the layout chain (after park_layout_1111, hanok_ground_fill, bakery_underlight);
-- idempotent: it only removes what is still there.

local store = workspace:WaitForChild("Hongdae_Layout"):FindFirstChild("OH24Store")
assert(store, "Hongdae_Layout.OH24Store is missing")
local removed = 0
for _, d in ipairs(store:GetChildren()) do
	if d:IsA("BasePart") and (string.match(d.Name, "^Cold") or d.Name == "ShelfRow")
		and d.Position.X > -106.5 and d.Position.X < -100 then
		d:Destroy()
		removed += 1
	end
end
print("[oh24_cold_off_1113] wall cooler parts removed:", removed)
return removed
