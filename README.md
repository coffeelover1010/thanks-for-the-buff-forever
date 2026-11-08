# Thanks for the Buff Forever

- Automatically thank players for buffs.
- Choose emotes, or customise replies by class, gender and race.
- Click to buff a target or buff someone back.
- Adjust delays, cooldowns and targeting.
- Resolve passing buff givers by name when they have no target or nameplate unit.
- Optional general thanks for recognised buffs when the giver cannot be identified (turn off directed thanks).

Open settings with `/tftbf`. Advanced opens the emote rule builder.

Open **Messages...** or `/tftbf messages` for whispers and custom emote text.
Choose a mode and your own character's race, enter one message per line, then
**Save and activate**. A random line is chosen each time. Save General fallback
lines for characters without a race-specific list. Whisper and custom-emote lists
are separate; the selected mode is shared across characters on the account.
Changing a dropdown discards unsaved edits. Choose Built-in emotes and save to
return to the existing emote settings/rules. Empty lists send nothing if there is
no general fallback. Whispers always go to the identified buff giver, including
when directed emotes are disabled. Custom emotes are plain text displayed after
your character name (for example, `raises a mug in thanks.`). These are text lines,
not recorded audio. Use plain text, up to 255 UTF-8 bytes per line; no placeholders
or chat markup. Existing timing, group filters and cooldowns apply to all modes.
The new editor and actual chat delivery still need live-client validation.

Buff back is optional: open **Buff back...** in settings, enable it, then bind
**Buff back next giver (out of combat)** in Key Bindings > Thanks for the Buff Forever.
No key is assigned automatically. The key works without the optional on-screen button.
The prompt and five-giver queue default off. Offers last 30 seconds by default
(adjustable from 5 to 120 seconds), and clear on combat or loading screens.
Right-click the prompt or use **Dismiss current giver** in settings to skip someone.
PvP checks default on; an unreadable flag holds the offer. Buff back keeps your
current target unless you explicitly choose to select the giver. Existing saved
targeting and target-button preferences are preserved; new target buttons default off.
Use `/tftbf status` for the current reason an offer is waiting. A click alone does
not remove an offer: the recipient must be observed wearing the buff, or the offer
must expire or be dismissed.

For WoW Forever. Skips known self-buffs, combat and existing login buffs. Buff buttons require a click and work out of combat. The generic fallback cannot identify the giver. Rank selection and fallback delivery still need live verification.

Logging: `/tftbf log`, `/tftbf log on`, `/tftbf log off`, `/tftbf log clear`. Reload or log out to save logs to disk.

Adapted from Gogo1951's MIT-licensed Thanks-for-the-Buff, revision e1f7164b8006ace5504168e8356db345d6c7703e. Forever port by Videocat. See LICENSE and NOTICE.md.
