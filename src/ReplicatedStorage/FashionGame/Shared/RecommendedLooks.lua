--!strict
-- (D-1373, user 2026-11-13: "마켓 아바타 번들 말고 추천 조합 올릴 수 있는 방법 찾아봐" → "1로
-- 하자": the user sends Marketplace look links, we copy their item ids here) The catalog's
-- ✨ 추천 window (RecommendedLooksView): one card per look; 입어 보기 puts the whole look on
-- at once (TryOnItem "WearLook" with the key: the server reads the items from this list,
-- AvatarService.WearLook), 🛒 사기 opens Roblox's one-purchase window for the items the
-- player does not own yet.
-- Marketplace "Looks" have no engine API (DevForum: Looks are web only), so each look is
-- read from its page by hand: roblox.com/looks/<id> → the "포함된 아이템" links.
-- items: kind "Bundle" (body / head / animation / shoes sets) or "Asset"; at most 20.

export type Item = { kind: string, id: number, name: string }
export type Look = { key: string, name: string, price: number, lookId: string, items: {Item} }

local RecommendedLooks: {Look} = {
	{
		key = "striped_street_wanderer", name = "줄무늬 거리 방랑자", price = 660, lookId = "3280169265994531316",
		items = {
			{ kind = "Bundle", id = 120131389746251, name = "애니메이션 화려한 소녀 🖤(다크)" },
			{ kind = "Bundle", id = 128273029481897, name = "루나 큐티 인형 2d" },
			{ kind = "Asset", id = 138205853607168, name = "폴로 롱 슬리브 오렌지" },
			{ kind = "Asset", id = 129144177664403, name = "디스트레스 반바지 (블랙)" },
			{ kind = "Asset", id = 99007171456342, name = "타투" },
			{ kind = "Asset", id = 96652554551397, name = "빨간 립스틱 키스 마크" },
			{ kind = "Asset", id = 18192469417, name = "초기 목걸이 R" },
			{ kind = "Asset", id = 16527749338, name = "❤️ 오렌지" },
			{ kind = "Asset", id = 16086841833, name = "빨간 무릎" },
			{ kind = "Asset", id = 16067572538, name = "펑크 모자 지저분한 머리 (플라티늄 금발)" },
		},
	},
	{
		key = "duality_plushie_wanderer", name = "이중성 인형 방랑자", price = 741, lookId = "1355996617550987559",
		items = {
			{ kind = "Bundle", id = 60692790041569, name = "애니메이션 용감한 소년 🩶 (회색)" },
			{ kind = "Bundle", id = 165616495694106, name = "루나 큐티 인형 2d" },
			{ kind = "Asset", id = 98714450565309, name = "셀라나 카고" },
			{ kind = "Asset", id = 98043975161068, name = "에모 소년 머리 / Y2K 후드 티" },
			{ kind = "Asset", id = 96642493722241, name = "Y2K 블랙 그라피티 패딩 재킷" },
			{ kind = "Asset", id = 82021400371401, name = "흰색·검은색 토끼 인형" },
			{ kind = "Asset", id = 18249165929, name = "검은색 탱크 탑" },
			{ kind = "Asset", id = 17329993840, name = "이모 크로스 체인 목걸이" },
			{ kind = "Bundle", id = 211115919506499, name = "체인 달린 흰색 운동화" },
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
