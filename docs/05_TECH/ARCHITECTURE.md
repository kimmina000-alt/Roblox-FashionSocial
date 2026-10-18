# Technical Architecture

## Places
- Main Social: current primary experience.
- Runway: future candidate Place; not required by current MVP.
- Add another Place only when a validated feature requires it.

## State Layers
- PLATFORM STATE: Roblox-owned items and platform inventory.
- GAME PERSISTENT DATA: SavedOutfits (maximum 50/user), Favorites, and only approved implemented settings/progress.
- SESSION STATE: server-confirmed CurrentOutfit, CurrentPlace, Recent, and (only when Runway is implemented) temporary RunwayOutfit/ActiveRunway.
- HOUSING DATA: deferred; not part of current MVP schema.

## Authority
Client = input/presentation and temporary drafts. Server = validation, actual applied appearance, saved records and final operation results.

## Design Rules
- Official Roblox APIs first.
- Current Outfit/Wearing are derived from the server-confirmed applied appearance.
- A SavedOutfit is a versioned snapshot of supported appearance data, not merely a list of untyped numeric IDs.
- Never treat temporary try-on as Roblox ownership.
- Preserve saved records during partial restore; skip only individual unavailable/unsupported entries.
- Implementation and Studio verification are tracked separately.
