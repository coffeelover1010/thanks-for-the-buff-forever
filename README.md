# BuffyLove 0.7.2

A WoW Forever addon for thanking buff givers, tracking players you buff, and offering optional click-to-buff-back icons.

CurseForge: https://www.curseforge.com/wow/addons/buffy-love
Project ID: 1712449. Addon folder: BuffyLover. Saved settings: BuffyLoverDB.

## Installation

Extract BuffyLover-0.7.2.zip into _forever_/Interface/AddOns. Open /buffy or Options > AddOns > BuffyLove after restarting or reloading WoW.

## Target buffs

Open the Target buffs subcategory to enable casting on the current target, cursor buttons, or automatic source viewing independently. These options default off. Allow buffing NPCs defaults on: friendly living NPCs with a missing supported buff are eligible for the target button and shortcut. Turn it off for player-only targeting. When enabled, buttons appear below the cursor on target selection and stay still for clicking. Left-click the flat spell icon once per missing buff; right-click it to view the target's visible buffs and their casters. Unknown / unavailable means the game did not expose a readable caster; no name is guessed.

Set separate Buff target and Show buff sources shortcuts here or in Options > Keybindings > BuffyLove. The cast shortcut works with cursor buttons hidden, while target buffing is enabled. Casting is out of combat only, uses learned level-appropriate missing buffs, and retains PvP checks. Source viewing is available for any class. The source window follows the current target and closes with Escape or its close button.

## Choose your responses

Open the Responses subcategory or Choose responses on the main page. Enable any combination:

- Built-in emote: automatic THANK, BOW, CHEER and other supported emotes.
- Custom RP: your saved text; outdoors a button requires your click before sending.
- Whisper: a private reply to the identified giver.

Choose Send all selected, Choose one type randomly, or First available in priority order. Disabled types and empty matching lists are skipped. Priority chooses available saved replies; it does not retry uncertain delivery. All selected types share a cooldown and delay. Random saved line within each type is separate from random response-type selection.

Existing response modes migrate to equivalent choices without enabling additional channels.

## Saved replies and character rules

The main page edits each type's general fallback and numbered character rules. Save list commits text. Rules describe YOUR class, race and gender. Most specific matching rule wins; ties use the earlier rule. An empty winning list suppresses that type. {name} inserts the giver's name. Built-in tokens: THANK, BOW, SALUTE, CHEER, WAVE, NOD, APPLAUD.

Saved rules lists every saved reply and the winning rule for each type. Editing a reply type does not enable it: use Responses for that. Switching editor rows discards unsaved edits.

Preview saved response and Preview saved style open local preview windows. They send no messages, cast no buffs and add no counts.

## Custom RP button

Outside instances, custom RP waits for a physical click on Send RP thanks. The panel shows the selected text and giver. Dismiss skips it. Up to five distinct givers can wait for 30 seconds. Combat, loading and configuration changes clear the queue. Clicking rechecks identity, group filters and restrictions. Both automatic and clicked messages remain subject to client restrictions.

## Timing and detection

Automatic thanks default on, with a 60-second per-player cooldown, no delay, and party/raid thanks off. Debug messages default off. Typing in chat does not delay or cancel thanks.

Recognised helpful buffs and readable expiry extensions trigger detection. Login/loading establishes a quiet baseline. Self/NPC buffs, unavailable data and restricted states are skipped. Givers are identified through public aura data, unit references, and GUID name lookup. No automatic targeting occurs.

Thank everyone when the buff giver cannot be identified controls the general THANK fallback. It defaults on and is independent of selected response types. Disable it to skip unidentified givers.

## Buff count

The account-wide lifetime count credits each full player name once after a successful recognised buff and aura confirmation. It persists across reloads. Tracking continues while the display is hidden. Show floating buff total defaults off. Visible totals sparkle at multiples of 10, with a larger celebration and optional sound at each rank milestone.

Default style: Nameplate font, size 20, white text, {count} toons buffed!, and the buff's icon. Existing styles remain saved. Selectors save immediately; font size saves on Enter or clicking away; text and colour use Apply appearance. Preview uses a sample Intellect icon before the first credited spell.

