# Rover sprites

These game-sized sprites were resized from the AstroSharks team's `sprites.zip`:

- `sojourner.png` from `soujourner.png` (source filename as supplied)
- `spirit.png` from `spirit.png`
- `opportunity.png` from `Opportunity.png`
- `curiosity.png` from `curiosity.png`
- `perseverance.png` from `Perseverance.png`

`scenes/mars/MarsMap.gd` now assigns them to the five corresponding rover mission objects.
The pushable camp rover uses Perseverance art via `assets/art/base/rover.png`.
Artwork was scaled to 64 game pixels wide, using nearest-neighbour interpolation.

Existing rover missions, objective targets, hitboxes, and positions are preserved.
