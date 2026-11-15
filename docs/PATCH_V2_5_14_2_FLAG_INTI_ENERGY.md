# Cóndor Rojo v2.5.14.2 — Flag / INTI / Energy

## Startup flow

1. Start a **New Game** (the change affects new missions, not previously parked in-memory runs).
2. The Ecuadorian flag is initially absent from the surface. A transparent flag preview follows the cursor or faces the player's last walking direction.
3. Find a **green** location close to the landed ship; press **E** or left click to plant it. Red means blocked or too far away.
4. The flag becomes permanent, and the "Plant the Ecuadorian flag" mission completes.
5. The **solar panel** preview now appears. Place it with **E** or click and then approach it to clean it.
6. Once the entire starter placement queue is done, the normal sol clock and mission actions continue.

## UI

- INTI uses the same regular m5x7 typeface at **16 px** as the mission tracker (top right). It is no longer tiny or bold.
- Placement instructions hide while INTI's dialogue is open, so the two boxes do not overlap.

## Resources

- In the pressurized ship, the suit oxygen value is preserved (no passive drain and no automatic refill).
- The energy value keeps decreasing **at 10 units per real minute**, including inside the ship, unless the game is paused or a modal sleep journal is open. Energy loss is intentionally paused during the initial placement sequence.
- Cave and outdoor oxygen behavior are unchanged.

## Checks

Project resource/JSON references and mission-order assertions passed. Godot was not available here, so **in-editor gameplay validation is still needed**.
