# v2.5.13.1 — Godot 4.7.2 parser hotfix

## Fix
- `scenes/mars/MountainRidge.gd` line 57: replace inferred `var a := ...` with explicit `var a: Vector2 = ...` to resolve the Godot 4.7.2 parse error shown in the debugger.
- `scenes/ui/Journal.gd` was **not modified**: it is byte-for-byte identical to v2.5.12, and its reported load error may be cascading from another script.
- No gameplay values, new spacecraft rooms, caves, missions, or UI layout were changed.

## Verify in Godot 4.7.2
1. Extract this ZIP into a **new clean folder** (do not merge with the broken project).
2. Open the `project.godot` in Godot 4.7.2 and allow asset import to complete.
3. From the editor, select **Project > Reload Current Project** if old script errors persist (a fresh folder is preferable).
4. Open `scenes/mars/MountainRidge.gd`: line 57 must show `var a: Vector2 = ...`.
5. Run the project (F5), start a game, place the solar panel, then test ship airlock, interior doors, cave, flashlight, and INTI.
6. If parsing still fails, open **Debugger > Errors**, click the first red error and share its complete message and file:line. The first root error is more useful than a cascading “Failed to load script” message.

This release has source/archive integrity validation only. A Godot executable was not available in this workspace, so in-engine compilation has not been verified.
