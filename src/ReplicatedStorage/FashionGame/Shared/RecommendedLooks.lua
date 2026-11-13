--!strict
-- (D-1373, user 2026-11-13: "마켓 아바타 번들 말고 추천 조합 올릴 수 있는 방법 찾아봐" → "1로
-- 하자": the user sends Marketplace look share links) The catalog's ✨ 추천 window
-- (RecommendedLooksView): one card per look.
--   outfitId: the look's Roblox outfit; 입어 보기 = TryOnItem "WearLook" with the key → the
--     server loads Players:GetHumanoidDescriptionFromOutfitId(outfitId) and puts it on like a
--     saved outfit (exactly the Marketplace look: only the bundle parts the look uses, body
--     colours, sizes, layer order)
--   items: what the look is made of, for 한 번에 사기 (Owned → BuyMany) and the card's pictures:
--     { kind "Bundle" / "Asset", id, price } (Marketplace prices when added)
-- How to add one: open the share link signed in to roblox.com, resolve it
-- (apis.roblox.com/sharelinks/v1/resolve-link → avatarItemDetailsData.itemId = lookId), read
-- apis.roblox.com/look-api/v2/looks/<lookId> (name, totalPrice, outfitId, items). Marketplace
-- Looks have no engine API, so this is done by hand (docs/06_LOG/DECISIONS.md D-1373).

export type Item = { kind: string, id: number, price: number }
export type Look = { key: string, name: string, price: number, lookId: string, outfitId: number, items: {Item} }

local RecommendedLooks: {Look} = {
	{
		key = "look3280169265994531316", name = "줄무늬 거리 방랑자", price = 660, lookId = "3280169265994531316", outfitId = 4814767058567451,
		items = {
			{ kind = "Bundle", id = 120131389746251, price = 70 }, { kind = "Bundle", id = 128273029481897, price = 165 },
			{ kind = "Asset", id = 138205853607168, price = 65 }, { kind = "Asset", id = 129144177664403, price = 60 },
			{ kind = "Asset", id = 99007171456342, price = 5 }, { kind = "Asset", id = 96652554551397, price = 90 },
			{ kind = "Asset", id = 18192469417, price = 50 }, { kind = "Asset", id = 16527749338, price = 90 },
			{ kind = "Asset", id = 16086841833, price = 5 }, { kind = "Asset", id = 16067572538, price = 60 },
		},
	},
	{
		key = "look1355996617550987559", name = "이중성 인형 방랑자", price = 741, lookId = "1355996617550987559", outfitId = 6283530060224586,
		items = {
			{ kind = "Bundle", id = 60692790041569, price = 70 }, { kind = "Bundle", id = 165616495694106, price = 165 },
			{ kind = "Asset", id = 98714450565309, price = 71 }, { kind = "Asset", id = 98043975161068, price = 60 },
			{ kind = "Asset", id = 96642493722241, price = 65 }, { kind = "Asset", id = 82021400371401, price = 135 },
			{ kind = "Asset", id = 18249165929, price = 65 }, { kind = "Asset", id = 17329993840, price = 50 },
			{ kind = "Bundle", id = 211115919506499, price = 60 },
		},
	},
	{
		key = "look1307698469070307598", name = "실버 스트라이더 방랑자", price = 1006, lookId = "1307698469070307598", outfitId = 4689583840373101,
		items = {
			{ kind = "Bundle", id = 625095, price = 70 }, { kind = "Bundle", id = 56690743669382, price = 175 },
			{ kind = "Bundle", id = 34601029706905, price = 165 }, { kind = "Asset", id = 138439701794876, price = 60 },
			{ kind = "Asset", id = 118440271095922, price = 71 }, { kind = "Asset", id = 115392749698336, price = 60 },
			{ kind = "Asset", id = 114548788312071, price = 60 }, { kind = "Asset", id = 107966977497481, price = 90 },
			{ kind = "Asset", id = 91639640197703, price = 65 }, { kind = "Asset", id = 79388572415694, price = 90 },
			{ kind = "Asset", id = 17419596162, price = 50 }, { kind = "Asset", id = 17329993840, price = 50 },
		},
	},
	{
		key = "look2541652729365922170", name = "스케이터 스트리트 라이더", price = 730, lookId = "2541652729365922170", outfitId = 6299095754261248,
		items = {
			{ kind = "Bundle", id = 143259505453426, price = 70 }, { kind = "Bundle", id = 394650, price = 175 },
			{ kind = "Asset", id = 134680850035585, price = 30 }, { kind = "Asset", id = 118960655407188, price = 60 },
			{ kind = "Asset", id = 18636349579, price = 55 }, { kind = "Asset", id = 17490697617, price = 65 },
			{ kind = "Asset", id = 16133388263, price = 5 }, { kind = "Asset", id = 13462728842, price = 135 },
			{ kind = "Asset", id = 9210584093, price = 75 }, { kind = "Asset", id = 382538295, price = 0 },
			{ kind = "Bundle", id = 228512101643447, price = 60 },
		},
	},
	{
		key = "look4467283673540067725", name = "고양이 귀 방랑자", price = 480, lookId = "4467283673540067725", outfitId = 5838408405779825,
		items = {
			{ kind = "Bundle", id = 153163536246919, price = 70 }, { kind = "Bundle", id = 128273029481897, price = 165 },
			{ kind = "Asset", id = 123600300171774, price = 115 }, { kind = "Asset", id = 105867175805337, price = 5 },
			{ kind = "Asset", id = 13388762379, price = 60 }, { kind = "Asset", id = 8346103048, price = 5 },
			{ kind = "Bundle", id = 62768628824145, price = 60 },
		},
	},
	{
		key = "look3610268085854011767", name = "진홍색 스케이터 십대", price = 1325, lookId = "3610268085854011767", outfitId = 6233620502772921,
		items = {
			{ kind = "Bundle", id = 597797, price = 70 }, { kind = "Bundle", id = 128416135717800, price = 165 },
			{ kind = "Bundle", id = 34601029706905, price = 165 }, { kind = "Asset", id = 138839570077007, price = 60 },
			{ kind = "Asset", id = 135324172000168, price = 9 }, { kind = "Asset", id = 124975849765682, price = 100 },
			{ kind = "Asset", id = 113565365143137, price = 70 }, { kind = "Asset", id = 111942761847998, price = 71 },
			{ kind = "Asset", id = 109842474899422, price = 90 }, { kind = "Asset", id = 105133051034948, price = 60 },
			{ kind = "Asset", id = 105101736126764, price = 60 }, { kind = "Asset", id = 84381652511986, price = 135 },
			{ kind = "Asset", id = 16255645346, price = 90 }, { kind = "Asset", id = 14426628259, price = 90 },
			{ kind = "Asset", id = 13405691589, price = 90 },
		},
	},
	{
		key = "look2516416463338865033", name = "플러시 탐험가 학생", price = 995, lookId = "2516416463338865033", outfitId = 6035532679260199,
		items = {
			{ kind = "Bundle", id = 70864928618316, price = 70 }, { kind = "Bundle", id = 128273029481897, price = 165 },
			{ kind = "Asset", id = 107593212441975, price = 5 }, { kind = "Asset", id = 100010042764081, price = 135 },
			{ kind = "Asset", id = 91540282728065, price = 60 }, { kind = "Asset", id = 85690550068476, price = 95 },
			{ kind = "Asset", id = 77170519561175, price = 76 }, { kind = "Asset", id = 73590717833654, price = 60 },
			{ kind = "Asset", id = 16484220768, price = 94 }, { kind = "Asset", id = 16202808707, price = 90 },
			{ kind = "Asset", id = 14426628259, price = 90 }, { kind = "Bundle", id = 120742774037976, price = 55 },
		},
	},
	{
		key = "look7133420700798419154", name = "어둠의 캐주얼 방랑자", price = 826, lookId = "7133420700798419154", outfitId = 5242237881862323,
		items = {
			{ kind = "Bundle", id = 625095, price = 70 }, { kind = "Bundle", id = 198817663533456, price = 175 },
			{ kind = "Bundle", id = 34601029706905, price = 165 }, { kind = "Asset", id = 130240243660618, price = 90 },
			{ kind = "Asset", id = 123191253917851, price = 65 }, { kind = "Asset", id = 79316838380481, price = 5 },
			{ kind = "Asset", id = 76732287946982, price = 71 }, { kind = "Asset", id = 17450708161, price = 60 },
			{ kind = "Asset", id = 15682954930, price = 5 }, { kind = "Asset", id = 13251126488, price = 60 },
			{ kind = "Bundle", id = 208966265516672, price = 60 },
		},
	},
	{
		key = "look1534951248732750192", name = "체크 무늬 스트리트 여행자", price = 845, lookId = "1534951248732750192", outfitId = 6611674890687159,
		items = {
			{ kind = "Bundle", id = 31586007206637, price = 70 }, { kind = "Bundle", id = 1643204, price = 175 },
			{ kind = "Bundle", id = 34601029706905, price = 165 }, { kind = "Asset", id = 123316458229208, price = 30 },
			{ kind = "Asset", id = 97228028957246, price = 65 }, { kind = "Asset", id = 71621725569953, price = 135 },
			{ kind = "Asset", id = 18840868675, price = 50 }, { kind = "Asset", id = 18167847255, price = 90 },
			{ kind = "Asset", id = 12895419695, price = 60 }, { kind = "Asset", id = 4975529488, price = 5 },
		},
	},
	{
		key = "look6622494107682078975", name = "체크무늬 퍼지 방랑자", price = 766, lookId = "6622494107682078975", outfitId = 4594957936469183,
		items = {
			{ kind = "Bundle", id = 2111146944549, price = 75 }, { kind = "Bundle", id = 9636558658408, price = 165 },
			{ kind = "Bundle", id = 600698, price = 165 }, { kind = "Asset", id = 140080096339528, price = 65 },
			{ kind = "Asset", id = 131016137545506, price = 60 }, { kind = "Asset", id = 112615545106942, price = 60 },
			{ kind = "Asset", id = 108225951452015, price = 6 }, { kind = "Asset", id = 104354982948850, price = 60 },
			{ kind = "Asset", id = 16874336447, price = 50 }, { kind = "Bundle", id = 215215551100279, price = 60 },
		},
	},
	{
		key = "look1637429685283193200", name = "올드 머니 룩", price = 1220, lookId = "1637429685283193200", outfitId = 5973780375519544,
		items = {
			{ kind = "Bundle", id = 259673009769320, price = 75 }, { kind = "Bundle", id = 9636558658408, price = 165 },
			{ kind = "Bundle", id = 99604282563162, price = 165 }, { kind = "Bundle", id = 167791703067850, price = 175 },
			{ kind = "Asset", id = 125761748178442, price = 50 }, { kind = "Asset", id = 102282518305667, price = 60 },
			{ kind = "Asset", id = 101673179018741, price = 90 }, { kind = "Asset", id = 94420022900551, price = 5 },
			{ kind = "Asset", id = 17815560161, price = 65 }, { kind = "Asset", id = 17523370002, price = 65 },
			{ kind = "Asset", id = 17426658643, price = 90 }, { kind = "Asset", id = 16636496157, price = 60 },
			{ kind = "Asset", id = 16320570945, price = 5 }, { kind = "Asset", id = 12395656419, price = 90 },
			{ kind = "Bundle", id = 261057445075307, price = 60 },
		},
	},
}

local byKey: {[string]: Look} = {}
for _, look in ipairs(RecommendedLooks) do byKey[look.key] = look end

return {
	list = RecommendedLooks,
	get = function(key: any): Look?
		return if typeof(key) == "string" then byKey[key] else nil
	end,
}
