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

-- Errors-only channel: own checkbox, always unfiltered.
local function DBGError(...)
    if RollAwayDB and (RollAwayDB.debug or RollAwayDB.debugErrorsOnly) and DEV_CHARS[UnitName("player")] then
        if RA.AppendDebugLogUnfiltered then RA.AppendDebugLogUnfiltered(...) end
    end
end
RA.DBGError = DBGError

------------------------------------------------------------------------
-- Content data lives in Data/*.lua.
------------------------------------------------------------------------
local SEASON1_DUNGEONS      = RA.DUNGEONS[1]
local SEASON2_DUNGEONS      = RA.DUNGEONS[2]
local SEASON1_DELVES        = RA.DELVES[1]
local SEASON2_DELVES        = RA.DELVES[2]
local SEASON1_RAIDS         = RA.RAIDS[1]
local SEASON2_RAIDS         = RA.RAIDS[2]
local SEASON1_LEGACY_RAIDS  = RA.LEGACY_RAIDS

------------------------------------------------------------------------
-- Lookup maps, built once at load
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
RA.LEGACY_ENCOUNTER_MAP = LEGACY_ENCOUNTER_MAP

------------------------------------------------------------------------
-- Raid difficultyID -> UI bucket (lfr / normal / heroic / mythic).
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
-- Saved variable defaults (AceDB-3.0, RollAwayDBAccount)
--   profile   per-profile settings (one profile per character by default)
--   global    account-wide settings, shared by all profiles
--   defaultsChar  SavedVariablesPerCharacter, never part of a profile
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
        autoSalvageSlot          = false,
        hideErrorMessages        = false,
        hideInfoMessages         = false,
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
        autoLogRaidCurrentOnly = false, -- skip raids of old tiers (Data/LegacyRaids.lua)
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
        -- Legacy raid roll selections shared across all characters.
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
-- Profile migration: before 3.0.1 RollAwayDB was one flat account-wide table.
-- Each character is offered once to take those values over or start fresh.
------------------------------------------------------------------------
function RA.RunProfileMigration(legacyFlatSV)
    -- Settings that moved to RA.db.global are taken over once, account-wide.
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

    -- Keep the first flat snapshot so alts get the same offer later.
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
    -- Shown a few seconds late: a popup this early in the login sequence may
    -- cause ADDON_ACTION_FORBIDDEN reports on a first login.
    C_Timer.After(3, function()
        StaticPopup_Show("ROLLAWAY_PROFILE_MIGRATION")
    end)
end

------------------------------------------------------------------------
-- Instance cache, loot history handling and the main event handler.
------------------------------------------------------------------------

local function UpdateInstanceCache()
    local ok, _, instType, diffID, _, _, _, _, instanceID = pcall(GetInstanceInfo)
    RA.cachedInstanceType = (ok and instType)   or "none"
    RA.cachedInstanceID   = (ok and instanceID) or 0
    RA.cachedDiffID       = (ok and diffID)     or 0
end
RA.UpdateInstanceCache = UpdateInstanceCache

-- Season check (developer aid, error log): compares the game's Mythic+ pool
-- with RA.DUNGEONS. Runs once, when the map info (CHALLENGE_MODE_MAPS_UPDATE) is in.
local seasonChecked = false

local function CheckSeasonData()
    if seasonChecked or not C_ChallengeMode or not C_MythicPlus then return end
    local live = C_ChallengeMode.GetMapTable()
    if not live or #live == 0 then return end
    seasonChecked = true

    local liveSet = {}
    for _, cmID in ipairs(live) do liveSet[cmID] = true end

    local matching, missing = {}, {}
    for season, dungeons in pairs(RA.DUNGEONS) do
        local known, covered = {}, 0
        for _, d in ipairs(dungeons) do
            if d.cmID then known[d.cmID] = true end
        end
        for cmID in pairs(liveSet) do
            if known[cmID] then covered = covered + 1 end
        end
        if covered == #live then
            local size = 0
            for _ in pairs(known) do size = size + 1 end
            if size == #live then matching[#matching + 1] = season end
        end
    end

    if #matching == 0 then
        for cmID in pairs(liveSet) do missing[#missing + 1] = cmID end
        table.sort(missing)
        DBGError("[Season] The game's Mythic+ pool matches no season in Data/Dungeons.lua | live cmIDs:", table.concat(missing, ","))
    elseif not tContains(matching, RA.ACTIVE_SEASON) then
        DBGError("[Season] The game's Mythic+ pool matches season", matching[1], "but RA.ACTIVE_SEASON is", RA.ACTIVE_SEASON)
    else
        DBG("[Season] Mythic+ pool matches season", RA.ACTIVE_SEASON)
    end
end

-- One-line zone-change summary: instance, matched dungeon/delve, auto-pass state.
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

    -- Open world: zone, map and whether it counts as Midnight (Prey auto-pass).
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

-- Raw GetInstanceInfo dump (/rawdump).
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

local function CountActiveRolls()
    local n = 0
    for _ in pairs(RA.activeRolls) do n = n + 1 end
    return n
end

-- Hide() on GroupLootHistoryFrame runs one frame later (RunNextFrame): called
-- straight from an event handler it taints the frame and later causes "secret
-- number" errors in Blizzard's tooltip code. SetAlpha is safe to call at once.
-- Covers Blizzard's frame and ElvUI's.
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

-- Frames that must never be seen (hide-in-raid): transparent at once, Hide() a frame later.
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

-- A roll that is over: drops it and its watchdog.
local function ForgetRoll(rollID, reason)
    RA.activeRolls[rollID] = nil
    RA.SafeCancelTimer(RA.rollTimers[rollID])
    RA.rollTimers[rollID] = nil
    DBG("Roll finished:", rollID, "|", reason, "| active left:", CountActiveRolls())
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

-- Debug log divider: a call more than 3s after the previous one starts a new
-- section (time-based, since delves fire only ZONE_CHANGED_NEW_AREA).
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
    -- The next raid/dungeon entry shows the reminders again.
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
    -- Legacy raids have their own switch; the difficulty boxes are for current raids.
    if RA.LEGACY_RAID_INSTANCES[RA.cachedInstanceID] then
        return RollAwayDB.hideInLegacyRaids == true
    end
    local bucket = RA.RAID_DIFFICULTY_BUCKET[RA.cachedDiffID]
    if not bucket or not RollAwayDB.hideInRaidBuckets then return false end
    return RollAwayDB.hideInRaidBuckets[bucket] == true
end

local function TryStartCloseTimer()
    if RollAwayDB and RollAwayDB.lootFrameAutoCloseDisabled then return end
    if HasActiveRolls() then return end
    -- Every finished roll restarts the countdown: the frame closes `delay` seconds
    -- after the LAST roll, not after the first one.
    if RA.closeTimer then
        DBG("Close timer restarted")
        RA.SafeCancelTimer(RA.closeTimer)
        RA.closeTimer = nil
    end
    DBG("Starting close timer:", RollAwayDB.delay, "sec")
    local timer
    timer = C_Timer.NewTimer(RollAwayDB.delay, function()
        if RA.closeTimer ~= timer then return end   -- replaced or cancelled meanwhile
        RA.closeTimer = nil
        -- A new roll can start while this timer runs; never close the frame under it.
        if HasActiveRolls() then
            DBG("Close timer expired, but a roll is active - keeping the frame")
            return
        end
        DBG("Close timer expired")
        HideHistoryFrame()
    end)
    RA.closeTimer = timer
end

-- After a roll ends: start the close timer unless the frame is meant to stay hidden.
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
    "InitWhatsNew", "InitAutoPass", "InitRollConfirm", "InitQoL", "InitCraftingSalvage", "InitQuests", "InitTankMarker", "InitVendorFilter",
    "InitParagon", "InitGreatVault", "InitLFGQuickCreate", "InitOptions", "InitDebug",
}

-- Adds `false` for every entry's key (entry[keyField]) missing from tbl.
local function FillMissing(tbl, entries, keyField)
    for _, entry in ipairs(entries) do
        local key = entry[keyField]
        if tbl[key] == nil then tbl[key] = false end
    end
end

-- Per-character selections: defaults, wrong types replaced, an entry (off) for
-- every dungeon/delve/boss. Also run after a profile reset.
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
    -- Account-wide mirror, used with legacyAccountWide.
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
f:RegisterEvent("CANCEL_LOOT_ROLL")
f:RegisterEvent("CANCEL_ALL_LOOT_ROLLS")
f:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
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
        local _, _, lootHandle = ...
        DBG("START_LOOT_ROLL rollID:", arg1, "| lootHandle:", lootHandle)

        -- LOOT_ROLLS_COMPLETE reports the lootHandle, not the rollID, so keep it.
        RA.activeRolls[arg1] = lootHandle or true

        if RA.closeTimer then RA.SafeCancelTimer(RA.closeTimer); RA.closeTimer = nil end

        -- Watchdog: force-closes the frame if the roll never ends cleanly.
        if not RA.rollTimers[arg1] and not (RollAwayDB and RollAwayDB.lootFrameAutoCloseDisabled) then
            local wdID = arg1
            RA.rollTimers[wdID] = C_Timer.NewTimer(RollAwayDB.rollTimeout, function()
                RA.rollTimers[wdID] = nil
                -- Only a still-open roll is a stuck one.
                if not RA.activeRolls[wdID] then return end
                DBG("Watchdog expired for rollID", wdID)
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
        DBG("LOOT_ROLLS_COMPLETE lootHandle:", arg1, "| active before:", CountActiveRolls())

        -- Completed roll, matched by lootHandle (or rollID).
        for rollID, lootHandle in pairs(RA.activeRolls) do
            if rollID == arg1 or lootHandle == arg1 then ForgetRoll(rollID, "completed") end
        end

        -- Rolls the game no longer knows.
        for rollID in pairs(RA.activeRolls) do
            if not select(2, GetLootRollItemInfo(rollID)) then ForgetRoll(rollID, "stale (game no longer knows it)") end
        end

        C_Timer.After(0.1, CheckAndClose)

    elseif event == "CHALLENGE_MODE_MAPS_UPDATE" then
        CheckSeasonData()

    elseif event == "CANCEL_LOOT_ROLL" then
        -- Only tracked rolls count: a history frame opened by hand stays.
        if RA.activeRolls[arg1] then
            DBG("CANCEL_LOOT_ROLL rollID:", arg1)
            ForgetRoll(arg1, "cancelled")
            C_Timer.After(0.1, CheckAndClose)
        end

    elseif event == "CANCEL_ALL_LOOT_ROLLS" then
        if next(RA.activeRolls) then
            DBG("CANCEL_ALL_LOOT_ROLLS")
            for rollID in pairs(RA.activeRolls) do ForgetRoll(rollID, "all cancelled") end
            C_Timer.After(0.1, CheckAndClose)
        end

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
        -- Combat hides the loot history everywhere (roll popups stay usable),
        -- unless auto-close is off.
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
        if not seasonChecked and C_MythicPlus then C_MythicPlus.RequestMapInfo() end
        ResetState(event)
        RA.lastLegacyEncounterID = 0
        -- "Shown once per instance" marks: cleared on a fresh login (not on /reload),
        -- on group leave and when the reminders see no instance.
        if arg1 and RollAwayDBChar then  -- arg1 = isInitialLogin
            RollAwayDBChar.lastReminderInstID = nil
            RollAwayDBChar.lastAdvLogReminderInstID = nil
        end
        LogInstanceSummary()
        if ShouldHideInInstance() then HideHistoryFrameAtOnce() end
        -- Both events fire for one zone change: the newest request wins (token),
        -- so ShowReminder runs once.
        if RA.reminderShowTimer then RA.SafeCancelTimer(RA.reminderShowTimer) end
        RA.reminderShowToken = (RA.reminderShowToken or 0) + 1
        local myReminderToken = RA.reminderShowToken
        local function FireReminder()
            RA.reminderShowTimer = nil
            if RA.reminderShowToken ~= myReminderToken then return end  -- superseded
            if RA.ShowReminder then RA.ShowReminder() end
        end
        -- Now, and again after 1.5s: instance info and the Voidcore currency can be
        -- stale right after a fast zone / login. ShowReminder is idempotent.
        if RA.ShowReminder then RA.ShowReminder() end
        RA.reminderShowTimer = C_Timer.NewTimer(1.5, FireReminder)

    elseif event == "ADDON_LOADED" and arg1 == addonName then

        -- The pre-3.0.1 flat RollAwayDB, captured before AceDB touches it.
        local legacyFlatSV = _G.RollAwayDB

        if legacyFlatSV then
            -- Old migrations on the flat snapshot (for users updating from far back).
            -- pre-2.6.3: joinReminderBigWigs (boolean) -> joinReminderKeyAddon (string)
            if legacyFlatSV.joinReminderKeyAddon == nil and legacyFlatSV.joinReminderBigWigs ~= nil then
                legacyFlatSV.joinReminderKeyAddon = legacyFlatSV.joinReminderBigWigs and "bigwigs" or "none"
            end
            legacyFlatSV.joinReminderBigWigs = nil

            -- pre-2.9.0: hideInRaid (bool) -> hideInRaidBuckets (per difficulty)
            if legacyFlatSV.hideInRaidBuckets == nil and legacyFlatSV.hideInRaid ~= nil then
                local v = legacyFlatSV.hideInRaid
                legacyFlatSV.hideInRaidBuckets = { lfr = v, normal = v, heroic = v, mythic = v }
            end
            legacyFlatSV.hideInRaid = nil
        end

        -- No 3rd argument: every character gets its own default profile
        -- ("true" would share one "Default" profile).
        RA.db = LibStub("AceDB-3.0"):New("RollAwayDBAccount", RA.defaults)

        -- RollAwayDB is an alias of the active profile, kept in sync on profile changes.
        local function SyncCompatAlias()
            RollAwayDB = RA.db.profile
        end
        SyncCompatAlias()
        RA.db.RegisterCallback(RA, "OnProfileChanged", SyncCompatAlias)
        RA.db.RegisterCallback(RA, "OnProfileCopied",  SyncCompatAlias)
        RA.db.RegisterCallback(RA, "OnProfileReset",   SyncCompatAlias)

        RA.InitCharDB()

        -- One-time migration offer per character.
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
