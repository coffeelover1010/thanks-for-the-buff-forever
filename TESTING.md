# Verification checklist

Automated: `python tests/run.py` with external Python/Lupa. Covers new buffs, login baseline, duplicate notifications, refresh after cooldown, multiple buffs from one caster, self/NPC/unknown/late casters, party/raid filters, cooldown expiry and pruning, combat and restriction recovery, thrown API errors, secret sentinels, disabled behaviour, unrecognised spells, failed output, settings validation and retention, Lua 5.1 syntax and TOC entries. Does not emulate a real secret value or the WoW SavedVariables serializer.

In-game verification is pending. Run these in Forever with other auto-thank addons disabled for an isolated result:

After the naming correction, `/reload`, then `/buffy debug`. Receive a fresh recognised buff (remove an existing one first and allow the cooldown to expire). Check that the diagnostic preserves the giver's full first name and surname and that the actual emote names that giver, rather than everyone. Repeat with a different current target or no target. Debug text confirms only the attempted recipient, not server delivery.

1. Enable BuffyLove, reload with existing buffs and check no thanks are sent. Check `/buffy status`; enable `/buffy debug` while diagnosing.
2. Out of combat, ask an identifiable non-group player for a listed buff. Confirm exactly one targeted thank names the correct caster. If no thanks occurs, note status, buff name and `/dump GetBuildInfo()` output; never infer successful delivery from a diagnostic alone.
3. Ask for another listed buff immediately: no extra thanks. Refresh the original buff after 60 seconds while it remains active: still no thanks.
4. Remove the buff, allow an aura update, wait beyond the cooldown and receive it again: one new thank. Receive two buffs together from the same caster: at most one thank.
5. Apply your own buff: no thanks. Test a pet/NPC effect and a buff whose caster is unavailable: no guessed recipient.
6. Repeat with party and raid members using `/buffy group off`, then `/buffy group on`; only the latter permits a new eligible buff response.
7. Receive buffs during combat: no response. End combat: no delayed response. Repeat around an instance/chat restriction and zoning; observe that recovery establishes a baseline.
8. Test `/buffy off` then `/buffy on`: pre-existing buffs should not trigger. Change cooldown/group/debug, reload and log out/in; settings should persist.
9. Check for Lua errors and blocked-action notices. If emotes are rejected, record the context and disable with `/buffy off`; do not attempt bypasses. Turn debug off after testing.

Record client build, zone, group state, spell, observed caster availability and actual emote recipient when reporting results.


## 0.2.0 RP/settings checks

1. Restart WoW after installation/removal. Confirm BuffyLove appears in Options > AddOns and `/buffy` opens it. Scroll to the editor and check labels/buttons fit.
2. Test the three modes separately. For each, save a line containing `{name}`, receive a fresh buff after cooldown, and check the actual recipient/full surname. Custom emotes should follow your character name; whispers should go only to the giver.
3. Toggle random replies with several lines and test over multiple eligible buffs. With random off, only the first line should be chosen.
4. Add a rule matching your class, then a more specific race/gender rule. Preview the saved active mode locally and verify the more specific rule wins. Test fallback, an empty matching list, deletion and reload persistence.
5. Configure a delay. During separate pending replies enter combat, change settings, zone or lose the source unit; no stale reply should be sent. Test group filtering again.
6. Try invalid tokens, markup, unsupported placeholders and oversized text. Confirm validation feedback and that unsaved edits are not activated. Check that timing validation rejects out-of-range values.
7. Check no ThanksForTheBuffForever entry remains enabled after restart. Its SavedVariables are intentionally retained in case of restoration.

Local 0.2.0 tests include response precedence, random selection, placeholder/byte validation, missing traits, full-name whispers, RP output, delayed cancellation, changed caster GUIDs and settings registration/editor callback smoke tests. Visual layout and live delivery remain pending.


## 0.3.0 giving reward checks

Run `python tests/giving.py` for mocked cast/aura attribution, unique-recipient counting, late aura arrival, failed casts, restricted data and expiry.

In game: restart or reload to load the new module. Enable friendly nameplates if you want overhead feedback, then buff a nearby player with a recognised buff. Confirm a green rising count above that player's nameplate and `/buffy giving` equals 1. Rebuff them or apply a second recognised buff: it stays 1. Buff a different player: it becomes 2. Turn off friendly nameplates and verify named centre-screen fallback. Verify self buffs and cancelled casts do not count. Toggle rewards off to suppress tracking/text, and reload to verify the session count resets. Group buffs count only the confirmed named target. Test changing target immediately after a cast; unresolved recipients should be skipped rather than credited to the new target. Visual positioning and live recipient data remain unverified until these checks.


