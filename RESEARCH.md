# Inspection report — 2026-11-09

## Live report and naming correction

The user observed one general thank-everyone emote, not multiple named responses. Research then identified an incorrect assumption in the initial implementation: Forever uses first name and surname; the second `UnitFullName` return must not be formatted as a realm. `GetUnitName(unit, true)` delegates to the client's name formatter and returns the complete native name. The corrected implementation uses that value unchanged, with GUID and name revalidation immediately before output. No first-name-only or guessed identity fallback is used.

Primary evidence: [Forever NameUtil](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_FrameXMLUtil/Camelot/NameUtil.lua) joins name components using `CHARACTERNAME_SURNAME_SEPARATOR`; [UnitFrame](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UnitFrame/Mainline/UnitFrame.lua) delegates `GetUnitName` to that helper. Both were also inspected in the local build 69893 extraction. The initial mocked test incorrectly modelled a realm and therefore did not catch this bug; regression tests now use surnames, Unicode and unavailable names.

The local `Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua` passes the complete slash-command message to `PerformEmote` and treats its return as a restriction flag, whereas generated API documentation labels it success. The addon therefore makes no delivery claim based on that return. The name-format bug is confirmed by source; whether it fully resolves the observed untargeted output still requires a live test. No client targeting or protected actions are introduced.

## Local feature comparison

Inspected the installed `C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/ThanksForTheBuffForever` Lua files and the workspace `thanks-for-the-buff-forever` and `buffers-gg` projects. These were read only; no source, interface, artwork or architecture was copied into BuffyLover!.

| Area | Observed implementation | Decision for 0.1.0 |
|---|---|---|
| Detection | Installed addon scans helpful auras, attempts caster-unit/GUID resolution and checks restricted values | Require a directly verifiable source unit; incomplete reads reset baseline |
| Responses | Installed addon supports targeted emotes, optional whispers and configurable/random emotes | One targeted THANK; no whispers |
| Spam controls | Installed addon has per-player/global intervals and delayed responses | Per-player 60-second default; synchronous deduplication |
| Refreshes | Installed source considers extended expiration a new application | Track spell presence independently of expiration and instance IDs |
| Unknown source | Installed source can queue an unknown-caster response | Always skip |
| Group controls | Installed settings include group participation | Include/exclude party and raid together |
| Other functions | Installed addon includes buff-back and graphical settings | Leave out of smallest useful release |
| Combat log | Workspace BuffersGG registers a combat-log path when available | Do not depend on Classic combat-log availability in Forever |

Useful future candidates: optional delays, response variety, opt-in whispers, character settings and encounter history. These need separate design, privacy/spam choices and client verification. None is implemented now. Source inspection establishes features, not working live-client compatibility. Unidentified fallback responses and refresh-triggered thanks do not meet this project's requirements. Classic event availability and automatic messages cannot be inferred from successful loading.

## Forever API evidence

Local Blizzard UI extraction inspected: `cf-ui-research/forever-69893/Interface/AddOns/`. This is build 69893 evidence, not proof of the currently running build. Also checked the online Forever branch of the Blizzard UI source mirror on 2026-11-09:

- [UnitAuraDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua): helpful aura reads, aura-instance caster APIs and aura events. Reads carry unit-aura access and secrecy restrictions. BuffyLover! uses `GetAuraDataByIndex` and rejects unreadable snapshots rather than exploiting alternate routes.
- Local `UnitAuraSharedDocumentation.lua`: aura data fields used for source attribution. Only public spell IDs and source-unit data are processed.
- Local `SecretPredicateAPIDocumentation.lua`: `C_Secrets.ShouldAurasBeSecret`. The implementation checks this before reads and guards values with `issecretvalue` before comparisons or concatenation. Protected-call error handling does not grant access to restricted information.
- [ChatInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua): `PerformEmote` takes an emote name and target name, returns success, and has restrictions. `SendChatMessage` also has restrictions; no chat-message path is used. Local documentation confirms `InChatMessagingLockdown`.
- Local `Blizzard_DeprecatedChatInfo/Deprecated_ChatInfo.lua` maps `DoEmote` to `C_ChatInfo.PerformEmote` only when deprecation fallbacks are enabled. Use the modern entry point directly.

Loading uses an Interface 16001 TOC, ordered Lua files and ADDON_LOADED before consuming SavedVariables. UNIT_AURA drives full snapshots (bounded to 256 entries); no OnUpdate/ticker runs. World entry and combat transitions establish safe baselines. No attempt is made to automate protected casting or change targets.

Remaining uncertainty: actual aura source visibility for strangers, exact restrictions on automatic targeted emotes in the user's current client, and observed loading/persistence. These require the in-game checklist. The mocked runner cannot reproduce Blizzard's secret-value enforcement; it tests sentinel rejection and thrown errors only.


## 0.5.0 return buttons

The original independent implementation statements above describe earlier releases. Version 0.5.0 adapts the local Forever helper spell-selection and secure buff-back code; see RETURN-NOTICE.md for attribution. The new panel is opt-in and user-clicked. Offline mocks are not evidence of live protected-casting compatibility.
