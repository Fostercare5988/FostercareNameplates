# FostercareNameplates User Guide

Open `/fnp` to configure this addon. Settings save per character.

**Use FostercareNameplates nameplate features** is the master switch. Type `/reload`
after changing it. Turning it off keeps ordinary Blizzard nameplates and your
independent target-frame castbar, and bypasses this addon's plate hooks, cast
queries and nameplate feature events. Individual feature choices are preserved;
**Reset nameplate settings** does not change the master switch. The remaining
settings apply live while the features are enabled.

- Feature controls and individual module switches apply live while enabled. The target preview uses sample values and caps its displayed scale at 2.5x so it fits the window.
- **Plate size** spans 0.1–4x independently of global UI scale. Optionally multiply by UI scale and enlarge the selected target by up to 1.5x. Existing base sizes migrate once. Scaling includes the health bar, border, level text and icons, and castbar, so the level stays inside the plate. Names keep their stock size; native targeting remains intact.
- **Target emphasis** enlarges the selected plate and offers adjustable opacity for other units. The optional warm highlight is off by default to preserve the stock bar and border. Marked units retain at least 90% opacity. Disable **Target emphasis, marks and details** for plain native visuals while retaining independent scale, class-color, castbar and cooldown modules.
- **Fade less important plates** dims critters, totems, other players' pets and guardians, grey-level enemies, or neutral units not in combat, each with its own switch. Choose 10–80% opacity. Your target and raid-marked units are never faded, and faded plates stay clickable. This belongs to **Target emphasis, marks and details**. All filters start off.
- **Raid target marks** use the game's native icon and visibility. Set 12–40 px size and left, right or above-name placement. Disabling adjustment restores native placement, without hiding marks. Unit-frame raid marks belong to FostercareTweaks and remain independent.
- **Health text** offers off, percent, current health or both. It defaults to target only. Values come from SuperWoW's native health queries.
- **Auras** show up to 1–6 of your debuffs, including your pet's, plus one crowd-control effect from any caster. A duplicated own CC effect appears once. Optionally show up to two enemy buffs. Choose 14–32 px icons. Countdown text is shown only when the client supplies timing; stacks appear in the corner. Aura and cooldown rows reserve separate space above the name.
- **Combo points** appear on the selected target. Optional **Targeting you** labels identify hostile non-player units whose current target is you; this indicates targeting, not threat lead or a guaranteed attack.
- **Castbars** retain the Blizzard texture, scale with the plate, and offer height and gap controls. **Grey bars for uninterruptible casts** controls this view independently of the target-frame castbar.
- **Enemy cooldowns** require NamPower 4.6.2+. Icons show the latest observed enemy-player abilities first, with a sweep and an estimated `~` timer. Set 1–8 visible icons, 14–40 px size, minimum base cooldown and extra space above the aura row. Optionally show cooldowns only on the target. Castbars remain below the plate.
- Base cooldowns come from the current client's spell data, including custom spells with that data. Talents, reset abilities, delayed cooldown starts and server-side rules can change the actual timer. An expired icon does not prove readiness. Item-only cooldowns, pets and unobserved abilities are not tracked.
- Observations survive a plate leaving view until their estimated expiry. World transitions clear them. The tracker uses no saved enemy database or sound alerts.
- **Reset nameplate settings** restores this page's visual/detail preferences. Other frames and module enable choices are kept. BlizzNameplatesPlus and ShaguPlates keep ownership of their plates; FostercareNameplates stays inactive for nameplates while either is loaded.


## Independent addon controls

FostercareNameplates starts disabled. Enable it in the character selection AddOns
list when ready. Enabling or disabling this addon never enables or disables
FostercareTweaks. When disabled, none of its Lua files, hooks, timers or event
handlers run. The game's enemy-plate key binding still controls plate visibility.
Use a full game restart when first installing the addon so the client discovers it.

The settings master switch preserves your individual choices and takes effect
after `/reload`. Other module switches apply immediately while the master is on.
Turning off castbars or cooldown estimates removes that feature's cast listeners;
cooldown estimates also stop their ticker. Turning off details clears its display,
countdowns and event listeners. Turning off scaling removes its UI-scale listener.

## Existing Tweaks settings

On the first enabled load, the addon copies existing nameplate preferences from
FostercareTweaks if that addon is enabled. Keep both enabled for this first import;
afterward either addon can run alone. The original Tweaks table is left intact.
Existing FostercareNameplates settings take precedence. Only nameplate scalar
settings and the initial uninterruptible-cast color choice are copied; no frame
settings, caches or enemy observations are shared.
