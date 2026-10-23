# OH24 편의점 (2026-10-23, D-120)

레퍼런스: docs/04_ART/references/oh24/ref_01..09 (매장 배치도, 진열대, 음료 냉장고, 계산대, GS25 외관).
위치: 서쪽 도로 남쪽 (x -146..-52, z 48..86, 2026-10-23 v2에서 주변 빈 땅까지 확장), 정면 = 북쪽. 북·동·서 세 면이 모두 통유리 + OH24 간판(홍대점 / 남부대로점 / 광안리점). 코드: 	ools/graybox/build_hongdae_layout.lua "OH24 convenience store".

## 구성
| 부분 | 레퍼런스 | 게임 |
|---|---|---|
| 외관 | GS25 홍대점 | 검은 석재 외벽, 가운데 OH24 로고(OH 흰색 + 24 청록), 좌우 청록 라이트 박스("Lifestyle Platform" / "홍대점"), 갈색 차양, 통유리 + 자동문, 체크 무늬 철판 계단 |
| 창가 | GS25 사진 | 유리 안쪽 흰 바 테이블 + 의자 4개(앉기) |
| 바닥·천장·벽 | 실내 사진 | 흰 베이지 타일, 흰 천장 판 + 격자 + LED 띠 4줄, 청록 띠 + "OH24 Fresh & Friendly" |
| 뒷벽 | 음료 냉장고 사진 | 유리문 냉장고 8칸(생수·음료·캔·우유), 위 간판 |
| 서쪽 벽 | 진열대 사진 | 벽 선반 5단(라면·과자·베이커리) |
| 가운데 | 배치도 | 양면 곤돌라 3줄(4단) + 앞쪽 엔드캡 3개, 위 분류 간판 |
| 계산대 | 계산대 사진 | 청록 상판, POS·고객 화면·카드 단말기·스캐너, 손님 쪽 사탕·껌·젤리 3단, 뒤 벽 "기프트카드 · 생활용품" |
| 동쪽 벽 | 사진 | 따뜻한 음료 온장고, 개방형 냉장 쇼케이스(도시락·삼각김밥·우유) |
| 기타 | 사진 | 아이스크림 냉동고, 입구 우산꽂이, 원형 보안 거울, 행사 포스터 |
- 담배·술은 넣지 않음(게임 규칙). 계산대 뒤는 기프트카드·생활용품.
- v2 배치: 통로 넓힘(곤돌라 5줄, 간격 12 → 통로 약 9), 서쪽 유리 앞 진열대, 뒷벽 서쪽 음료 냉장고 10칸, 동쪽 간편식 쇼케이스 + 온장고, 창가 바 테이블 2곳(북·동). 계산대 POS 화면은 계산원(안쪽, 동쪽) 방향, 고객 화면·카드 단말기는 손님 쪽.
- 부품 2,702개, SurfaceGui 1,230개(상품 1,411개, 글자는 가까이 갈 때만 그림). 모바일 프레임 확인 필요.

## 상품 이미지 작업 (개별 디자인)
- 진짜 과자 봉지 사진·로고는 상표라 게임에 쓸 수 없음 → 모든 상품은 가상 이름, 하나씩 디자인해서 넣는 구조.
- 목록: src/ReplicatedStorage/FashionGame/Shared/OH24Products.lua. 상품마다 image = "" 칸이 있음.
- 넣는 방법: 디자인 이미지를 Roblox에 올려 bxassetid://숫자를 해당 상품 image에 넣고 맵을 다시 빌드 → 그 상품이 놓인 모든 칸에 자동 적용(아직 없는 상품은 색 + 이름 임시 포장).
- 이미지 크기(앞면, px)는 모양별로 아래 표. 병·캔은 라벨 띠 부분만.

