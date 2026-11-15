# Cóndor Rojo v2.5.13 — unified spacecraft, ridges, cave flashlight, clearer INTI

Changes built on top of v2.5.12; the custom HTML loader and existing accessibility/touch controls remain.

## Surface
- The lander sprite is replaced by `assets/art/base/ship_integrated.png`: an integrated crew, crops and science spacecraft with an airlock (E).
- Habitat, greenhouse and antenna modules are docked into the ship at the start. They still register with missions and the nightly resource system, but they no longer appear as detached exterior buildings. The oxygen reserve is still **inside** the living area. Solar panels are still placed outside by the player.
- `MountainRidge.gd` renders solid, shaded terrain obstacles. A large ridge blocks the straight northern approach; mission trail routing bends around it. Additional ridges appear where they cannot cover missions, spawn or trails.
- The rover, Mars biomes, cave mouth, minimap, mission logic, and world boundary code remain.

## Interior
- Use the exterior ship airlock (E) to enter the pressurized **Living** bay.
- In Living, use the small cyan **Lab** doorway on the upper-right to access the science bay, and the **Crops** doorway on the lower-left to reach the greenhouse if the selected kit includes that module.
- Lab and greenhouse have internal return passages to Living. Only Living has an exterior exit. The cave remains separate with its own exit.
- The greenhouse plants and mission target are unchanged. The tank near the right side of Living takes 2 seconds to refill the suit and recharges over 120 in-game minutes.

## Visibility and UI
- Lava-tube interior now has full darkness at any sol time. The helmet flashlight switches on when entering and can be toggled with **F**. It uses energy.
- The HUD remains visible above the darkness mask.
- INTI's box size and portrait dimensions are unchanged. Dialogue/tips now use the bundled Silkscreen Bold for clearer glyphs, cream on navy with a dark outline.

## Gameplay smoke-check in Godot 4.7
1. Choose **Safe** kit, place the **solar panel outdoors**, enter the single spacecraft airlock with E.
2. In Living, stand by the oxygen station (right) and press E. Check that it refills the suit, not just the bar; exiting/re-entering does not refill the tank instantly.
3. Follow the **Lab** doorway and return using the **Living** doorway; try leaving the ship via its Living exit.
4. Start another game with the **Farmer** kit. Verify that a **Crops/Greenhouse** passage appears, plants are interactive, and the greenhouse mission can complete.
5. Walk north toward the lava-tube cave: the first large escarpment should force a detour. Use the mission arrow, then press E at the cave opening.
6. Inside the cave, check that the room is dark except for a small nearby circle and the helmet beam. Press F to switch the beam off/on; E at the exit returns to the surface.
7. Open INTI with Tab, review readable text with the same-sized box, and resize the game window or try touch controls.
8. Open Options: accessibility color modes should still be present. Confirm the rover can still be pushed.

Source and resource validation can run in this environment; **a live Godot/editor/export runtime is unavailable here**. Please perform the in-engine smoke test before publishing the browser build.
