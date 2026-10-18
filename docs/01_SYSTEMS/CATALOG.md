# Catalog System

## Goal
플레이어가 소셜 월드를 떠나지 않고 현재 아바타를 보면서 아이템을 탐색하고, 임시 착용하고, 필요하면 해제할 수 있어야 한다. Catalog는 특정 방이나 전용 Fashion Studio에 종속되지 않는다.

## UX Direction
첫 번째 레퍼런스 영상에서 참고할 원칙:
- 아바타 미리보기와 아이템 목록을 같은 화면에 둔다.
- 아이템 탐색은 텍스트보다 썸네일을 우선한다.
- 검색과 자주 쓰는 카테고리는 눈에 잘 띄게 둔다.
- 최근/인기 탐색 같은 보조 탭은 기본 탐색을 방해하지 않을 때만 추가한다.
- 화면의 모든 기능을 한꺼번에 복제하지 않는다. 현재 게임의 핵심인 빠른 코디 변경을 우선한다.

## Layout
### Desktop / wide viewport
- Left: current avatar preview, compact category shortcuts, current-outfit entry point.
- Right: search and browse controls above a scrollable item grid.
- Item card: compact thumbnail, item name, price/sale status, current wear state, primary action. Keep cards about 20% smaller than the original 165×240 px layout; do not reduce them to one-fifth of their dimensions because that would make names and tap targets unusable.
- Close control remains easy to find. Closing the catalog returns the player to the same world and does not reset CurrentOutfit.

### Small viewport
- Keep the item grid usable and controls reachable.
- Avatar preview may collapse into a compact preview/toggle rather than forcing a permanent split layout.
- Category shortcuts should scroll horizontally or collapse into a clear category menu.
- Avoid tiny tap targets and controls that overlap the results.

## Item Interaction Contract
1. Selecting a card's thumbnail/name focuses the item and exposes its information; selection alone must not silently equip it.
2. The primary action is state-aware:
   - Not worn: WEAR
   - Worn: REMOVE (or WORN with an unmistakable remove affordance)
   - Unsupported item: VIEW ONLY, with a reason where possible.
3. Pressing WEAR requests a server-side equip. Show a busy state while the request is in progress.
4. Only after the server confirms success should CurrentOutfit and the card state update.
5. Pressing the same item's action again removes that exact item. It must not remove unrelated items in the same category.
6. After success, refresh the avatar preview and the visible worn state. On failure, keep the last confirmed state and show a readable error.
7. Prevent duplicate concurrent requests while a wear/remove request is pending.
8. Reopening the catalog refreshes CurrentOutfit from the authoritative server state.

## Browse Controls
- Search by keyword; Enter and the search button should have equivalent behavior.
- Category filters should map to supported Roblox API asset/bundle types. Categories with no API mapping must be visibly marked unavailable rather than appearing to load.
- Sort and price filters should preserve the selected values during a search.
- IncludeOffSale must have one clear source of truth. Category defaults must not silently overwrite a player's explicit filter selection.
- Paginated results should show loading and error states and should not duplicate stale cards.
- Empty results should distinguish a valid empty search from a search/API error.

## Current Scope
Implemented in the current branch: keyword search, nested category menu, sort menu, price bounds, off-sale toggle, paginated item cards, WEAR/WORN action, server request for wear/remove, and worn-item refresh when opening the catalog.

Not yet established as complete: persistent left-side avatar preview, responsive/mobile layout, robust per-item-type handling, and reliable animation/makeup search and wear flows. Treat these as planned work, not finished features.

## Outfit Codes / Saved Looks
Outfit code search/load and saved outfits are useful secondary features seen in the reference experience, but they are not prerequisites for a reliable catalog MVP. Add them only after search, preview, wear, remove, and state synchronization are stable.

## Ownership
Try-on changes the game's session CurrentOutfit; it does not grant Roblox account ownership. Actual purchases must use the official Roblox purchase flow.

## Social
Players may inspect another player's visible outfit and try the same catalog items, subject to supported item types and server validation.


## Catalog Panel and Discovery UX — Planned

### Primary user goal
The main loop is **find an item quickly → try it on → immediately inspect the result**. The avatar/world preview, category access, and keyword search are primary controls; advanced filters must not push them out of view or make them harder to use.

### Responsive panel layout
- **Desktop compact mode:** keep the catalog right-docked at the reduced width/height. Search, category, and sort share one toolbar row; item cards use a compact desktop-specific size.
- **Expanded mode:** use the full viewport on both PC and mobile. Reserve a dedicated left-side avatar preview area on PC and a top preview area on mobile, with the item grid remaining visible beside/below it.
- Allow resizing by dragging a corner/edge when reliable. If resizing proves unreliable, use a clear expand/collapse control instead.
- Clamp the panel to the viewport so it cannot be dragged completely off-screen; preserve usable minimum dimensions.
- **Mobile/narrow screens:** the collapsed catalog is a bottom-right floating window occupying roughly one-quarter of the screen area (about half the viewport width and half its height). Its search/category/sort controls share one row, and the item grid starts directly below the compact status row. Expanding opens the full-screen view with a dedicated current-avatar preview window. Advanced price/off-sale filters are hidden only in compact mode and return when expanded.
- Keep the search and sort controls above the item grid. The item grid must retain enough room for readable thumbnails and card actions.

