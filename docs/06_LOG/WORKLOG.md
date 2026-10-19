# Work Log

이 문서는 날짜별 작업 내용, 실제 확인 결과, 미완료 항목을 기록한다.  
코드 변경 이력은 `CHANGELOG.md`, 오류 추적은 `ISSUES.md`, 남은 작업은 `TODO.md`와 함께 관리한다.

---

## 2026-10-15 — Catalog / Avatar 작업

### 진행한 작업
- `feature/catalog-api-expansion` 브랜치에서 카탈로그 검색 및 아바타 아이템 표시 동작을 점검했다.
- 애니메이션 팩(Animations Bundle) 검색 결과가 표시되도록 관련 동작을 정리했다.
- 번들 썸네일 주소를 `BundleThumbnail` 형식으로 수정했다.
- 개별 애니메이션 카테고리 검색 결과가 없을 때 애니메이션 팩을 대신 표시하던 fallback을 제거했다. 개별 애니메이션과 애니메이션 팩을 서로 다른 아이템 유형으로 정확히 표시하기 위한 변경이다.
- 카탈로그/아바타 시스템 문서와 오류·할 일 기록을 정리했다.
- 메이크업 아이템 착용 실패, 개별 애니메이션 검색 결과, UIBlox 경고를 각각 별도 확인 항목으로 구분했다.

### 테스트 및 확인 결과
- [x] 대기, 걷기, 달리기, 점프, 낙하, 오르기 등 애니메이션 카테고리 선택 동작 확인.
- [x] 애니메이션 팩 검색 결과와 썸네일 표시 정상 확인.
- [x] 개별 애니메이션 카테고리에서 애니메이션 팩을 개별 애니메이션인 것처럼 섞어 보여 주지 않도록 처리.
- [ ] 메이크업 아이템 착용/해제는 서버의 타입 처리 경로를 확인하고 Studio에서 재검증해야 한다.
- [ ] 개별 애니메이션 유형의 검색 결과가 0개인 동작은 현재 검색 API의 반환 특성과 구분해, 사용자에게 혼동이 없도록 안내/카테고리 정책을 확정해야 한다.
- [ ] UIBlox `FoundationProvider not found` 경고는 실제 게임 UI에 문제가 있는 경우에만 추가 조사한다.

### 다음 작업
1. 메이크업 타입별 착용 및 제거 경로를 점검하고 Studio에서 검증한다.
2. 개별 애니메이션 카테고리가 지원되지 않거나 결과가 없는 경우의 UX를 결정한다. 애니메이션 팩은 별도 카테고리로 유지한다.
3. 착용 → 동일 아이템 다시 클릭 → 제거 → 카드/아바타 상태 동기화의 전체 흐름을 회귀 테스트한다.
4. 사용자가 제공한 두 레퍼런스 영상을 모두 확인한 뒤, 공통 UX와 차이점을 비교해 기획서 수정안을 확정한다. 두 영상의 비교는 두 번째 영상 수신 후 진행한다.

### 관련 기록
- `docs/06_LOG/CHANGELOG.md`
- `docs/06_LOG/ISSUES.md`
- `docs/06_LOG/TODO.md`
- `docs/01_SYSTEMS/CATALOG.md`

## 2026-10-15 — Catalog panel layout, first coding pass

### Implemented in code
- Updated `CatalogController.client.lua` so the catalog panel docks to the right at roughly 34% viewport width on desktop, with a maximum width to avoid covering the whole world.
- Added an expand/collapse-width button for desktop (default narrow panel; expanded panel around 72% width).
- Added viewport-responsive layout updates for search, category/sort controls, price/off-sale controls, results grid, status, and pagination.
- On narrow screens (viewport width below 720 px), the catalog uses the full available screen instead of retaining desktop proportions.
- Kept existing catalog search, category selection, filters, wear/remove handlers, and pagination logic unchanged.

### Validation status
- [ ] Open in Roblox Studio and confirm desktop right-side width and that the avatar/world remain visible.
- [ ] Test expand/collapse and resize the Studio/game viewport while the catalog is open.
- [ ] Test a narrow/mobile emulator viewport and confirm no controls are clipped or overlapping.
- [ ] Regression-test search, category menu, sort menu, price/off-sale filters, pagination, wear, and remove.
- Note: code was committed through the GitHub file API; Roblox Studio runtime testing has not been performed here.


