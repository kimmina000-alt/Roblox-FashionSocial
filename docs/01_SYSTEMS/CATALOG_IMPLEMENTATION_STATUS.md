# Catalog 구현 현황 및 다음 작업 기준

기준일: 2026-10-17  
기준 브랜치: `catalog-ui-redesign`

이 문서는 현재 실행 대상 소스와 PDF UI 작업본을 구분해, 구현 사실·사용자 확인·미검증 사항·앞으로 할 일을 추적한다. 체크박스는 코드가 있다는 이유만으로 완료하지 않는다.

## 1. 소스 기준과 중요한 차이

### 실제 게임 소스
- `src/StarterPlayer/StarterPlayerScripts/FashionGame/CatalogController.client.lua`
- 서버 착용 처리: `src/ServerScriptService/FashionGame/Services/AvatarService.lua`
- 카탈로그 설정: `src/ReplicatedStorage/FashionGame/Shared/CatalogConfig.lua`
- 서버 시작/Remote 연결: `src/ServerScriptService/FashionGame/ServerMain.server.lua`

### 격리된 PDF UI 작업본
- `workbench/catalog-ui-redesign/working-copy/CatalogController.client.lua`
- 기준 백업: `workbench/catalog-ui-redesign/baseline/CatalogController.client.lua` (수정 금지)

중요: `workbench/.../working-copy`는 Rojo가 게임에 동기화하지 않도록 `src/` 밖에 둔 작업본이다. 문서에 UI 작업본에서 구현되었다고 적힌 내용이 실제 게임에 반영되었다고 단정하지 않는다. 실제 게임 적용 여부는 `src/...` 파일에서 별도로 확인해야 한다. 기준 백업은 보존한다.

## 2. 현재 실제 소스에서 확인된 내용

`src/StarterPlayer/StarterPlayerScripts/FashionGame/CatalogController.client.lua`를 확인한 기준:
- `AvatarEditorService`, `AssetService` 및 `CatalogConfig`를 사용한다.
- 검색어, 대분류/중분류, 정렬, 가격 범위, 판매 종료 아이템 포함 여부, 페이지 상태를 관리한다.
- 정렬 기본값은 `Enum.CatalogSortType.Relevance`다.
- 검색 결과 카드와 착용/해제 요청에 대한 클라이언트 상태가 있다.
- `currentWornItems`, `wornOrder`, `viewedOrder` 상태 변수가 선언되어 있다. 변수 선언만으로 Recent 기능이 완성되었다고 판단하지 않는다.
- 아바타 미리보기용 별도 `ScreenGui`, `ViewportFrame`, `WorldModel`, 카메라가 만들어지고 현재 캐릭터를 복제해 표시하는 코드가 있다.
- 현재 Outfit 카드 영역과 착용 아이템 카드/갱신용 함수 구조가 존재한다.
- Avatar Editor 버튼은 클릭 시 안내 문구를 출력하는 placeholder다.
- Wardrobe 버튼도 저장/불러오기가 아니라 안내 문구를 출력하는 placeholder다.
- 현재 소스 첫 화면의 카탈로그 패널 및 검색 UI는 구성되어 있지만, 현재 UI의 최종 크기·배치·카드 노출 여부는 Studio에서 재검증해야 한다.

서버 `AvatarService.lua`에는 classic clothing, rigid accessory, layered clothing, animation 등 여러 유형을 위한 매핑/적용 경로가 존재한다. 이 사실만으로 모든 매핑이 정확하거나 모든 유형의 착용·해제가 정상이라고 판정하지 않는다. 메이크업은 별도 경로 검증이 필요하다.

## 3. PDF UI 작업본에서 확인된 내용

`workbench/catalog-ui-redesign/working-copy/CatalogController.client.lua` 및 `workbench/catalog-ui-redesign/README.md`에는 다음이 들어 있다/기록되어 있다.
- PDF 기반 확장 레이아웃과 왼쪽 아바타 미리보기/오른쪽 결과 영역
- 가로 스크롤 가능한 대분류, 화살표 및 드래그/터치 탐색
- 접이식 필터 UI
- Current Outfit 가로 목록과 개별 해제 동작
- Recent / Popular / Favorites 버튼이 있으나 명세 기준으로는 실제 데이터 연결 전 placeholder
- Avatar Editor / Wardrobe placeholder
- 일부 툴팁과 검색/카테고리 변경 시 결과 스크롤 초기화