### Category navigation
- Pin high-frequency shortcuts near the top (initial candidates: Clothing, Hair, Face, Accessories).
- Keep less frequently used categories in clearly named grouped menus rather than requiring players to repeatedly expand multiple groups to reach common categories.
- On narrow screens, show shortcuts as horizontally scrollable chips/icons and put the long-tail category list in a separate menu.
- Keep the avatar preview and category/search entry points more prominent than advanced filtering.

### Search and filters
- Keep the default browse area compact:
  - Keyword search.
  - Category shortcuts.
  - Sort, defaulting to `Relevance`.
- Available sort choices to verify against the current catalog API: `Relevance`, `MostFavorited`, `Bestselling`, `RecentlyCreated` (UI label may be “Recently Published”), `PriceLowToHigh`, and `PriceHighToLow`.
- Put secondary filters in a collapsed “More filters” area:
  - Creator: all creators / creator name.
  - Price: any price / minimum and maximum price.
  - Include unavailable/off-sale items: explicit on/off toggle.
  - Sales type: all / limited, **only if the returned metadata and API behavior can reliably distinguish the requested limited-item definition**. Do not present a nonfunctional filter.
- Preserve selected sort/filter values while searching and paginating. The visible off-sale toggle must match the effective search parameters.
- Verify whether Most Favorited and Bestselling expose a configurable aggregation period before adding any period selector; do not imply a time range if the API does not support one.
- Show loading, empty-result, and error states distinctly. Keep item thumbnail, name, price/sale status, wear state, and the primary wear/remove action legible on each card.

### Acceptance criteria
- Players can search or open a common category without first opening advanced filters.
- On desktop, the catalog defaults to approximately one-third width and the avatar/world remain visible.
- On narrow screens, controls and item cards remain usable rather than shrinking to desktop proportions.
- The player can tell whether an item is worn and see the confirmed avatar result after wear/remove.
- Existing search, category selection, sort, price bounds, off-sale behavior, pagination, wear, and remove flows continue to work after the layout changes.


## Current Worn Items Panel — Planned

- Add a dedicated panel/window that lists the items currently worn by the local player's avatar, not just a WORN label on catalog search cards.
- Each row/card should show the thumbnail, item name/type, and a clear remove action where supported.
- Refresh the list from the authoritative server CurrentOutfit after opening the panel and after successful wear/remove actions.
- Keep the worn-item list distinct from catalog search results so users can inspect and manage their current outfit even when an item is not in the current search page.
- Do not mark an item removed or worn until the server confirms the operation; unsupported types should have a clear non-actionable state.


## Current responsive layout and navigation — source-aligned 2026-10-18

- Compact toolbar keeps keyword search, category selection, and sort on one row where the viewport allows it. Enter submits the search.
- Card sizes must match the current source file, not historical design drafts: compact phone 76×114; other compact viewports 100×146. Expanded cards are responsive: width = clamp(floor((rightWidth - 36) / 6), 88, 148), height = floor(width × 1.45).
- Expanded layout is full-screen. The left preview column is approximately 25% of the width; catalog results use the remaining right area. On mobile the preview and results must not overlap controls.
- Current Outfit is a horizontal strip of the actual currently worn items, derived from the same server-confirmed snapshot as Wearing. Each supported item can be removed through its explicit remove action.
- Avatar Editor and Wardrobe entry points exist in the UI, but their buttons/entry points do not prove the full editor or persistence features are implemented.
- Studio verification is required for card visibility, responsive preview, keyboard/touch interaction, and results scrolling.

## Current catalog toolbar requirements

- Navigation: Recent / Popular / Wearing / Favorites / Wardrobe. Recommended is removed. Wardrobe opens the saved Outfit list and is not a catalog search mode.
- Search/filter/category/sort controls apply to global catalog searches only, and only where official CatalogSearchParams/current runtime support the field.
- Recent contains successful wear actions in the current session only. It is not a search history and clears when the player leaves.
- Popular uses MostFavorited with PastMonth aggregation where supported; fallback to AllTime must be explicit. Do not expose Bestselling or RecentlyCreated as Popular.
- Wearing uses only the actual server-confirmed applied avatar snapshot. Favorites uses only the player's in-game saved favorites. Neither may silently fall back to full catalog results.
- Item image double-click/double-tap toggles Favorites only. Wear/Worn buttons exclusively issue wear/remove actions. The threshold is 0.5 seconds; delay any single-click behavior until the threshold expires so a double-click does not also fire a single-click side effect.
- Current UI source values and the authoritative avatar contract are described in the current navigation section below. Historical card dimensions and earlier toolbar sketches belong in WORKLOG/CHANGELOG, not as current requirements.

