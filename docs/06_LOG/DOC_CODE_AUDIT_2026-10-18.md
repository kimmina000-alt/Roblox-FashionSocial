# Documentation and Source Audit — 2026-10-18

브랜치: `catalog-ui-redesign`  
범위: 저장소 트리, 주요 프로젝트/시스템/공간/기술/로그 문서, 실제 `src/` 카탈로그 소스, 격리된 `workbench/` UI 작업본  
결과 상태: **정적 소스/문서 조사. Roblox Studio 실행 테스트는 이 감사에서 수행하지 않음.**

## 1. 확인한 저장소 구조

- 실행 대상 게임 소스: `src/ReplicatedStorage/FashionGame/Shared/CatalogConfig.lua`, `src/ServerScriptService/FashionGame/ServerMain.server.lua`, `src/ServerScriptService/FashionGame/Services/AvatarService.lua`, `src/StarterPlayer/StarterPlayerScripts/FashionGame/CatalogController.client.lua`.
- 별도 Rojo 프로젝트 파일: `catalog-ui-redesign.project.json`.
- 기본 프로젝트 파일: `default.project.json`. 이 감사에서는 수정하지 않는다.
- 격리된 UI 작업본: `workbench/catalog-ui-redesign/working-copy/CatalogController.client.lua`; 기준본 `workbench/catalog-ui-redesign/baseline/CatalogController.client.lua`는 보존 대상이다. `workbench/`는 `src/` 밖이므로 현재 실행 소스와 동일하다고 볼 수 없다.
- 문서는 `GAME_MASTER.md`, `docs/00_PROJECT/`, `docs/01_SYSTEMS/`, `docs/02_WORLDS/`, `docs/04_ART/`, `docs/05_TECH/`, `docs/06_LOG/`로 나뉜다.

## 2. 실제 소스에서 확인한 구현 상태

### Present in source (not equivalent to complete/verified)

- Client catalog source contains search keyword, category/subcategory, sorting, price/off-sale filters, page loading, item cards, wear/remove calls and an avatar preview using a ViewportFrame.
- `ServerMain.server.lua` routes `Wear`, `Remove` and `GetCurrent` actions to `AvatarService`. Its `CatalogSearch` RemoteFunction returns `false, "Catalog search runs on the client."`; search is currently client-side through `AvatarEditorService`.
- `AvatarService.lua` contains paths for classic clothing, rigid/layered accessories, animation slots, emotes and makeup. It applies a HumanoidDescription and calls `GetAppliedDescription()` after applying, but logs the resulting accessory list rather than comparing the full requested change against the applied state.
- `GetCurrentItems()` reconstructs classic clothing, makeup, emotes, animation properties and accessories from the applied description.
- The client has a local `actionBusy` guard and refreshes a current-worn list from `GetCurrent`.

### Explicitly placeholder or incomplete in source

- Avatar Editor button displays a status message; it is not a working editor.
- Wardrobe button displays a status message; save/load is not implemented in the inspected source.
- Recent, Popular and Favorites buttons log that those views are placeholders. Their complete data/filter/persistence behavior is not implemented in the active source.
- The client keys `currentWornItems` and `wornOrder` by numeric asset ID only. It does not preserve a complete typed Asset/Bundle identity in these UI structures.
- `TryOnItem` RemoteFunction passes an action plus numeric `assetId`; the server resolves it with `GetItemDetailsAsync(assetId, Enum.AvatarItemType.Asset)`. There is no typed Bundle request path in this interface.
- Remove also accepts only numeric ID, so the request contract does not encode type-specific identity.
- The client contains no observed DataStore-backed Favorites or SavedOutfits implementation. The existing 50-outfit limit, versioned records, migration and partial restore are design requirements, not implemented behavior in these inspected files.
- The inspected `src/` tree contains no dedicated implementation modules for Club dances, Photo Spots, beach/aquarium swimming, cafe seating, playground rides, Backstage, Runway, or Housing. Their documentation describes planned concepts, not implemented world features.
- Avatar state changes are guarded by a client-local busy flag, but no per-player server-side operation lock/action gate was found in `ServerMain.server.lua` or `AvatarService.lua`.

