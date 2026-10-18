# Catalog Quick Navigation — 구현 상세 명세

> 상태: **요구사항/구현 계획**. 이 문서의 체크리스트는 구현 완료를 의미하지 않는다. 현재 소스 조사와 Roblox Studio 검증 결과를 별도로 기록한다.
> 기준 브랜치: `catalog-ui-redesign`
> 실제 UI 진입점: `src/StarterPlayer/StarterPlayerScripts/FashionGame/CatalogController.client.lua`
> 서버 착용 처리: `src/ServerScriptService/FashionGame/Services/AvatarService.lua`
> 관련 상태 보고: `docs/01_SYSTEMS/CATALOG_IMPLEMENTATION_STATUS.md`

## 1. 목적 및 범위

상단의 Recent / Popular / Wearing / Favorites 버튼이 단순히 선택 상태만 바꾸는 장식이 아니라, 기존 카탈로그 카드 영역에 각 모드의 올바른 데이터 목록을 표시하도록 한다. 네 모드는 동일한 카드 UI를 재사용하되 데이터 출처, 정렬, 갱신 이벤트, 오류 상태가 서로 다르다.

- **Recent**: 사용자가 실제로 열어 본 아이템 기록. 검색어/검색 기록이 아니다.
- **Popular**: Roblox 카탈로그가 실제 지원하는 인기 관련 정렬 결과.
- **Wearing**: 현재 아바타에 실제 적용되어 착용 중인 아이템.
- **Favorites**: Roblox 계정의 공식 즐겨찾기와 별개인, 이 게임의 사용자별 개인 즐겨찾기.
- **Wardrobe / Saved Outfit**: 저장된 코디 목록이며, 위 네 탐색 모드와 별도 기능이다.
- **Current Outfit strip**: 현재 착용 아이템을 한 줄로 보여 주는 별도 표현이다. Wearing 카드 그리드와 동일한 권위 있는 착용 상태를 공유하되 UI 역할은 다르다.

이 문서는 탐색 모드의 상세 계약을 소유한다. 전체 카탈로그 UX는 `CATALOG.md`, 실제 구현/검증 상태는 `CATALOG_IMPLEMENTATION_STATUS.md`, Outfit 저장/복원은 `OUTFIT_WARDROBE_AND_AVATAR_EDITOR_PLAN.md`, Avatar Editor는 `AVATAR_EDITOR_IMPLEMENTATION_PLAN.md` 및 `AVATAR.md`를 함께 참조한다.

## 2. 구현 전 조사 및 변경 안전성

수정 전에 최신 `catalog-ui-redesign` 브랜치의 실제 `src/` 코드를 확인한다. PDF/격리 작업본은 실제 게임에 반영된 코드로 간주하지 않는다.

1. 상단 탐색 버튼, 선택 상태, 결과 목록을 렌더링하는 코드.
2. 카드 단일 클릭, 상세/선택/미리보기, WEAR/REMOVE 이벤트 및 비동기 요청.
3. 현재 착용 상태를 반환하는 서버 경로와 `AvatarService`의 실제 적용 결과.
4. Asset/Bundle의 ID 및 유형을 저장하고 다시 조회하는 방식.
5. 검색어, 대분류/중분류, 정렬, 페이지네이션, IncludeOffSale가 실제 검색 요청에 반영되는 방식.
6. 사용자별 영구 저장 구조(DataStoreService 등), RemoteFunction/RemoteEvent 검증, 요청 제한 및 오류 반환.
7. 썸네일/이름/가격 메타데이터를 얻는 공식 경로와 해당 아이템이 더 이상 조회되지 않을 때의 처리.

현재 `CatalogController.client.lua`에는 `currentWornItems`, `wornOrder`, `viewedOrder` 등 상태가 존재하지만, 변수 존재만으로 기능이 완성된 것은 아니다. `ServerMain.server.lua`의 현재 확인된 Remote 경로는 착용/해제 및 현재 아이템 조회 중심이며, Recent/Favorites/Outfit의 영구 저장이 이미 구현됐다고 가정하지 않는다.