## 2026-10-15 — Catalog sizing revision and current-worn-items plan

### User validation of previous pass
- [x] Desktop catalog appeared on the right while the avatar/world remained visible.
- [x] Expand/collapse worked.
- [x] Resizing the Studio window updated the layout.
- [x] Mobile emulator showed search, filters, and item cards without clipping.
- [x] Search, category, sort, price filter, and pagination still worked.
- [x] Wear and remove still worked.

### Implemented in code
- Compact desktop panel width reduced to about two-thirds of its prior default width; panel height is about two-thirds of viewport height and remains right-docked.
- Compact mobile view now floats at the bottom-right at about half viewport width × half viewport height (approximately one-quarter of screen area); expanding restores the full-screen mobile browsing view.
- Price/off-sale controls are hidden only in compact mobile mode and return when expanded.
- Item card grid and card contents reduced by about 20% to retain readable names and usable tap targets. A literal one-fifth-size card would make controls too small to use, so the change uses a 20% reduction instead.
- Added a dedicated current-worn-items panel/window to the planning documents.

### Validation status
- [ ] Run the six existing checks again after this sizing revision; previous success does not establish that this new layout has passed Studio validation.


## 2026-10-15 — User validation and compact toolbar / avatar preview revision

### Confirmed by user
- [x] The previous catalog sizing revision works without issues.
- [x] PC right-side placement, expand/collapse, viewport resizing, mobile controls, search/category/sort/price filters/pagination, and wear/remove all worked in the prior revision.

### Code changes committed for next review
- Compact catalog places search, category, and sort controls in a single toolbar row; the separate Search button is hidden only in compact mode, and Enter submits the query.
- Results begin much higher in compact mode so item cards are visible instead of being pushed below the fold.
- Card dimensions now vary by viewport/state: compact mobile 96×144, compact desktop 120×174, expanded 132×192. Card contents are scaled separately.
- Expanding the catalog now uses full-screen layout on PC and mobile. A dedicated current-avatar preview window uses a ViewportFrame clone of the player's current character, refreshes after wear/remove and character respawn, and can be closed independently.
- In expanded PC mode, the item grid is shifted right to reserve a left preview column. In expanded mobile mode, the preview sits above the item grid.

### Validation status for this revision
- [ ] Re-open catalog and confirm cards appear in compact PC/mobile windows.
- [ ] Confirm search, category, and sort fit in the compact toolbar and Enter searches correctly.
- [ ] Confirm item card content is legible at mobile/PC compact sizes.
- [ ] Expand on PC/mobile and confirm the avatar preview shows the current outfit while item cards remain visible.
- [ ] Re-test wear/remove and verify the preview refreshes after each confirmed change.
- This new revision has been committed to the feature branch but has not yet been Studio-tested.


## 2026-10-15 — Compact card visibility and expanded avatar preview follow-up

### User feedback
- The prior revision's six functional/layout checks were reported as working.
- In the current compact catalog, the item-card area was not visible.
- Search, category (ALL), and sort should share one toolbar row so results can begin immediately below it.
- Compact item cards should be smaller; card dimensions are separate for compact mobile and compact PC.
- Expanded mobile must show the avatar's current outfit in a separate preview window. Expanded PC should use the same full-screen catalog + current-avatar preview pattern.

### Code changes committed for review
- Compact results now begin at y=82 with the result viewport extending to the pagination area; compact status and secondary filters are hidden to free vertical space. Bundle back navigation remains available when bundle contents are open.
- Compact mobile cards are 76×114; compact PC cards are 100×146; expanded mobile cards are 112×164; expanded PC cards are 132×192. This confirms card sizing is device/state-specific, not one shared size.
- Expanded mode remains full-screen on both PC and mobile. Mobile controls are placed above the preview; the preview is positioned below the controls and the results grid starts below the preview. PC reserves a left-side preview column.
- The preview remains a ViewportFrame clone of the current character and refreshes after confirmed wear/remove and character respawn.

### Validation status
- [ ] Studio-test compact PC/mobile to verify cards are visible and usable.
- [ ] Studio-test expanded PC/mobile to verify the current-avatar preview is visible and does not cover controls or item cards.
- [ ] Re-test search, category, sort, price/off-sale filters, pagination, wear and remove after these layout changes.