## 0.3.1 supersedes session behaviour

Check that ordinary rewards show only a small number. At 10, 20, etc. check gold sparkles; at 100, 200, etc. check the larger burst and sound. Disable the sound toggle and verify silence at the next hundred. `/buffy giving` should retain its total across reload/logout, and a previously credited full name should not increment again. Earlier session/reset expectations no longer apply. Local tests simulate milestone counts without changing real saved totals. Visual timing and actual sound playback remain live-test items.


## 0.3.2

Receive a fresh recognised buff with no target: expect directed thanks if resolved, otherwise general thanks. Repeat with an unrelated target; general thanks must not name that target. Verify several unknown buffs share one cooldown, whisper mode uses general THANK for unknown givers, and disabling the fallback restores skipping. Mocked tests cover these decisions; live verification remains pending.


## 0.3.3 supersedes refresh suppression

Receive a recognised buff, then renew it within the giver cooldown: no extra thanks. Wait past cooldown and renew it again while it remains active: expect thanks if its expiry is readable and extended. Merely waiting or receiving duplicate notifications should not send anything. Repeat for general unknown-giver fallback, which shares one cooldown. Live validation pending.


## 0.4.0

After reload, confirm floating rewards are hidden and the lifetime total appears at the top of settings. Buff a new recipient with the panel open: the total should update without text/sparkles/sound. Enable the floating display and check font, size, colour, custom {count} text and each icon, plus no icon. Preview must not increment totals. Reload and check preferences persist. Visual layout/texture availability remain live-test items.


## 0.4.2

Enter 0 cooldown and 0 delay, click Apply timing and confirm the nearby saved message. Reload and confirm both remain 0. Separate real buffs/rebuffs may respond immediately, while duplicate notifications still do not. Client throttling/restrictions still apply.


## 0.4.3

Save RP and built-in lists, choose RP first and verify one RP response. Empty the matching RP list and verify built-in fallback. Repeat in reverse with Built-in first. Both should produce one RP line and one built-in emote per eligible buff under one cooldown; duplicate notifications must not repeat either. Check preview, settings persistence and unknown-giver single general THANK. Verify live channel restrictions and settings layout.


## 0.4.4

Enter/leave an instance with existing buffs, including with zero cooldown: expect no entry-time thanks. After five seconds, receive a new buff or a genuine renewal: expect normal response. A buff received during the initial quiet period is deliberately skipped. Test zoning while a delayed response is pending. Mocked transition tests pass; live timing remains to verify.


## 0.5.0 buff back

Run `uv run --with lupa python tests/buff_back.py` alongside `tests/run.py` and `tests/giving.py`.
In game: confirm no prompt by default; enable buff back in /buffy, move the preview and reload to verify saved placement. Receive a fresh buff from a visible player. Verify each learned missing buff has an icon, each click casts only that buff on that giver, and your target stays unchanged. Test 5-second expiry, a failed/out-of-range cast, a changed target, partial/full buff completion, right-click dismissal, and combat/loading clearing all icons. Disable automatic thanks and verify buff-back still works. Check priest/druid multi-icon rows and low-level rank selection. No live checks are claimed complete.

## 0.7.0 target buffs

Offline: run tests/target_buff.py for target eligibility, missing buffs, PvP checks, combat guards, source attribution, settings, binding conflicts and window toggling.

Live checks pending: reload (restart if the new Keybindings entries do not appear), enable target buffing and cursor buttons under Target buffs. Select a friendly player missing your buffs; verify the button stays below the selection-time cursor and each physical click casts one missing buff. Change target and repeat with the shortcut, then hide cursor buttons and repeat. Confirm combat prevents casting and buttons recover afterward. Verify dead/enemy/already-buffed targets do not cast. Use right-click on the spell icon and the source shortcut; check known and unavailable casters, target changes, scrolling and Escape. Save shortcuts through both settings and standard Keybindings, reload, and verify persistence.


NPC targeting: with target buffing enabled, target a friendly NPC missing your buff and verify a spell is offered. Turn Allow buffing NPCs off and verify the action clears. Already-buffed, dead and hostile NPCs must not cast. NPC eligibility, toggle and exclusions pass offline; server acceptance still needs live testing.

Rank checks: tests/giving.py verifies 999/1000 and 1999/2000 boundaries, saved lifetime totals, progress, badge reuse above rank 14 and persistent badge visibility. Live settings layout and badge rendering remain to be verified.