| 분류 | id | 이름 | 모양 | 앞면 크기 | 완료 |
|---|---|---|---|---|---|
| snack_bag | `chip_original` | 바삭감자 오리지널 | bag | 512x680 | ☐ |
| snack_bag | `chip_sourcream` | 바삭감자 사워크림 | bag | 512x680 | ☐ |
| snack_bag | `chip_honey` | 바삭감자 허니버터 | bag | 512x680 | ☐ |
| snack_bag | `corn_butter` | 콘스낵 버터구이 | bag | 512x680 | ☐ |
| snack_bag | `shrimp_snack` | 새우스낵 | bag | 512x680 | ☐ |
| snack_bag | `onion_ring` | 양파링 | bag | 512x680 | ☐ |
| snack_bag | `nacho_cheese` | 나쵸 치즈맛 | bag | 512x680 | ☐ |
| snack_bag | `sweet_potato` | 고구마칩 | bag | 512x680 | ☐ |
| snack_bag | `popcorn_caramel` | 팝콘 카라멜 | bag | 512x680 | ☐ |
| snack_bag | `tortilla_spicy` | 토르티야 매운맛 | bag | 512x680 | ☐ |
| snack_tube | `tube_original` | 튜브칩 오리지널 | tube | 300x740 | ☐ |
| snack_tube | `tube_sourcream` | 튜브칩 사워어니언 | tube | 300x740 | ☐ |
| snack_tube | `tube_cheese` | 튜브칩 치즈 | tube | 300x740 | ☐ |
| snack_tube | `tube_bbq` | 튜브칩 바베큐 | tube | 300x740 | ☐ |
| snack_tube | `tube_pizza` | 튜브칩 피자 | tube | 300x740 | ☐ |
| sweets_box | `choco_cake` | 초코 케이크 | box | 512x420 | ☐ |
| sweets_box | `butter_cookie` | 버터 쿠키 | box | 512x420 | ☐ |
| sweets_box | `choco_biscuit` | 초코 비스킷 | box | 512x420 | ☐ |
| sweets_box | `strawberry_wafer` | 딸기 웨하스 | box | 512x420 | ☐ |
| sweets_box | `salt_cracker` | 소금 크래커 | box | 512x420 | ☐ |
| sweets_box | `pepero_stick` | 초코 스틱 | box | 512x420 | ☐ |
| sweets_box | `energy_bar` | 에너지바 | box | 512x420 | ☐ |
| candy | `xylitol_gum` | 자일껌 | candy | 280x340 | ☐ |
| candy | `mint_candy` | 민트 캔디 | candy | 280x340 | ☐ |
| candy | `fruit_jelly` | 과일 젤리 | candy | 280x340 | ☐ |
| candy | `bear_jelly` | 곰젤리 | candy | 280x340 | ☐ |
| candy | `chewy_candy` | 츄잉 캔디 | candy | 280x340 | ☐ |
| candy | `sour_worm` | 새콤 지렁이 | candy | 280x340 | ☐ |
| candy | `lolipop` | 막대 사탕 | candy | 280x340 | ☐ |
| noodle | `cup_spicy` | 컵라면 매운맛 | cup | 420x420 | ☐ |
| noodle | `cup_mild` | 컵라면 순한맛 | cup | 420x420 | ☐ |
| noodle | `cup_udon` | 우동컵 | cup | 420x420 | ☐ |
| noodle | `cup_jjajang` | 짜장컵 | cup | 420x420 | ☐ |
| noodle | `cup_kimchi` | 김치 컵라면 | cup | 420x420 | ☐ |
| noodle | `cup_seafood` | 해물 컵라면 | cup | 420x420 | ☐ |
| bread | `bread_milk` | 우유식빵 | bread | 560x360 | ☐ |
| bread | `bread_cream` | 크림빵 | bread | 560x360 | ☐ |
| bread | `bread_red_bean` | 단팥빵 | bread | 560x360 | ☐ |
| bread | `bread_castella` | 카스테라 | bread | 560x360 | ☐ |
| drink_bottle | `water` | 생수 | bottle | 240x300 | ☐ |
| drink_bottle | `ion_drink` | 이온음료 | bottle | 240x300 | ☐ |
| drink_bottle | `cola` | 콜라 | bottle | 240x300 | ☐ |
| drink_bottle | `cider` | 사이다 | bottle | 240x300 | ☐ |
| drink_bottle | `orange_juice` | 오렌지 주스 | bottle | 240x300 | ☐ |
| drink_bottle | `green_tea` | 녹차 | bottle | 240x300 | ☐ |
| drink_bottle | `barley_tea` | 보리차 | bottle | 240x300 | ☐ |
| drink_bottle | `latte` | 카페 라떼 | bottle | 240x300 | ☐ |
| drink_bottle | `energy` | 에너지 드링크 | bottle | 240x300 | ☐ |
| drink_bottle | `peach_tea` | 복숭아 아이스티 | bottle | 240x300 | ☐ |
| drink_can | `can_lemon` | 레몬 탄산 | can | 220x260 | ☐ |
| drink_can | `can_coffee` | 캔커피 | can | 220x260 | ☐ |
| drink_can | `can_grape` | 포도 탄산 | can | 220x260 | ☐ |
| drink_can | `can_soda` | 소다 | can | 220x260 | ☐ |
| milk | `banana_milk` | 바나나 우유 | milk | 220x440 | ☐ |
| milk | `choco_milk` | 초코 우유 | milk | 220x440 | ☐ |
| milk | `strawberry_milk` | 딸기 우유 | milk | 220x440 | ☐ |
| milk | `white_milk` | 흰우유 | milk | 220x440 | ☐ |
| milk | `yogurt` | 요거트 | milk | 220x440 | ☐ |
| fresh | `tri_tuna` | 삼각김밥 참치마요 | tri | 440x380 | ☐ |
| fresh | `tri_bulgogi` | 삼각김밥 불고기 | tri | 440x380 | ☐ |
| fresh | `tri_kimchi` | 삼각김밥 김치볶음 | tri | 440x380 | ☐ |
| fresh | `sandwich` | 샌드위치 | box | 512x420 | ☐ |
| fresh | `kimbap` | 김밥 | bread | 560x360 | ☐ |
| lunch | `lunch_bulgogi` | 불고기 도시락 | lunch | 640x220 | ☐ |
| lunch | `lunch_pork` | 제육 도시락 | lunch | 640x220 | ☐ |
| lunch | `lunch_chicken` | 치킨 도시락 | lunch | 640x220 | ☐ |
| icecream | `ice_bar_choco` | 초코바 | icecream | 360x240 | ☐ |
| icecream | `ice_bar_melon` | 메론바 | icecream | 360x240 | ☐ |
| icecream | `ice_cone` | 콘 아이스 | icecream | 360x240 | ☐ |
| icecream | `ice_fish` | 붕어 아이스 | icecream | 360x240 | ☐ |
| icecream | `ice_cup` | 컵 아이스 | icecream | 360x240 | ☐ |
| goods | `gift_card` | 기프트 카드 | goods | 360x520 | ☐ |
| goods | `charge_cable` | 충전 케이블 | goods | 360x520 | ☐ |
| goods | `earphone` | 이어폰 | goods | 360x520 | ☐ |
| goods | `hot_pack` | 핫팩 | goods | 360x520 | ☐ |
| goods | `tissue` | 휴대용 티슈 | goods | 360x520 | ☐ |
| goods | `mask` | 마스크 | goods | 360x520 | ☐ |
| goods | `battery` | 건전지 | goods | 360x520 | ☐ |