## 2026-10-16 — Expanded catalog layout foundation

### User-approved layout
- Full-screen expanded catalog with a fixed left avatar preview column at roughly 25% width and right catalog at roughly 75%.
- Avatar Editor and Wardrobe icon entry points at the top-left of preview; Current Outfit below preview as a horizontally scrollable row, newest worn first.
- Right side: navigation strip (Recent, Popular, Recommended, Favorites, Currently Worn), fixed Search and Filter controls, second quick-category row, then independently scrolling results.
- Hide Min/Max/Off Sale in the default toolbar and place them in Filter.
- Single-line item names at twice the previous label size, truncated with ellipsis; desktop hover tooltip should reveal full names.
- Replace NEXT button with incremental loading after the initial 30 results.

### Code committed
- Expanded preview is reserved to the left 25% and results are offset into the right 75% area.
- Added transparent icon-only Avatar Editor and Wardrobe entry points (currently explanatory placeholder actions; feature panels are not implemented yet).
- Adjusted preview camera to face the avatar from the front.
- Enlarged card item-name labels to 20px and disabled wrapping with end truncation.
- Hid page label/NEXT controls and connected results scrolling to next-page requests.

### Known incomplete work / validation
- Current Outfit horizontal strip/order, preview drag rotation, toolbar navigation strip, quick category row, Filter panel, and hover tooltip still need implementation.
- Infinite-scroll append/reset behavior requires Studio validation; this revision has not been run in Roblox Studio.


## 2026-10-16 — PDF-driven catalog UI pass (isolated branch)
- Kept the baseline catalog controller unchanged and made UI changes only in `workbench/catalog-ui-redesign/working-copy/CatalogController.client.lua`.
- Added top-left catalog launcher placement, translucent black backgrounds, fixed 25/75 expanded preview/results layout, fixed search/filter controls, horizontally scrolling discovery buttons and top-level categories with arrows/drag.
- Retained existing Config.CategoryGroups and category selection logic; selecting a new category/search resets results to the top.
- Added filter panel for creator name, price range and unavailable items; Limited sales type is visibly disabled pending API verification.
- Added Current Outfit horizontal item strip with individual remove actions and session-level newest-first ordering for newly worn items.
- Added placeholder actions for Avatar Editor and Wardrobe, plus desktop full-name hover tooltip.
- Not tested in Roblox Studio. Static review only. Recent/Favorites/Popular remain placeholders, Wardrobe persistence and transform editing are not implemented, and CreatorName support must be confirmed in the running client.


## 2026-10-18 — Avatar state contract and Roblox API research

### Source and API review
- Reviewed the current branch's CatalogController.client.lua and AvatarService.lua plus Catalog, Avatar, Outfit/Wardrobe, quick-navigation, TODO, status, and workbench documentation.
- Confirmed the current CatalogController compact card sizes in source: phone 76×114, other compact viewports 100×146. Expanded card width is computed as clamp(floor((rightWidth - 36) / 6), 88, 148), with height floor(width × 1.45). These are source values, not Studio-tested layout results.
- Roblox Creator Hub documents Humanoid:GetAppliedDescription() as returning a copy of the HumanoidDescription currently applied to the Humanoid. HumanoidDescription supports reading/writing accessories, classic clothing, body parts/scales/colors, animations and emotes; GetAccessories(true)/SetAccessories support rigid and layered accessory metadata.
- AccessoryDescription Position/Rotation/Scale are documented for rigid accessories only. Do not apply that promise to layered clothing or makeup without separate API evidence.
- CatalogSearchParams exposes SortAggregation; CatalogSortAggregation includes PastMonth and AllTime. The documented aggregation applies to MostFavorited and Bestselling. Product decision is MostFavorited + PastMonth, with explicit AllTime fallback if the runtime request fails or yields invalid behavior.
- DataStoreService is the platform persistence service. Feature persistence remains a design requirement until server-side read/write and rejoin tests are implemented.