기존 카탈로그 검색, 카테고리, 필터, 정렬, 페이지 이동, 카드, 착용/해제 및 미리보기를 보존한다. `default.project.json`과 `workbench/catalog-ui-redesign/baseline/`은 수정하지 않는다. 작업은 `catalog-ui-redesign`에서 수행하고 `main`에 병합하지 않는다.

## 3. 공통 탐색 모드 및 카드 계약

### 3.1 상단 버튼

- Recent / Popular / Wearing / Favorites 중 한 번에 하나만 선택 상태가 된다.
- 선택된 모드에 맞춰 기존 결과 카드 영역을 실제로 다시 렌더링한다.
- 모드 변경 시 이전 비동기 요청의 늦은 응답이 새 모드 결과를 덮어쓰지 않도록 요청 세대/취소 또는 동등한 보호를 둔다.
- 모드 전환만으로 아이템을 착용하거나 Recent 기록을 생성하지 않는다.
- 카탈로그를 닫았다 다시 열 때 기본 탐색 화면으로 돌아간다. 저장 데이터는 유지되며 사용자가 원하는 모드를 다시 선택할 수 있다.

### 3.2 공통 카드

가능한 경우 기존 카드 컴포넌트를 재사용한다. 아이템 유형이 지원하는 정보만 표시하고 누락된 이름/가격/유형을 임의로 만들지 않는다.

- 썸네일, 이름, 유형, API가 제공하는 가격/판매 상태
- 실제 착용 상태(서버 확인된 상태)
- 게임 내 즐겨찾기 상태(활성 시 카드 왼쪽 위 노란 별)
- 기존의 착용/해제 액션 및 해당 유형의 지원 여부

Asset과 Bundle은 같은 숫자 ID라는 이유만으로 동일 아이템으로 취급하지 않는다. 저장 키는 유형/종류와 ID를 함께 포함한다. Outfit은 카탈로그 아이템이 아니므로 일반 아이템 착용 API에 Outfit ID를 전달하지 않는다.

### 3.3 검색·필터·정렬

- **Recent**: 최근 기록을 기준으로 검색어/카테고리 필터를 기록 목록 안에 적용할 수 있다.
- **Popular**: 지원되는 검색어/카테고리 조건과 공식 API 정렬을 함께 전달한다.
- **Wearing**: 현재 착용 목록 내부에서 검색/카테고리 필터를 적용한다. 전체 카탈로그로 전환하지 않는다.
- **Favorites**: 개인 즐겨찾기 목록 내부에서 검색/카테고리 필터를 적용한다. 전체 카탈로그로 전환하지 않는다.
- 정렬 컨트롤이 모드별로 의미가 다르면 유효한 정렬만 활성화하고, 사용자가 선택한 값과 실제 적용된 값이 일치해야 한다.
- API에서 전달할 수 없는 조건을 일부 결과에만 로컬 적용했을 때 전체 결과의 정확한 순서를 보장하지 못한다면, 전체 카탈로그 기준 정렬인 것처럼 표시하지 않는다.
- 검색어 또는 필터 변경 시 현재 모드의 데이터 출처를 유지한다.

### 3.4 상태 처리

각 모드는 빈 목록, 로딩, 요청 오류, 메타데이터/썸네일 누락을 구분한다.

- Recent: 최근 열람 아이템이 없음
- Popular: 조건에 맞는 결과 없음 또는 해당 유형에서 인기 정렬 미지원
- Wearing: 현재 착용 중인 아이템이 없음
- Favorites: 즐겨찾기 아이템이 없음

API/저장소 오류를 정상적인 빈 목록으로 위장하지 않는다. 썸네일 실패는 해당 아이템 자체가 없다는 뜻으로 처리하지 않는다.

## 4. Recent — 이번 세션에서 착용한 아이템

### 4.1 기록 조건

Recent는 검색 기록이나 최근 열람 기록이 아니다. **서버가 착용 성공을 확인한 아이템만** 기록한다. 검색어 입력, API 결과 수신, 결과 페이지 표시, 페이지 스크롤, 아이템 상세 열기, Recent 목록 진입, 착용 실패, Outfit 복원만으로는 기록하지 않는다.

