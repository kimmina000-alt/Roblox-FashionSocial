# Issues

이 문서는 재현 가능한 문제, 기대/실제 결과, 원인 조사 및 해결 결과를 기록한다. 계획/우선순위는 TODO.md, 요구사항/수락 기준은 기능 상세 명세, 실제 조사와 테스트 증거는 WORKLOG.md, 커밋 변경 내역은 CHANGELOG.md에 둔다.

## Template

### ISSUE-001 — Title
Status: Open
Area: System / World / Art / Tech
Description:
Steps:
Expected:
Actual:
Decision / Fix:

---

### ISSUE-AVATAR-001 — Makeup item rejected by wear service
Status: Open
Area: Tech / Avatar / Catalog
Description: Face makeup was selected in the catalog, but the server rejected the wear request.
Steps:
1. Open the catalog in Studio.
2. Browse to Face Makeup, Lip Makeup, or Eye Makeup.
3. Press the wear action on a makeup item.
Expected: The supported makeup type is added through the MakeupDescription path and the avatar/card state updates after confirmation.
Actual: Output reports [CatalogController] Wear failed: false This item type is not supported yet.
Investigation notes:
- Makeup types are not ordinary AccessoryType values and should not depend on the generic accessory mapping.
- Review the server dispatcher and the placement/scope of the existing MakeupDescription handling before changing behavior.
Decision / Fix: Keep makeup Wear enabled only when the server path is verified. Add a type-specific handler and a matching remove path, then test each makeup type in Studio.

### ISSUE-CATALOG-002 — Animation subcategories return zero results
Status: Open
Area: Tech / Catalog
Description: Selecting individual animation subcategories in Studio returns 0 items loaded.
Steps:
1. Open the catalog.
2. Select an individual animation category such as Idle, Walk, Run, Jump, Fall, Climb, or Swim.
Expected: Results appear when Roblox's catalog API has matching items for the selected filters.
Actual: The category reports zero loaded items.
Investigation notes:
- Confirm whether the API returns individual assets for each AvatarAssetType filter in the current experience.
- Verify IncludeOffSale behavior for each animation subcategory.
- The current category selection path does not pass BundleTypes to the search function, so animation-pack search is also misconfigured.
Decision / Fix: Test asset filters and bundle filters separately; log the effective CatalogSearchParams and distinguish a legitimate empty result from an API/filter issue.

### ISSUE-CATALOG-003 — Off-sale toggle can be overwritten
Status: Fixed on `feat/catalog-ui-1019` (IncludeOffSale = user choice OR category default)
Area: Tech / Catalog
Description: Search sets IncludeOffSale from the user toggle and then overwrites it with the category default.
Expected: The explicit user choice should be preserved unless the UI clearly communicates a category-specific override.
Actual: The final search parameter can ignore the visible toggle state.
Decision / Fix: Define one precedence rule for the global toggle and category defaults, then test it across normal and animation categories.

### ISSUE-UI-004 — FoundationProvider warning from UIBlox
Status: Needs triage
Area: Tech / UI
Description: Studio Output showed a Roblox CorePackages UIBlox warning: FoundationProvider not found. Please ensure that the FoundationProvider is present in the component tree.
Expected: No relevant UI failure; if a Roblox internal warning remains, establish whether it affects this experience before assigning ownership.
Actual: Warning and CorePackages stack were observed during Play.
Decision / Fix: Check whether any in-game UI is visibly broken and capture a minimal reproduction. Do not classify as a game-code defect based on the warning alone.


## Audit findings — 2026-10-18

### ISSUE-AUDIT-001 — Wear/remove request does not preserve typed identity
Status: Open
Area: Tech / Catalog / Avatar
Description: The active client request passes an action plus numeric assetId. Server detail lookup explicitly requests `Enum.AvatarItemType.Asset`; the UI's current worn state is keyed by numeric ID. Bundle and cross-type identity are not represented end-to-end.
Expected: Request and state preserve the item type and type-specific metadata; unsupported types are clearly disabled/rejected.
Actual: Asset-only request contract in the inspected active source.
Decision / Fix: Add a typed request/result contract or disable Bundle wear until a verified application route is implemented. Update Current Outfit, Wearing, Favorites and restore identity consistently.

### ISSUE-AUDIT-002 — Server does not gate concurrent avatar mutations
Status: Fixed on `feat/catalog-ui-1019` (per-player runExclusive in ServerMain)
Area: Tech / Avatar / Network
Description: Client uses a local busy flag, but the inspected server entry point has no per-player operation lock shared by wear/remove/current future Apply/restore operations.
Expected: One authoritative per-player mutation at a time; reject or disable later requests while one is in progress.
Actual: Local client guard only was found in the inspected path.
Decision / Fix: Add server-side action gate and test rapid duplicate/mixed requests and failure cleanup.