### Decisions documented
- Added the shared avatar state and persistence contract and a dedicated player data schema document.
- Updated API research table, Catalog navigation/layout policy, Wearing partial-implementation status, quick navigation behavior, Outfit/Avatar Editor integration, and workbench Rojo isolation clarification.
- Chosen action concurrency policy: first request wins; while an avatar mutation is active, reject subsequent requests instead of queuing them.
- Recent is session-only successful wear history; Favorites and SavedOutfits must persist. SavedOutfits are game-only and limited to 50 per user initially (정정 2026-10-19: 이 기록의 초기 20개 표기는 오기이며 확정 한도는 50개). Outfit preview is rendered from saved appearance data.
- Avatar Editor values are draft until Apply succeeds. Cancel/close discards draft; Outfit restore and respawn discard unapplied changes. Respawn returns to the default Roblox avatar; temporary in-game wear is not auto-restored.
- R6/R15 switching is a game-wide avatar policy change, not an editor-level per-player toggle.

### Validation status
- Evidence level: official API docs reviewed and project source statically reviewed.
- No Roblox Studio session was run in this work. DataStore persistence, Popular query aggregation, every item-type wear/remove, partial restore, avatar preview rendering, and PC/mobile interaction remain unverified.


## 2026-10-18 — Static repository/documentation audit

### Scope inspected
- Read the repository tree for `catalog-ui-redesign`, the project/roadmap/vision/core-loop/design-principles docs, Club and other system plans, world concept and art-direction docs, API/state/persistence docs, logs, active catalog source, server entry point, avatar service, catalog config, and workbench README.
- Distinguished active `src/` code from `workbench/catalog-ui-redesign/working-copy/` and its baseline.
- Added `docs/06_LOG/DOC_CODE_AUDIT_2026-10-18.md` and `docs/00_PROJECT/DEVELOPMENT_ORDER.md` as central references for findings and dependency order.
- Expanded per-space planning documents for Beach, Cafe/City View, Park/Playground, City Street, Club spatial layout and Fashion Week Backstage; added a separate unresolved art exploration note.

### Source findings (static inspection only)
- Active catalog has search/filter/pagination, item cards, client wear/remove requests and a ViewportFrame preview structure.
- Server exposes Wear, Remove and GetCurrent routes; CatalogSearch RemoteFunction states that search runs on the client.
- Avatar service has classic clothing, accessory, animation, emote and makeup branches, and reads GetAppliedDescription after applying. Full requested-change verification was not found.
- Recent/Popular/Favorites and Wardrobe/Avatar Editor are placeholders in active source; Wearing is partial.
- Active request/state structures use numeric asset IDs and do not preserve typed Asset/Bundle identity end-to-end.
- `IncludeOffSale` is assigned from the user toggle and then overwritten with a category value in the inspected search function.
- No per-player server-side action gate or DataStore-backed SavedOutfits/Favorites implementation was found in the inspected active paths.
- The inspected source tree did not contain dedicated gameplay implementation modules for the documented world interactions.

### Validation limits
- This was a static GitHub inspection. No Roblox Studio runtime, published multi-client, live DataStore or mobile-emulator tests were run during this audit.
- Historical user confirmation for an earlier UI revision does not verify the current source or isolated workbench copy.
- No game source code was changed as part of this audit. Documentation changes only.

### Next action
Follow `docs/00_PROJECT/DEVELOPMENT_ORDER.md`, starting with P0 Catalog correctness and typed server-authoritative state before persistence or world expansion.


## 2026-10-19 — Studio-only code backup and workflow change
- Connected Roblox Studio MCP; read the scripts actually running in Studio.
- Found ChatGPT-era changes that were never pushed (FashionData remote, PlayerDataService, AppearanceCodec, AvatarService edit API, UI tweaks). Restored all six files, verified byte length + djb2 hash against Studio, pushed to `backup/studio-2026-10-19`.
- Confirmed the 1392 error cause in the real Studio code: forward reference to `refreshWornItems` (ISSUE-CATALOG-006).
- Listed conflicts with decisions (10 vs 50 outfits, persisted recents, SwitchRig, transform bounds, SetAsync) in `STUDIO_ONLY_CODE_AUDIT_2026-10-19.md`.
- New workflow: Claude edits → Rojo sync → Claude tests via Studio MCP → user approves → push.
- No game code changed on `catalog-ui-redesign`.

