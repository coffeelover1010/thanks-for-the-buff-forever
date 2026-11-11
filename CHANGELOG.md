# 0.6.1 - 2026-11-11

- Make numeric settings compact; retain values on Enter, save on focus loss, restore invalid input, and support Escape, Up/Down and timing-field Tab navigation.

- Clarify response setup and default replies; show character filters only when editing a character rule, with reply-type-specific help.

- Set the per-player cooldown range to 0-2000 seconds; response delay remains 0-40 seconds.

- Raise the response-delay maximum to 40 seconds.

- Fix buff-back status reporting disabled after login when the saved setting is enabled and no giver is pending.
- Remove typing protection and its settings; chat input no longer delays or cancels replies.

# 0.6.0 - 2026-11-10

- Combine built-in emotes, custom RP and whispers with independent checkboxes.
- Send all selected types, choose one randomly, or use a configurable priority order.
- Preserve existing settings, reply lists and character rules during migration.
- Offer a click-to-send button for custom RP outdoors, respecting the client input requirement.
- Improve directed thanks to passing players without a selected target.
- Add Responses, Saved rules, Buff count and Buff back settings pages.
- Show saved-rule winners and visible response/style preview windows.
- Add configurable typing wait and a bounded /buffy log activity history.
- Use Nameplate font, white size-20 text, actual buff icon and "{count} toons buffed!" as the default count style.

Validated with offline Lua tests and user-reported in-game testing, including directed built-in emotes and click-to-send RP.

# 0.5.0

- Add optional out-of-combat buff-back icons, disabled by default and independent of automatic thanks.
- Add saved draggable placement, position reset, and a 5-120 second offer duration.
- Offer learned, missing buffs for the identified giver; one physical click per cast, preserving the current target.
- Revalidate recipient GUID, buff state and spell rank at click time; clear offers for combat/loading, expiry or dismissal.
- Add offline regression coverage; live rendering and protected casting remain unverified.

# Changelog

## 0.4.4 — 2026-11-09

- Suppress thanks during a five-second world-entry settling period and establish a final aura baseline.
- Cancel queued thanks at loading-screen start and ignore stale transition timers.
- Test empty/staggered entry snapshots and normal buffs after settling.

## 0.4.3 — 2026-11-09

- Add RP-first, built-in-first and Both response choices alongside single-channel modes.
- Separate What to send from List to edit in settings and preview planned outputs.
- Both shares one cooldown/delay and attempts each channel independently without retries.

## 0.4.2 — 2026-11-09

- Accept zero cooldown in settings, slash commands and saved configuration.
- Show timing validation/success next to the timing controls.
- Keep duplicate-event suppression with cooldown zero.

## 0.4.1 — 2026-11-09

- Add Buff being given icon choice, using the confirmed spell texture with safe text-only fallback.
- Preview the most recently credited spell during this session.

## 0.4.0 — 2026-11-09

- Hide floating rewards by default while continuing lifetime tracking.
- Show the live lifetime total at the top of settings.
- Add font, size, RGB colour, text format and optional icon controls with a local preview.
- Preserve totals and save display preferences independently of tracking.

## 0.3.3 — 2026-11-09

- Thank genuine rebuffs after the giver cooldown when a public expiration extension confirms renewal.
- Keep duplicate notifications, login/recovery baselines and unavailable-expiry transitions suppressed.

## 0.3.2 — 2026-11-09

- Add caster GUID/unit lookup and optional general THANK fallback with a shared cooldown.
- Preserve secret-value guards, self/NPC filtering and refresh suppression.

## 0.3.1 — 2026-11-09

- Replace reward sentences with a subtle number-only display.
- Save account-wide lifetime total and full-name recipient deduplication.
- Add sparkles every 10 and larger gold bursts plus optional level-up sound every 100.
- Test persistence, milestone boundaries and effect cleanup.

## 0.3.0 â€” 2026-11-09

- Reward giving recognised buffs with a distinct-player session counter and rising, fading text above a visible recipient nameplate.
- Use named centre-screen feedback when a recipient nameplate is unavailable.
- Confirm a successful cast against a readable recipient aura attributed to the player; skip failed, secret, unknown and self casts.
- Add a settings toggle and `/buffy giving` to view the count. Reload/logout resets this session counter.

## 0.2.0 â€” 2026-11-09

- Add a BuffyLover! category in Options > AddOns, opened by `/buffy`.
- Add built-in emote lists, custom RP emotes and optional whispers with full-name substitution.
- Add fixed/random replies and saved rules for the responding character's class, race and gender.
- Add 0â€“10-second response delays with identity revalidation and cancellation on combat, zoning and configuration changes.
- Add local-only previews, message validation, and mocked response/settings tests.

## 0.1.0 correction â€” 2026-11-09

- Preserve Forever first name and surname using the client's complete-name helper instead of constructing a realm-style hyphenated name.
- Recheck full name and GUID immediately before an emote attempt.
- Add surname, Unicode and unavailable-name regression coverage.
- Do not interpret the emote return value as delivery confirmation: generated documentation and Blizzard's slash handler disagree on its meaning.

## 0.1.0 â€” 2026-11-09

- Initial independent Forever addon, interface 16001.
- Recognised-buff detection with verified player attribution and targeted thanks.
- Login/recovery baselines, refresh suppression and per-player cooldowns.
- Persistent slash-command settings and opt-in debug output.
- Mocked Lua tests and a separate live-client checklist.