위 내용은 격리된 작업본에 관한 것이며, 실제 게임 소스에 복사·통합되어 동작한다는 뜻이 아니다. 작업본의 README에는 Studio 테스트 미완료 사항도 남아 있다.

## 4. 구현 완료와 사용자 확인을 구분

### 기존에 구현되었거나 사용자가 이전 리비전에서 확인했다고 기록된 항목
- 카탈로그 검색, 카테고리 선택, 정렬, 가격/판매 종료 필터, 페이지 탐색
- 아이템 착용/해제의 기본 흐름
- 우측 패널/확장·축소 및 화면 크기에 따른 레이아웃의 이전 리비전
- 이전 리비전에서 사용자가 PC/모바일 화면, 검색/필터/페이지, 착용/해제를 확인했다는 기록

주의: 사용자가 확인한 것은 이전 UI 리비전이다. 이후 PDF UI 변경분이나 현재 소스의 최신 레이아웃까지 통과했다고 확대 해석하지 않는다.

### 코드에 일부 구조만 있고 완성으로 볼 수 없는 항목
- Recent: `viewedOrder` 변수는 있으나, 기획 기준은 이번 세션에서 서버가 착용 성공을 확인한 아이템 기록이다. 현재 변수/구조가 이 규칙과 연결되어 완성됐다고 확인되지 않았다.
- Popular: 정렬 enum이 존재하는 것과 Popular 버튼이 공식 API 정렬을 실제로 실행하는 것은 별개다.
- Favorites: 실제 사용자별 즐겨찾기 저장/토글/별 표시가 구현되었다고 확인되지 않았다.
- Wearing: 현재 착용 상태를 추적하는 구조와 Current Outfit 영역은 있으나, 상단 Wearing 모드가 카드 영역을 권위 있는 실제 착용 목록으로 전환하는 완성 기능인지 별도 검증해야 한다.
- Current Outfit strip: UI 작업본에는 명시되어 있으나 실제 `src/` 버전과 동작 일치 여부를 확인해야 한다.
- Avatar Editor / Wardrobe: 현재는 placeholder.
- 아바타 미리보기 회전/줌 입력: 사용자가 요구한 마우스 드래그 회전과 휠 줌이 완성되었다고 확인되지 않았다.
- 착용 목록, 카드 WEAR/WORN, 실제 아바타 외형의 3자 상태 동기화: 오류 보고가 있었으며 전체 회귀 테스트가 필요하다.

## 5. 열린 문제 및 사용자가 보고한 UI 요구

다음은 사용자가 첨부한 작업 메모에 있는 요구/관찰이며, 현재 소스에서 모두 수정되었다는 뜻이 아니다.
- 최대화 창 상단이 Roblox 상단 UI와 겹치므로 안전 여백/높이 조정
- 메인 카탈로그 바깥쪽 라운드 패널 배경의 불투명도 조정
- 대분류/중분류 아래 스크롤바를 시각적으로 숨기되 드래그/스크롤은 유지
- 정렬을 Filter 팝업으로 이동해 검색 및 대분류 공간 확보
- 대분류/중분류 버튼 너비를 텍스트 길이에 맞춤
- 착용 목록에서 해제한 결과가 카드와 아바타에 즉시 반영되고, 카드에서 착용/해제한 결과도 착용 목록에 반영되어야 함
- 결과가 없는 카테고리(예: Body > Full Body/Head/Face, Clothing > Shoes)를 API 매핑/필터와 실제 빈 결과를 구분해 처리
- 중분류의 가로 스크롤 위치가 선택 후 처음으로 돌아가지 않도록 유지
- 착용 중 카드 선택 시 가능한 공식 API 정보를 표시할 수 있는지 조사
- 아바타 미리보기 영역 안에서만 드래그 회전 및 휠 줌
- 모바일 compact 창 크기/위치 및 UI 텍스트 크기 조정
- 카탈로그가 열린 상태에서 C 버튼을 누르면 닫힘
- 원형 페이지 화살표와 카테고리 텍스트 크기 조정

