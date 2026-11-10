--!strict
-- Our own icons (user 2026-10-30 top bar mock-ups; docs/04_ART/icons/).
-- White icons for the top bar, the gold ₩ coin for every coin amount.
-- heart / dots / hanger / backpack / note are cut from the user's icon sheet
-- (rev 2); coin and give are drawn by tools/dev/icons/draw_icons.ps1.

return {
	-- (2026-11-01: the user's ₩ line drawing in gold with a dark edge,
	-- docs/04_ART/icons/coin_won_v3.png; before: v2 125376576385689, 88375483293732)
	coin = "rbxassetid://81001660486697",
	-- the ₩ mark alone, gold, no rings or edge: the top bar's coin pill
	-- (docs/04_ART/icons/coin_won_mark.png)
	won = "rbxassetid://71526225179744",
	-- (D-1267, user 2026-11-11: "가방 아이콘은 홈화면 상단 오른쪽 버튼에도 적용할 것": the
	-- backpack from the 오후네컷 design, docs/04_ART/icons/ohucuts_bag.png; before 95921900076363)
	bag = "rbxassetid://98853481270424", -- backpack
	note = "rbxassetid://101715049079271",
	give = "rbxassetid://92507739080371", -- hands + heart (old ♥ button)
	heart = "rbxassetid://102999852159498",
	dots = "rbxassetid://72179608746038",
	hanger = "rbxassetid://116288505140764",
}
