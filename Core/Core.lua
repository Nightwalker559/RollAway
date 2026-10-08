-- RollAway - Core/Core.lua
-- Shared state, data, utilities and event handling.

local addonName = ...

-- Locale fallback: missing keys return the key itself to prevent UI crashes.
local RA_L = _G["RollAwayLocale"] or {}
setmetatable(RA_L, { __index = function(_, k) return k end })

-- Shared namespace, reused if Data/*.lua already created it.
local RA = _G["RollAway"] or {}
_G["RollAway"] = RA

RA.RA_L                 = RA_L
RA.VOIDCORE_CURRENCY_ID = 3418  -- Nebulous Voidcore currency

------------------------------------------------------------------------
-- Season configuration
-- BONUS_ROLLS_ENABLED: Bonus Rolls were disabled in S1, re-enabled for S2.
------------------------------------------------------------------------
RA.BONUS_ROLLS_ENABLED = true
RA.ACTIVE_SEASON       = 2

------------------------------------------------------------------------
-- Debug output – only for designated developer/tester characters
------------------------------------------------------------------------
local DEV_CHARS = {
    ["Thal\195\174ndra"] = true, -- "Thalîndra", byte-escaped for encoding safety
    ["Asiamonatina"]     = true,
    ["Luckyone"]         = true,
    ["Urannok"]          = true,
    ["Frostbryn"]        = true,
    ["Nirakita"]         = true,
}
RA.DEV_CHARS = DEV_CHARS

local function DBG(...)
    if RollAwayDB and RollAwayDB.debug and DEV_CHARS[UnitName("player")] then
        if RA.AppendDebugLog then RA.AppendDebugLog(...) end
    end
end
RA.DBG = DBG

-- Separate, quieter channel: gated on its own "errors only" checkbox instead
-- of the full "debug" flag, so a dev char can catch rare self-heal errors
-- (e.g. CharFrameButtons.lua's refresh errors) without wading through the full
-- verbose debug log for everything else.
local function DBGError(...)
    if RollAwayDB and (RollAwayDB.debug or RollAwayDB.debugErrorsOnly) and DEV_CHARS[UnitName("player")] then
        if RA.AppendDebugLogUnfiltered then RA.AppendDebugLogUnfiltered(...) end
    end
end
RA.DBGError = DBGError

------------------------------------------------------------------------
-- Content data now lives in Data/*.lua (see .toc). Add seasons there.
------------------------------------------------------------------------
local SEASON1_DUNGEONS      = RA.DUNGEONS[1]
local SEASON2_DUNGEONS      = RA.DUNGEONS[2]
local SEASON1_DELVES        = RA.DELVES[1]
local SEASON2_DELVES        = RA.DELVES[2]
local SEASON1_RAIDS         = RA.RAIDS[1]
local SEASON2_RAIDS         = RA.RAIDS[2]
local SEASON1_LEGACY_RAIDS  = RA.LEGACY_RAIDS

------------------------------------------------------------------------
-- Lookup maps – O(1) matching, built once at load time
------------------------------------------------------------------------
local DUNGEON_MAP         = {}
local DUNGEON_ENTRY_MAP   = {}  -- mapID -> full dungeon entry (for cmID/lfgID lookup)
local DELVE_MAP           = {}
local RAID_ENCOUNTER_MAP  = {}
local LEGACY_ENCOUNTER_MAP = {}

for _, d in ipairs(SEASON1_DUNGEONS)     do DUNGEON_MAP[d.mapID] = d.key ; DUNGEON_ENTRY_MAP[d.mapID] = d end
for _, d in ipairs(SEASON2_DUNGEONS)     do DUNGEON_MAP[d.mapID] = d.key ; DUNGEON_ENTRY_MAP[d.mapID] = d end
for _, d in ipairs(SEASON1_DELVES)       do DELVE_MAP[d.mapID]                = d.key  end
for _, d in ipairs(SEASON2_DELVES)       do if d.mapID then DELVE_MAP[d.mapID] = d.key end end
for _, b in ipairs(SEASON1_RAIDS)        do RAID_ENCOUNTER_MAP[b.encounterID] = b.key  end
for _, b in ipairs(SEASON2_RAIDS)        do if b.encounterID then RAID_ENCOUNTER_MAP[b.encounterID] = b.key end end
for _, b in ipairs(SEASON1_LEGACY_RAIDS) do LEGACY_ENCOUNTER_MAP[b.encounterID] = b.raid end

RA.DUNGEON_MAP          = DUNGEON_MAP
RA.DELVE_MAP            = DELVE_MAP
RA.RAID_ENCOUNTER_MAP   = RAID_ENCOUNTER_MAP

------------------------------------------------------------------------
-- Raid difficulty bucket map – groups the various difficultyIDs seen
-- across normal raids and raid-instance Lairs/World Bosses into 4 UI
-- buckets. 233 (Mythic Flex) folds into "mythic", 250 (World) folds into
-- "lfr" - both driven by cachedDiffID at ENCOUNTER_END/zone change.
------------------------------------------------------------------------
RA.RAID_DIFFICULTY_BUCKET = {
    [14]  = "normal",
    [15]  = "heroic",
    [16]  = "mythic",
    [17]  = "lfr",
    [233] = "mythic", -- Mythic Flex (Lairs)
    [250] = "lfr",    -- World (Lairs)
}

-- Dungeon difficulty IDs that count as "Mythic" content (Reminder, Logs).
RA.MYTHIC_DUNGEON_DIFFICULTY_IDS = {
    [8]  = true,  -- Mythic (non-keystone)
    [23] = true,  -- Mythic Keystone (M+)
}

------------------------------------------------------------------------
-- State variables – shared across all modules
------------------------------------------------------------------------
RA.cachedInstanceType = "none"
RA.cachedInstanceID   = 0
RA.cachedDiffID       = 0
RA.lastEncounterID    = 0
RA.bonusRollEncounterID = nil  -- DungeonEncounterID of the open bonus roll's boss (AutoPass.lua)
-- Developer test switches (Options/OptionsDev.lua); never saved, off after /reload.
RA.devTest = { oldRaidAutoPass = false }
RA.lastLegacyEncounterID = 0
RA.closeTimer            = nil
RA.ElvLootModule         = nil
RA.activeRolls           = {}
RA.rollTimers            = {}

------------------------------------------------------------------------
-- Saved variable defaults
--
-- 3.0.1+: settings are managed by AceDB-3.0 (RollAwayDBAccount), which is
-- character-specific by default (one profile per character, switchable).
-- RA.defaults.profile  -> per-character settings (was flat RollAwayDB pre-3.0.1)
-- RA.defaults.global   -> true account-wide settings, shared by all profiles
-- RA.defaultsChar       -> unchanged: SavedVariablesPerCharacter, always
--                          strictly per-character, never part of a profile.
------------------------------------------------------------------------
RA.defaults = {
    profile = {
        delay              = 5,
        hideInRaidBuckets  = { lfr = false, normal = false, heroic = false, mythic = false },
        hideInLegacyRaids  = false,   -- own switch: legacy raids ignore the per-difficulty boxes
        rollTimeout        = 60,
        lootFrameAutoCloseDisabled = false,
        legacy             = false,
        legacyNeed         = false,
        legacyGreed        = false,
        legacyTransmog     = false,
        legacyPass         = false,
        showReminder       = false,
        autoPassWarning    = true,   -- safety net: only ever shows when an auto-pass is active
        readyCheckReminder = false,
        readyCheckShowSpec = false,
        qolReminderLockPosition = false,
        durabilityWarning    = false,
        expansionFilterAH    = false,
        vaultCurrencyDisplay = false,
        instanceJoinReminder = false,
        autoAcceptInvite     = false,
        autoRepairMode       = "none",   -- "none" | "player" | "guild"
        joinReminderKeyAddon = "none",    -- "none" | "bigwigs" | "details" | "teleport" – mutually exclusive
        lfgQuickCreate       = false,
        lfgAutoPlaystyle     = false,
        lfgDefaultPlaystyle  = 0,
        lfgAutoMythicPlus    = false,
        hideOmniumfoliantMinimap = false,
        vaultButtonCharFrame     = false,
        hideMapActivityTracker   = false,
        hideCraftingOutputLog    = false,
        hideErrorMessages        = false,
        hideTalkingHead          = false,
        hideBossBanner           = false,
        hideEventToasts          = false,
        hideAlerts               = false,
        questAcceptRegular       = false,
        questAcceptDaily         = false,
        questAcceptWeekly        = false,
        questAutoTurnIn          = false,
        questRequireModifier     = false,
        questModifierKey         = "SHIFT",   -- "SHIFT" | "ALT" | "CTRL"
        tankMarkEnabled          = false,
        tankMarkIcon             = 6,   -- raid marker 1-8 (6 = square)
        paragonAlert            = false,
        greatVaultAlert          = false,
        talentFontSize     = 20,
        autoLogEnabled       = false,
        autoLogScenario      = false,   -- scenarios and delves (delves count as scenarios)
        autoLogMythicDungeon = false,
        autoLogRaidMythic    = false,
        autoLogRaidHeroic    = false,
        autoLogRaidNormal    = false,
        autoLogRaidLFR       = false,
        autoLogChatNotify    = false,
        advLogReminderEnabled = false,
        debug              = false,
        debugErrorsOnly    = false,
        whatsNewSeen       = "",
        vendorFilterEnabled = false,
        vendorFilterAlpha   = 0.35,
        confirmRoll         = { need = false, greed = false, transmog = false, pass = false },
    },
    global = {
        -- The one setting that stays account-wide on purpose: whether legacy
        -- raid roll selections are shared across all characters/profiles.
        legacyAccountWide = false,
        legacy_raids      = {},
    },
}

RA.defaultsChar = {
    dungeons     = {},
    dungeons_s2  = {},
    dungeonAutoPassAll = false,
    delves       = {},
    delves_s2    = {},
    delveAutoPassAll = false,
    raids        = {},
    raidAutoPassDifficulty = { lfr = false, normal = false, heroic = false, mythic = false },
    legacy_raids = {},
    prey         = false,
}

-- Active Legacy Raids table: account-wide (RA.db.global) or per-character.
local function GetLegacyRaidsDB()
    if RA.db and RA.db.global.legacyAccountWide then
        return RA.db.global.legacy_raids
    end
    return RollAwayDBChar and RollAwayDBChar.legacy_raids
end
RA.GetLegacyRaidsDB = GetLegacyRaidsDB

------------------------------------------------------------------------
-- Profile migration (3.0.1): pre-3.0.1 RollAwayDB was a single flat,
-- account-wide table. 3.0.1 switches to AceDB-3.0 profiles, character-
-- specific by default, so every character now starts on a blank Default
-- profile. On each character's first login after the update we offer to
-- carry the old (already-customized) values over instead, or start that
-- character fresh on defaults - see RA_L["profile_migration_popup_text"].
------------------------------------------------------------------------
function RA.RunProfileMigration(legacyFlatSV)
    -- The two settings that moved to RA.db.global are applied once ever,
    -- account-wide, regardless of what each character chooses below.
    if legacyFlatSV and not RA.db.global.legacyMigrated then
        if legacyFlatSV.legacyAccountWide ~= nil then
            RA.db.global.legacyAccountWide = legacyFlatSV.legacyAccountWide
        end
        if type(legacyFlatSV.legacy_raids) == "table" then
            RA.db.global.legacy_raids = RA.DeepCopy(legacyFlatSV.legacy_raids)
        end
        RA.db.global.legacyMigrated = true
    end

    -- Already asked this character - nothing more to do.
    if RollAwayDBChar.profileMigrationAsked then return end
    RollAwayDBChar.profileMigrationAsked = true

    -- Cache the first flat snapshot seen account-wide, so alts logging in
    -- later still get the same offer even though the per-character
    -- RollAwayDB alias has since moved on to point at their own profile.
    if legacyFlatSV and next(legacyFlatSV) then
        RA.db.global.legacyMigrationSnapshot = RA.db.global.legacyMigrationSnapshot or RA.DeepCopy(legacyFlatSV)
    end

    local snapshot = RA.db.global.legacyMigrationSnapshot
    if type(snapshot) ~= "table" or not next(snapshot) then return end -- nothing to offer (fresh install)

    RA.RegisterPopup("ROLLAWAY_PROFILE_MIGRATION", {
        text          = RA_L["profile_migration_popup_text"],
        button1       = RA_L["profile_migration_keep"],
        button2       = RA_L["profile_migration_default"],
        OnAccept      = function()
            for k, v in pairs(snapshot) do
                if RA.defaults.profile[k] ~= nil then
                    RA.db.profile[k] = RA.DeepCopy(v)
                end
            end
        end,
        hideOnEscape  = false,
    })
    -- Shown a few seconds after ADDON_LOADED instead of immediately: a
    -- StaticPopup this early in the login sequence, before Blizzard's own
    -- UI (guild frame included) has finished initializing, is a plausible
    -- contributor to ADDON_ACTION_FORBIDDEN/IsUserOAuthed reports seen only
    -- on a character's very first login. Cheap to try, can't make things
    -- worse either way.
    C_Timer.After(3, function()
        StaticPopup_Show("ROLLAWAY_PROFILE_MIGRATION")
    end)
end

------------------------------------------------------------------------
-- Instance cache, loot-history handling and the main event handler.
-- Generic popup/timer/table utilities live in Helpers.lua (loaded next).
------------------------------------------------------------------------

local function UpdateInstanceCache()
    local ok, _, instType, diffID, _, _, _, _, instanceID = pcall(GetInstanceInfo)
    RA.cachedInstanceType = (ok and instType)   or "none"
    RA.cachedInstanceID   = (ok and instanceID) or 0
    RA.cachedDiffID       = (ok and diffID)     or 0
end
RA.UpdateInstanceCache = UpdateInstanceCache

-- Compact, single-line zone-change summary: instance identity + matched
-- dungeon/delve + whether auto-pass would currently trigger. Replaces the
-- old multi-line dump for normal use (raw field dump moved to /rawdump).
local function LogInstanceSummary()
    if not RollAwayDB or not RollAwayDB.debug then return end
    local ok, instName = pcall(GetInstanceInfo)
    local id = RA.cachedInstanceID

    local matchLabel = "no match"
    if id ~= 0 then
        local dungKey  = DUNGEON_MAP[id]
        local delveKey = DELVE_MAP[id]
        if dungKey then
            matchLabel = "Dungeon: " .. RA_L["dungeon_"..dungKey]
        elseif delveKey then
            matchLabel = "Delve: " .. RA_L["delve_"..delveKey]
        end
    end

    local shouldPass, reason = false, nil
    if RA.ComputeAutoPassState then
        shouldPass, reason = RA.ComputeAutoPassState()
    end
    local passLabel = shouldPass and ("yes (" .. tostring(reason) .. ")") or "no"

    -- Open world: also show the zone (with expansion), the world map and
    -- whether it counts as Midnight (Prey auto-pass only applies there).
    local mapLabel = ""
    if RA.cachedInstanceType == "none" and RA.IsInMidnightZone and RA.GetZoneLabel then
        local midnight, mapID = RA.IsInMidnightZone()
        mapLabel = string.format(" | Zone: %s | Map: %s | Midnight: %s",
            RA.GetZoneLabel(), tostring(mapID), tostring(midnight))
    end

    DBG(string.format("Instance: %s | Type: %s | ID: %d | Diff: %d | %s%s | Auto-pass: %s",
        (ok and instName) or "?", RA.cachedInstanceType, id, RA.cachedDiffID, matchLabel, mapLabel, passLabel))
end
RA.LogInstanceSummary = LogInstanceSummary

-- Raw GetInstanceInfo field dump – manual use only via /rawdump. The
-- matched-content + auto-pass summary lives in LogInstanceSummary above.
local function DebugInstanceDump()
    if not RollAwayDB or not RollAwayDB.debug then return end
    local ok, instName, instType, diffID, diffName, maxPlayers, dynDiff, isDynamic, instanceID, groupSize, lfgID = pcall(GetInstanceInfo)
    if not ok then
        DBG("--- GetInstanceInfo dump --- pcall failed:", instName)
        return
    end
    DBG("--- GetInstanceInfo dump ---")
    DBG("  name        =", tostring(instName))
    DBG("  instanceType=", tostring(instType))
    DBG("  difficultyID=", tostring(diffID))
    DBG("  diffName    =", tostring(diffName))
    DBG("  maxPlayers  =", tostring(maxPlayers))
    DBG("  dynDiff     =", tostring(dynDiff))
    DBG("  isDynamic   =", tostring(isDynamic))
    DBG("  instanceID  =", tostring(instanceID))
    DBG("  groupSize   =", tostring(groupSize))
    DBG("  lfgDungeonID=", tostring(lfgID))
    DBG("  cmID (live) =", tostring(C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID()))
    DBG("----------------------------")
    local entry = instanceID and DUNGEON_ENTRY_MAP[instanceID]
    if entry then
        DBG("-> Dungeon entry | cmID:", tostring(entry.cmID), "| lfgID:", tostring(entry.lfgID))
    end
end
RA.DebugInstanceDump = DebugInstanceDump

local function HasActiveRolls()
    for _ in pairs(RA.activeRolls) do return true end
    return false
end

-- Deferred by one frame (RunNextFrame) so our Hide() call runs on a fresh,
-- untainted execution stack instead of directly inside whatever event handler
-- (START_LOOT_ROLL, ENCOUNTER_END, etc.) triggered it. Calling Hide() on
-- GroupLootHistoryFrame synchronously from insecure code taints that frame's
-- execution context, which later surfaces as unrelated "secret number value"
-- arithmetic errors in Blizzard's own tooltip/layout code (GetUnscaledFrameRect,
-- GameTooltip_InsertFrame) when the player hovers a loot history row.
-- Transparency only (SetAlpha runs no Blizzard script, so it is safe to call
-- right away, unlike Hide()). Covers Blizzard's frame and ElvUI's.
local function SetHistoryAlpha(alpha)
    if GroupLootHistoryFrame then GroupLootHistoryFrame:SetAlpha(alpha) end
    local elvFrame = RA.ElvLootModule and RA.ElvLootModule.GroupLootHistoryFrame
    if elvFrame then elvFrame:SetAlpha(alpha) end
end

local function HistoryFrameShown()
    local elvFrame = RA.ElvLootModule and RA.ElvLootModule.GroupLootHistoryFrame
    return (GroupLootHistoryFrame and GroupLootHistoryFrame:IsShown())
        or (elvFrame and elvFrame:IsShown()) or false
end

local function DoHideHistoryFrame()
    if GroupLootHistoryFrame and GroupLootHistoryFrame:IsShown() then
        DBG("Hiding loot history frame")
        GroupLootHistoryFrame:Hide()
    end
    if RA.ElvLootModule and RA.ElvLootModule.GroupLootHistoryFrame
    and RA.ElvLootModule.GroupLootHistoryFrame:IsShown() then
        RA.ElvLootModule.GroupLootHistoryFrame:Hide()
    end
    SetHistoryAlpha(1)  -- hidden now; full alpha again for the next time it is opened
end

local function HideHistoryFrame()
    RunNextFrame(DoHideHistoryFrame)
end

-- For frames that must never be seen (hide-in-raid): Hide() has to wait a
-- frame, so make the frame see-through at once - no flash in between.
local function HideHistoryFrameAtOnce()
    SetHistoryAlpha(0)
    HideHistoryFrame()
end

local function CancelAllRollTimers()
    for rollID, t in pairs(RA.rollTimers) do
        DBG("Watchdog cancelled:", rollID)
        RA.SafeCancelTimer(t)
    end
    wipe(RA.rollTimers)
end

-- Resets roll state and timers – does not touch the loot history frame.
local function ResetState(reason)
    DBG("ResetState:", reason)
    CancelAllRollTimers()
    if RA.closeTimer then RA.SafeCancelTimer(RA.closeTimer); RA.closeTimer = nil end
    wipe(RA.activeRolls)
    RA.lastEncounterID = 0
    RA.bonusRollEncounterID = nil
end

-- Debug-log section divider: a call more than 3s after the previous one
-- starts a new section. Time-gap based rather than tied to a fixed event
-- name, since e.g. Delves only fire ZONE_CHANGED_NEW_AREA and never
-- PLAYER_ENTERING_WORLD, while a normal instance entry fires both ~1s
-- apart and should stay one section. Called from zone-change and
-- group-leave/join handling (see Core.lua and Debug.lua's event logger).
local function NoteDebugLogSectionEvent()
    local now = GetTime()
    if RA.AppendDebugLogSeparator and (not RA.lastZoneEventTime or (now - RA.lastZoneEventTime) > 3) then
        RA.AppendDebugLogSeparator()
    end
    RA.lastZoneEventTime = now
end
RA.NoteDebugLogSectionEvent = NoteDebugLogSectionEvent

-- Full reset including hiding the loot history frame (group/raid leave only).
local function FullReset(reason)
    DBG("FullReset:", reason)
    ResetState(reason)
    RA.lastLegacyEncounterID = 0
    -- Clear reminder state so the next raid/dungeon entry shows the reminder again.
    if RollAwayDBChar then
        RollAwayDBChar.lastReminderInstID = nil
        RollAwayDBChar.lastAdvLogReminderInstID = nil
        DBG("Reminder reset: FullReset triggered by:", reason)
    end
    HideHistoryFrame()
end

local function ShouldHideInInstance()
    if not RollAwayDB or RollAwayDB.lootFrameAutoCloseDisabled then return false end
    if RA.cachedInstanceType ~= "raid" then return false end
    -- Legacy raids have their own switch, whatever the difficulty; the
    -- per-difficulty boxes below are for current-season raids only.
    if RA.LEGACY_RAID_INSTANCES[RA.cachedInstanceID] then
        return RollAwayDB.hideInLegacyRaids == true
    end
    local bucket = RA.RAID_DIFFICULTY_BUCKET[RA.cachedDiffID]
    if not bucket or not RollAwayDB.hideInRaidBuckets then return false end
    return RollAwayDB.hideInRaidBuckets[bucket] == true
end

local function TryStartCloseTimer()
    if RollAwayDB and RollAwayDB.lootFrameAutoCloseDisabled then return end
    if HasActiveRolls() or RA.closeTimer then return end
    DBG("Starting close timer:", RollAwayDB.delay, "sec")
    RA.closeTimer = C_Timer.NewTimer(RollAwayDB.delay, function()
        DBG("Close timer expired")
        HideHistoryFrame()
        RA.closeTimer = nil
    end)
end

-- Called once after all rolls complete to decide whether to start close timer.
local function CheckAndClose()
    if not HasActiveRolls() and not ShouldHideInInstance() then
        TryStartCloseTimer()
    end
end

------------------------------------------------------------------------
-- Event handler
------------------------------------------------------------------------

-- Module Init functions, run in this order once the saved variables are ready.
local INIT_ORDER = {
    "InitWhatsNew", "InitAutoPass", "InitRollConfirm", "InitQoL", "InitQuests", "InitTankMarker", "InitVendorFilter",
    "InitParagon", "InitGreatVault", "InitLFGQuickCreate", "InitOptions", "InitDebug",
}

-- Adds `false` for every entry's key (entry[keyField]) missing from tbl.
local function FillMissing(tbl, entries, keyField)
    for _, entry in ipairs(entries) do
        local key = entry[keyField]
        if tbl[key] == nil then tbl[key] = false end
    end
end

-- Per-character selections (SavedVariablesPerCharacter): fills in defaults,
-- replaces any key that has the wrong type, and adds an entry (default off)
-- for every dungeon/delve/boss. Also re-run after a profile reset wipes the
-- table (Options\OptionsProfile.lua), so nothing sees it half-empty.
function RA.InitCharDB()
    RollAwayDBChar = RollAwayDBChar or {}
    for k, v in pairs(RA.defaultsChar) do
        if type(v) == "table" then
            if type(RollAwayDBChar[k]) ~= "table" then RollAwayDBChar[k] = RA.DeepCopy(v) end
        elseif RollAwayDBChar[k] == nil then
            RollAwayDBChar[k] = v
        end
    end

    FillMissing(RollAwayDBChar.dungeons,     SEASON1_DUNGEONS, "key")
    FillMissing(RollAwayDBChar.dungeons_s2,  SEASON2_DUNGEONS, "key")
    FillMissing(RollAwayDBChar.delves,       SEASON1_DELVES,   "key")
    FillMissing(RollAwayDBChar.delves_s2,    SEASON2_DELVES,   "key")
    FillMissing(RollAwayDBChar.raids,        SEASON1_RAIDS,    "key")
    FillMissing(RollAwayDBChar.raids,        SEASON2_RAIDS,    "key")
    FillMissing(RollAwayDBChar.legacy_raids, SEASON1_LEGACY_RAIDS, "raid")
    -- Account-wide (true global) mirror of legacy_raids, used when
    -- RA.db.global.legacyAccountWide is enabled.
    FillMissing(RA.db.global.legacy_raids,   SEASON1_LEGACY_RAIDS, "raid")

    -- Delves removed from the game pool stay disabled.
    if RA.ACTIVE_SEASON >= 2 then
        for _, d in ipairs(SEASON1_DELVES) do
            if d.removedAfterS1 then RollAwayDBChar.delves[d.key] = false end
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("START_LOOT_ROLL")
f:RegisterEvent("LOOT_ROLLS_COMPLETE")
f:RegisterEvent("ENCOUNTER_END")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("GROUP_LEFT")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")

f:SetScript("OnEvent", function(_, event, ...)
    local arg1 = (...)

    if event == "START_LOOT_ROLL" then
        DBG("START_LOOT_ROLL rollID:", arg1)

        RA.activeRolls[arg1] = true

        if RA.closeTimer then RA.SafeCancelTimer(RA.closeTimer); RA.closeTimer = nil end

        -- Watchdog: force-closes frame if LOOT_ROLLS_COMPLETE never fires cleanly.
        -- Skipped entirely if the whole auto-close feature is disabled in Options.
        if not RA.rollTimers[arg1] and not (RollAwayDB and RollAwayDB.lootFrameAutoCloseDisabled) then
            local wdID = arg1
            RA.rollTimers[wdID] = C_Timer.NewTimer(RollAwayDB.rollTimeout, function()
                DBG("Watchdog expired for rollID", wdID)
                RA.rollTimers[wdID] = nil
                RA.activeRolls[wdID] = nil
                if not HasActiveRolls() then
                    CancelAllRollTimers()
                    HideHistoryFrame()
                end
            end)
        end

        if ShouldHideInInstance() then HideHistoryFrameAtOnce() end

        -- Legacy auto-roll
        if RollAwayDB and RollAwayDB.legacy and RA.ExecuteLegacyRoll then
            local raidKey = LEGACY_ENCOUNTER_MAP[RA.lastLegacyEncounterID]
            local legacyRaidsDB = GetLegacyRaidsDB()
            if raidKey and legacyRaidsDB and legacyRaidsDB[raidKey] then
                DBG("[Legacy] Auto-roll for rollID:", arg1, "| raid:", raidKey)
                RA.ExecuteLegacyRoll(arg1)
            end
        end

    elseif event == "LOOT_ROLLS_COMPLETE" then
        DBG("LOOT_ROLLS_COMPLETE arg1:", arg1)

        -- Remove the completed roll and its watchdog.
        RA.activeRolls[arg1] = nil
        RA.SafeCancelTimer(RA.rollTimers[arg1])
        RA.rollTimers[arg1] = nil

        -- Clean up stale rolls with no valid item link (concurrent rolls only).
        if next(RA.activeRolls) then
            for rollID in pairs(RA.activeRolls) do
                if not GetLootRollItemLink(rollID) then
                    RA.SafeCancelTimer(RA.rollTimers[rollID])
                    RA.rollTimers[rollID] = nil
                    RA.activeRolls[rollID] = nil
                end
            end
        end

        C_Timer.After(0.1, CheckAndClose)

    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName, _, _, endStatus = ...
        if endStatus == 1 then
            DBG("ENCOUNTER_END kill | encounterID:", encounterID, "| name:", encounterName)
            if RAID_ENCOUNTER_MAP[encounterID] then
                RA.lastEncounterID = encounterID
            elseif LEGACY_ENCOUNTER_MAP[encounterID] then
                RA.lastLegacyEncounterID = encounterID
                DBG("[Legacy] Raid matched:", LEGACY_ENCOUNTER_MAP[encounterID])
            end
        end

    elseif event == "GROUP_LEFT" then
        FullReset("GROUP_LEFT")

    elseif event == "PLAYER_REGEN_DISABLED" then
        ResetState("PLAYER_REGEN_DISABLED")
        -- Nobody wants a loot popup blocking the screen mid-fight - hide it
        -- the instant combat starts, even with rolls still pending (only
        -- RollAway's own history window closes; Blizzard's roll popups are
        -- unaffected and still usable). Independent of ShouldHideInInstance,
        -- which is a separate, narrower "never show at all in this raid
        -- difficulty" preference - this applies everywhere, unless the whole
        -- auto-close/auto-hide feature is disabled via its master switch.
        if not (RollAwayDB and RollAwayDB.lootFrameAutoCloseDisabled) then
            if HistoryFrameShown() then DBG("Entering combat – hiding loot history frame") end
            HideHistoryFrame()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if RA.pendingProtectedAction then
            local fn = RA.pendingProtectedAction
            RA.pendingProtectedAction = nil
            fn()
        end

    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if not RA.initialized then return end  -- wait for ADDON_LOADED
        NoteDebugLogSectionEvent()
        UpdateInstanceCache()
        ResetState(event)
        RA.lastLegacyEncounterID = 0
        -- "Shown once per instance" marks (per character, so a shared profile
        -- cannot suppress another character's reminder): cleared on group
        -- leave, on a fresh login, and whenever the reminders see that we are
        -- outside instanced content (Reminder.lua / Logs.lua). A /reload
        -- inside an instance keeps them, so it does not pop up again.
        if arg1 and RollAwayDBChar then  -- arg1 = isInitialLogin
            RollAwayDBChar.lastReminderInstID = nil
            RollAwayDBChar.lastAdvLogReminderInstID = nil
        end
        LogInstanceSummary()
        if ShouldHideInInstance() then HideHistoryFrameAtOnce() end
        -- PLAYER_ENTERING_WORLD and ZONE_CHANGED_NEW_AREA both fire for a
        -- single actual zone change; cancel any pending timer from the
        -- other one so ShowReminder only runs once, not twice ~1s apart.
        -- A token guard backs up the cancel call: cancelling a timer that
        -- is already about to fire can still let its callback through, so
        -- the callback also checks it's still the most recent request.
        if RA.reminderShowTimer then RA.SafeCancelTimer(RA.reminderShowTimer) end
        RA.reminderShowToken = (RA.reminderShowToken or 0) + 1
        local myReminderToken = RA.reminderShowToken
        local function FireReminder()
            RA.reminderShowTimer = nil
            if RA.reminderShowToken ~= myReminderToken then return end  -- superseded
            if RA.ShowReminder then RA.ShowReminder() end
        end
        -- Show right away (the instance cache was just refreshed), then once
        -- more shortly after as a safety recheck: GetInstanceInfo() and the
        -- Voidcore currency can still be stale on the very first event after
        -- a fast zone / login. ShowReminder is idempotent per instance.
        if RA.ShowReminder then RA.ShowReminder() end
        RA.reminderShowTimer = C_Timer.NewTimer(1.5, FireReminder)

    elseif event == "ADDON_LOADED" and arg1 == addonName then

        -- Capture the pre-3.0.1 flat, account-wide RollAwayDB *before* AceDB
        -- touches anything. Nil on a fresh install / already-migrated account.
        local legacyFlatSV = _G.RollAwayDB

        if legacyFlatSV then
            -- Historical migrations, run once on the raw flat snapshot so a
            -- user jumping straight from a much older version still lands on
            -- correct values if they choose "keep old settings" below.

            -- Migration (pre-2.6.3): joinReminderBigWigs (boolean) -> joinReminderKeyAddon (string).
            if legacyFlatSV.joinReminderKeyAddon == nil and legacyFlatSV.joinReminderBigWigs ~= nil then
                legacyFlatSV.joinReminderKeyAddon = legacyFlatSV.joinReminderBigWigs and "bigwigs" or "none"
            end
            legacyFlatSV.joinReminderBigWigs = nil

            -- Migration (pre-2.9.0): hideInRaid (single bool) -> hideInRaidBuckets (per-difficulty).
            if legacyFlatSV.hideInRaidBuckets == nil and legacyFlatSV.hideInRaid ~= nil then
                local v = legacyFlatSV.hideInRaid
                legacyFlatSV.hideInRaidBuckets = { lfr = v, normal = v, heroic = v, mythic = v }
            end
            legacyFlatSV.hideInRaid = nil
        end

        -- AceDB-3.0: RollAwayDBAccount holds one profile per character (by
        -- default) plus a "global" namespace for the one setting that must
        -- stay truly account-wide (legacyAccountWide / its shared table).
        -- No 3rd arg: each character gets its own default profile (e.g. the
        -- ElvUI-style "Name - Realm"). Passing "true" here would instead give
        -- everyone a single shared "Default" profile - not what we want.
        RA.db = LibStub("AceDB-3.0"):New("RollAwayDBAccount", RA.defaults)

        -- Backward-compat alias: every other module still reads/writes
        -- "RollAwayDB.foo" directly. Point that name at the active profile
        -- and keep it in sync whenever the profile is switched/copied/reset.
        local function SyncCompatAlias()
            RollAwayDB = RA.db.profile
        end
        SyncCompatAlias()
        RA.db.RegisterCallback(RA, "OnProfileChanged", SyncCompatAlias)
        RA.db.RegisterCallback(RA, "OnProfileCopied",  SyncCompatAlias)
        RA.db.RegisterCallback(RA, "OnProfileReset",   SyncCompatAlias)

        RA.InitCharDB()

        -- One-time-per-character migration popup from the pre-3.0.1 flat DB.
        RA.RunProfileMigration(legacyFlatSV)

        if ElvUI then
            local E = unpack(ElvUI)
            if E and E.GetModule then RA.ElvLootModule = E:GetModule("Loot", true) end
        end

        for _, initName in ipairs(INIT_ORDER) do
            local init = RA[initName]
            if init then init() end
        end

        -- Hook Show at startup so auto-hide works on the first roll too.
        if GroupLootHistoryFrame then
            hooksecurefunc(GroupLootHistoryFrame, "Show", function()
                if ShouldHideInInstance() and HasActiveRolls() then
                    HideHistoryFrameAtOnce()
                end
            end)
        end

        RA.initialized = true
        DBG("RollAway initialized")
    end
end)
