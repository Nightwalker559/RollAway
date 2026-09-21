# RollAway – Changelog

---

## 3.0.6

### New
- RollAway Portal Overview: own 2-tab portal frame (current season / all learned dungeons, sorted by expansion) for premade groups, no BigWigs/Details needed. Manual toggle via `/rat`.

### Fixed
- Teleport Reminder no longer reappears for a dungeon whose portal is on cooldown.
- Keystone companion addon no longer opens when joining an in-progress key (mid-dungeon backfill).

### Changed
- Removed unused abbreviation helper and other dead code in Portal Overview.
- Removed unused `RA.LEGACY_RAID_TELEPORTS` table in LegacyRaids.lua (abandoned feature, never referenced).
- Portal Overview and Dungeon Quick Select now list dungeons alphabetically instead of data-entry order.
- Added Siege of Boralus / The MOTHERLODE!! to the "all learned dungeon teleports" overview (faction-specific spell ID resolved at load time).
- Portal Overview's "Current Season" tab now shows a "Season N" header matching Tab 2's style, so content doesn't shift when switching tabs.

## 3.0.5

### New
- QoL: auto-accept group invites from guild/friends (Default UI only).
- QoL: Auto Repair (None/Player/Guild) at any merchant (Default UI only).

### Changed
- Bonus Roll tabs/reminder now hidden below max level.
- ElvUI skin: tabs now show distinct backgrounds at rest, not just on hover.
- ElvUI skin: disabled season tabs keep gold text but lose active styling.
- Profile tab now notes that Bonus Roll selections stay per-character, not per-profile.

### Fixed
- Legacy section overlapped and then clipped raid-difficulty checkboxes.
- Debug toggle on dev chars below max level now reveals tabs without `/reload`.
- Teleport Reminder no longer fails after applying via Group Finder cache miss.
- Auto-accept invite: fixed `for` limit error from removed `STATICPOPUP_NUMDIALOGS`.
- Auto Repair info text now indented like other Misc options.
- BigWigs Keystones no longer wrongly opens on Timewalking/random queue pops.

### Internal
- Auto-accept invite moved to its own module (Misc.lua, new "Misc" tab).

## 3.0.4

### Fixed
- LFG Quick Create's auto-playstyle could taint the Group Finder's EntryCreation frame, causing `ADDON_ACTION_BLOCKED` (`SetEntryTitle`) on later genuine clicks (e.g. Edit in the Application Viewer) until `/reload`. No longer calls the playstyle dropdown's Blizzard API; sets the underlying value directly instead.

## 3.0.3

### Fixed
- Teleport Reminder no longer closes on Esc (was in UISpecialFrames, closing unintentionally during normal play). Close via the X button, a portal click, or it auto-clears on combat/group change.
- Omniumfoliant/Great Vault character-frame buttons could vanish mid-session and not return even after toggling the option off/on (only /reload fixed it). Now self-heal parent/strata/anchor every reapply, not just Show().
- Dungeon/AdvLog reminder could disappear instantly when queuing as a partial group (e.g. 2 of 5) via the automatic Dungeon Finder: GROUP_JOINED fired right after entering and hid the just-shown popup. GROUP_JOINED no longer hides an active reminder, only resets the dedup key.

### Internal
- Debug log auto-scrolls to the newest line.
- /rawlog reopens the debug log without needing debug logging on.
- Debug log shows a divider between instance-entry sections (time-gap based; also triggers on group leave/join, e.g. Delves).
- Reminder check no longer runs twice on instance entry.
- VendorFilter no longer spams identical debug lines on vendor open.

## 3.0.2

### Fixed
- Fixed Ctrl+C on profile export closing the popup before the copy fired.

## 3.0.1

### New
- ElvUI skin support for the Advanced Combat Logging reminder popup.
- New popup reminder if Advanced Combat Logging is off when entering M+/raid.
- Logs info text now notes Advanced Combat Logging is enabled automatically.
- Settings are now per-character via AceDB-3.0, groundwork for named profiles.
- "Apply Legacy settings to all characters" remains account-wide only.
- One-time login popup: keep old settings or start fresh per character.
- New "Profile" tab: switch, create, copy, delete, reset profiles.
- Export/Import profiles as text codes (CBOR+Base64, no extra library).
- Importing a profile code always creates a new named profile.

