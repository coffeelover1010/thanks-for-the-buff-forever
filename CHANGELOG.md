# Unreleased

- Fix thanking on login for a buff carried over from the last session (for example Mark of the Wild still active after logging out).
- The login and post-combat quiet windows now use a real-time clock: `GetTime()` is stale after a loading screen, so the 5-second window had already expired by the time aura data arrived.
- Only buffs with close to their full duration remaining count as newly cast; run-down buffs that appear late are recorded but not thanked. Recasts that refresh a buff are still thanked.
- All 14 offline test scripts passed, including a reproduction of the logged 2026-10-11 login thanks.

# 0.4.4-beta

- Fix missed thanks for Renew and other helpful effects when the giver is identified by player GUID without a visible unit.
- Fix the Buff mouseover keybinding category.
- Preserve self, NPC, unknown-effect, group and duplicate filtering.
- All 13 offline test scripts passed. User reports improved in-game thanking; protected casting and rank selection remain separately unverified.

# 0.4.3-beta

- Fix missed thanks when a buff giver has no target or nameplate unit: use their name from the buff caster GUID.
- Keep directed thanks working when the giver's unit token disappears during the delay.
- Preserve self-buff, group, cooldown and system-effect filters.
- All 13 offline test scripts passed, including a reproduction of the missed Arcane Intellect case. In-game emote delivery still needs verification.

# 0.4.2-beta

- Tries the buff caster GUID and unit-token lookup when the normal caster is missing.
- Checks the resolved player's identity before applying emote rules or offering Buff Back.
- Directed thanks stays quiet if the giver cannot be identified; undirected thanks respects the selected emote.
- Explicitly ignores Campfire Nearby as well as Honorless Target.
- Offline checks passed; live caster recovery still needs testing.

# 0.4.1-beta

- Honorless Target no longer triggers thanks or Buff Back.
- General thanks now requires a recognised shareable buff when the giver is unknown, avoiding false thanks for unidentified food, drink, mounts and system effects.
- New Forever buffs still work when their giver can be identified as another player.
- Offline regression checks passed; in-game verification is still pending.

# 0.4.0-beta

- Thanks for any helpful buff, with a general thank-you when the giver is unknown.
- More emotes and optional rules by class, gender and race.
- Click-to-buff and Buff Back buttons with rank selection and targeting options.
- Adjustable delays, cooldowns and party/raid inclusion.
- Saved diagnostic logging.

Beta: offline checks pass; fallback delivery and rank cutoffs still need live verification.

# 0.3.0-beta

- Added configurable overall and per-player thanks cooldowns (0-3600 seconds), applied immediately and saved between sessions.

- Added a comma-separated extra-emote field for Random mode, with client emote/alias validation, deduplication, and saved choices.

- Random emotes now use a saved selection of checked emotes, with at least one required. Random off restores the last single choice.

- Moved all settings into the native AddOns page; /tftbf and /buffthanks open that category directly.

- Added a 10-second Buff back prompt for newly received supported buffs, with recipient identity checks and missing-buff filtering.

- Added a configurable Buff mouseover key-binding entry with missing-buff checks and no target fallback, out of combat only.

- Removed recipient-class and self exclusions from mage buff suggestions; added buff-helper diagnostics to `/tftbf status`.

- Added a small missing-buff spell icon in the selected friendly player's target-frame aura row, with a gold + and click tooltip.
- Matches supported ranks and names; hides while the buff is present, aura data is unreadable, the target is unsuitable, or combat is active.
- Selects learned single-target buffs for mage, priest, druid and paladin with simple class presets.
- Uses the next free aura slot, or the side of the row if occupied; never moves existing auras.
- Explicit clicks only, with a final target and buff check before casting. Existing thanks preferences are preserved.
- Offline checks passed; live casting, placement and combat/taint checks remain pending.

# 0.2.0-beta

- Added a movable settings window with an on/off checkbox and clear status.
- Choose random or a specific friendly emote, and include or exclude group members.
- Open it with /tftbf, /buffthanks, or the game's AddOns settings page.
- GUI and slash commands share saved settings. Existing choices are preserved.
- In-game layout and behavior still need verification.

# 0.1.0-beta

- First independent Forever port from Gogo1951's MIT-licensed TFTB.
- Player-aura detection with restricted-data checks, instead of combat-log events.
- Friendly emote choices, optional group thanks, and persistent settings.
- 15-second overall and 90-second per-player cooldowns.
- Offline checks passed. In-game Forever testing is still pending.