## 6. 앞으로 구현할 탐색 모드

### Recent
- 검색/열람 기록이 아닌, 이번 세션에서 서버가 착용 성공을 확인한 아이템만 기록
- 착용 요청 실패, 검색 결과 노출, 상세 열기, Outfit 복원은 Recent를 갱신하지 않음
- Asset/Bundle 유형과 ID를 함께 식별
- 같은 아이템을 다시 착용하면 중복 생성 대신 최근 착용 시각 갱신
- 최근 착용 성공 순으로 정렬하고 세션 종료 시 초기화; DataStore에는 저장하지 않음
- 빈 상태/착용 실패 상태를 구분

### Popular
- Roblox 공식 카탈로그 정렬만 사용
- API/아이템 유형이 지원하지 않는 경우 인기순이라고 거짓 표시하지 않음
- `MostFavorited`, `Bestselling`, `RecentlyCreated`, 가격순 등은 실제 지원되는 조합을 공식 문서 및 결과로 검증
- 게임 내부 Favorites와 Roblox 카탈로그 정렬은 완전히 별개

### Wearing
- 실제 현재 아바타 착용 상태를 기준으로 카드 영역 표시
- 카탈로그 카드에서 착용/해제하거나 Outfit을 복원한 뒤 상태 갱신
- 검색/카테고리 필터는 Wearing 목록 안에서만 필터링
- 실패한 서버 요청을 성공 상태로 낙관 반영하지 않음

### Favorites
- 게임 내부 사용자별 즐겨찾기 목록
- 카드 더블클릭으로 토글; 즐겨찾기 중이면 왼쪽 위 노란 별
- Favorites 모드는 즐겨찾기 아이템만 표시
- Favorites 모드 안에서도 더블클릭으로 해제 가능
- 단일 클릭 기존 기능과 더블클릭을 충돌 없이 처리
- 보존 범위/저장 구조는 현재 서버 데이터 구조 확인 후 확정

## 7. 필터·정렬·카테고리 정책

- 검색어, 카테고리, 정렬은 실제 `CatalogSearchParams`에 반영되는 값과 일치해야 한다.
- `IncludeOffSale` 사용자 선택이 카테고리 기본값에 의해 조용히 덮어써지지 않도록 우선순위를 단일화한다.
- Creator, 가격 범위, 판매 종료 아이템, Sales Type 필터는 실제 API 지원을 검증한 뒤 활성화한다.
- Limited 여부를 API가 안정적으로 판별/필터링하지 못하면 비활성화 상태로 유지하고 완료로 표시하지 않는다.
- 대분류/중분류가 API의 AssetTypes와 BundleTypes에 정확히 매핑되는지 확인한다.
- 빈 결과, 지원하지 않는 유형, API 오류, 썸네일 실패를 같은 상태로 표현하지 않는다.

## 8. 통합 테스트 체크리스트

- [ ] 현재 실제 게임 소스가 의도한 최신 UI 작업본과 일치하는지 확인
- [ ] PC compact / PC expanded
- [ ] 모바일 compact / 모바일 expanded
- [ ] 검색어 입력 + Enter + 검색 버튼
- [ ] 대분류 변경, 중분류 선택, 선택 후 스크롤 위치 유지
- [ ] 정렬, 가격 범위, IncludeOffSale 우선순위
- [ ] 페이지 추가 로딩과 중복 요청 방지
- [ ] 착용 → 카드 WORN 상태 → 아바타 미리보기
- [ ] 착용 목록에서 해제 → 카드 상태/아바타/목록 동기화
- [ ] 실패한 착용/해제가 UI를 잘못 갱신하지 않음
- [ ] Recent는 성공한 착용만 기록하고 검색/열람과 분리
- [ ] Popular의 API 정렬 지원 범위
- [ ] Favorites 추가/해제/별 표시/모드 필터
- [ ] Asset과 Bundle ID/type 구분
- [ ] 카탈로그 닫기/다시 열기
- [ ] Roblox Studio에서 실제로 수행한 항목만 통과 표시