### Fixed
- Fixed error on BoP confirm after Need roll: bad STATIC_POPUPS reference.
- Profile reset now also clears Dungeons/Raids/Delves/Prey selections.
- Fixed AdvLog reminder not ElvUI-skinned when opened via /rawreminder.
- Fixed AdvLog ElvUI skin hook never firing (bypassed via local upvalue).
- Fixed AdvLog reminder overlapping other popups; stacking now shared.
- Fixed reminder check firing twice on zone entry; now debounced.
- Fixed stray space before closing parenthesis in debug log lines.
- "Other profile" dropdown no longer gets stuck open when empty.

### Changed
- Moved generic popup/timer/table helpers out of Core.lua into new Helpers.lua.
- Extracted shared reminder-popup lifecycle helper (combat/group reset).
- Removed unused debug leftovers in CharFrameButtons.lua and LFGQuickCreate.lua.
- New/default profiles start with everything disabled (timers/fonts unaffected).
- Default keystone companion addon is now "None" instead of BigWigs.
- BigWigs/Details Keystones now stay open until a portal is cast, up to 20s.
- Updated options info text for the new keystone close behavior.
- Kith'ix (12.1.5) encounterID confirmed, still pending in-game verification.
- ElvUI popup skinning consolidated into RA.CreatePopupFrame (was 4 duplicates).
- Removed checkbox/slider color forcing; both use plain ElvUI styling now.
- Debug output moved to a dedicated, copyable log window instead of chat.
- Zone-change debug output reduced to one compact line (was 3x duplicated).
- Debug summary now reflects real auto-pass state (was missing "pass all").
- Raw GetInstanceInfo dump moved to a dedicated /rawdump command.
- AutoRoll ElvUI button cache: 5 log lines collapsed into 1 summary line.
- Combat log zone checkboxes grey out while master toggle is off.
- Profile panel flags pending reload (red/green) after profile changes.
- Legacy migration popup now shows a few seconds after login, not instantly.
- Profile export popup now closes automatically on Ctrl+C.

### Internal
- Rigorous pre-release code review: 0 syntax errors, 0 real lint warnings.
- Removed unused HideTeleportReminder function (dead code).
- /rawreminder now also triggers Great Vault and Advanced Logging test popups.
- Added /rawlog to reopen the debug log window if closed.
- Added ElvUI skin support for the debug log window.

---

## 3.0.0

### New
- Separate companion addon choice (BigWigs/Details!) for premade groups.
- Chonky Character Sheet support for Omnium/Vault CharacterFrame buttons.

### Fixed
- Omnium/Vault buttons no longer vanish on spec change (Chonky Character Sheet).
- Omnium/Vault buttons no longer get stuck after switching CharacterFrame tabs.
- Omnium/Vault buttons now reliably reappear after reopening the Character panel.
- Shortened BigWigs/Details labels so the RollAway Teleport checkbox isn't cut off.

### Changed
- Extracted Omnium/Vault buttons into their own file (Modules/CharFrameButtons.lua).
- Merged duplicate Season 1/2 raid grid code into one shared helper.
- Removed duplicated comment block in crafting output log code.
- Removed unused locale scaffolding in WhatsNew.lua.
- Merged duplicate popup-close code from AutoRoll/RollConfirm into Core.lua.
- Merged duplicate popup-frame code from Reminder/Paragon/GreatVault into Core.lua.

### Prep (12.1.5, marked "coming soon", not selectable yet)
- Added Labyrinth of Kindo'jan delve entry (mapID 3043), labeled [12.1.5].
- Added Kith'ix raid boss placeholder (encounterID pending), labeled [12.1.5].
- Kith'ix shown side by side with Tidebound Grotto instead of stacked.
- Fixed potential nil-index crash for raids without an encounterID yet.

---

## 2.9.9

### New
- New teleport reminder: portal button for your queued Season 2 M+ dungeon.
- Replaces BigWigs/Details for dungeons when selected; stays open until used.

