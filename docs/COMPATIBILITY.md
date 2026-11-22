# Compatibility and implementation evidence

## Baseline

- Target: WoW Forever **1.60.1.71037**, interface **16001**, Lua 5.1. Other WoW editions are rejected by this preview.
- Installed client's build metadata matched the target during implementation on 2026-11-21. This proves installation metadata, not gameplay execution.
- Blizzard UI/API source mirror pinned to commit `734f065329cff4992835b01a84f210a297db91b6`, whose commit identifies build 1.60.1 (71037).
- No live game interaction was available during implementation. Every class/environment below remains pending live verification.

## Source contracts

- [Nameplate API](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/NamePlateDocumentation.lua): request normal plates without `includeForbidden`; still inspect `IsForbidden()` before accessing native children.
- [Native base plate](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlateBase.lua): `unitToken` identifies displayed unit; native `UnitFrame` can be pooled separately from base plate. Addon-owned root follows its current base.
- [Threat/cast/unit API](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua): threat, unit identity, and cast information can be restricted. Only readable tanking states 2/3 activate ally cue; nil/secret values never imply absence of danger.
- [Spellbook API](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua): resolve active known player/pet entries; exclude off-spec/passive entries; use slot/bank APIs for range, usability, cooldown info, and native duration objects.
- [Cooldown structure](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua): `isActive`/`isEnabled` are documented NeverSecret, but code guards them anyway. Active global cooldown also prevents ready emphasis. Restricted timing is not calculated in Lua; native cooldown widget renders duration object. `isOnGCD` is not trusted outside its documented event boundary.
- [Aura filters](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_FrameXMLUtil/AuraUtil.lua): `HARMFUL|RAID` is player-dispellable harmful effects; `RAID_PLAYER_DISPELLABLE` means someone in group, not necessarily this character, so it is not used as player capability evidence. Enemy queries use `HELPFUL|DISPELLABLE`, followed by learned removal-type matching.
- [Native aura renderer](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlateAuras.lua): secure post-hooks track normal aura instance IDs without writing native records. Visible matching icons get addon-owned outlines; missing effects get at most one stable fallback icon. Native aura ordering and visibility stay unchanged.
- [Native artwork](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlates.xml): ally glow references native aggro flare and mask; no custom artwork package.

## Class coverage

All nine Forever classes have capability records and automated resolution tests. The table describes implemented families, **not live-certified spell behavior**. IDs/ranks are curated trainer families, gated by actual active spellbook presence. Client changes or unknown new ability families require a record update; arbitrary spell names are not parsed to guess abilities. Runtime base/action IDs handle active overrides of recorded families.

| Class | Interrupt families | Removal families | Automatic range references | Live status |
| --- | --- | --- | --- | --- |
| Warrior | Pummel, Shield Bash | None | Hamstring, Heroic Strike | Pending |
| Paladin | None | Cleanse/Purify: friendly Magic/Poison/Disease as learned | Judgment; Holy Light | Pending |
| Hunter | None | Tranquilizing Shot: Enrage | Arcane Shot | Pending |
| Rogue | Kick | None | Sinister Strike | Pending |
| Priest | None | Dispel Magic: friendly/enemy Magic; Cure/Abolish Disease | Smite; healing families | Pending |
| Shaman | Earth Shock | Purge: enemy Magic; Cure Poison/Disease | Lightning Bolt; Healing Wave | Pending |
| Mage | Counterspell | Remove Lesser Curse: friendly Curse | Frostbolt | Pending |
| Warlock | Felhunter Spell Lock | Felhunter Devour Magic: friendly/enemy Magic | Shadow Bolt | Pending |
| Druid | Feral Charge in Bear/Dire Bear | Remove Curse in caster/Moonkin; Cure/Abolish Poison in caster form | Claw/Maul/Wrath by form; Healing Touch in caster form | Pending |

No Retail Counter Shot, Rebuke, Wind Shear, or Skull Bash is imported. Stuns/fears do not become general interrupts. Hunter and Paladin's lack of a general interrupt is also stated in Blizzard's [Hunter/Druid class overview](https://worldofwarcraft.blizzard.com/en-us/news/24301515/) and [Paladin overview](https://news.blizzard.com/en-gb/article/24302099/world-of-warcraft-forever-class-deep-dives-paladin).

Default range families are finite convenience choices. User may select another active learned harmful/helpful spell. Nil range results stay unknown; spell range can include a minimum range and does not establish line of sight.

## Environment matrix

| Environment | Intended behavior | Verified |
| --- | --- | --- |
| Solo/open world | Enemy interrupts/removals and target range; no unrelated-player aggro | Mocked only |
| Open-world party/raid | Above plus accessible group-player aggro/dispels | Mocked only |
| Dungeons/raids | Same where native plate access permits; forbidden friendly plates skipped | Live access and taint pending |
| Duels/battlegrounds | Enemy-player casts/range/removals when readable; restricted information suppressed | Live PvP pending |
| Combat login/new plates | Protected attachment queued; ordinary unprotected plates attach during combat | Mocked only |
| Native name-only/classic/modern styles | Owned cues follow available native anchors | Actual rendering pending |
| EllesmereUI Nameplates/other replacements | Native attachment suspended; user settings untouched | Loaded-addon detection mocked; real integration pending |

`/fplates status` reports current configuration, resolved capabilities, last skipped plate, and restrictions encountered since reload. It stores no combat trace or player names.

## Release gate

Automated results do not certify engine restrictions, actual class spells, visual readability, or PvP legality/availability. Before a validated release, complete [in-game checks](IN_GAME_TESTING.md). Any blocked approved feature must be reported explicitly; no forbidden-frame bypass or hidden party-frame replacement is an acceptable substitute.

## 0.1.1 live-error correction

A user session on 2026-11-21 recorded 1,790 repeats of one `Backdrop.lua:226` error: the native backdrop size callback attempted arithmetic on a secret width while execution was tainted by ForeverPlates. This establishes a live failure in the 0.1.0 aura-outline path, not complete gameplay verification.

Aura outlines now use four one-pixel solid textures positioned with native anchors. They have no BackdropTemplate, size callback, Lua dimension reads, or tiled texture-coordinate arithmetic. Regression tests reproduce the native backdrop size calculation with a restricted-dimension fixture: old outline fails, replacement survives repeated layout, combat reuse, and aura removal. User must `/reload` to discard already-created 0.1.0 backdrop frames. Post-fix live verification remains pending.
