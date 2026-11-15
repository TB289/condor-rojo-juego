# Fixes — 2026-11-15 (cave entrance + resize border)

Included in this package:

- Re-centered the cave entrance interact area on the skylight itself.
- Enlarged the cave entrance collision so `E`/interact works more reliably.
- Moved the cave prompt anchor slightly upward so the enter prompt is easier to read.
- Restored a fixed 640x360 world render path so window/browser resizing no longer reveals the map border.

Suggested test:
1. Load the `Study the caves` mission.
2. Walk directly onto the cave mouth and press `E`.
3. Confirm the mission step `Enter the cave` completes.
4. Resize the game window or browser.
5. Confirm the black void / world edge does not appear.
