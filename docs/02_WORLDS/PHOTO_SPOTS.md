# Photo Spots

Status: current core feature, developed after Catalog/SavedOutfits and Club.

## Purpose
Create visually distinct places where players can pose and show off their catalog-styled avatars. Public photo-gallery posting, likes and style-copy feeds are out of scope.

## Candidate Locations
- Flower Garden
- Sunset Beach / Beach Resort
- Dream Aquarium underwater vista (candidate; needs swim/surface navigation prototype)
- Glasshouse Cafe Window
- Neon Rooftop City
- Fountain
- Moon Garden
- Flower Tunnel
- Mirror Room

House Garden is excluded while Housing is deferred. Runway Entrance is not required while Runway is deferred. The list is a candidate pool; build a small number first rather than committing to all locations. These names refer to areas of the whole world, not a requirement to create a separate photo-only map. See `docs/02_WORLDS/WORLD_CONCEPTS_AND_INTERACTIONS.md`.

## Per-Spot Specification
For each selected location, define actual placement, visual theme, camera framing, lighting, suitable poses, interaction points, entry/exit flow and multi-player behavior.

## Acceptance Criteria
- Each implemented spot provides a distinct composition.
- The avatar remains visible with the selected pose and camera framing.
- PC and mobile controls are usable.
- Players can enter/leave without becoming trapped or blocking ordinary movement.
- Studio tests record verified behavior separately from planned behavior.