### Fixed
- Crafting output log now also hides for crafting orders, not just own crafts.
- Dev-only Options scroll height now accounts for the debug info text.
- Removed leftover unused variable in QoL vendor alpha slider code.

---

## 2.9.8

### Fixed
- Keystone companion addon now also opens for manually formed (premade) M+ groups, not just LFG listings.
- Premade group: companion addon kept flickering open/close repeatedly, now opens once per group.
- Fixed companion addon flicker (open/close/open) when own LFG listing fills up.
- Transmog roll confirmation didn't complete – now clicks the real button instead of guessing RollOnLoot args.

---

## 2.9.7

### Fixed
- Transmog roll confirmation used wrong rollType (Disenchant instead of Greed), breaking the roll.

---

## 2.9.6

### New
- Vendor Filter Light (QoL): dims already-known vendor items (recipes, toys, mounts, pets, tabards, illusions, housing decor). Toggle + alpha slider in Options > QoL > Filter.
- Option to disable the entire Group Loot History auto-close/auto-hide feature, so the frame always stays open like default WoW.
- Option in Raids tab to show a confirmation popup before rolling Need, Greed, Transmog or Pass on group loot (each togglable separately).

### Changed
- Removed the Tester section from the General settings tab.
- General tab scroll area now sizes dynamically to content instead of a fixed oversized height.
- Scrollbar on the General tab now hides automatically when content doesn't need scrolling.
- Delay slider range changed from 1-10s to 5-20s.
- Safety timeout slider range changed from 15-120s to 30-180s.
- Renamed "Auto-Pass by Difficulty" to "Bonus Roll Auto-Pass by Difficulty" to avoid confusion with item roll Pass.

### Internal
- Full codebase audit: syntax, duplicates, dead code, performance - all clean.
- Removed orphaned `NeedConfirm.lua` (unused prototype, not in `.toc`, fully superseded by `RollConfirm.lua`).
- Added What's New entries for all 2.9.6 features.

---

## 2.9.5

### Changed
- Omniumfoliant/Vault CharacterFrame buttons shrunk to 24x24 (was 32x32).

### Fixes
- CharacterFrame buttons could silently stop reappearing after certain load orders.
- Auto-logging now enables "Advanced Combat Logging" CVar if it was off.

### Internal
- Merged duplicate toast-frame setup code (Ready Check / Durability reminders) into one shared helper.

---

## 2.9.4

### New
- QoL: option to hide the Crafting Output Log popup on the professions window.

