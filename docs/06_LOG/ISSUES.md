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
Status: Open
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