## 2026-10-19 — Catalog 1392 fix + Studio UI changes (option A)
- Brought the Studio-only client UI changes (text/transparency, preview inside main frame, "옷장" discovery button, round arrows, hidden scrollbars) and CatalogConfig bundle/off-sale/popular-sort settings into `fix/catalog-1392`.
- Removed client references to FashionData/AppearanceCodec and unused browse-mode locals so the client does not wait on server code that is not merged yet.
- Fixed ISSUE-CATALOG-006: forward-declared `refreshWornItems` and `searchCatalog`; wrapped wear/remove handlers so `actionBusy` is always released.
- Static scan found no other local function called before its definition.
- Studio play test (phone emulator, inputs via GUI selection + Enter): open catalog, expand, card WEAR (hat 417457461) → outfit-panel "× 해제" (the old 1392 path) → card WEAR → card REMOVE, filter Apply → search. All succeeded, no script errors; server logs show matching wear/remove.
- Test caveat: Studio server still ran the Studio-only server code; its Wear/Remove/GetCurrent paths match GitHub.
- Found: in expanded mode the "옷장" button overflows the discovery bar and is hidden behind the expand/close buttons (placement decision pending).

## 2026-10-19 — Catalog UI pass, shoes, layer order, preview orbit
- Read every note in `image/카탈로그 UI 20261017 14.jpg` and the KOYA layer video (frame-by-frame crops of the panel).
- Implemented (branch `feat/catalog-ui-1019`): right-anchored C button (TopbarInset) that also toggles close; expanded window below the top bar with equal margins and two 80% rounded boxes; circular arrows; text-width category chips; filter popup per reference with Sort moved inside; phone compact = 1/4 width; ⚙ in the minimized strip; preview drag-orbit + wheel zoom; Shoes bundle wear/remove as a pair; layer-order drag in the expanded worn strip; per-player server action gate; IncludeOffSale fix; subcategory scroll kept; glyphs that the font cannot render (⛶ ⌕ ☰ ▾) replaced.
- Studio play test (phone emulator 705×338, inputs via GUI selection + Enter): no script errors; compact/expanded/filter/sort screenshots match the reference; Shoes: WEAR → both shoes on, strip shows L/R separately, remove left only → right stays, card WEAR→WORN→remove both. Server SetLayerOrder verified on the real character (WrapLayer.Order changed; incomplete list rejected).
- Not verifiable in the emulator (mouse input does not reach the game): the drag gestures (layer drag, preview orbit). Needs the user's mouse/touch check.
- Studio was synced to match the repo exactly (hash-verified); Studio-only PlayerDataService/AppearanceCodec/FashionData were removed from the place (they remain on `backup/studio-2026-10-19`).

## 2026-10-19 — Discovery modes, favourites, Avatar Editor (feat/catalog-editor-1019)
- Official API research in Studio: GetAvatarRules (refinement types/bounds, scales, palettes), AccessoryDescription transforms survive GetAccessories/SetAccessories, client ApplyDescriptionAsync works on a client-created clone (D-024 option A), MakeupDescription.Order semantics, Shoes/animations are bundle-only (individual assets off-sale), GetBatchItemDetails, Popular PastMonth works, DataStore blocked in Studio (API access off).
- Implemented: phone minimized 2/5 width; half-size arrow circles; worn order (D-029) in strip and 착용 중; 착용 중 shows only worn items; layer drag in both views via a shared ReorderDrag module; Recent/Popular/Favorites/Wearing modes; favourites with DataStore (UpdateAsync, session fallback); empty-state messages; Wear verification (AUDIT-003); Avatar Editor (accessory adjust, body scales, skin palette, makeup order) with draft/preview/Apply/Cancel/close-confirm.
- Studio play test (phone emulator; GUI selection + Enter): 착용 중 19 cards in the right order, no extra items after scrolling; favourite double-tap → ★ + toast + Favorites list; Popular 30 results; Recent records a wear and keeps the item after removal; editor opens from the minimized ⚙ and the preview ⚙; accessory cards (face = adjustable, hair = 조정 불가) and 9 sliders with current values; skin chip → only the preview clone changes, Apply visible; close with changes → confirm → 버리기 restores; skin chip → 적용 → live character colours changed. Server ApplyEdit clamps out-of-range values to the official bounds and rejects non-palette colours. Test changes were reverted.
- Not verifiable here (mouse input does not reach the emulator): slider dragging, makeup drag (no makeup worn during the test), layer drag in the 착용 중 grid. Studio 3D view stopped rendering in screen captures during this session, so the preview image itself was checked through data, not pictures.