### ISSUE-AUDIT-003 — Applied appearance is read but not fully checked against requested change
Status: Open
Area: Tech / Avatar
Description: The service applies a HumanoidDescription and reads GetAppliedDescription(), but the inspected path logs accessory details and returns success without checking that the requested item/property is present in the resulting applied state.
Expected: Success means the intended change was verified in the actual applied description.
Actual: Post-apply read/logging is present; requested-change comparison was not found.
Decision / Fix: Implement type-specific post-apply verification and return a confirmed snapshot/result.

### ISSUE-AUDIT-004 — Active UI has placeholder discovery and Wardrobe controls
Status: Open
Area: UI / Catalog / Persistence
Description: Recent, Popular and Favorites handlers log placeholder messages; Wardrobe and Avatar Editor display planned-status text. Wearing has a partial list path.
Expected: Each enabled control performs its documented behavior, or is visibly marked disabled/not yet available.
Actual: Full behavior is not implemented in inspected active source.
Decision / Fix: Implement after the core typed-state/persistence gates, or disable/defer controls explicitly.

### ISSUE-AUDIT-005 — IncludeOffSale UI state is overwritten
Status: Fixed on `feat/catalog-ui-1019` (see ISSUE-CATALOG-003)
Area: Tech / Catalog / Search
Description: `searchCatalog()` sets `params.IncludeOffSale` from `currentIncludeOffSale` and later overwrites it with `currentCategoryIncludeOffSale`.
Expected: Effective API params match the visible filter state under one documented precedence rule.
Actual: Later assignment can ignore the user toggle.
Decision / Fix: Resolve the precedence and add regression tests across categories, including animation/bundle searches.

### ISSUE-AUDIT-006 — Persistence and world plans exceed active implementation
Status: Open
Area: Product / Systems / World
Description: Data schema and world plans are detailed, but the inspected active source has no confirmed DataStore implementation, and the source tree contains no dedicated implementation modules for the documented Club, Photo Spots, Beach/Aquarium, Cafe, Playground, Backstage, Runway or Housing features.
Expected: Planning status and implemented status remain separate.
Actual: These features remain plans/candidates based on this source inspection.
Decision / Fix: Follow `../00_PROJECT/DEVELOPMENT_ORDER.md`; implement one core loop/interaction at a time and update the audit/worklog only with new evidence.

### ISSUE-AUDIT-007 — Popular mode has no mode-specific aggregation yet
Status: Open
Area: Catalog / API / UX
Description: `CatalogConfig.SortAggregation` currently defaults to `AllTime`. The documented Popular behavior prefers `MostFavorited + PastMonth` with explicit fallback to `AllTime`, but the active and workbench Popular handlers are placeholders.
Expected: Popular mode explicitly applies its documented aggregation, handles runtime rejection/invalid results with a visible/logged fallback, and never labels other sorts as Popular.
Actual: Global config is AllTime; Popular mode-specific behavior is not implemented.
Decision / Fix: Implement a Popular-mode-specific sort/aggregation branch and verify the supported combinations in Studio. Keep ordinary catalog sort aggregation behavior separate.

### ISSUE-CATALOG-006 — CatalogController:1392 nil call (forward reference)
Status: Fixed on `fix/catalog-1392` (Studio-tested 2026-10-19, awaiting user approval to merge)
Area: Tech / Catalog
Description: Wear/remove flow errors at CatalogController line ~1392 (Studio copy) calling `refreshWornItems`.
Expected: Worn list refreshes after wear/remove.
Actual: `attempt to call a nil value` — `refreshWornItems` (and `searchCatalog`) are local functions defined after the functions that call them, so the call resolves to a nil global. `actionBusy` can stay locked after the error.
Decision / Fix: Forward-declare both locals at the top, assign later; ensure actionBusy is released on every path (pcall/finally). Regression test wear/remove/discovery in Studio. See `STUDIO_ONLY_CODE_AUDIT_2026-10-19.md`.

### ISSUE-CATALOG-007 — Shoes category showed CONTENTS instead of WEAR
Status: Fixed on `feat/catalog-ui-1019` (Studio-tested)
Area: Catalog / Avatar
Cause: Roblox sells shoes only as `Shoes` bundles; the individual Left/RightShoeAccessory assets are off-sale (search with on-sale assets only returns 0). All Shoes results were bundles, and every bundle card showed CONTENTS.
Fix: Shoes bundle cards show WEAR/WORN. Server `WearShoeBundle` reads the bundle on the server, adds both shoe assets in one apply (replacing shoes on the same side). Card WORN → `RemoveMany` removes both. The worn strip keeps separate left/right cards with separate remove.