### Fixes
- Crafting Output Log hide option now actually works (previous hook missed Blizzard's SetShown() calls).

---

## 2.9.3

### New
- Dungeons tab: "Auto-pass ALL dungeons" checkbox, locks individual dungeon checkboxes while active.
- Delves tab: "Auto-pass ALL delves" checkbox, locks individual delve checkboxes while active.

### Fixes
- Omniumfoliant/Great Vault buttons: added self-healing watchdog, more robust re-apply.
- BigWigs/Details! Keystones companion choice no longer resets to "none" every options panel open when the addon isn't detected yet (e.g. right after login).

### Internal
- Removed dead code (unused patch-version flag, redundant manual-check exports).
- QoL.lua: merged duplicate Omniumfoliant/Vault button creation into one shared factory.

---

## 2.9.2

### Changes
- Internal: split `Options.lua` into `Options/OptionsHelpers.lua` (shared UI builders) and `Options/OptionsQoL.lua` (QoL subcategory panel); no behavior change.
- Internal: moved feature modules (AutoPass, AutoRoll, Reminder, QoL, Paragon, GreatVault, LFGQuickCreate, Logs, WhatsNew) into a `Modules\` folder; no behavior change.

---

## 2.9.1

### Fixes
- Options panel: fixed `SetPoint` error on tester section anchor when dev/debug block is hidden (was anchoring to the checkbox widget instead of its frame).

---

## 2.9.0

### New
- Group Loot History: auto-hide now per raid difficulty (LFR/Normal/Heroic/Mythic), visible by default.
- Raids tab: "Auto-Pass by Difficulty" toggles, combinable with per-boss checkboxes.
- All checkboxes across the options panel now use AceGUI's CheckBox widget instead of the Blizzard template + ElvUI skin combo, fixing a mis-rendered checked state when checkboxes sat directly next to each other.

### Changes
- Nymrissa Wavecaller (Tidebound Grotto) moved from Open World/World Bosses to Raids tab.

### Fixes
- Season 2 raid bosses were never pre-initialized in the saved `raids` table.

---

## 2.8.4

### Fixes
- Omniumfoliant/Great Vault buttons: re-apply on `Blizzard_CharacterFrame` load, anchor to `CharacterFrame` (not `PaperDollFrame`, was buried under the stats pane), and re-apply on every Character panel open — fixes buttons missing at login, after zoning/portals, and in general.

### Internal
- Removed unused `addonName` locals in `Data/*.lua`.
- Removed stale 12.1 TODO comment in `Core.lua`.
- Full syntax + static analysis pass, no issues.

---

## 2.8.3

### Fixes
- Fixed "Current Expansion Only" filter in the Auction House not visually checking the box: Patch 12.1.0 moved filter state from `SearchBar.FilterButton.filters` to a global `g_auctionHouseFilters.filters` table, which the addon wasn't writing to.

---

## 2.8.2

### Fixes
- Fixed auto-logging sometimes not starting when zoning quickly from one dungeon into another: `GetInstanceInfo()` can briefly return stale data on the first `PLAYER_ENTERING_WORLD`, and a `LoggingCombat` rate-limit failure had no further retry if no more zone events fired. Added a 1.5s safety recheck and more retries.

---

## 2.8.1

### Fixes
- Fixed Omniumfoliant/Vault CharacterFrame buttons getting covered by the secondary stats flyout (Versatility/Leech/Avoidance) when hovering stats.

---

## 2.8.0

### New
- Great Vault reminder: optional popup on login (once per weekly reset) if you have unclaimed Great Vault rewards. Toggle in Reminder options; manual check via `/rawvault`.
- New QoL "Logs" tab: automatic combat logging (`LoggingCombat`) based on the zone/difficulty you're in — makes Method Raid Tools' logging feature obsolete for RollAway users. Individually togglable per content type: Scenarios, Mythic/Mythic+ Dungeons, Raid Mythic/Heroic/Normal/LFR, Delves, Arena. Off by default except Raid Mythic/Heroic.
- Optional chat message when auto-logging starts/stops (on by default).
- Handles the `LoggingCombat` rate limit (5 calls/10s shared across all addons) with automatic retry.

### Changes
- QoL options panel: checkboxes in Reminder, Filter, and LFG tabs are now sorted alphabetically by label instead of by feature grouping.

### Fixes
- Fixed taint errors in Blizzard's Group Loot History frame (`GameTooltip_InsertFrame`/`GetUnscaledFrameRect` "secret number value" errors on hover) caused by our `C_LootHistory` override and synchronous `Hide()` calls.
- Fixed "Current Expansion Only" AH filter not being enforced on 12.1+ clients; now re-applied on every AH open.
- Fixed `GreatVault.lua` missing from `.toc` — Great Vault reminder never initialized.
- Fixed Great Vault reminder re-popping after claiming a reward; now only auto-shows once per login session.
- Great Vault reminder now gets the ElvUI skin, matching the other reminders.
- Fixed deDE Great Vault strings ("Großes Gewölbe" → "Große Schatzkammer").
- Fixed `.toc` Notes still referencing "Midnight Season 1".
- Fixed auto-logging not triggering on real zone changes.
- Fixed `ADDON_ACTION_BLOCKED` error opening options in combat — now opens automatically once combat ends.
- Fixed misaligned checkboxes in Reminder, Filter, and LFG tabs.

### Internal
- Full codebase review: syntax check, locale parity, `.toc`/init order, scan for unsafe global API overrides — all clean.

---

## 2.7.2

### Changes
- Season 2 is now active immediately; removed the date-gated auto-switch (`RA.SEASON_SWITCH_DATE`).
- Bonus Rolls re-enabled (`RA.BONUS_ROLLS_ENABLED = true`) — were only disabled during Season 1.
- Updated "What's New" text (deDE/enUS) — no longer references the removed date-based auto-switch.

### Internal
- Fixed stale "Season 1 only" comment in `Reminder.lua`.

---

## 2.7.1

### Fixes
- Omniumfoliant/Vault/Voidcore QoL options hidden pre-max-level; remaining checkboxes shift up.
- World Boss / Lair difficulty IDs corrected (Tidebound Grotto: Mythic `233`, World `250`).
- Fixed tooltip Lua error on Omniumfoliant minimap button pre-max-level.
- Fixed Omniumfoliant minimap button being force-shown, overriding Blizzard's own visibility.

### Internal
- Removed stale comment on Sporefall raid entry in `Raids.lua`.
- Trimmed verbose comments across all files to concise one/two-liners.

---

## 2.7.0

### New
- Automatic Season 1 → Season 2 switch on a configurable date (`RA.SEASON_SWITCH_DATE`).
- World Boss / Lair support (12.1): Tidebound Grotto auto-pass, own toggle, per-difficulty checkboxes.
- Account-wide Legacy Raids setting — shared across characters instead of per-character.
- QoL: hide World Map tracked-faction button (experimental).
- Season 2 Raid: The Venomous Abyss, all 8 bosses.
- Season 2 Delves (12.1): Ring of Glory, Gnarldor Isle, Venomfall Deeps. Delves tab now grouped by patch.
- New Paragon Bag faction: Zul'jarra's Forces (turn-in not yet verified).

### Changes
- Adapted to 12.1's native AH filter persistence — `SetAHExpansionFilter` skipped from 12.1 onward.
- Season tab buttons only clickable in debug mode.
- Torment's Rise removed from delve pool.
- German translations added for Season 2 content.
- "Prey" tab renamed to "Open World", now includes World Bosses / Lairs.
- Reminder text is now season-neutral.

### Fixes
- Torment's Rise no longer disabled prematurely before the actual S1→S2 switch.
- `SetCraftingOrderExpansionFilter` no longer double-fires.
- Reminder popup now also triggers in Season 2 raids (missing map ID).
- Omniumfoliant/Great Vault buttons no longer disappear after zoning.
- Omniumfoliant checkbox label no longer cut off.
- "Hide World Map" no longer breaks Blizzard's cursor-coordinates widget.
- World Map tracked-faction button no longer flashes visible on map switch.
- Debug-only season tabs no longer stick after disabling debug mode.
- Guarded against a Blizzard client bug in `C_LootHistory.GetSortedDropsForEncounter`.

### Internal
- Content data refactored into `Data/` folder, indexed by season number.
- Removed orphaned locale keys and unused locals.

---

## 2.6.3

### Changes
- S2/S3 season tabs now show/hide immediately when toggling debug mode.

### Fixes
- Fixed dev-char lookup breaking on non-UTF-8 file encoding (accented name).
- Fixed `ADDON_ACTION_BLOCKED` when auto-applying default LFG playstyle.

---

## 2.6.2

### New
- QoL: Details! Keystones support alongside BigWigs — new dropdown, mutually exclusive.

### Changes
- S2/S3 tab gating simplified to debug-mode-only.
- Dungeons S2 tab sorted alphabetically.
- Stale ElvUI-only comments updated.
- Dev command list now documents `/rawwhats` and `/rawparagon`.
- Minor cleanup of unused locals.

### Fixes
- Fixed AH filter applying/logging twice on open.
- Fixed hardcoded English error in LFGQuickCreate.
- Fixed What's New "Okay" button relying on hardcoded English text.

---

## 2.6.1

### Fixes
- Fixed Paragon Bag popup showing on every `/reload` instead of only on login.
- Fixed Omniumfoliant/Great Vault buttons leaking onto Titel/Ausrüstungsmanager sub-views.
- S2/S3 season sub-tabs gated behind dev/debug mode.
- Removed misleading "Season 1" header on Delves tab.
- Filled in full Season 2 dungeon roster (mapID/cmID/lfgID + locale), not yet wired into LFGQuickCreate.

---

## 2.6.0

### New
- QoL: Paragon Bag Notification for all 6 Midnight factions, `/rawparagon` to check manually.

### Changes
- Omniumfoliant/Great Vault buttons no longer require ElvUI.

### Fixes
- Nil guard for `C_MythicPlus` in LFGQuickCreate.
- Omniumfoliant/Great Vault buttons no longer appear on every Character Frame tab.
- Paragon/Reminder popups now skin correctly under ElvUI.
- Fixed Paragon popup text overlap with Bonus Roll reminder.
- Fixed LFG auto-playstyle checkbox not saving if AceGUI fails to load.
- Omniumfoliant/Great Vault buttons now gated to max level (fixes tooltip Lua error), re-checked on level-up.

---

## 2.5.6

### New
- QoL: hide Omniumfoliant minimap icon, show as Character Frame button instead (ElvUI only at this point).
- QoL: Great Vault button on Character Frame (ElvUI only at this point).

---

## 2.5.5

### Fixes
- Fixed Sporefall instance ID (2427 → 1592).

---

## 2.5.4

### New
- Auto-apply playstyle toggle for LFG Quick Create.

---

## 2.5.3

### Fixes
- Fixed "List Group" button staying greyed out on first Group Finder open with a default playstyle set.

---

## 2.5.2

### New
- Instance name reminder: BigWigs Keystones toggle now independent from name display.

### Fixes
- Nil guard for `C_ChallengeMode.GetActiveChallengeMapID()`.

---

## 2.5.1

### New
- What's New window — shows new features on first login after a version bump. `/rawwhats`.

### Fixes
- Fixed playstyle labels not matching WoW's UI text.
- Fixed default playstyle not updating live from options.
- Fixed AceGUI Slider editbox staying visible after layout.

### Changes
- Debug mode now shows `cmID`/`lfgID` for matched dungeons.
- Added dev character `Frostbryn`.

---

## 2.5.0

### New
- QoL: LFG Quick Create — dungeon icon buttons in Group Finder for instant listing creation. Own-keystone dungeon highlighted.
- QoL: Default Playstyle dropdown.
- QoL: BigWigs Keystones auto-open on own listing.
- AceGUI-3.0 embedded for ElvUI-native widgets.
- New file `LFGQuickCreate.lua`.

### Changes
- `cmID`/`lfgID` centralized in `Core.lua`'s `SEASON1_DUNGEONS`.

### Fixes
- Fixed loot history auto-hide not working on first roll of a session.
- Fixed reminder/BigWigs auto-open triggering for the group leader.
- Fixed BigWigs double-toggle and open-on-cancel edge cases.

### Notes
- Season 2 dungeon data pending PTR confirmation.

---

## 2.4.2

### New
- Instance join reminder now also fires on direct invite.
- BigWigs Keystones auto-open on join (party only).

### Changes
- Join reminder waits for full group before the hide timer (raids start immediately).
- Join reminder filtered to M+ dungeons and current-season raids.
- Spam protection for `GROUP_ROSTER_UPDATE`.
- Dev slash commands now require dev char + debug mode.

### Fixes
- Fixed direct `C_Timer.After` call in ElvUI_Skin.lua.
- Fixed `waitFrame` missing a parent frame.
- Fixed `bwOpened` race condition.
- Fixed `MakeSeasonTabs` ordering in Options.lua.

---

## 2.4.1

### New
- Tab styling (active/inactive/hover states) for all option tabs.

---

## 2.4.0

### New
- `Debug.lua` — centralized developer tooling and event logger.
- QoL: Instance join reminder (6s display), disabled by default.
- Season sub-tabs for Dungeons/Raids.
- Season 2 dungeons (partial, 12.1): 4 of 8 added.
- Sporefall added as Season 1 raid (12.0.7).

### Changes
- Slash commands centralized in `Debug.lua`.
- Durability warning timer reduced to 6s.
- Season feature flags added: `RA.ACTIVE_SEASON`, `RA.BONUS_ROLLS_ENABLED`.

### Fixes
- Fixed S1/S2 dungeon tab frame-name collisions.
- Fixed Bonus Roll options staying visible when disabled.
- Fixed Legacy tab anchoring when Bonus Roll tabs hidden.
- Fixed join reminder firing for other players' joins.
- Fixed `RA.ShowJoinReminder` nil at test time.
- Fixed vault currency display not appearing (lazy-loaded frame, `SetShown` hook, position by UI type).
- Removed durability event from event logger (chat spam).

---

## 2.3.7

### New
- Added `/rawreset` dev command; added dev character **Urannok**.

### Changes
- Reminder reset logic reworked around `GROUP_JOINED`/`GROUP_LEFT`/`FullReset`.
- Debug logging added for all reminder resets.

### Fixes
- Fixed reminder re-appearing on re-entering the same instance without leaving group.
- Fixed unintended reset on leaving to open world.

---

## 2.3.6

### Changes
- TOC updated for patch 12.0.7.
- File headers cleaned up.
- Reminder reset logic refined around group/instance changes.

### Fixes
- Fixed AH filter clearing when switching AH tabs.

---

## 2.3.5

### New
- QoL: Great Vault currency display (Nebulous Voidcore count), enabled by default.

### Changes
- `VOIDCORE_CURRENCY_ID` centralized in `Core.lua`.

### Fixes
- Fixed duplicate `Show()`/`DBG()` calls.
- Fixed vault currency frame overflowing frame bounds.
- Fixed hardcoded English "Bonus Loot" label.

---

## 2.3.4

### New
- QoL: AH & Crafting Orders "Current Expansion Only" auto-filter, disabled by default.

### Changes
- QoL panel split into Reminder / Filter sections.
- Shortened slider label.

### Fixes
- Removed redundant nil init of timer locals.

---

## 2.3.3

### New
- QoL: Durability warning at ≤30%.
- Reminder: Okay button replaces X close button.

### Changes
- Developer/Tester sections restricted to designated characters.
- Test commands restricted to dev characters.
- Test commands documented in General tab.
- ScrollFrame scroll input fixed in default UI.

### Fixes
- Fixed `SetHitRectInsets` no-op on zero-width Legacy checkboxes.

---

## 2.3.2

### Fixes
- Fixed Legacy Transmog roll not working in default Blizzard UI.
- Fixed silent skip on missing button reference fallback.

---

## 2.3.1

### New
- QoL: Ready Check reminder ("Check Talents"), adjustable font size.
- New QoL subcategory in addon list.

### Changes
- General tab now scrollable; Visibility section moved to top; larger section headers.

---

## 2.3.0

### New
- Reminder popup shows current Voidcore count and available bonus rolls (color-coded).

### Changes
- Separator line added between reminder text and currency display.
- Difficulty ID now cached; minor performance cleanups.

---

## 2.2.2

### Changes
- Reminder now Mythic/M+ only, not Normal/Heroic.
- Added description texts under Visibility checkboxes.

### Fixes
- Fixed reminder reappearing after `/reload`.
- Fixed reminder not showing again after portal re-entry.
- Fixed manual `/loot` being blocked in raids.
- Renamed `hideInDungeons` → `hideInRaid`.

---

## 2.2.1

### Fixes
- Fixed reminder reappearing after The Voidspire's portal zone change.
- Fixed reminder appearing in non-Mythic dungeons.
- Fixed reminder not closing on leaving group.
- Fixed ESC not closing reminder popup.
- Fixed Legacy roll checkboxes registering the wrong checkbox.
- Fixed reminder status bar color under ElvUI.

### Changes
- Reminder popup now has a 20s countdown bar, closes on combat start.
- Performance cleanups (auto-pass, loot roll frame cache).

---

## 2.2.0

### New
- Reminder popup on entering Season 1 Mythic dungeon/raid.
- Legacy auto-roll (Need/Greed/Transmog) in legacy raids.

### Changes
- Prey detection rewritten (no hardcoded zone IDs).
- Codebase split into modules.
- General tab reorganized.
- Instance/encounter lookups now O(1).

### Fixes
- Fixed Prey auto-pass failing after weekly reset.
- Fixed crash in `IsPreyActive`.

---

## 2.0.0

### New
- Complete rework for Midnight 12.0.5.
- Bonus Roll auto-pass for Season 1 dungeons, delves, raids, Prey.
- Modular tab-based settings UI.
- ElvUI skin support throughout.