## 9. 출처 문서
- `docs/01_SYSTEMS/CATALOG.md` — UX/레이아웃 요구사항
- `docs/01_SYSTEMS/AVATAR.md` — 착용/아바타 API 및 편집 요구사항
- `docs/06_LOG/TODO.md` — 실행 순서
- `docs/06_LOG/ISSUES.md` — 재현 가능한 오류 추적
- `docs/06_LOG/WORKLOG.md` — 날짜별 진행 내역
- `docs/06_LOG/CHANGELOG.md` — 커밋/변경 요약
- `workbench/catalog-ui-redesign/README.md` — PDF 작업본과 기준 백업에 대한 설명


## 10. Detailed feature specification links

- Recent / Popular / Wearing / Favorites: `docs/01_SYSTEMS/CATALOG_QUICK_NAVIGATION_IMPLEMENTATION_PLAN.md`
- Outfit / Wardrobe save and restore: `docs/01_SYSTEMS/OUTFIT_WARDROBE_AND_AVATAR_EDITOR_PLAN.md`
- Avatar Editor detailed requirements: `docs/01_SYSTEMS/AVATAR_EDITOR_IMPLEMENTATION_PLAN.md`

These documents describe planned behavior, not proof of implementation. Verify the actual `src/` code and mark Studio tests separately.


## 11. Authoritative avatar state and implementation boundaries — 2026-10-18

- **Wearing은 부분 구현**이다. 현재 소스에 현재 착용 항목을 읽는 경로는 있지만, 모든 item type에 대한 조회/착용/해제 범위와 server-confirmed 상태 동기화가 완성됐다고 볼 수 없다.
- Catalog wear/remove, Wearing, Current Outfit, Avatar Editor Apply, Outfit restore는 모두 동일한 서버 확인 Current Avatar snapshot을 사용해야 한다. 클라이언트의 currentWornItems / wornOrder 등은 캐시일 뿐이며 실제 적용 상태의 원본이 아니다.
- Roblox 공식 Humanoid:GetAppliedDescription()은 현재 Humanoid에 적용된 HumanoidDescription 복사본을 반환한다. 서버는 이 결과를 읽어 snapshot을 재구성하고, 불일치 시 이를 기준으로 클라이언트 캐시를 복구한다. 게임 전용 메타데이터나 API가 표현하지 않는 유형을 이 description만으로 복구할 수 있다고 가정하지 않는다.
- 아이템 identity는 itemType + itemId를 사용한다. Asset/Bundle, assetType/bundleType, layered/accessory metadata, classic clothing, animation, emote, makeup, body appearance를 한 숫자 ID나 하나의 generic accessory type으로 뭉개지 않는다.
- Current Outfit은 현재 착용 아이템의 가로 목록이며 Wearing grid와 같은 snapshot에서 파생된다.
- 탐색 모드는 Recent / Popular / Wearing / Favorites / Wardrobe다. Recommended는 제거했다. Wardrobe는 저장 Outfit 관리이며 Recent/Popular/Wearing/Favorites와 같은 catalog result mode로 취급하지 않는다.
- Recent는 실제 착용 성공 항목만, 세션 한정이다. Favorites/Outfit 영구 저장은 구현 확인 전까지 미완료로 유지한다.
- Popular는 MostFavorited + PastMonth를 우선 사용한다. API enum 지원은 공식 문서에서 확인했지만 실제 카테고리별 검색 결과/Studio 동작은 미검증이다.
- Avatar Editor는 draft → Apply/Cancel 계약을 따른다. 변경이 있을 때만 Apply/Cancel을 표시하고, 닫기/Outfit restore/respawn 시 미적용 draft를 자동 적용하지 않는다.
- 외형 변경 요청은 per-player action gate를 공유한다. 첫 요청만 실행하고 후속 요청은 대기열에 넣지 않고 거절/비활성화한다. 로딩 중 버튼 비활성화, 가능하면 “입는 중…” 표시.
- 리스폰 시 임시 착장을 자동 재적용하지 않고 Roblox 기본 아바타로 시작한다. Saved Outfit은 데이터에 남아 Wardrobe에서 다시 입을 수 있다.
- R6/R15는 개인 편집기 토글이 아니다. 게임 전체 avatar policy 변경으로 다루며 모든 Place/카메라/애니메이션/의상 호환성 조사 전에는 구현하지 않는다.
- 자세한 계약: [AVATAR_STATE_AND_PERSISTENCE.md](../05_TECH/AVATAR_STATE_AND_PERSISTENCE.md). API 근거 표: [API.md](../05_TECH/API.md). 데이터 저장 설계: [DATA.md](../05_TECH/DATA.md).

