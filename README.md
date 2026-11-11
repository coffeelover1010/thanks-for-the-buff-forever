# BuffyLove! 0.6.1

A WoW Forever addon for thanking buff givers, tracking players you buff, and offering optional click-to-buff-back icons.

CurseForge: https://www.curseforge.com/wow/addons/buffy-love
Project ID: 1712449. Addon folder: BuffyLover. Saved settings: BuffyLoverDB.

## Installation

Extract BuffyLover-0.6.1.zip into _forever_/Interface/AddOns. Open /buffy or Options > AddOns > BuffyLover! after restarting or reloading WoW.

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

The account-wide lifetime count credits each full player name once after a successful recognised buff and aura confirmation. It persists across reloads. Tracking continues while the display is hidden. Show floating buff total defaults off. Visible totals sparkle at multiples of 10, with a larger celebration and optional sound at 100.

Default style: Nameplate font, size 20, white text, {count} toons buffed!, and the buff's icon. Existing styles remain saved. Selectors save immediately; font size saves on Enter or clicking away; text and colour use Apply appearance. Preview uses a sample Intellect icon before the first credited spell.

## Buff back

Optional and off by default. Learned, missing, level-appropriate buffs are offered for identified givers. One physical click casts one buff without changing your target. Offers expire, and clear in combat/loading. Duration is configurable from 5-120 seconds. Move / preview icons saves a draggable position; right-click finishes positioning.

Supported classes: mage, priest, druid and paladin. Identity, availability, PvP flag and spell checks can prevent an offer or cast.

## Commands and diagnostics

/buffy opens settings. /buffy on, off, status, debug, cooldown 60, group on, group off and giving remain available. /buffy log prints the last 30 recorded response attempts and addon-block notices. API return values do not confirm delivery.

## Verification

Tests use Python and Lupa (Lua 5.1); these dependencies do not ship in the addon. Run tests/run.py, giving.py, buff_back.py, manual_reply.py and combinations.py. tests/package.py builds and verifies the release ZIP. User testing confirmed directed built-in emotes and clicked RP; offline tests do not reproduce every client restriction.

MIT licensed. See LICENSE and BuffyLover/RETURN-NOTICE.md for attribution.
