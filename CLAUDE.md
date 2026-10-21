# FostercareNameplates

Nameplate features: health and auras, cast bars, class colors, scaling, enemy
cooldowns. Player guide: `docs/USER_GUIDE.md`. Regression tests:
`regressions/FostercareNameplates` in VanillaForge (14 tests).

| File | Job |
| --- | --- |
| `ClassicAPIRequirement.lua` | Stops loading without ClassicAPI 1.16.0+ |
| `Core.lua` | Module registry and settings |
| `Helpers.lua` | Event and script helpers (`FNP.SetEventHandler`, `FNP.HookScript`) |
| `Lifecycle.lua` | Finds plates and binds them to unit GUIDs (`C_NamePlate`) |
| `Details.lua` | Health text, auras, combo points, target glow, fading |
| `Scaling.lua` | Plate and cast bar size |
| `ClassColors.lua` | Class-colored health bars |
| `Castbars.lua` | Enemy cast bars |
| `Cooldowns.lua` | Observed enemy cooldowns |
| `Settings.lua` | Settings window |

Things to know:

- Work per plate per frame runs only while a module needs rendering
  (`FNP.RefreshRendering`). Keep per-frame callbacks cheap; queries are throttled.
- At logout the client can free a plate's child frames before `Shutdown` runs;
  `Visible` skips them.
