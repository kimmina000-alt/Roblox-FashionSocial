# API Mapping

Catalog search: AvatarEditorService
Avatar editing: AvatarEditorService + HumanoidDescription
Current description: Humanoid:GetAppliedDescription()
Appearance application: Humanoid/HumanoidDescription
Purchase: MarketplaceService / applicable Avatar purchase flow
Teleport: TeleportService:TeleportAsync()
Persistent: DataStoreService
Temporary session: MemoryStoreService
Cross-server messaging: MessagingService
Reserved server: TeleportService:ReserveServerAsync()
Photo: Roblox Camera APIs + custom system
Housing/Building/Runway: custom systems

구현 시 현재 Creator Hub 문서에서 정확한 메서드/제약을 재검증한다.


## Verified Roblox API research — Catalog / Avatar / persistence

기준일: 2026-10-18. 아래는 Creator Hub 문서에서 확인한 API 가능 범위다. **공식 API 지원 ≠ 프로젝트 연결 완료 ≠ Roblox Studio에서 동작 검증 완료**이며, 현재 Studio 검증 상태는 별도 열에 기록한다.

| 기능 | 공식 API 근거 | 프로젝트 적용 가능 여부 | 실제 적용 검증 |
|---|---|---|---|
| Popular 정렬 | [CatalogSearchParams](https://create.roblox.com/docs/reference/engine/datatypes/CatalogSearchParams)의 SortType / SortAggregation, [CatalogSortType](https://create.roblox.com/docs/reference/engine/enums/CatalogSortType), [CatalogSortAggregation](https://create.roblox.com/docs/reference/engine/enums/CatalogSortAggregation) | 가능. Popular는 MostFavorited만 사용. SortAggregation=PastMonth를 지정할 수 있음. 해당 aggregation은 MostFavorited와 Bestselling에만 적용됨. 기본은 AllTime. | 미검증: 실제 검색 결과와 기간 적용 여부를 Studio에서 확인해야 함 |
| Catalog search / filters | [AvatarEditorService](https://create.roblox.com/docs/reference/engine/classes/AvatarEditorService), [CatalogSearchParams](https://create.roblox.com/docs/reference/engine/datatypes/CatalogSearchParams) | 검색어, category, asset/bundle type, price, off-sale 등은 각 파라미터가 지원하는 범위 내에서 사용. CreatorName/SalesTypeFilter 등은 현재 클라이언트 런타임에서 설정과 결과를 별도 확인. 검색 모드에서만 검색 필터 적용. Wearing/Favorites는 검색 API가 아닌 자체 목록 필터링. | 미검증: 필터별 Studio 회귀 테스트 필요 |
| 실제 적용 외형 조회 | [Humanoid:GetAppliedDescription()](https://create.roblox.com/docs/reference/engine/classes/Humanoid) | 가능. 현재 Humanoid에 적용된 외형을 나타내는 HumanoidDescription 복사본. 서버 확인 후 Wearing/Current Outfit/카드 상태를 재구성하는 기준으로 사용. | 현재 AvatarService에서 적용 직후 일부 검증 코드 확인; 전체 snapshot 계약은 미구현/미검증 |
| 액세서리 목록 및 레이어 | [HumanoidDescription](https://create.roblox.com/docs/reference/engine/classes/HumanoidDescription) GetAccessories(true)/SetAccessories(..., true) | 지원 가능한 액세서리의 AssetId, AccessoryType, IsLayered, Order 등을 조회/적용 가능. Rigid와 layered를 동일하게 취급하지 않음. | 미검증: 모든 catalog category와 duplicate/ordering 사례를 Studio에서 테스트해야 함 |
| Rigid accessory transform | [AccessoryDescription](https://create.roblox.com/docs/reference/engine/classes/AccessoryDescription) | Position/Rotation/Scale은 rigid accessory에 적용. Position/Rotation/Scale이 모든 layered clothing 또는 makeup에 적용된다고 가정하면 안 됨. | 미검증 |
| Body / scale / color / animations / classic clothing | [HumanoidDescription](https://create.roblox.com/docs/reference/engine/classes/HumanoidDescription) | HumanoidDescription에 표현되는 값은 versioned appearance snapshot에 저장할 수 있음. 각 property의 지원/rig 제약은 개별 검증. | 미검증 |
| Bundle | [AvatarEditorService](https://create.roblox.com/docs/reference/engine/classes/AvatarEditorService) 및 CatalogSearchParams | Bundle은 검색 결과 유형으로 구분해야 함. Bundle ID를 AssetId로 넘겨 개별 착용/해제할 수 있다고 간주하지 않는다. 필요한 경우 bundle 구성 요소를 조사하고 실제 적용 가능한 Asset 항목으로 변환. | 현재 프로젝트의 Bundle wear/remove 완전 지원은 확인되지 않음 |
| Makeup | [HumanoidDescription](https://create.roblox.com/docs/reference/engine/classes/HumanoidDescription)과 프로젝트의 MakeupDescription 경로 | 프로젝트 AvatarService는 MakeupDescription을 별도 처리함. 일반 AccessoryDescription transform 규칙을 makeup에 그대로 적용하지 말고 MakeupDescription 속성/적용 결과를 별도 검증. | 현재 소스에 일부 makeup handler 있음; 모든 makeup 유형의 적용/제거/저장 복원은 미검증 |
| Persistent user data | [DataStoreService](https://create.roblox.com/docs/reference/engine/classes/DataStoreService), [Data store limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits) | Favorites와 Saved Outfits는 서버 DataStore에 사용자별로 저장. Recent는 세션 한정이라 영구 저장하지 않음. UpdateAsync 기반 단일 사용자 record로 버전과 동시 업데이트를 관리. | 해당 feature 저장/불러오기 구현 및 Studio 재접속 테스트는 미완료 |
| Respawn / character lifecycle | [Player](https://create.roblox.com/docs/reference/engine/classes/Player), [Humanoid](https://create.roblox.com/docs/reference/engine/classes/Humanoid) | CharacterAdded/CharacterAppearanceLoaded 및 새 Humanoid의 applied description을 이용해 캐릭터가 준비된 뒤 snapshot을 다시 구성. 현재 제품 정책은 respawn 시 기본 Roblox avatar로 시작하며 임시 착장을 자동 복구하지 않음. | 미검증 |

### Popular time window decision

Roblox의 공식 CatalogSortAggregation enum에는 PastMonth 값이 있다. 따라서 MostFavorited + PastMonth 조합을 코드에서 지정하는 설계가 가능하며, 별도의 직접 집계나 복잡한 기간 계산은 필요하지 않다. 다만 API enum이 존재한다는 사실만으로 모든 카테고리에서 동일한 품질/결과가 보장되는 것은 아니므로 Studio에서 실제 검색 요청과 결과를 검증한다. 사용자 요청에 따라 기본 Popular는 MostFavorited만 사용하고 집계 기간은 PastMonth를 우선 적용한다. 런타임에서 거부되거나 결과가 유효하지 않으면 오류를 기록하고 AllTime으로 명시적 fallback한다. Bestselling/RecentlyCreated 등 다른 sort는 Popular UI에 노출하지 않는다.

### DataStore record size clarification

“크기 제한”은 저장 가능한 Outfit 개수와 별개로, 한 번에 DataStore에 쓰는 직렬화된 값의 byte 크기 및 요청 처리량을 뜻한다. 초기 제품 한도는 사용자당 Saved Outfit 20개이며, record에는 썸네일 이미지 파일 자체가 아니라 렌더링에 필요한 appearance data만 저장한다. API/서비스의 플랫폼 한도에 가까워질 때까지 저장하지 말고, 앱 차원에서 훨씬 작은 안전 상한을 두고 serialize 결과의 byte 크기를 검사한다. 실제 상한값은 schema가 확정되고 측정 가능한 샘플 데이터가 생긴 뒤 결정한다. 저장 실패 시 기존 저장 데이터를 덮어쓰지 않고 오류 메시지를 표시한다.

Official sources:
- https://create.roblox.com/docs/reference/engine/enums/CatalogSortType
- https://create.roblox.com/docs/reference/engine/enums/CatalogSortAggregation
- https://create.roblox.com/docs/reference/engine/datatypes/CatalogSearchParams
- https://create.roblox.com/docs/reference/engine/classes/AvatarEditorService
- https://create.roblox.com/docs/reference/engine/classes/Humanoid
- https://create.roblox.com/docs/reference/engine/classes/HumanoidDescription
- https://create.roblox.com/docs/reference/engine/classes/AccessoryDescription
- https://create.roblox.com/docs/reference/engine/classes/DataStoreService
- https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits
- https://create.roblox.com/docs/reference/engine/classes/Player