### Implementation evidence labels

- **API 문서 확인**: 공식 API 문서에 해당 기능/속성이 있음.
- **소스 확인**: 현재 branch의 코드를 정적으로 읽음.
- **Studio 검증**: 해당 시나리오를 Roblox Studio에서 직접 실행해 결과 확인.
- 이 기준일에 새로 한 작업은 문서와 소스 정적 조사뿐이다. 이 턴에서 Roblox Studio 실행 테스트는 하지 않았다.


### Source-level item-type limitations confirmed in AvatarService

Static source review of src/ServerScriptService/FashionGame/Services/AvatarService.lua confirms:
- TryOnItem currently accepts only a numeric assetId and calls GetItemDetailsAsync(assetId, Enum.AvatarItemType.Asset). RemoveItem likewise accepts only a numeric assetId.
- GetCurrentItems returns entries centered on AssetId/Category and some IsLayered/AssetTypeId fields; it does not yet provide the complete typed itemType + itemId contract.
- The service contains separate branches for classic clothing, makeup, emotes, animations, and mapped accessories, but unsupported asset types return an error. A catalog Bundle result is not currently handled as a Bundle identity or generic wearable.
- Therefore Bundle display/search support must not be treated as Bundle wear/remove support. Implement a typed dispatcher only after each type's official application path is established. Keep unsupported types disabled/non-actionable and report them clearly.
- These are static code findings, not Studio verification.


## 12. Saved Outfit MVP — aligned policy (2026-10-18)

This is a requirements checklist, not a claim that persistence has been implemented.

- [ ] Save only the server-confirmed applied appearance as a versioned SupportedAppearanceSnapshot.
- [ ] Use a unique outfitId even when names repeat; validate trimmed/non-empty names and name length.
- [ ] Enforce the product limit of **50 SavedOutfits per user**. This is a game policy, not a Roblox platform recommendation.
- [ ] Never silently overwrite an existing Outfit at the limit.
- [ ] Rejoin and load the saved records from server-side persistence.
- [ ] Restore the selected Outfit by replacing the current appearance, not by blindly appending saved entries.
- [ ] Skip only unsupported, deleted, unavailable or rejected entries; apply remaining valid appearance and identify skipped items where possible.
- [ ] Preserve the original SavedOutfit unchanged after partial restore.
- [ ] Rebuild Current Outfit, Wearing, card state and preview from the actual server-confirmed applied result.
- [ ] Distinguish empty Wardrobe from load/migration failure; never overwrite data with an empty default after a read error.
- [ ] Classify transient service/network errors, throttling, invalid/unserializable payload, payload-too-large and ambiguous write results.
- [ ] Use bounded retries/backoff only for retryable failures; verify ambiguous writes with a cache-bypassing follow-up read before reporting a final result.
- [ ] Validate serialized payload byte size. Roblox's 4 MiB per-key maximum is a hard platform limit, not an application target; set a smaller internal limit after measuring representative snapshots.
- [ ] Verify save/load/rejoin/partial-restore/failure paths in Studio before marking these items complete.

Authoritative contracts: `docs/01_SYSTEMS/OUTFIT.md`, `docs/01_SYSTEMS/OUTFIT_WARDROBE_AND_AVATAR_EDITOR_PLAN.md`, `docs/05_TECH/DATA.md`, and `docs/05_TECH/AVATAR_STATE_AND_PERSISTENCE.md`.

## Popular aggregation note — 2026-10-18
The current `CatalogConfig.SortAggregation` is `Enum.CatalogSortAggregation.AllTime` and is applied through the generic search path. The Popular button remains a placeholder in the inspected source, so the required Popular-only `MostFavorited + PastMonth` behavior and explicit AllTime fallback are **not implemented**. Do not treat the global AllTime config as proof that Popular works.
