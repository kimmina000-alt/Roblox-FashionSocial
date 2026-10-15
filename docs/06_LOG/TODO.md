# TODO

## High — Catalog / Avatar Reliability
- [ ] Fix makeup dispatch and remove handling; verify Face, Lip, and Eye Makeup in Studio.
- [ ] Diagnose zero results in individual animation subcategories using logged effective CatalogSearchParams and actual API responses.
- [ ] Pass BundleTypes through category selection and verify Animation Bundle results.
- [ ] Fix IncludeOffSale precedence so the visible toggle matches the applied search filter.
- [ ] Test the full interaction: open catalog → wear item → confirm preview/state → press the same item's action → remove item → confirm state.
- [ ] Verify failure paths: unsupported type, empty results, API error, failed apply, repeated click while request is pending.
- [ ] Triage the UIBlox FoundationProvider warning only if it correlates with a visible game UI issue.

## Medium — Catalog UX
- [ ] Plan a left-side current-avatar preview alongside the item grid.
- [ ] Reduce category friction: keep common categories immediately accessible and move long-tail categories into a clear expandable menu.
- [ ] Add responsive layout behavior for narrow/mobile screens.
- [ ] Preserve item name, price/sale status, and wear state on every card.
- [ ] Add readable empty/loading/error states and verify pagination.
- [ ] Consider outfit-code/save-load tools only after the core catalog loop is stable.

## Medium — Core Game
- [ ] HumanoidDescription transfer verification.
- [ ] Main→Runway teleport verification.
- [ ] Central Plaza blockout.
- [ ] Player outfit copy.
- [ ] Housing MVP and building placement engine.
- [ ] Runway core.

## Later
- [ ] Club polish.
- [ ] Advanced housing.
- [ ] Advanced photo.
- [ ] Monetization polish.
- [ ] Optimization.
- [ ] QA / soft launch.
