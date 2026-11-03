# FostercareNameplates

Adjustable Blizzard-style nameplates for World of Warcraft 1.12.1. This addon runs
independently of [FostercareTweaks](https://github.com/Fostercare5988/FostercareTweaks).

## Features

- Independent plate size, optional UI-scale multiplier and target enlargement.
- Native raid target marks with adjustable size and position.
- Optional player class colors, health text, level sized with the plate, combo points and target emphasis.
- Optional fading of critters, totems, pets, grey-level and idle neutral units.
- Your debuffs, crowd control and optional enemy buffs, with the game's own countdown numbers.
- Nameplate castbars, grey for casts you cannot interrupt.
- Estimates of observed enemy-player cooldowns from the client's spell data.

Scaling, details, class colors, castbars and cooldown estimates each have their own
switch. Native names, mouseover and targeting stay with the game.

## Requirements

WoW 1.12.1 build 5875 with **ClassicAPI**, **SuperWoW** and **NamPower**.
Countdown numbers on auras and cooldown estimates show while the game's
`countdownForCooldowns` setting is 1 (`/console countdownForCooldowns 1`).

## Installation and settings

Download **Code → Download ZIP**, extract it into `Interface/AddOns`, and rename
the folder to `FostercareNameplates`. The folder must contain
`FostercareNameplates.toc`. Restart the game so the addon appears in the AddOns list.

**The addon starts disabled.** Enable it in the character selection AddOns list
when ready, then use **`/fnp`** for its settings and live preview. Your enemy
nameplate key binding still controls whether the game shows plates.
The settings master switch takes effect after `/reload`; other feature choices
apply live while enabled. Settings save per character.

The target-frame castbar stays in FostercareTweaks under **Unit Frames > Combat
details**. Its switch and grey-castbar option are independent of this addon's view.

## Performance and timing

Plates are found and bound to their units by ClassicAPI's nameplate events, and
unit events reach the addon only for nameplate units. Health and aura work is
coalesced into one update a frame; aura and cooldown timers are the game's own
countdowns. Castbars ask about a cast only when a cast event or a new plate says
so, and then fill themselves. Classes are asked once per unit. Cooldown
observations and spell data have fixed limits and stay out of SavedVariables.

Cooldown icons appear only after an observed enemy-player ability. `~` means the
timer is estimated: talents, resets and server rules can change real cooldowns.
An expired icon does not prove readiness.

Disabling this addon prevents all its files, events, hooks and timers from loading.

See the [user guide](docs/USER_GUIDE.md) for individual controls.