## Buff back

Optional and off by default. Learned, missing, level-appropriate buffs are offered for identified givers. One physical click casts one buff without changing your target. Offers expire, and clear in combat/loading. Duration is configurable from 5-120 seconds. Move / preview icons saves a draggable position; right-click finishes positioning.

Supported classes: mage, priest, druid and paladin. Identity, availability, PvP flag and spell checks can prevent an offer or cast.

## Commands and diagnostics

/buffy opens settings. /buffy on, off, status, debug, cooldown 60, group on, group off and giving remain available. /buffy log prints the last 30 recorded response attempts and addon-block notices. API return values do not confirm delivery.

## Verification

Tests use Python and Lupa (Lua 5.1); these dependencies do not ship in the addon. Run buffy-tests/run.py, giving.py, buff_back.py, manual_reply.py and combinations.py. buffy-tests/package.py builds and verifies the release ZIP. User testing confirmed directed built-in emotes and clicked RP; offline tests do not reproduce every client restriction.

MIT licensed. See LICENSE and BuffyLover/RETURN-NOTICE.md for attribution.




## Buff ranks

Buff count settings show your BuffyLove rank and progress. Ranks 1-9 require 32, 128, 512, 1,204, 1,337, 2,048, 10,001, 32,768 and 100,001 lifetime unique players. Existing totals count immediately; repeat buffs and NPCs do not count. Rank 9 is the highest rank. Badges use the corresponding classic PvP icons; this does not change actual PvP rank.

Show rank badge beside the floating buff graphic defaults on and can be disabled independently of the spell icon. There is no badge before rank 1. The settings rank remains visible when the floating badge is disabled.

Target buffs also provides Hide icon when no buff is possible (on by default), icon size (16-80), and horizontal/vertical cursor offsets (-300 to 300). Range and spell usability are rechecked before casting. Forever pet offers use a spell allowlist: Thorns on friendly pets and Dampen Magic on own/party/raid pets. Stat buffs are excluded. Dampen Magic reduces healing received as well as spell damage; it is not added to player/NPC offers. Server-only restrictions such as line of sight may still reject a cast. The source shortcut remains available with the cursor icon hidden.

Use Buff count > Preview next rank to inspect the next milestone's badge and styled graphic without changing your lifetime total. The graphic preview respects the badge toggle; the sample rank summary always shows its badge.


Choose the rank-up sound in Buff count settings: Level up, Quest complete or Ready check. Preview sound plays your selection without adding counts. Automatic sound uses the existing sound and floating-display toggles and occurs only at a rank milestone; 100 has no separate celebration.

Target buffs > Position cycles between cursor-at-selection, fixed screen position and below the target frame. Drag to set screen position opens a movable marker; dropping it saves a fixed screen location. Right-click the marker to finish. Horizontal and vertical offsets allow fine adjustment.

Newly earned ranks offer a click-to-send custom emote: BuffyLove: {player name} has obtained rank {rank} for buffing {count} players! Disable this through Offer a custom emote when I earn a rank. Existing ranks are not announced on reload or settings changes. The offer expires after 30 seconds and follows the existing RP queue/combat safeguards.


Buff count settings include Reset count and Restore default settings. Both require typing RESET and clicking Confirm reset outside combat. Reset count clears the account-wide lifetime total, credited-player ledger, rank and pending celebrations while retaining settings. Restore default settings resets addon preferences, appearance, positions and saved replies while preserving lifetime progress and WoW keybindings. No reset happens merely by opening the confirmation.

Target buffs > Icon appearance provides Square, Rounded square and Circle shapes, border width (0-6; zero hides it), a six-digit hex border colour, opacity (20-100%), and a preview. Enter or click away to save. Existing size and position controls still apply. Changes to the live button wait until combat ends.

Every settings page has Page defaults and All settings defaults, each with a second-click confirmation. Page defaults resets only that page; the main page includes its saved reply editor and character rules. Target buffs includes its two addon shortcuts. All settings defaults resets all options and addon shortcuts. Lifetime buff count and rank are preserved; Reset count remains a separate explicit action.