### 4.2 레코드 및 정렬

- 아이템 식별은 `itemType + itemId`를 포함한 typed identity를 사용한다.
- 착용 요청이 서버에서 성공 확인된 후에만 Recent를 갱신한다.
- 같은 아이템을 다시 착용하면 중복 카드를 계속 쌓지 않고 최신 착용 시각으로 갱신한다.
- 가장 최근에 성공적으로 착용한 아이템이 먼저 표시된다.
- 최근 목록은 현재 세션에서만 유지한다. 플레이어가 나가면 초기화하며 DataStore에 저장하지 않는다.

### 4.3 오류 및 보존

- 서버 착용 실패는 Recent를 갱신하지 않는다.
- Outfit 복원은 Recent를 자동으로 채우거나 변경하지 않는다.
- 현재 아바타에서 이미 착용 중인 항목이더라도 이번 세션에서 성공한 착용 이벤트가 없으면 Recent에 자동으로 넣지 않는다.
- Recent는 게임 내 개인 저장 Favorites와 별도 기능이다.

### 4.4 수락 기준

- [ ] 검색어 입력, 결과 노출, 상세 열기만으로 기록되지 않는다.
- [ ] 서버가 착용 성공을 확인한 아이템만 기록된다.
- [ ] 같은 아이템 재착용은 중복 대신 최근 시각을 갱신한다.
- [ ] Asset/Bundle 구분을 포함한 typed identity를 사용한다.
- [ ] 최근 착용 성공 순으로 표시된다.
- [ ] 세션 종료 시 초기화되고 영구 저장되지 않는다.
## 5. Popular — Roblox 공식 인기 정렬

### 5.1 정책

Popular는 게임이 임의 점수를 계산한 목록이 아니다. Roblox 공식 카탈로그 API가 지원하는 정렬을 사용한다. 지원하지 않는 정렬이나 유형을 다른 정렬 결과로 대체한 뒤 인기순이라고 표시하지 않는다.

