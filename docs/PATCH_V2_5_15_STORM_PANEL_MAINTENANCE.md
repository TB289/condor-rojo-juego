# Cóndor Rojo v2.5.15 — Persistent solar dust + storm aftermath

This patch branches from **v2.5.14.3-rover-sprites-fixed**. It is an independent gameplay branch while the other teammate fixes the INTI dialogue typography. It does **not** edit the INIT/INTI scripts, fonts, text, or scene layouts.

## Changes

- New `GameState.solar_panel_dust` percentage (0–100) tracks persistent panel grime. It resets with a new game, but **does not disappear on its own when a weather flag expires**.
- The solar panel starts lightly dirty (25%) when first deployed, matching the first `fix_solar_panel` mission. Completing the real cleaning objective restores it to 0%.
- Each later sol adds 8% dust if a panel is present. A live daytime storm adds 48%; a journal-night dust storm adds 42%, unless the player selected its *go out and clean* option. Dust builds up over successive events to at most 100%.
- Panel efficiency falls gradually as dust increases, down to 38% at maximum accumulation, combined with the existing temporary weather/loose-panel penalties. The already-provided clean and dusty sprite textures switch automatically; the module card can show dust percentage when inspected.
- Approach a dusty panel and press **E** to perform the existing 1.5-second cleaning service; no new key, UI panel or tutorial is introduced. Damaged panels must be repaired first, then cleaned. The familiar bar, mission prompt and notes are retained.
- Daytime storms now last 22 real seconds and ease in (3 seconds) and out (4 seconds), so the atmospheric veil, drifting dust and 28% maximum movement slowdown track the same smooth intensity.
- The storm clock stops while the game/journal is paused or a cutscene is playing, and gets reset for new games.
- Storm damage is possible but rarer than dust: 28% for an undamaged solar panel, 15% for an undamaged undocked auxiliary module. The aftermath log reports specific equipment damage and panel dust; a short HUD notice directs the player to check/clean it.

## Verification in Godot 4.7

1. Start a **new game**. Plant the Ecuadorian flag, deploy the solar panel and see the dirty artwork. Complete `fix_solar_panel` by interacting; expect clean artwork and dust of 0%.
2. Advance through a couple of sols. Dust should persist and the sprite should become dirty again at 16% or above. Walk to the panel, press **E**, finish the service, and confirm the clean sprite returns.
3. In a debug build, use **F9** on the Martian surface after placement. Watch the red haze and movement speed ramp gradually up and back down. Open the habitat: astronaut movement indoors should not be slowed. Let the storm finish and check the brief HUD notice and longer journal note.
4. Inspect/clean or repair the panel after the storm. If damage rolled, repair the module then clean the dust on a second interaction. Repeat F9 after the previous storm ends to verify new dust accumulates rather than resetting.
5. Sleep through a *dust_storm* journal event and select **shelter**: the panel remains dirty the next day. On another *dust_storm* journal event select **go out and shake**: its dust clears by the next sol (except the small daily 8% deposit).
6. Recheck oxygen/energy rules in the habitat, INTI Tab behavior, flag→panel ordering, rover art, mission progression and opening/closing the menu. Those systems were not intentionally changed here.

## Merge guidance

When the teammate's INTI build is available, compare both source trees against `v2.5.14.3-rover-sprites-fixed` and port the **specific gameplay changes**, rather than replacing the teammate's project wholesale. Changed GDScript files:

- `autoload/GameState.gd`
- `autoload/DayNightSystem.gd`
- `autoload/MissionSystem.gd`
- `scenes/base/BasePlacer.gd`
- `scenes/base/BaseModule.gd`
- `scenes/player/Player.gd`
- `scenes/mars/DustDrift.gd`
- `scenes/mars/DustVeil.gd`
- `scenes/ui/ModuleInfoPanel.gd`
- `systems/WorldEventDirector.gd`

No sprite, rover image, sound, mission JSON, INIT/INTI or Godot UI scene was replaced. Keep the teammate's INTI updates during conflicts. This is a **Godot source project**, not a pre-exported executable/browser release. No Godot binary is installed in this environment; source/reference validation was performed, but in-engine playtests remain to be done before a final release.