## 3. Confirmed documentation/code gaps and risks

1. **Typed identity mismatch:** design documents require typed item identity; active wear/remove/current UI code uses numeric asset IDs and explicitly assumes Asset for detail lookup. Bundle and same-ID cross-domain handling are not implemented by the current request contract.
2. **Server concurrency mismatch:** documents specify first-request-wins/action gating; the inspected implementation relies on a client-local busy flag. Server-side serialization/rejection remains unimplemented.
3. **Applied-state verification gap:** the service reads the post-apply description but does not verify that the specific requested item/property was actually applied before returning success.
4. **Persistence gap:** Save Data/Data schema requirements are extensive, but active source has no inspected DataStore implementation. Wardrobe remains placeholder.
5. **Discovery navigation gap:** Recent/Popular/Favorites are placeholders; Wearing has a partial client list based on asset IDs. Do not report the entire quick-navigation feature as complete.
6. **Off-sale filter precedence:** `searchCatalog()` assigns `params.IncludeOffSale = currentIncludeOffSale` and later overwrites it with `currentCategoryIncludeOffSale`. This conflicts with the documented single-source-of-truth policy and existing issue `ISSUE-CATALOG-003`.
7. **Studio verification gap:** source presence and historical user checks on earlier revisions do not verify the current branch’s complete behavior or the isolated working copy.
8. **World scope gap:** per-space files `BEACH.md`, `CAFE.md`, `CITY_STREET.md`, `CLUB_AREA.md`, `PARK.md` and `HOUSING_DISTRICT.md` were originally brief summaries. The master concepts document carried more detailed proposals, creating a risk that local edits would not have a single clear home.
9. **Order ambiguity:** `ROADMAP.md` prioritizes Catalog/SavedOutfits before Club/Photo, while the world-concepts implementation list began with whole-map blockout. These are compatible only if low-cost blockout is explicitly distinguished from full space production and detailed art.
10. **Duplicate authority:** world concepts, Main Social, per-space files, and `WORLD_STYLE.md` repeat art direction and build-order statements. The updated structure assigns whole-game sequence to `DEVELOPMENT_ORDER.md`, spatial detail to per-space files, and undecided aesthetic exploration to `WORLD_DESIGN_EXPLORATION.md`.

## 4. Priority order for fixing the real implementation gaps

### P0 — Required before calling the catalog loop complete
- [ ] Resolve `IncludeOffSale` precedence and add regression checks.
- [ ] Add server-side action gating/serialization for wear/remove and any future restore/apply operation.
- [ ] Change the request contract to validate item type and identity; define explicit Bundle handling or visibly disable Bundle wear.
- [ ] Verify the requested change against the actual post-apply description and return a confirmed snapshot.
- [ ] Ensure exact-item remove and all UI views derive from the same typed, confirmed snapshot.

### P1 — Core persistence and reliable UX
- [ ] Implement DataStore-backed SavedOutfits and Favorites; do not treat schema documents as implementation.
- [ ] Implement versioned snapshot capture, size validation, migrations, bounded retry and ambiguous-write verification.
- [ ] Implement Wardrobe save/load and per-item partial restore with failure feedback.
- [ ] Implement or explicitly remove/defer Recent/Popular/Favorites UI controls until they have real behavior.
- [ ] Verify mobile and desktop layouts against the active `src/` code and the workbench copy separately.

### P2 — World gameplay
- [ ] Create a minimal graybox and validate traversal before detailed art.
- [ ] Implement Club dance start/stop and multiplayer visibility.
- [ ] Implement one representative Photo Spot.
- [ ] Add one simple interaction per selected additional space only after its movement/camera requirements are clear.
- [ ] Keep Runway/Housing deferred unless explicitly reprioritized.

## 5. Audit limitations

- This was a static GitHub source/document inspection. No Roblox Studio session, published multi-client test, live DataStore test, or runtime API test was performed.
- A feature may work in a Studio revision the user tested previously; that history does not prove the currently inspected source and workbench are identical.
- No source code was changed by this audit document itself. The actionable documentation updates are tracked in `WORKLOG.md`, `TODO.md`, `ISSUES.md`, and `ROADMAP.md`.