공식 문서 확인 지점:
- [CatalogSortType](https://create.roblox.com/docs/reference/engine/enums/CatalogSortType)
- [CatalogSearchParams](https://create.roblox.com/docs/reference/engine/datatypes/CatalogSearchParams)
- [Avatar Editor Service](https://create.roblox.com/docs/players/avatar-editor)

문서에 적힌 enum 이름만으로 현재 클라이언트에서 모든 조합이 지원된다고 단정하지 않는다. 현재 공식 문서와 실제 요청 결과를 구현 시점에 확인한다.

### 5.2 정렬 후보와 UI

검토 대상은 다음과 같다.

- `MostFavorited`: Roblox 카탈로그 즐겨찾기 수 기반 정렬
- `Bestselling`: 판매량 기반 정렬
- `RecentlyCreated`: 최근 생성 순(인기 정렬과는 의미가 다르므로 Popular에 포함할지 별도 결정)
- `Relevance`, 가격 오름차순/내림차순은 일반 검색 정렬이며 Popular의 대체값이 아니다.

MostFavorited와 Bestselling을 구분해 표시한다. 기본 Popular 정렬은 API와 유형별 지원을 검증한 뒤 확정하며, MostFavorited를 우선 후보로 검토한다. 집계 기간(`SortAggregation`)이 공식적으로 지원되는지와 허용 enum을 확인하기 전에는 기간 선택 UI를 약속하지 않는다. 지원하는 경우에만 실제 요청에 적용하고 화면 라벨에 정확히 반영한다.

### 5.3 카테고리/검색/페이지

각 지원 카테고리 및 하위 카테고리에서 검색 가능 여부, MostFavorited/Bestselling 지원 여부, 실제 적용 여부, 빈 결과와 미지원 구분을 조사한다. Popular 모드에서도 검색/필터/페이지 이동이 같은 공식 정렬 조건을 유지해야 한다. API 미지원 유형은 해당 인기 기준을 비활성화하거나 명시적으로 안내한다.

### 5.4 수락 기준

- [ ] 버튼이 실제 결과 목록을 갱신한다.
- [ ] 화면에 표시된 정렬 기준이 실제 API 요청과 일치한다.
- [ ] MostFavorited와 Bestselling이 혼동되지 않는다.
- [ ] 기간 옵션은 공식 지원이 확인된 경우에만 제공된다.
- [ ] 카테고리별 지원 여부가 확인된다.
- [ ] 미지원 유형을 임의의 인기순으로 표시하지 않는다.
- [ ] 검색/필터/페이지 이동이 정렬을 유지한다.
- [ ] API 오류, 빈 결과, 정렬 미지원이 구분된다.
- [ ] 게임 내 Favorites는 Roblox의 공식 MostFavorited 순위와 별개다.

## 6. Wearing — 실제 착용 중인 아이템

### 6.1 데이터 원칙

Wearing은 검색 결과에서 추정하지 않고 실제 현재 아바타에 적용된 상태를 기준으로 한다. 기존 서버의 착용 상태 조회/적용 경로를 조사하고 가능한 범위에서 이를 재사용한다. 내부 목록과 실제 HumanoidDescription/아바타 상태가 다를 수 있다면 상태를 동기화하는 정책을 먼저 정한다.

조사 대상 유형:
- 모자, 헤어, 얼굴, 목/어깨/앞/뒤/허리 액세서리
- 클래식 의상, 레이어드 의상/신발
- 얼굴/신체 부위 및 번들
- 애니메이션/애니메이션 번들, 이모트
- 프로젝트에서 실제 착용을 지원하는 기타 유형

이 목록은 모든 유형의 구현 완료를 의미하지 않는다. 실제 조회/표시/해제 지원 범위를 확인해 기록한다.

### 6.2 갱신 이벤트

다음 시점에 서버 확인 상태를 다시 읽거나, 확인된 결과를 기반으로 갱신한다.

- Wearing 모드 진입 및 카탈로그 재오픈
- 아이템 착용/해제 성공
- Outfit 복원 완료(부분 실패 포함 실제 적용 결과 기준)
- Avatar Editor 변경으로 실제 착용 상태가 변경된 경우
- 캐릭터 재생성 또는 리그 전환 후 실제 상태가 달라진 경우

착용 요청 실패 시 낙관적으로 목록을 바꾸지 않는다. 아이템 해제 시 실제로 제거된 경우에만 목록에서 사라지게 한다. Outfit 복원 및 Avatar Editor와 같은 상태 원본을 공유한다.

### 6.3 필터와 카드

검색/카테고리 필터는 Wearing 목록 안에서만 적용한다. 카드에는 기존 썸네일/이름/유형/착용 상태/게임 내 Favorites 별표를 표시하고, 지원되는 항목에만 해제 액션을 제공한다. Current Outfit 가로 strip과 Wearing 그리드는 서로 다른 표현이지만 같은 착용 상태를 반영한다.

### 6.4 수락 기준

- [ ] 실제 착용 상태가 카드 영역에 표시된다.
- [ ] 검색 결과가 데이터 출처가 아니다.
- [ ] 착용/해제 후 목록이 실제 결과와 일치한다.
- [ ] Outfit 복원과 Avatar Editor 변경 후 동기화된다.
- [ ] 검색/필터는 착용 목록 안에서만 작동한다.
- [ ] 미착용/빈 상태/조회 실패가 구분된다.
- [ ] 지원하지 않는 유형을 착용 중인 것으로 꾸며 표시하지 않는다.

## 7. Favorites — 게임 내 개인 즐겨찾기

### 7.1 의미 및 토글

Favorites는 사용자가 이 게임 안에서 직접 관리하는 사용자별 개인 목록이다. Roblox 계정의 공식 즐겨찾기 상태를 변경하는 기능이 아니다. 카드 더블클릭으로 토글한다.

- 즐겨찾기 아님 + 동일 카드 더블클릭 → 즐겨찾기 추가
- 이미 즐겨찾기 + 동일 카드 더블클릭 → 즐겨찾기 해제
- 즐겨찾기 카드 왼쪽 상단에 노란 별
- Favorites 버튼 → 즐겨찾기한 아이템만 표시
- Favorites 목록 안에서도 더블클릭으로 해제 가능

더블클릭은 자동 착용/해제 동작이 아니다. 기존 단일 클릭이 선택/미리보기/착용 중 무엇을 수행하는지 먼저 조사한다. 단일 클릭이 보존되어야 한다면 더블클릭 판정 전 실행을 지연하는 방식 등으로 중복 실행을 막는다. 동일 아이템의 연속 클릭만 더블클릭으로 판정한다. 서로 다른 카드 클릭은 토글로 취급하지 않는다.

### 7.2 식별 및 저장

즐겨찾기 레코드는 아이템 ID와 Asset/Bundle 및 유형 구분을 포함한다. 이름/썸네일 URL만으로 식별하지 않는다. 같은 아이템 중복 등록을 방지한다. 최근 변경 시각 등은 필요 시 저장한다.

현재 서버 저장 구조를 조사하고, 가능한 경우 사용자별 서버 검증 영구 저장을 사용한다. 중복 요청, 빠른 토글, 요청 제한, 크기 제한, 저장 실패, 불러오기 실패를 처리한다. 클라이언트 임시 테이블은 영구 저장이 아니다. 영구 저장 구조가 없다면 먼저 한계와 설계를 보고한다.

### 7.3 카드 표시 및 목록

노란 별은 실제 저장 상태에 연결하고, 어떤 모드에서 카드가 렌더링되어도 동일하게 표시한다. 별은 썸네일/텍스트/액션을 가리지 않도록 PC/모바일에서 배치한다. Favorites 모드에서는 즐겨찾기 데이터만 표시하며, 검색/카테고리 필터는 그 목록 안에서만 적용한다. 기본 정렬은 최근 즐겨찾기 변경 순을 후보로 삼되 기존 정렬 UX와 충돌 여부를 조사하고 확정한다.

해제 후 별을 제거하고 Favorites 목록에서만 카드를 제거한다. 해당 아이템을 카탈로그에서 삭제하거나 착용 상태를 변경하지 않는다. 저장 성공이 확인되기 전에 최종 상태를 성공으로 확정하지 않는다. 빠른 연속 입력과 저장 실패에서 최종 상태가 일관되게 유지되도록 요청을 직렬화하거나 병합한다.

### 7.4 수락 기준

- [ ] 더블클릭 추가/해제와 노란 별이 실제 저장 상태와 일치한다.
- [ ] Favorites 버튼은 즐겨찾기 아이템만 보여 준다.
- [ ] Favorites 내부에서도 해제할 수 있고 해제 후 해당 목록에서 사라진다.
- [ ] 즐겨찾기 변경이 착용/해제 상태에 영향을 주지 않는다.
- [ ] 단일 클릭의 기존 기능이 보존된다.
- [ ] 더블클릭이 착용/해제를 중복 실행하지 않는다.
- [ ] 중복 레코드 및 빠른 연속 요청을 처리한다.
- [ ] 모든 모드의 별표 상태가 일관된다.
- [ ] 저장/조회 실패가 성공/빈 목록으로 위장되지 않는다.
- [ ] 재접속 후 보존 여부를 실제 검증한다.

## 8. 모드 간 불변 조건

- Recent는 현재 세션에서 서버가 성공 확인한 착용 이벤트만 기록한다. 검색/열람이나 Outfit 복원은 Recent를 변경하지 않는다.
- Outfit 복원은 Recent 열람 기록이나 Favorites를 자동으로 변경하지 않는다.
- Outfit 복원 후 Wearing은 실제 복원 결과를 반영하고, 즐겨찾기 별표는 기존 Favorites 저장 상태를 따른다.
- Avatar Editor에서 실제 착용 상태가 바뀌면 Wearing을 갱신한다. 위치/크기/레이어 조정만으로 Favorites/Recent를 변경하지 않는다.
- Popular의 Roblox MostFavorited는 게임 내 개인 Favorites와 별개다. 개인 즐겨찾기를 바꿔도 Roblox 인기 순위가 바뀌었다고 표시하지 않는다.
- Wearing에서 해제해도 Favorites는 유지된다. Favorites에서 해제해도 착용 상태는 유지된다.
- Current Outfit strip과 Wearing 그리드는 동일한 권위 있는 착용 상태를 사용한다.

## 9. 성능, 비동기 및 오류

- 결과 카드 수를 무제한으로 생성하지 않고 기존 페이지네이션/카드 재사용 구조를 활용한다.
- Recent/Favorites 목록은 설정 가능한 최대 크기로 제한한다.
- 오래된 요청 응답이 현재 모드/검색/필터 결과를 덮어쓰지 않도록 한다.
- 중복 착용·해제·저장 요청을 방지한다.
- 로딩 중 관련 액션을 잠시 비활성화할 수 있지만 UI가 영구 로딩 상태에 빠지지 않게 한다.
- 썸네일 오류, 아이템 삭제/미조회, API 오류, 저장 오류, 정상 빈 목록을 구분한다.
- 로그는 원인 분석에 필요한 범위로 남기고 프레임마다 반복 출력하지 않는다.

## 10. 통합 테스트 체크리스트

### 공통
- [ ] 네 버튼이 단일 선택 상태를 유지하고 카드 영역을 실제로 갱신한다.
- [ ] 검색/카테고리/필터가 현재 모드의 목록 범위를 벗어나지 않는다.
- [ ] 모드 전환 중 늦게 온 응답이 새 결과를 덮어쓰지 않는다.
- [ ] 카드의 착용 상태와 노란 별이 실제 데이터와 일치한다.
- [ ] PC 및 모바일에서 컨트롤/카드가 겹치지 않는다.

### Recent
- [ ] 검색어/결과 노출만으로 기록되지 않는다.
- [ ] 열람 기록 중복 제거, 최근 순 정렬, 개수 제한, 빈 상태 및 오류가 작동한다.

### Popular
- [ ] 공식 지원 정렬을 사용하고 실제 요청과 UI 라벨이 일치한다.
- [ ] 유형별 미지원, 기간, 빈 결과 및 API 오류를 구분한다.

### Wearing
- [ ] 서버 확인된 실제 착용 상태가 표시된다.
- [ ] 착용/해제, Outfit 복원, Avatar Editor 변경, 재오픈 후 동기화된다.

### Favorites
- [ ] 더블클릭 추가/해제, 노란 별, Favorites 목록 필터가 동작한다.
- [ ] 단일 클릭 기존 기능이 유지되고 더블클릭에 의한 착용 중복 실행이 없다.
- [ ] 저장 실패/중복 요청/재접속 보존이 검증된다.

### 보고 원칙
- [ ] 각 항목을 코드 구현, 정적 검토, Studio 검증으로 구분한다.
- [ ] Studio에서 직접 수행하지 않은 항목은 미검증으로 표시한다.

## 11. 구현 완료 보고서 형식

작업 종료 시 다음을 보고한다.

1. 변경 파일 및 각 파일의 역할
2. 커밋 해시와 브랜치
3. Recent 기록 이벤트/식별/보존 방식
4. Popular의 공식 정렬 enum 및 유형별 지원 제한
5. Wearing의 실제 데이터 출처와 갱신 이벤트
6. Favorites 식별/저장 구조, 더블클릭 판정, 단일 클릭 충돌 방지
7. 검색/필터/정렬/페이지 이동 연동 결과
8. Outfit/Avatar Editor와 상태 동기화 결과
9. 수행한 테스트 및 결과
10. Studio에서 검증하지 못한 항목과 검증 절차

코드가 작성되었다는 이유만으로 완료 처리하지 않는다.


## Decisions locked — 2026-10-18

### Navigation and data source
- Visible modes: Recent / Popular / Wearing / Favorites / Wardrobe. Recommended is removed. Wardrobe is a separate saved-Outfit screen, not a fifth catalog query mode.
- Current Outfit is a horizontal list of current worn items, derived from the same server-confirmed snapshot as Wearing.
- Recent is session-only and records only a successfully worn item. Search input, result exposure, opening details, and saved Outfit restore do not add Recent entries.
- Popular uses CatalogSortType.MostFavorited only. Set CatalogSortAggregation.PastMonth if accepted by the current API runtime; if the request fails or results are invalid, log the error and retry explicitly with AllTime. Do not offer Bestselling or RecentlyCreated as Popular modes.
- Search/category/price/creator/off-sale filters apply only to global catalog search. Wearing filters the actual worn snapshot; Favorites filters the user's own Favorites records. Neither may fall back to all catalog results.
- Wear/remove are separate explicit card buttons. Double-click/double-tap on the item image only toggles in-game Favorites and must never issue wear/remove.

### Double-click timing and mobile interaction
- Double-click threshold: 0.5 seconds between the first and second image activation. A second activation after 0.5 seconds is a separate single activation.
- To avoid single-click side effects firing before the double-click is known, the first image activation is held for up to 0.5 seconds before its single-click action is committed. If a second activation arrives inside the window, cancel the pending single action and toggle Favorite once. Image single-click must not itself wear/remove.
- A small star icon can still be used as a state indicator rather than a clickable control, placed over a low-information corner with a translucent background. It must not be the sole interaction target; the image's double-click/double-tap is the action. The Wear/Worn button remains a separate, sufficiently large touch target.
- Test double-click/double-tap, two clicks separated by >0.5 seconds, touch latency, accessibility, and item-card selection. If a future single-click image action is introduced, it must use the same delayed arbitration and must never duplicate a Favorite action.

### Shared state and operations
- Contract: [AVATAR_STATE_AND_PERSISTENCE.md](../05_TECH/AVATAR_STATE_AND_PERSISTENCE.md). Data persistence: [DATA.md](../05_TECH/DATA.md). API evidence: [API.md](../05_TECH/API.md).
- Current Avatar is server-confirmed from the applied HumanoidDescription. Client currentWornItems/wornOrder are display caches only.
- While a wear/remove/Apply/restore action is running, show progress if possible and disable related buttons. The first request wins; subsequent requests are not queued and should be rejected with a message.
- Wearing is partial implementation until all supported item types and state synchronization are verified. Item identity is itemType + itemId, with type-specific metadata; do not assume Bundle ID is directly wearable.
- Avatar Editor changes are draft values. Apply commits; Cancel/close discards. If draft changes exist when closing, prompt Apply/Cancel. Reset affects only the selected item. Respawn or Outfit restore discards unapplied draft values.
- SavedOutfit is game-only. Store a versioned restorable appearance snapshot, not just item IDs. The Outfit preview is rendered from saved data; do not assume a captured screenshot can be persisted.
- Saved Outfit cap starts at 50 per user and must be configurable. Favorites and Outfits persist across sessions; Recent does not. Actual DataStore integration and rejoin persistence are not yet verified.

### Search/filter support matrix
| Mode | Search text | Catalog API category/type/sort/price filters | Data source |
|---|---|---|---|
| Global catalog | Yes | Yes, only when supported by CatalogSearchParams and current runtime | Roblox catalog API |
| Recent | No global-catalog fallback | No; optionally filter only the session Recent records if product UI later defines it | Session list of successfully worn typed item refs |
| Popular | Query is API-driven, not local fallback | API-supported category/type filters; MostFavorited + PastMonth preferred | Roblox catalog API |
| Wearing | No global catalog search | No global-catalog filters | Server-confirmed applied avatar snapshot |
| Favorites | No global catalog search | No global-catalog filters | Persistent user Favorites |
| Wardrobe | Outfit name/list operations only | Not catalog filters | Persistent SavedOutfits |

API support and Studio behavior must remain separately labeled. The acceptance checklist in this file is not complete until Studio results are recorded in WORKLOG.md.
