# FostercareNameplates

Nameplate features: health and auras, cast bars, class colors, scaling, enemy
cooldowns. Player guide: `docs/USER_GUIDE.md`. Regression tests:
`regressions/FostercareNameplates` in VanillaForge (30 tests).

| File | Job |
| --- | --- |
| `ClassicAPIRequirement.lua` | Stops loading without ClassicAPI 1.17.7+ |
| `Core.lua` | Module registry and settings |
| `Helpers.lua` | Event and script helpers (`FNP.SetEventHandler`, `FNP.HookScript`) |
| `Lifecycle.lua` | Finds plates and binds them to unit GUIDs (`C_NamePlate`) |
| `Details.lua` | Health text, auras, combo points, target glow, fading |
| `Scaling.lua` | Plate and cast bar size |
| `ClassColors.lua` | Class-colored health bars |
| `Castbars.lua` | Enemy cast bars |
| `Cooldowns.lua` | Observed enemy cooldowns |
| `ForgeUI.lua`, `Media/` | VanillaForge ForgeUI kit (Ember), copied unchanged |
| `Settings.lua` | Settings window: four ForgeUI tabs and a shared live preview |

Things to know:

- Work per plate per frame runs only while a module needs rendering
  (`FNP.RefreshRendering`). Keep per-frame callbacks cheap; queries are throttled.
- Never touch a plate at logout. The client is already freeing plates then;
  restoring them was followed by ERROR #124 (SGroupPtr invalid block,
  2026-10-22). `ShutdownNameplates` (Lifecycle.lua) only stops our events and
  timers.
- A plate that gets a unit is drawn at once (`Bind` in Details.lua); hiding it
  and drawing a frame later made the health text flicker.
- Never re-anchor or re-font the engine's own plate regions (level, level icon,
  border, bar, dragon) from Scaling. 1.1.1 did (anchor offsets and level font
  scaled with the plate) and the client crashed on login (ACCESS_VIOLATION,
  2026-10-22); it was backed out. The raid mark re-anchor in Details predates it.
  To change how a native part looks, hide it by alpha and draw our own, like
  the level (`NP:Level`, setting `nameplate_level`; `PlaceLevel` centers it in
  the border's oval).
