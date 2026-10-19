# Roadmap

Roadmap order reflects the current product priority. Runway and Housing are not dependencies for the Catalog/Saved Outfit MVP.

## Phase 0 — Catalog Core
- Catalog search, category mapping, item cards and supported item-type dispatch.
- Server-validated temporary wear and exact-item remove.
- Confirmed appearance visible to other players.
- Current Outfit / Wearing list derived from the server-confirmed applied appearance.
- Clear loading, empty, unsupported-item and request-failure states.

**Acceptance criteria**
- A supported item can be searched, worn, seen by another player, and removed.
- Removing an item does not remove unrelated items.
- Card state, Current Outfit strip, Wearing list, avatar preview, and actual character remain synchronized after confirmed operations.
- Failed requests never appear as successful wear/remove.

## Phase 0.5 — Avatar Editor (accessory adjustment)
- Entry: ⚙ on the expanded preview and in the compact discovery strip; opens the expanded catalog in edit mode.
- Worn-items list by category, accessory position / rotation / scale with per-axis reset, draft → Apply / Discard.
- Supported types and limits come from the platform avatar rules; unsupported items are disabled with a reason.

**Acceptance criteria**
- Applied adjustments are visible to other players and survive later wear/remove actions.
- Discard or leaving without Apply never changes the live character.

## Phase 1 — Saved Outfits and Persistence
- Save the server-confirmed supported appearance snapshot, including applied accessory adjustments.
- Wardrobe list, unique Outfit IDs, duplicate names allowed, maximum 50 SavedOutfits per user.
- Reconnect and restore saved Outfit.
- Skip only unavailable/unsupported entries and apply the remaining valid appearance.
- Save/load failure handling, schema versioning, byte-size checks and migration safety.

**Acceptance criteria**
- A saved Outfit remains available after leaving and rejoining.
- Partial restore preserves the original saved record and clearly identifies skipped items.
- Empty Wardrobe and load failure are distinct states.
- A save is not reported successful until its result is verified.
- Existing saved data is not overwritten by an empty/default record after load or migration failure.

## Phase 2 — Club
- Club area in Main Social.
- Multiple dance styles/animations and clear interaction controls.
- Multiplayer visibility, PC/mobile interaction and animation transition checks.

**Acceptance criteria**
- Players can start/stop dances and other players can see them.
- Dance state does not trap the character or prevent normal movement.
- Core Catalog and Current Outfit remain available.

## Phase 3 — Photo Spots
- Build a small number of visually distinct photo locations first.
- Define framing, lighting, camera position, poses and entry/exit flow per location.
- Validate solo and group-photo feasibility, PC/mobile controls and avatar visibility.

**Acceptance criteria**
- Each first-pass spot provides a distinct composition.
- Camera/pose controls do not block ordinary play or hide the avatar.
- Photo-taking works without a public in-game gallery.

## Phase 4 — Additional World Spaces (one at a time)
The canonical proposed sequence is maintained in `DEVELOPMENT_ORDER.md` Stage 6. Do not interpret the phase list here as a requirement to build every space in parallel.

1. **Beach + Dream Aquarium:** validate beach rest and the dome → underwater space → surface → beach traversal loop.
2. **Cafe / City View:** validate sitting, viewpoint and window-side photo composition. Whether Glasshouse Cafe and Neon Rooftop City share a structure remains undecided until blockout.
3. **Fantasy Playground:** begin with one interaction, such as a swing with seated animation. Carousel, Viking-ship ride and roller coaster remain later candidates.
4. **Central Street / decorative landmarks:** add route legibility and exploration landmarks as needed.
5. **Fashion Week Backstage:** consider as a standalone social/exploration space. Runway portal and round system remain deferred.

Select the next space based on blockout findings, player experience, and implementation cost; build and test one vertical slice at a time.

**Acceptance criteria**
- The chosen space has a clear purpose and a meaningful interaction, not just decorative geometry.
- Player routes, camera, collisions, multi-player behavior, mobile controls and performance are tested.
- Existing Catalog, SavedOutfits, Club and photo flows remain usable.

## Future Candidate — Runway (Deferred)
Re-evaluate only after the core Catalog, Saved Outfits, Club and Photo Spots experience is validated. Before implementation, define player count, theme, dressing, runway, voting, rewards, teleport, failure recovery and appearance restoration.

RunwayOutfit is temporary. At the end of a round, show a save confirmation; save to SavedOutfits only after explicit player confirmation.

## Deferred — Housing
Housing, house structure customization, furniture placement, persistence, permissions and friend visits are out of the current MVP and are the furthest priority. Revisit only if playtesting shows it strengthens the game's identity enough to justify the complexity.

## Completion Policy
Do not mark a phase complete because code exists. Record implementation, user-confirmed behavior, and Studio-verified acceptance tests separately.


## World Concept Planning — 2026-10-18

Before detailed world art production, create a whole-map blockout with readable routes and area roles. The world concept is documented in `docs/02_WORLDS/WORLD_CONCEPTS_AND_INTERACTIONS.md`.

Proposed areas:
- Club / Idol Concert City — detailed design in `docs/01_SYSTEMS/CLUB.md`.
- Beach — Sunset Beach Resort plus Dream Aquarium concept; underwater swimming/breath-duration mechanic is unverified and requires prototype testing.
- Cafe / City View — Glasshouse Cafe and Neon Rooftop City.
- Fantasy Playground — begin with one simple interaction; carousel, Viking-ship ride and roller coaster are later candidates.
- Fashion Week Backstage — possible standalone space first; Runway portal remains deferred.

World-layout planning is early because it affects adjacency and traversal, but do not build every area in parallel. Build and test a small number of interactions before expanding. The Korean-inspired vs American-vintage/global-fantasy art direction remains undecided until moodboards and blockout are compared.


## Execution Order and Space Planning
The whole-game dependency order is maintained in [`DEVELOPMENT_ORDER.md`](DEVELOPMENT_ORDER.md). Use that document to distinguish low-cost whole-map blockout from full space implementation: the blockout may happen early, while detailed art and gameplay are built incrementally after the Catalog/SavedOutfits gates. Each space's detailed design and local construction order lives in its own file under [`../02_WORLDS/`](../02_WORLDS/). The cross-space concept index remains [`../02_WORLDS/WORLD_CONCEPTS_AND_INTERACTIONS.md`](../02_WORLDS/WORLD_CONCEPTS_AND_INTERACTIONS.md).

## Current Source Audit
See [`../06_LOG/DOC_CODE_AUDIT_2026-10-18.md`](../06_LOG/DOC_CODE_AUDIT_2026-10-18.md) for the source-level gap list. The most important implementation gates are server-side operation gating, typed Asset/Bundle identity, applied-state verification, `IncludeOffSale` precedence, and real SavedOutfits/Favorites persistence. None should be marked complete until tested.
