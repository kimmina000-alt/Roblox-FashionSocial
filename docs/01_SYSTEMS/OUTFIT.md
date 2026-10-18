# Outfit System

## States
- **CurrentOutfit:** server-confirmed appearance currently applied to the active character/session.
- **SavedOutfits:** game-only named looks saved by this experience; maximum **50 per user**.
- **RunwayOutfit:** temporary round outfit only if the deferred Runway feature is implemented.
- **RobloxOwnedItems:** Roblox platform ownership; separate from all in-game Outfit states.

These states are not interchangeable. Temporary try-on does not grant account ownership or create a Roblox platform Outfit.

## Catalog State Synchronization
- The server's applied avatar description is authoritative for currently worn state.
- Opening the catalog refreshes the worn-item set.
- After confirmed wear/remove, refresh the affected card, Current Outfit strip, Wearing list and avatar preview from the confirmed state.
- Do not optimistically show an item as worn if the server call fails.
- Prevent duplicate concurrent appearance requests.
- Unsupported items must retain the last confirmed state and show a readable reason.

## Saved Outfit Record
Each SavedOutfit uses a unique outfitId even when names repeat and includes a schemaVersion, name, timestamps, and a server-validated snapshot of supported appearance properties that the implementation can actually read and reapply. Store typed item identities and the required type-specific data; a plain list of untyped numeric IDs is insufficient. Do not store Roblox Instances or thumbnail image bytes.

The initial product limit is **50 SavedOutfits per user**. This is a game policy, not a Roblox platform recommendation. At the limit, do not silently overwrite an existing Outfit; ask the player to delete one before saving another.

## Save / Load
- Save only the server-confirmed current appearance, not an un-applied Avatar Editor draft.
- Preserve previous valid data until the replacement write is validated and its result confirmed.
- Use schema versioning and safe migrations.
- Distinguish empty Wardrobe from load or migration failure.
- Classify errors: transient service/network failure and throttling can use bounded backoff; invalid data must be corrected; payload-too-large must be reported without silent truncation; ambiguous write results require follow-up verification before claiming success/failure.
- Do not retry indefinitely or report success before verification.

## Restore Contract
1. Load and validate the selected record.
2. Validate each supported appearance entry.
3. Skip only unsupported, deleted, unavailable or rejected entries and apply the remaining valid appearance.
4. Show partial-success feedback and identify skipped items where possible.
5. Rebuild CurrentOutfit/Wearing from the actual applied result.
6. Preserve the original SavedOutfit unchanged after partial restore. Only an explicit user save/edit/delete action may change it.
7. If the overall application fails and the result is untrusted, attempt baseline recovery, re-read the actual avatar state, and show an error if recovery cannot be confirmed.

## Runway Transfer (Future Candidate)
Main Outfit A → temporary Runway Outfit B → end of round → restore Main Outfit A.
After a Runway round, ask whether the player wants to save B. Save only after explicit confirmation; cancel/close means do not save. Runway is deferred and not a dependency of the current MVP.