## Plan Reconciliation — 2026-10-17

- The core Catalog loop remains search/category → inspect → wear/remove → confirm the real avatar state. Saved Outfit/Wardrobe is a secondary feature and must not destabilize this loop; see `docs/01_SYSTEMS/OUTFIT_WARDROBE_AND_AVATAR_EDITOR_PLAN.md` for its detailed requirements.
- The Avatar system overview is `docs/01_SYSTEMS/AVATAR.md`; detailed Avatar Editor requirements are owned by `docs/01_SYSTEMS/AVATAR_EDITOR_IMPLEMENTATION_PLAN.md`. Catalog defines only integration points.
- Historical toolbar sketches mentioned Recommended, but it is not a current mode. The current navigation is Recent / Popular / Wearing / Favorites / Wardrobe; Wardrobe is the separate saved-Outfit entry.
- “Current Outfit” as the horizontal strip of currently worn items and “Wearing” as a card-grid browse mode are related but distinct UI presentations. Both must read from the same authoritative current-worn state.
- Latest responsive-layout notes are requirements, not proof of the current implementation. Studio verification is required for the current revision.


## Quick Navigation Modes — Detailed Specification

The implementation contract for Recent, Popular, Wearing, and Favorites is owned by [`CATALOG_QUICK_NAVIGATION_IMPLEMENTATION_PLAN.md`](CATALOG_QUICK_NAVIGATION_IMPLEMENTATION_PLAN.md). Use that file for each mode's data source, record lifecycle, API sorting constraints, click/double-click behavior, search/filter interactions, persistence, error handling, cross-feature invariants, and acceptance tests.

The four modes reuse the catalog item-card area but do not share the same data source:
- Recent = items successfully worn in the current session, not search or view history.
- Popular = actual Roblox-supported catalog sort only; never relabel another sort as popularity.
- Wearing = current server-confirmed avatar wear state.
- Favorites = user-specific in-game favorites, distinct from Roblox account favorites.

Outfit/Wardrobe and Avatar Editor must keep these modes synchronized with the same authoritative avatar state. Implementation status is tracked separately in `CATALOG_IMPLEMENTATION_STATUS.md`; this system document and the detailed spec do not imply that placeholders are already functional.


## Current navigation contract — 2026-10-18

- 탐색 모드는 **Recent / Popular / Wearing / Favorites / Wardrobe**다. Recommended는 현재 범위에서 제거한다.
- Recent/Popular/Wearing/Favorites는 동일한 catalog card area를 재사용한다. Wardrobe는 저장한 Outfit을 관리하는 별도 화면/진입점이다.
- **Current Outfit**은 현재 실제 착용 항목을 가로로 보여 주는 별도 strip이다. Wearing grid와 같은 서버 확인 snapshot을 사용하며 자체 착용 상태를 만들지 않는다.
- 실제 착용/해제 버튼은 카드의 Wear/Worn 버튼에서만 수행한다. 카드 이미지의 더블클릭은 Favorites 추가/해제 전용이며, 착용/해제 요청을 실행하지 않는다.
- Recent는 현재 세션에서 실제 착용에 성공한 항목만 기록한다. 세션 종료 시 초기화한다.
- Popular는 Roblox 공식 API의 MostFavorited만 사용하고 PastMonth aggregation을 우선 지정한다. 지원/결과가 유효하지 않으면 명시적으로 AllTime으로 fallback한다. Bestselling/RecentlyCreated는 현재 Popular 모드에 노출하지 않는다.
- Favorites와 Wardrobe는 사용자별 영구 저장 대상이며, 실제 DataStore 연결/재접속 보존은 별도 구현 및 Studio 검증 전까지 미완료다.
- 검색/카테고리/정렬/가격/creator/off-sale 필터는 검색 결과 모드에서만 적용한다. Wearing은 현재 실제 착용 snapshot만, Favorites는 즐겨찾기 record만 필터링하고 전체 catalog 검색 결과로 fallback하지 않는다.
- 레이아웃 수치는 최신 소스 기준이다. Compact cards: phone 76×114, other compact 100×146. Expanded cards: cellWidth = clamp(floor((rightWidth - 36) / 6), 88, 148); height = floor(cellWidth * 1.45). Expanded size is responsive, not a fixed 132×192 value.
- 이 수치는 코드 정적 확인 결과이며 Studio에서 실제 가독성/배치 검증을 완료했다는 뜻은 아니다.

Single source and persistence contract: [AVATAR_STATE_AND_PERSISTENCE.md](../05_TECH/AVATAR_STATE_AND_PERSISTENCE.md). API support evidence: [API.md](../05_TECH/API.md). Player data schema: [DATA.md](../05_TECH/DATA.md).
