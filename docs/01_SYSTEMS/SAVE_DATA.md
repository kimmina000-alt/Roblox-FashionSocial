# Save Data

Status: design requirements; implementation and rejoin persistence are not yet confirmed.

## Persistent Data
- SavedOutfits: game-only versioned appearance snapshots; maximum **50 per user**.
- Favorites: game-only user favorites, separate from Roblox account favorites.
- Settings/Progress: only add fields when the corresponding feature is approved and implemented.
- Housing and furniture data: deferred; not part of the current MVP.

## Session Data
- CurrentOutfit / Current Avatar: derived from the server-confirmed applied appearance.
- Recent: every item successfully worn at least once in the current session, kept even if removed immediately.
- CurrentPlace.
- ActiveRunway and temporary RunwayOutfit: future Runway feature only.

## Failure Handling
- Transient service/network failure: bounded retries with backoff; if exhausted, preserve existing data and offer retry.
- Request throttling: prevent duplicate clicks, wait before retrying and respect request budgets.
- Invalid/unserializable payload: validate and report; do not retry the same invalid data indefinitely.
- Payload too large: reject before write and explain that the saved data is too large; never silently truncate fields.
- Ambiguous write result: verify with a follow-up read that bypasses cache before reporting success/failure or blindly retrying.
- Load/migration failure: distinguish error from empty Wardrobe; never overwrite valid data with an empty default.
- Unavailable/unsupported Outfit item: skip only that item during restore, apply the remaining valid appearance and identify the skipped item where possible. Preserve the original SavedOutfit.

## Data Integrity
- Server-side validation and protected DataStore calls.
- Versioned schema and migration checks.
- Preserve previous valid data until replacement is validated and the write result is confirmed.
- Keep implementation, user-confirmed behavior and Studio test status separate.
