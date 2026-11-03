# FostercareNameplates

Nameplate features: health and auras, cast bars, class colors, scaling, enemy
cooldowns. Player guide: `docs/USER_GUIDE.md`. Regression tests:
`regressions/FostercareNameplates` in VanillaForge (90 tests).

| File | Job |
| --- | --- |
| `Core.lua` | DLL check (loaded, never a version), module registry and settings |
| `Helpers.lua` | Event and script helpers (`FNP.SetEventHandler`, `FNP.HookScript`) |
| `Lifecycle.lua` | Finds plates, binds them to unit GUIDs (`C_NamePlate`), plate unit events (`FNP.RegisterPlateEvent`), logout shutdown |
| `Details.lua` | Health text, auras, combo points, target glow, fading |
| `Scaling.lua` | Plate and cast bar size |
| `ClassColors.lua` | Class-colored health bars |
| `Castbars.lua` | Enemy cast bars |
| `Cooldowns.lua` | Observed enemy cooldowns |
| `ForgeUI.lua`, `ForgeLayout.lua`, `Media/` | VanillaForge ForgeUI kit (Ember) and its page layout, copied unchanged |
| `Settings.lua` | Settings: four pages built as sections, in the `/fnp` window (two columns) and as AddOn Options categories (one column, `UI.Book`); one live preview that moves to the page being placed |

Things to know:

- Work per plate per frame runs only while a module needs rendering
  (`FNP.RefreshRendering`). Keep per-frame callbacks cheap; queries are throttled.
- Never touch a plate at logout. The client is already freeing plates then;
  restoring them was followed by ERROR #124 (SGroupPtr invalid block,
  2026-10-22). `ShutdownNameplates` (Lifecycle.lua) only stops our events and
  timers, through each module's `shutdown`; a module with events or timers has one.
- A plate that gets a unit is drawn at once (`Bind` in Details.lua); hiding it
  and drawing a frame later made the health text flicker.
- Never re-anchor or re-font the engine's own plate regions (level, level icon,
  border, bar, dragon) from Scaling. 1.1.1 did (anchor offsets and level font
  scaled with the plate) and the client crashed on login (ACCESS_VIOLATION,
  2026-10-22); it was backed out. The raid mark re-anchor in Details predates it.
  To change how a native part looks, hide it by alpha and draw our own, like
  the level (`NP:Level`, setting `nameplate_level`; `PlaceLevel` centers it in
  the border's oval).
- No `...` in handlers or helpers on per-frame or event paths: in the client's
  Lua 5.0 each call builds an `arg` table, and the plate OnUpdate wrapper made
  about 320 KB/s at 40 plates (fixed in 1.4.3, KNOWN_PATTERNS KP-58).
- Unit events fire once per token naming the unit. Register them with
  `FNP.RegisterPlateEvent` (ClassicAPI `RegisterUnitEvent` for `nameplate1`...,
  grown when a plate takes a higher slot), so only the `nameplateN` one reaches
  Lua. "Targeting you" follows UNIT_TARGET (ClassicAPI 1.18),
  registered only while that option is on. Aura timers are native Cooldown frames
  (numbers only, threshold 60 s, `OnCooldownDone` redraws the row): they show while
  the player's `countdownForCooldowns` CVar is 1 and need no timer.
- Plate auras follow ClassicAPI's `UNIT_AURA_DELTA` (1.17.10): `NP:AuraDeltaShows`
  queues a row rebuild only when a refreshed spell is on the row or a new or lost
  aura moves its inputs (own debuff count, first crowd control, first two buffs),
  so other players' debuffs on an enemy cost no rebuild.
- Cast bars are event-driven: a cast event for the `nameplateN` token, or a plate
  getting its unit (ADDED, or PLAYER_ENTERING_WORLD), is the only time they ask
  `C_Spell`. The bar fills itself (`SetTimerDuration`, one duration object per
  bar) and the spark rides its texture. Other units' pushback is never sent to the
  client, so nothing re-asks during a cast. A 0.5 s backstop runs only while a bar
  is up, for a STOP that never came.
- A plate's unit binding is owned by ADDED/REMOVED alone: a unit that moves to
  another plate fires REMOVED (old frame) then ADDED (new frame) since 1.19. No
  polling of the binding.
- Cooldown icons use the native countdown with a formatter (`~%d`, `~%dm`,
  `C_StringUtil.CreateNumericRuleFormatter`); `OnCooldownDone` redraws the row.
  No ticker. Like aura timers, the numbers need `countdownForCooldowns` 1.
