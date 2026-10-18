# Photo System

## Goal
Photo Spots let players show off their catalog-styled avatars through distinctive compositions, lighting, poses and backgrounds. Photo-taking is an in-world activity, not a public gallery feature.

## Current MVP
- A small set of visually distinct photo locations.
- Intentional framing and lighting that keep the avatar visible.
- A small set of useful poses.
- Camera controls that remain usable on PC and mobile.
- Group-photo feasibility where it can be implemented without destabilizing the core camera flow.
- Clear entry/exit and interaction points at each spot.

## Photo Spot Design Contract
For each location, define:
- Visual theme and background
- Camera angle, framing and distance
- Lighting and any intended time-of-day treatment
- Suitable poses and interaction points
- How players enter/leave and how multiple players share the area
- Mobile camera visibility and accessibility

Candidate locations: Flower Garden, Sunset Beach, Cafe Window, Rooftop, Fountain, Moon Garden, Flower Tunnel and Mirror Room. These are candidates, not a commitment to build all of them in the first pass.

## Out of Scope
- Public in-game photo gallery posting
- Likes/reactions on posted photos
- Public style-copy feed
- House Garden as a dependency while Housing is deferred
- Runway Entrance as a dependency while Runway is deferred
- Advanced filters, extensive weather/time controls until the core photo flow is validated
