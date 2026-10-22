# FostercareNameplates

Adjustable Blizzard-style nameplates for World of Warcraft 1.12.1. This addon runs
independently of [FostercareTweaks](https://github.com/Fostercare5988/FostercareTweaks).

## Features

- Independent plate size, optional UI-scale multiplier and target enlargement.
- Native raid target marks with adjustable size and position.
- Optional player class colors, health text, level sized with the plate, combo points and target emphasis.
- Optional fading of critters, totems, pets, grey-level and idle neutral units.
- Your debuffs, crowd control and optional enemy buffs with available duration data.
- Nameplate castbars, with separate controls for size and uninterruptible casts.
- Optional estimates of observed enemy-player cooldowns using current client data.

Scaling, details, class colors, castbars and cooldown estimates each have their own
switch. Native names, mouseover and targeting stay with the game.
BlizzNameplatesPlus and ShaguPlates take precedence when loaded.

## Requirements

WoW 1.12.1 build 5875, **ClassicAPI 1.16.0+** and **SuperWoW 2.2+**.
**NamPower 4.6.2+** is optional and enables enemy cooldown estimates.
FostercareTweaks is optional. If installed, update it to **1.3.0+** for the split.
Older builds with active nameplate features take precedence to avoid duplicate hooks.

## Installation and settings

Download **Code → Download ZIP**, extract it into `Interface/AddOns`, and rename
the folder to `FostercareNameplates`. The folder must contain
`FostercareNameplates.toc`. Restart the game so the addon appears in the AddOns list.

**The addon starts disabled.** Enable it in the character selection AddOns list
when ready, then use **`/fnp`** for its settings and live preview. Your enemy
nameplate key binding still controls whether the game shows plates.
The settings master switch takes effect after `/reload`; other feature choices
apply live while enabled. Settings save per character.

For existing FostercareTweaks users, keep both addons enabled on the first load to
copy your nameplate preferences automatically. Existing new-addon preferences
take precedence. After importing, either addon can run alone. Original Tweaks
settings remain intact, and no caches or runtime objects are shared.

The target-frame castbar stays in FostercareTweaks under **Unit Frames > Combat
details**. Its switch and grey-castbar option are independent of this addon's view.

## Performance and timing

Plate discovery uses ClassicAPI lifecycle events and verified GUID bindings.
Health and aura work is coalesced; aura countdowns use a shared ticker only while
timed rows exist. Classes are cached per GUID. Cast animation runs at render rate,
with bounded cast-state reconciliation. Cooldown observations and spell metadata
have fixed limits and stay out of SavedVariables.

Cooldown icons appear only after an observed enemy-player ability. `~` means the
timer is estimated: talents, resets and server rules can change real cooldowns.
An expired icon does not prove readiness.

Disabling this addon prevents all its files, events, hooks and timers from loading.
Separating it makes performance isolation possible; it does not establish a cause
for client stutters or guarantee native crash safety.

See the [user guide](docs/USER_GUIDE.md) for individual controls.

The initial implementation was extracted from FostercareTweaks commit `99263b7`,
including its native-plate safeguards and existing Blizzard-style UI approach.
