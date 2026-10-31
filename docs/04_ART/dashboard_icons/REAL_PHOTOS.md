# 대시보드 아이콘 — 실제 아이템 사진으로 바꿀 목록 (2026-10-31)

게임 속 실제 모델을 찍어 512×512로 만든다. 배경은 묶음 색(클럽 보라 / VIP 금색 / 카페 핑크 / 국밥 베이지),
VIP가 상품은 같은 사진에 오른쪽 위 금색 "VIP" 표시. 파일: `docs/04_ART/dashboard_icons/real/<코드 키>.png`.
찍는 모델: `FashionGame.DrinkPreviews`(음료), `FashionGame.ItemPreviews`(불꽃·야광봉), `FashionGame.FoodPreviews`(카페·국밥집).

## 실제 사진으로 바꿀 것 (27개, 사진 23장 — VIP가 4개는 같은 사진에 VIP 표시)

| # | 종류 | 상품 | 코드 키 | 찍을 모델 | 배경 |
|-|-|-|-|-|-|
| 1 | 개발자 상품 | 진저 브루 | Drink_GingerBrew | DrinkPreviews.ginger_brew | 클럽 |
| 2 | 개발자 상품 | 몬테 스파클링 | Drink_Monte | DrinkPreviews.monte | 클럽 |
| 3 | 개발자 상품 | 프렌치 레모네이드 | Drink_FrenchLemonade | DrinkPreviews.french_lemonade | 클럽 |
| 4 | 개발자 상품 | 골든 애플 스파클링 | Drink_GoldenApple | DrinkPreviews.golden_apple | 클럽 |
| 5 | 개발자 상품 | 쨍팝 | Drink_ZzangPop | DrinkPreviews.zzang_pop_pink / _lime / _orange 세 병 | 클럽 |
| 6 | 개발자 상품 | 핫부스트 | Drink_HotBoost | DrinkPreviews.hot_boost | 클럽 |
| 7 | 개발자 상품 | 그린 클로 | Drink_GreenClaw | DrinkPreviews.green_claw | 클럽 |
| 8 | 개발자 상품 | 블루 윙 | Drink_BlueWing | DrinkPreviews.blue_wing | 클럽 |
| 9 | 개발자 상품 | 스택 하이드로 | Drink_StackHydro | DrinkPreviews.stack_hydro | 클럽 |
| 10 | 개발자 상품 | 스택 하이드로 (VIP가) | Drink_StackHydro_VIP | 9번 사진 + VIP 표시 | 클럽 |
| 11 | 개발자 상품 | 파스텔 스플래시 | Drink_PastelSplash | DrinkPreviews.pastel_splash | 클럽 |
| 12 | 개발자 상품 | 파스텔 스플래시 (VIP가) | Drink_PastelSplash_VIP | 11번 + VIP | 클럽 |
| 13 | 개발자 상품 | 스컬 캔 워터 | Drink_SkullWater | DrinkPreviews.skull_water | 클럽 |
| 14 | 개발자 상품 | 스컬 캔 워터 (VIP가) | Drink_SkullWater_VIP | 13번 + VIP | 클럽 |
| 15 | 개발자 상품 | 메종 드 루미에르 (VIP 전용) | Drink_Golmok | DrinkPreviews.golmok_* 네 병 | VIP |
| 16 | 개발자 상품 | 테이블 스파클러 | Sparkler1 | ItemPreviews.Sparkler1 | 클럽 |
| 17 | 개발자 상품 | 테이블 스파클러 5개 | Sparkler5 | ItemPreviews.Sparkler5 | 클럽 |
| 18 | 개발자 상품 | 손 스파클러 | HandSparkler | ItemPreviews.HandSparkler | 클럽 |
| 19 | 개발자 상품 | 스파클러 버킷 세트 | SparklerBucket | ItemPreviews.SparklerBucket | 클럽 |
| 20 | 개발자 상품 | 스파클러 버킷 세트 (VIP가) | SparklerBucket_VIP | 19번 + VIP | 클럽 |
| 21 | 게임 패스 | 야광봉 | Glowstick | ItemPreviews.Glowstick | 클럽 |
| 22 | 개발자 상품 | 딸기 파르페 | Cafe_Parfait | FoodPreviews.parfait | 카페 |
| 23 | 개발자 상품 | 딸기생크림 케이크 | Cafe_CakeStrawberry | FoodPreviews.cake_strawberry | 카페 |
| 24 | 개발자 상품 | 빈티지 레터링 케이크 | Cafe_CakeVintage | FoodPreviews.cake_vintage | 카페 |
| 25 | 개발자 상품 | 티라미수 케이크 | Cafe_CakeTiramisu | FoodPreviews.cake_tiramisu | 카페 |
| 26 | 개발자 상품 | 바스크 치즈케이크 | Cafe_CakeBasque | FoodPreviews.cake_basque | 카페 |
| 27 | 개발자 상품 | 수육 한 접시 | Gukbap_Suyuk | FoodPreviews.suyuk | 국밥 |

## 그림 아이콘 그대로 두는 것 (실제 물건이 없는 상품, 17개)

VIP 패스·가드 패스·DJ 30분(클럽 팔찌), 프레임 팩, 코인 x2 패스, 1시간 코인 부스트, 버스 광고 24시간 / 3일,
무대 콜드 스파크(+VIP가: 무대 장치라 그림 유지), 후원 10 / 50 / 100 / 500 / 1,000 / 5,000, 사진첩 +10장.
