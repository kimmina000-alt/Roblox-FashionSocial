# Catalog UI Redesign Workbench

This directory is deliberately outside `src/` so Rojo does not sync duplicate LocalScripts into the game.

- `baseline/CatalogController.client.lua`: untouched snapshot of the existing catalog code before PDF-driven UI work.
- `working-copy/CatalogController.client.lua`: isolated copy to modify for the new UI.
- Branch: `catalog-ui-redesign`, based on `feature/catalog-api-expansion`.
- Do not merge to `main` until the user reviews Studio behavior.
- Keep existing catalog API, category expansion, search, wear/remove, and scroll pagination behavior intact while changing presentation.

## PDF-derived UI requirements
1. Home screen: move catalog button to the circular button location shown on PDF page 2; preserve the existing button if replacing its icon is too risky.
2. Compact catalog: dark background at 60% transparency; phone width reduced by about half versus current compact width, but keep tablet sizing as-is.
3. Compact toolbar: horizontally scrollable top-level navigation for Recent, Popular, Favorites, Currently Worn; fixed search and filter controls. Popular must only use a supported Roblox API sort.
4. Main categories: Body, Clothing, Accessories, Face Makeup, Animations, Other. Horizontal drag plus small left/right arrow buttons. Selected button has opaque white text and solid/darker background. Preserve current category functionality.
5. Subcategory row remains functional and visually separate from the main categories.
6. Sort options: Relevance, Most Favorited, Bestselling, Recently Published, Price Low to High, Price High to Low, only where supported by existing/API behavior.
7. Collapsible filters: Creator (All creators / Creator name), Price (Any price / Price range), Unavailable items (On / Off), Sales type (All / Limited only after API support is verified).
8. Expanded catalog: left fixed avatar preview around 25% width; right independent Roblox catalog/results area around 75%. Avatar stays visible while results scroll.
9. Under avatar: Current Outfit as a single horizontal row of small item cards, horizontally draggable, newest worn item first, each individually removable.
10. Avatar Editor and Wardrobe icon buttons at top-left of avatar panel; add print-only placeholder actions for now.
11. Category change must reset result scroll position to top and show new category results.
12. All black UI surfaces should use about 60% transparency where appropriate.
13. Desktop and mobile should share the same layout concept while adapting to screen width.
14. PDF pages 1-7 inspected visually. See user-provided instructions for detailed page annotations.

## Progress — isolated copy
Implemented in `working-copy/CatalogController.client.lua`:
- Category/search/filter queries reset the results scroller to the top before rendering new results.
- Phone compact width uses 25% of viewport width (minimum 150px); tablet compact width remains 50%.
- Main catalog and results surfaces use a black background at 60% transparency.
- Existing category definitions, catalog API search, sorting, try-on, and incremental loading code were copied intact as the starting point.

Still to implement in the working copy:
- PDF toolbar layout (Recent / Popular / Favorites / Currently Worn with fixed search and filter controls).
- Main category horizontal strip with arrows/drag and selected-state styling, while preserving existing group/subcategory mappings.
- Collapsible filter UI for Creator, Price, Unavailable items, Sales type. Limited must remain disabled unless supported by the current API/config is verified.
- Fixed left avatar preview and separate results area on both phone and tablet; horizontal Current Outfit row ordered newest-first and item removal.
- Print-only placeholder handlers for Avatar Editor and Wardrobe if not already wired in the copied script.
- Home-screen catalog button placement: locate the actual launcher script before changing it.
- Studio test of scroll reset and phone/tablet compact sizes.


## Progress — PDF layout implementation (2026-10-16)

Implemented in the working copy:
- Home-screen catalog launcher moved to the top-left with a translucent black surface.
- Expanded catalog uses a fixed 25% avatar-preview column and 75% independent results column on desktop, tablet, and phone.
- Search and Filter stay fixed; Recent / Popular / Favorites / Currently Worn are in a horizontal discovery strip.
- Top-level category buttons follow existing `CatalogConfig.CategoryGroups`, with selected-state styling, arrows, touch scrolling, and mouse-drag scrolling. Existing detailed subcategory API mappings are preserved.
- Filter panel includes Creator name, Min/Max price, Unavailable items toggle, and a disabled Limited sales-type control. CreatorName is set defensively with `pcall` because runtime support needs verification.
- Current Outfit is a horizontal strip below the avatar preview with individual remove buttons and session-level newest-first ordering for items worn during this session.
- Avatar Editor and Wardrobe buttons show placeholder status messages; actual transform editing and outfit persistence are not implemented.
- Desktop item-name hover tooltip and search/category scroll-to-top reset are implemented.
- Phone compact width is 25% of viewport width (minimum 150px); tablet compact width remains 50%.

Still to validate or implement:
- Run Roblox Studio tests on PC, tablet, and phone. No runtime Studio test has been performed for this branch.
- Verify CreatorName support in the actual client API; unsupported assignment logs a warning.
- Recent, Favorites, and Popular are print-only placeholders; Popular must not be presented as an actual popularity ranking yet.
- Confirm Current Outfit reflects previously worn items and ordering after respawn/server refresh.
- Sales type Limited remains disabled until API support is verified.
- Verify the top-left launcher position against the in-game PDF reference.


## Separate Rojo test mapping

A separate project config was added at repository root: `catalog-ui-redesign.project.json`.

- The original `default.project.json` is unchanged.
- ReplicatedStorage and ServerScriptService continue to map to the existing `src/` folders.
- StarterPlayerScripts continues to map to the existing source tree, with the project file explicitly pointing `FashionGame/CatalogController.client.lua` to the workbench copy.
- The baseline file remains untouched at `workbench/catalog-ui-redesign/baseline/CatalogController.client.lua`.

### Run locally

From the repository root, try:

```powershell
rojo serve catalog-ui-redesign.project.json
```

Then connect Roblox Studio's Rojo plugin to the running server. Before relying on the test, verify the Rojo output/sourcemap and Studio Explorer contain exactly one `CatalogController` under `StarterPlayerScripts/FashionGame`, and that its source matches the workbench copy. This mapping has been committed but has **not** been executed/validated by Rojo or Roblox Studio in this session. If Rojo reports a duplicate-path or project-tree conflict, stop and do not sync; use an isolated test copy of the full StarterPlayerScripts tree instead.


## Isolation clarification — 2026-10-18

“격리”는 working copy가 기본 Rojo 설정인 default.project.json에 자동 반영되지 않는다는 뜻이다. 이 작업본은 실제 Studio 테스트에 연결할 수 있으며, 저장소 루트의 catalog-ui-redesign.project.json을 사용해 `rojo serve catalog-ui-redesign.project.json`을 실행한 뒤 Studio Rojo plugin으로 연결한다. 이 설정은 CatalogController를 workbench working copy로 명시적으로 매핑하고, baseline은 변경하지 않는다. 별도 설정으로 연결 가능하다는 점은 실제 Rojo/Studio 실행 검증 완료를 뜻하지 않는다. 첫 sync 전에 Rojo sourcemap과 Studio Explorer에서 CatalogController가 정확히 하나인지 확인한다.
