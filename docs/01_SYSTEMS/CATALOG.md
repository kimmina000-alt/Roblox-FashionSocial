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


### Compact toolbar and avatar preview
- In compact mode, keep keyword search, category selection, and sort on a single horizontal row. Enter in the search field submits the search; the separate Search button is hidden only in compact mode.
- Compact card sizes are device-aware: compact mobile 76×114, compact desktop 100×146, expanded mobile 112×164, expanded PC 132×192. Keep card content scaled with the card rather than clipped.
- Expanded mode opens a dedicated `ViewportFrame` preview of the player's current character/outfit. Refresh it after successful wear/remove, on reopening, and after character respawn.
- On PC, reserve a left-side preview column and keep catalog results to the right. On mobile, place the preview below the search/filter controls and above the results grid so it does not cover the controls.
- Studio validation must confirm the preview accurately reflects the server-applied outfit and that card names, prices, and actions remain readable at each size.


### Compact card visibility follow-up — 2026-10-15
- Keep the compact toolbar on one row: keyword search, category (ALL), and sort.
- Place results directly below that row and hide status/secondary filter rows in compact mode to avoid pushing cards below the fold.
- Use distinct card dimensions for compact mobile and compact PC; compact PC cards should also be smaller than expanded cards.
- When expanded, both PC and mobile use full-screen catalog layout and show a separate current-avatar preview. On mobile, stack the preview between controls and the results grid; on PC, reserve the left preview column.
- Verify the preview clone and card visibility in Studio; these latest changes are not yet confirmed in Studio.


## Expanded catalog layout — 2026-10-16

### Confirmed layout
- Expanded catalog is full-screen. The avatar preview is a fixed left column occupying approximately 25% of the width; the catalog occupies the remaining 75%.
- Avatar preview controls have reserved icon-only entry points in the preview panel: Avatar Editor (transform editing) and Wardrobe (save/load outfits).
- Current Outfit should remain below the avatar preview as a single horizontal, horizontally scrollable row, ordered newest worn item first. Each item should support individual removal.
- Catalog results should scroll independently; scrolling results must not move the preview.
- Item names use a larger single-line label with end ellipsis. Desktop hover should reveal the full name in a tooltip.
- Phone compact mode should be narrower than tablet compact mode; tablet sizing remains unchanged.

### Catalog toolbar requirements
- Row 1: horizontally scrollable navigation strip for Recent, Popular, Recommended, Favorites, and Currently Worn. Search and Filter remain fixed and must not scroll away with that strip.
- Row 2: quick category buttons All, Hair, Face, Tops, Bottoms, Accessories, Animations.
- Min / Max / Off Sale should move into a Filter panel rather than occupy the default toolbar.
- Recent means recently viewed items, not search history. Popular must use an actual supported Roblox API sort; unsupported types must not be labeled Popular. Recommended is deferred until a real recommendation rule exists.
- Infinite scroll: request the first 30 items, then append subsequent pages as the result scroller nears its bottom. Prevent duplicate concurrent requests and reset results on search/filter/category/sort changes.

### Implementation status for this revision
- Implemented: full-screen 25/75 preview/catalog sizing; icon-only Avatar Editor and Wardrobe entry points; front-facing preview camera; single-line enlarged item names; hidden NEXT/page controls and scroll-triggered page fetching; expanded results area reserved to the right of the preview.
- Still needs implementation/validation: fixed Current Outfit horizontal item strip and newest-first ordering; drag-to-rotate preview; actual Avatar Editor and Wardrobe panels; Recent/Popular/Recommended/Favorites/Currently Worn navigation strip; quick category row; Filter panel with Min/Max/Off Sale; mouse-following full-name tooltip; verify the scroll loader appends results correctly across all categories and resets on changed filters.
- This commit has not been run in Roblox Studio. Do not treat the remaining items as completed.
