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

## Phase 1 — Saved Outfits and Persistence
- Save the server-confirmed supported appearance snapshot.
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

## Phase 4 — Playground Interactions
- Blockout a Playground area connected to Park or Central Plaza.
- Add a small number of place-specific interactions, such as a moving swing with a seated animation.
- Validate multi-player synchronization, collisions, exit behavior, mobile controls and performance.

**Acceptance criteria**
- Interactions have clear start/stop behavior and do not trap players.
- Other nearby players can see the interaction.
- Catalog and photo flows remain usable.

## Future Candidate — Runway (Deferred)
Re-evaluate only after the core Catalog, Saved Outfits, Club and Photo Spots experience is validated. Before implementation, define player count, theme, dressing, runway, voting, rewards, teleport, failure recovery and appearance restoration.

RunwayOutfit is temporary. At the end of a round, show a save confirmation; save to SavedOutfits only after explicit player confirmation.

## Deferred — Housing
Housing, house structure customization, furniture placement, persistence, permissions and friend visits are out of the current MVP and are the furthest priority. Revisit only if playtesting shows it strengthens the game's identity enough to justify the complexity.

## Completion Policy
Do not mark a phase complete because code exists. Record implementation, user-confirmed behavior, and Studio-verified acceptance tests separately.
