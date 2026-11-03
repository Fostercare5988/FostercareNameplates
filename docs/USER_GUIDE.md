# FostercareNameplates User Guide

Type `/fnp` to open the settings window. The same four pages are also in
**Game Menu > AddOn Options > FostercareNameplates**, one category each
(General, Text & auras, Target, Casts), in one column at full size. Settings
save per character and apply right away, except the main switch. The preview
on every page shows a sample enemy with your choices: at the top right in the
window, at the top in AddOn Options. Its size is capped so it fits. Settings
that cannot take effect, because their feature is off, are dimmed.

## General

- **Use FostercareNameplates** is the main switch. Type `/reload` after changing
  it. Off keeps ordinary Blizzard plates and your target-frame castbar, and none
  of this addon's plate hooks or events run. Your other choices are kept.
- **Features** turn whole parts of the addon on or off: plate size, target and
  plate details (health and level text, auras, combo points, raid marks, fading),
  class colors, enemy castbars and enemy cooldowns. Each part that is off stops
  its events and timers.
- **Plate size** spans 0.1–4x, independent of the game's UI scale unless
  **Follow UI scale** is on. It resizes the bar, border and castbar. Names keep
  their stock size.
- **Reset settings** restores every option to its default. The main switch and
  feature switches stay as they are.
- The line above the button explains anything that stops the addon from working,
  such as another nameplate addon owning the plates.

## Text & auras

- **Health text**: off, percent, current health or both. By default only on your
  target.
- **Level in the level slot** shows the level in the round slot at the right end
  of the plate, sized with the plate and colored by difficulty. Skull-level units
  show ??. While it is on, the game's own level number and skull are hidden.
- **Combo points** show above your target's name. **Label NPCs targeting you**
  marks hostile non-player units whose target is you, as soon as their target
  changes. It shows targeting, not threat.
- **Raid marks** use the game's icon. Set 12–40 px and left, above-name or right.
  **Move raid marks** off puts them back where the game draws them.
- **Auras**: up to 1–6 of your debuffs (your pet's too), one crowd-control effect
  from any caster, and optionally two enemy buffs, at 14–32 px. The game counts
  them down while its `countdownForCooldowns` setting is 1, when it knows the timing.

## Target

- **Warm glow** highlights your target's plate. **Target size** enlarges it up to
  1.5x. **Other plates** sets everyone else's opacity while you have a target.
  Marked units stay at least 90% visible.
- **Fade** dims critters, totems, other players' pets and guardians, grey-level
  enemies, or neutral units not in combat, each with its own switch, to 10–80%.
  Your target and marked units never fade, and faded plates stay clickable.

## Casts

- **Castbars** keep the Blizzard texture and scale with the plate. Set the height
  and the gap below the bar. Grey bars are casts you cannot interrupt. This is
  separate from the target-frame castbar in FostercareTweaks.
- **Enemy cooldowns** show abilities seen used by enemy players, newest first,
  with a sweep and the game's countdown marked `~` as an estimate. Set 1–8
  icons, 14–40 px, the shortest cooldown worth showing and the space above the
  aura row, or show them only on your target.
- Base cooldowns come from the client's spell data. Talents, resets and server
  rules can change the real timer, so an expired icon does not prove readiness.
  Item cooldowns, pets and unseen abilities are not tracked. Observations clear
  on loading screens and are never saved.

## Turning the addon on

FostercareNameplates starts disabled. Enable it in the character selection
AddOns list. It never enables or disables FostercareTweaks, and while it is
disabled none of its files run. The game's enemy-plate key binding still decides
whether plates show. Restart the game once after first installing it.
