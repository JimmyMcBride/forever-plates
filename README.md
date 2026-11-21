# Forever Plates

Small functional additions to Blizzard's nameplates for **WoW Forever**. Keeps Blizzard's layout, fonts, enemy threat colors, cast bars, and aura settings.

**0.1.0 preview:** automated checks pass; actual client rendering, combat/taint behavior, dungeon/raid access, and PvP behavior are **not yet live verified**. See [compatibility](docs/COMPATIBILITY.md) and [in-game checks](docs/IN_GAME_TESTING.md). This is a testing preview, not a certified all-class release.

## Features

- **Ally aggro:** highlights other group players actually holding NPC aggro. Blizzard-style glow defaults on; small icon and temporary health-bar color are alternatives. Optional assigned-tank exclusion. Unrelated players, pets, and your personal resource plate are excluded.
- **Interrupt availability:** one ability icon beside each visible, accessible enemy cast bar. Shows native cooldown sweep. Green emphasis requires a known interruptible cast, learned/usable ability, inactive cooldown, and positive per-unit range result. Unknown information stays neutral; known uninterruptible casts get no extra cue.
- **Target range:** small indicator only when current target is explicitly out of selected spell's range. Automatic hostile/healing references, with optional learned-spell selection for each character's talent setup. This checks spell range, not line of sight.
- **Purge/dispel:** outlines existing aura icons for effects your current class/form/pet can remove. Adds at most one compact aura icon for eligible effects Blizzard isn't displaying. Cue means removal capability, not cooldown, resource, or range readiness.

All features are independently switchable. No automatic targeting, casting, chat announcements, Blizzard setting changes, or other-addon configuration changes. Mouse clicks pass through added indicators.

## Install

1. Use the installable `ForeverPlates-0.1.0-preview.zip` from a preview download or CI artifact, or build it using the commands below.
2. Extract its `ForeverPlates` folder into your Forever client's `Interface/AddOns` directory. Expected path: `<WoW>/_forever_/Interface/AddOns/ForeverPlates/ForeverPlates.toc`.
3. Restart game for a new addon installation; enable **Forever Plates** at character selection. Updates to an existing installation can use `/reload`.
4. Enable desired friendly/enemy plates in Blizzard's settings. Forever Plates does not change their visibility or enable native aura/cast options.
5. Use `/fplates` or **Options → AddOns → Forever Plates**. Use `/fplates status` for client, capabilities, spell choices, conflicts, and observed restrictions.

GitHub's source-code ZIP is not the installable package: its root directory must be renamed `ForeverPlates`, or use the package script.

## Settings

Visual and feature settings are shared across characters by default. **Use independent settings for this character** copies shared settings on first use. Returning to shared settings retains that independent copy. Range spell selections always stay character-specific, keyed by active talent group; invalid/unlearned selections return to Automatic.

All five feature toggles default on. Aggro style defaults to glow, and tank exclusion defaults off. Spell capabilities refresh after learning spells, changing talents/specs/forms, and pet changes. Some classes have no general interrupt; their interrupt cue stays absent. Lower learned interrupt ranks remain candidates when a higher rank is unusable.

## Restrictions and other nameplate addons

Forbidden plates cannot be decorated. Restricted cast, range, threat, or aura data may make individual cues unavailable, especially in PvP or restricted group content. Unknown information never becomes a ready/safe claim. Aggro describes NPC threat, not which player an enemy player is targeting.

Attachment pauses when EllesmereUI Nameplates, Plater, Threat Plates, Platynator, or ElvUI is loaded. Disable the conflicting nameplate addon/module and reload to test with stock plates. Detection is deliberately conservative; customization modules are not controlled automatically. Other independent threat meters do not trigger suspension.

Protected attachment or health-color restoration can be deferred until combat ends. The addon does not circumvent forbidden-frame or secret-value restrictions. No replacement party-frame fallback is installed.

## Development

Requires Python 3 and Lua 5.1 (`lua5.1`, `luac5.1`):

```sh
python3 tools/check.py
python3 tools/package.py
```

Package output: `dist/ForeverPlates-0.1.0-preview.zip`, with a single `ForeverPlates/` directory. CI runs the same checks and uploads that ZIP as an artifact. No third-party runtime libraries; built-in `Blizzard_NamePlates` dependency ensures native mixins exist before attachment.

Modules separate settings, class capability records, pure decisions, client API access, visual attachment, options, and event coordination. Added visuals are reused across plate recycling. One shared 0.2-second updater handles relevant range/interrupt changes; aura/threat updates use events.

MIT license covers original addon source. Blizzard assets are referenced from the installed client, not distributed in this repository.
