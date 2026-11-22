# In-game preview checklist

Status: **checklist results not yet recorded**. A 0.1.0 user session logged repeated restricted-width errors in aura outlines; 0.1.1 fixes the reproduced path, with live retest pending. Start by using `/reload` and repeating enemy purge/ally dispel aura display while moving camera and entering combat; confirm error flood stops. Record client build, class/level, talent setup, pet/form, zone/content, actual outcome, and Lua/taint errors for each test. Do not record account identifiers or other players' personal data.

## Load and native behavior

1. Install packaged folder, restart client, enable Forever Plates, and open `/fplates`. Run `/fplates status`; confirm build/interface and ability families.
2. Test with stock plates. If a replacement is loaded, confirm status names it and no added visuals attach. Disable its nameplate module manually and reload. Leave all other settings unchanged.
3. Toggle every feature off: Blizzard plate visibility, layout, fonts, threat colors, cast shields/highlights, and auras must match baseline. Added visuals must disappear and click targets remain unchanged.
4. Enable only ally aggro. Test glow, icon, and color in classic/modern/name-only native styles, different native nameplate sizes, UI scales, and crowded scenes. Check color restoration after role/faction/death changes.

## Ally aggro and restrictions

1. Group with tank, healer, and damage player. Pull NPCs; expect cue only for player actually tanking, not merely approaching aggro. Transfer aggro and verify old cue clears.
2. Test assigned-tank exclusion, unassigned roles, raid membership, unrelated friendly players, pets, and own personal resource plate.
3. Enter dungeon and raid. Record whether friendly plates are accessible or forbidden. Forbidden plates must remain untouched, even if this means ally feature unavailable there. Report restriction as a feature limitation.
4. Reload/login in combat and let new plates appear during combat. Protected attachment/color restoration may wait until combat ends; no blocked-action/taint errors are acceptable.

## Interrupts and range

1. Shaman: cast/cooldown Earth Shock, exhaust resources, test higher/lower ranks, and move across its range boundary. Green emphasis requires all readiness inputs. Test global cooldown separately.
2. Hunter/Paladin: no invented interrupt cue. Warrior: Pummel/Shield Bash, correct stance/equipment/resources. Druid: Feral Charge range and Bear/Dire Bear versus other forms. Mage/Rogue: Counterspell/Kick. Warlock: Felhunter Spell Lock, pet death/dismissal/swap and pet-versus-player range.
3. Test two visible enemies casting simultaneously, interruptible channels, uninterruptible casts, interrupted/failed/finished casts, and hidden native cast bars.
4. Hunter: Arcane Shot range, including minimum range if applicable. Melee: cross reference-spell range boundary. Healer: switch friendly/hostile targets and verify reference changes. Nil/unknown range must not show out-of-range cue.
5. Choose another learned reference in settings; switch talent groups, learn new ranks, change forms, and reload. Invalid/unlearned selections must return to Automatic.

## Removal cues

1. Shaman: Purge enemy Magic, friendly Poison/Disease. Hunter: Tranquilizing Shot against Enrage, not ordinary Magic buffs.
2. Mage: Curse only. Paladin: correct types before/after learning Cleanse. Priest: friendly/enemy Magic and friendly Disease. Druid: Curse/Poison with form changes. Warlock: Devour Magic with current live pet.
3. Confirm cooldown/resource depletion does not turn this capability cue into a readiness promise. Effects outside character's removal types must not highlight.
4. Test native aura row enabled/disabled: visible eligible icons get outlines; missing eligible effects get at most one compact fallback. No native ordering/visibility changes and no duplicate icon for same effect.
5. Refresh/remove an effect, add another, and recycle plates. Fallback should retain selected effect until ineligible/removed; all stale outlines/icons must disappear.

## PvP, persistence, and performance

1. Duel and enter battleground. Test enemy-player casts, harmful/helpful target ranges, enemy buffs, friendly dispels, and restricted data. No guessed readiness or NPC-threat interpretation of player targeting.
2. Test shared settings across characters, character override isolation, shared/independent switch, active talent groups, and `/reload` persistence.
3. Run through many mobs, pan camera, change targets, join/leave group, and switch forms/pets. Look for stale icons, wrong base-plate parenting, allocations growing after reuse, or frame-time spikes.
4. Enable script errors/taint logging manually if desired; inspect actual errors. No live acceptance claim until these checks have recorded results.
