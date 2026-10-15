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
- Item card: thumbnail, item name, price/sale status, current wear state, primary action.
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
