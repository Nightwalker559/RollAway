-- RollAway - Core.lua
-- Shared state, data, utilities and event handling.

local addonName = ...

-- Locale fallback: missing keys return the key itself to prevent UI crashes.
local RA_L = _G["RollAwayLocale"] or {}
setmetatable(RA_L, { __index = function(_, k) return k end })

-- Shared namespace, reused if Data/*.lua already created it.
local RA = _G["RollAway"] or {}
_G["RollAway"] = RA

RA.RA_L               = RA_L
RA.addonName          = addonName
RA.VOIDCORE_CURRENCY_ID = 3418  -- Nebulous Voidcore currency

------------------------------------------------------------------------
-- Season configuration
-- Season 2 is live; no date gate needed anymore.
-- BONUS_ROLLS_ENABLED: Bonus Rolls were disabled in S1, re-enabled for S2.
------------------------------------------------------------------------
RA.BONUS_ROLLS_ENABLED       = true
RA.ACTIVE_SEASON = 2 -- Season 2 is active

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

------------------------------------------------------------------------
-- API upvalues (resolved once at load time)
------------------------------------------------------------------------
local GetLootRollItemLink = GetLootRollItemLink
local GetInstanceInfo     = GetInstanceInfo
local hooksecurefunc      = hooksecurefunc
local GetTime             = GetTime
local C_Timer_After       = C_Timer and C_Timer.After
local C_Timer_NewTimer    = C_Timer and C_Timer.NewTimer
local C_Timer_NewTicker   = C_Timer and C_Timer.NewTicker

RA.GetLootRollItemLink = GetLootRollItemLink
RA.hooksecurefunc      = hooksecurefunc
RA.C_Timer_After       = C_Timer_After
RA.C_Timer_NewTimer    = C_Timer_NewTimer
RA.C_Timer_NewTicker   = C_Timer_NewTicker

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
RA.LEGACY_ENCOUNTER_MAP = LEGACY_ENCOUNTER_MAP

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

------------------------------------------------------------------------
-- State variables – shared across all modules
------------------------------------------------------------------------
RA.cachedInstanceType = "none"
RA.cachedInstanceID   = 0
RA.cachedDiffID       = 0
RA.lastEncounterID    = 0
RA.lastLegacyEncounterID = 0
RA.closeTimer            = nil
RA.isHooked              = false
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
        rollTimeout        = 60,
        lootFrameAutoCloseDisabled = false,
        legacy             = false,
        legacyNeed         = false,
        legacyGreed        = false,
        legacyTransmog     = false,
        showReminder       = false,
        readyCheckReminder = false,
        readyCheckShowSpec = false,
        qolReminderLockPosition = false,
        lastReminderInstID = nil,
        lastAdvLogReminderInstID = nil,
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
        hideOmniumfoliantMinimap = false,
        vaultButtonCharFrame     = false,
        hideMapActivityTracker   = false,
        hideCraftingOutputLog    = false,
        paragonAlert             = false,
        greatVaultAlert          = false,
        talentFontSize     = 20,
        autoLogEnabled       = false,
        autoLogScenario      = false,
        autoLogMythicDungeon = false,
        autoLogRaidMythic    = false,
        autoLogRaidHeroic    = false,
        autoLogRaidNormal    = false,
        autoLogRaidLFR       = false,
        autoLogDelve         = false,
        autoLogArena         = false,
        autoLogChatNotify    = false,
        advLogReminderEnabled = false,
        debug              = false,
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
-- (DeepCopy helper lives in Helpers.lua, shared with other modules.)
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

    StaticPopupDialogs["ROLLAWAY_PROFILE_MIGRATION"] = {
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
        timeout       = 0,
        whileDead     = true,
        hideOnEscape  = false,
        preferredIndex = 3,
    }
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
-- Generic popup/timer/table utilities (MakeDraggable, CreatePopupFrame,
-- CreateTimerBar, CreateOneShotTimer, SafeCancelTimer, DeepCopy, etc.)
-- now live in Helpers.lua, loaded right after this file.
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

    DBG(string.format("Instance: %s | Type: %s | ID: %d | Diff: %d | %s | Auto-pass: %s",
        (ok and instName) or "?", RA.cachedInstanceType, id, RA.cachedDiffID, matchLabel, passLabel))
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
RA.HasActiveRolls = HasActiveRolls

-- Deferred by one tick (C_Timer_After 0) so our Hide() call runs on a fresh,
-- untainted execution stack instead of directly inside whatever event handler
-- (START_LOOT_ROLL, ENCOUNTER_END, etc.) triggered it. Calling Hide() on
-- GroupLootHistoryFrame synchronously from insecure code taints that frame's
-- execution context, which later surfaces as unrelated "secret number value"
-- arithmetic errors in Blizzard's own tooltip/layout code (GetUnscaledFrameRect,
-- GameTooltip_InsertFrame) when the player hovers a loot history row.
local function DoHideHistoryFrame()
    if GroupLootHistoryFrame and GroupLootHistoryFrame:IsShown() then
        DBG("Hiding loot history frame")
        GroupLootHistoryFrame:Hide()
    end
    if RA.ElvLootModule and RA.ElvLootModule.GroupLootHistoryFrame
    and RA.ElvLootModule.GroupLootHistoryFrame:IsShown() then
        RA.ElvLootModule.GroupLootHistoryFrame:Hide()
    end
end

local function HideHistoryFrame()
    if C_Timer_After then
        C_Timer_After(0, DoHideHistoryFrame)
    else
        DoHideHistoryFrame()
    end
end
RA.HideHistoryFrame = HideHistoryFrame

local function CancelAllRollTimers()
    for rollID, t in pairs(RA.rollTimers) do
        DBG("Watchdog cancelled:", rollID)
        RA.SafeCancelTimer(t)
    end
    wipe(RA.rollTimers)
end
RA.CancelAllRollTimers = CancelAllRollTimers

-- Resets roll state and timers – does not touch the loot history frame.
local function ResetState(reason)
    DBG("ResetState:", reason)
    CancelAllRollTimers()
    if RA.closeTimer then RA.SafeCancelTimer(RA.closeTimer); RA.closeTimer = nil end
    wipe(RA.activeRolls)
    RA.lastEncounterID = 0
end
RA.ResetState = ResetState

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
    if RollAwayDB then
        RollAwayDB.lastReminderInstID = nil
        DBG("Reminder reset: FullReset triggered by:", reason)
    end
    HideHistoryFrame()
end
RA.FullReset = FullReset

local function ShouldHideInInstance()
    if not RollAwayDB or RollAwayDB.lootFrameAutoCloseDisabled then return false end
    if RA.cachedInstanceType ~= "raid" then return false end
    local bucket = RA.RAID_DIFFICULTY_BUCKET[RA.cachedDiffID]
    if not bucket or not RollAwayDB.hideInRaidBuckets then return false end
    return RollAwayDB.hideInRaidBuckets[bucket] == true
end
RA.ShouldHideInInstance = ShouldHideInInstance

local function TryStartCloseTimer()
    if RollAwayDB and RollAwayDB.lootFrameAutoCloseDisabled then return end
    if HasActiveRolls() or RA.closeTimer then return end
    DBG("Starting close timer:", RollAwayDB.delay, "sec")
    if C_Timer_NewTimer then
        RA.closeTimer = C_Timer_NewTimer(RollAwayDB.delay, function()
            DBG("Close timer expired")
            HideHistoryFrame()
            RA.closeTimer = nil
        end)
    elseif C_Timer_After then
        C_Timer_After(RollAwayDB.delay, function()
            if not HasActiveRolls() then
                DBG("Close timer expired (After fallback)")
                HideHistoryFrame()
            end
            RA.closeTimer = nil
        end)
        RA.closeTimer = true
    else
        DBG("WARNING: No timer API available")
    end
end
RA.TryStartCloseTimer = TryStartCloseTimer

-- Called once after all rolls complete to decide whether to start close timer.
local function CheckAndClose()
    if not HasActiveRolls() then
        wipe(RA.activeRolls)
        if not ShouldHideInInstance() then TryStartCloseTimer() end
    end
end

------------------------------------------------------------------------
-- Event handler
------------------------------------------------------------------------

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
        if C_Timer_NewTimer and not RA.rollTimers[arg1] and not (RollAwayDB and RollAwayDB.lootFrameAutoCloseDisabled) then
            local wdID = arg1
            RA.rollTimers[wdID] = C_Timer_NewTimer(RollAwayDB.rollTimeout, function()
                DBG("Watchdog expired for rollID", wdID)
                RA.rollTimers[wdID] = nil
                RA.activeRolls[wdID] = nil
                if not HasActiveRolls() then
                    wipe(RA.activeRolls)
                    CancelAllRollTimers()
                    HideHistoryFrame()
                end
            end)
        end

        if ShouldHideInInstance() then HideHistoryFrame() end

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

        if C_Timer_After then C_Timer_After(0.1, CheckAndClose) else CheckAndClose() end

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
        if ShouldHideInInstance() then
            DBG("Combat in raid (hidden difficulty) – hiding frame")
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
        -- Note: lastReminderInstID is only reset on GROUP_LEFT (see Reminder.lua)
        LogInstanceSummary()
        if ShouldHideInInstance() then HideHistoryFrame() end
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
        if C_Timer_NewTimer then
            RA.reminderShowTimer = C_Timer_NewTimer(2, FireReminder)
        elseif C_Timer_After then
            C_Timer_After(2, FireReminder)
        end

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
            _G.RollAwayDB = RA.db.profile
        end
        SyncCompatAlias()
        RA.db.RegisterCallback(RA, "OnProfileChanged", SyncCompatAlias)
        RA.db.RegisterCallback(RA, "OnProfileCopied",  SyncCompatAlias)
        RA.db.RegisterCallback(RA, "OnProfileReset",   SyncCompatAlias)

        _G.RollAwayDBChar = _G.RollAwayDBChar or {}
        RollAwayDBChar = _G.RollAwayDBChar
        for k, v in pairs(RA.defaultsChar) do
            if RollAwayDBChar[k] == nil then RollAwayDBChar[k] = v end
        end

        if type(RollAwayDBChar.dungeons) ~= "table" then RollAwayDBChar.dungeons = {} end
        if type(RollAwayDBChar.dungeons_s2) ~= "table" then RollAwayDBChar.dungeons_s2 = {} end
        for _, d in ipairs(SEASON2_DUNGEONS) do
            if RollAwayDBChar.dungeons_s2[d.key] == nil then RollAwayDBChar.dungeons_s2[d.key] = false end
        end
        for _, d in ipairs(SEASON1_DUNGEONS) do
            if RollAwayDBChar.dungeons[d.key] == nil then RollAwayDBChar.dungeons[d.key] = false end
        end

        if type(RollAwayDBChar.delves) ~= "table" then RollAwayDBChar.delves = {} end
        for _, d in ipairs(SEASON1_DELVES) do
            if d.removedAfterS1 and RA.ACTIVE_SEASON >= 2 then
                RollAwayDBChar.delves[d.key] = false -- no longer obtainable in-game, keep disabled
            elseif RollAwayDBChar.delves[d.key] == nil then
                RollAwayDBChar.delves[d.key] = false
            end
        end

        if type(RollAwayDBChar.delves_s2) ~= "table" then RollAwayDBChar.delves_s2 = {} end
        for _, d in ipairs(SEASON2_DELVES) do
            if RollAwayDBChar.delves_s2[d.key] == nil then RollAwayDBChar.delves_s2[d.key] = false end
        end

        if type(RollAwayDBChar.raids) ~= "table" then RollAwayDBChar.raids = {} end
        for _, b in ipairs(SEASON1_RAIDS) do
            if RollAwayDBChar.raids[b.key] == nil then RollAwayDBChar.raids[b.key] = false end
        end
        for _, b in ipairs(SEASON2_RAIDS) do
            if RollAwayDBChar.raids[b.key] == nil then RollAwayDBChar.raids[b.key] = false end
        end

        if type(RollAwayDBChar.legacy_raids) ~= "table" then RollAwayDBChar.legacy_raids = {} end
        for _, b in ipairs(SEASON1_LEGACY_RAIDS) do
            if RollAwayDBChar.legacy_raids[b.raid] == nil then
                RollAwayDBChar.legacy_raids[b.raid] = false
            end
        end

        -- Account-wide (true global) mirror of legacy_raids, used when
        -- RA.db.global.legacyAccountWide is enabled.
        for _, b in ipairs(SEASON1_LEGACY_RAIDS) do
            if RA.db.global.legacy_raids[b.raid] == nil then
                RA.db.global.legacy_raids[b.raid] = false
            end
        end

        if RollAwayDBChar.prey == nil then RollAwayDBChar.prey = false end

        if type(RollAwayDBChar.raidAutoPassDifficulty) ~= "table" then
            RollAwayDBChar.raidAutoPassDifficulty = { lfr = false, normal = false, heroic = false, mythic = false }
        end

        -- One-time-per-character migration popup from the pre-3.0.1 flat DB.
        RA.RunProfileMigration(legacyFlatSV)

        -- Sort dungeons and delves alphabetically by localized name.
        table.sort(SEASON1_DUNGEONS, function(a, b)
            return RA_L["dungeon_"..a.key] < RA_L["dungeon_"..b.key]
        end)
        table.sort(SEASON1_DELVES, function(a, b)
            return RA_L["delve_"..a.key] < RA_L["delve_"..b.key]
        end)

        if ElvUI then
            local E = unpack(ElvUI)
            if E and E.GetModule then RA.ElvLootModule = E:GetModule("Loot", true) end
        end

        if RA.InitWhatsNew         then RA.InitWhatsNew()         end
        if RA.InitAutoPass        then RA.InitAutoPass()        end
        if RA.InitAutoRoll        then RA.InitAutoRoll()        end
        if RA.InitRollConfirm     then RA.InitRollConfirm()     end
        if RA.InitReminder        then RA.InitReminder()        end
        if RA.InitTeleportReminder then RA.InitTeleportReminder() end
        if RA.InitPortalOverview  then RA.InitPortalOverview()  end
        if RA.InitQoL             then RA.InitQoL()             end
        if RA.InitVendorFilter    then RA.InitVendorFilter()    end
        if RA.InitParagon         then RA.InitParagon()         end
        if RA.InitGreatVault      then RA.InitGreatVault()      end
        if RA.InitLFGQuickCreate  then RA.InitLFGQuickCreate()  end
        if RA.InitOptions         then RA.InitOptions()         end
        if RA.InitDebug           then RA.InitDebug()           end

        -- Hook Show at startup so auto-hide works on the first roll too.
        if GroupLootHistoryFrame then
            hooksecurefunc(GroupLootHistoryFrame, "Show", function()
                if ShouldHideInInstance() and HasActiveRolls() then
                    HideHistoryFrame()
                end
            end)
            RA.isHooked = true
        end

        RA.initialized = true
        DBG("RollAway initialized")
    end
end)