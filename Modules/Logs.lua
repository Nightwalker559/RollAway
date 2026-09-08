-- RollAway - Logs.lua
-- Automatic combat logging (LoggingCombat) based on the zone/difficulty the
-- player is currently in. Mirrors Method Raid Tools' "gespeicherte Logs"
-- feature so MRT is no longer required just for this.

local RA   = _G["RollAway"]
local DBG  = RA.DBG

-- Difficulty IDs for Mythic (non-keystone) and Mythic Keystone dungeons.
local MYTHIC_DUNGEON_DIFFICULTY_IDS = {
    [8]  = true,  -- Mythic (non-keystone)
    [23] = true,  -- Mythic Keystone (M+)
}

-- Raid difficulty IDs.
local RAID_DIFFICULTY_IDS = {
    MYTHIC = 16,
    HEROIC = 15,
    NORMAL = 14,
    LFR    = 17,
}

------------------------------------------------------------------------
-- Decide whether logging should be on/off for the current zone.
-- Returns true/false, or nil if the master toggle is off (i.e. "don't touch
-- whatever state the player/another addon has set").
------------------------------------------------------------------------
local function DetermineDesiredLogState()
    if not RollAwayDB or not RollAwayDB.autoLogEnabled then return nil end

    local db     = RollAwayDB
    local iType  = RA.cachedInstanceType
    local diff   = RA.cachedDiffID
    local instID = RA.cachedInstanceID

    if iType == "raid" then
        if diff == RAID_DIFFICULTY_IDS.MYTHIC then return db.autoLogRaidMythic end
        if diff == RAID_DIFFICULTY_IDS.HEROIC then return db.autoLogRaidHeroic end
        if diff == RAID_DIFFICULTY_IDS.NORMAL then return db.autoLogRaidNormal end
        if diff == RAID_DIFFICULTY_IDS.LFR    then return db.autoLogRaidLFR    end
        return false

    elseif iType == "party" then
        return db.autoLogMythicDungeon and MYTHIC_DUNGEON_DIFFICULTY_IDS[diff] and true or false

    elseif iType == "arena" then
        return db.autoLogArena and true or false

    elseif iType == "scenario" then
        if RA.DELVE_MAP and RA.DELVE_MAP[instID] then
            return db.autoLogDelve and true or false
        end
        return db.autoLogScenario and true or false

    else
        -- "none", "pvp" (battlegrounds), etc. - never auto-log.
        return false
    end
end
RA.DetermineDesiredLogState = DetermineDesiredLogState

------------------------------------------------------------------------
-- Make sure "Advanced Combat Logging" is on before we start a log - without
-- it WoWCombatLog.txt is missing resource/spell details tools like
-- warcraftlogs.com need. Not a secure CVar, safe to set anytime.
------------------------------------------------------------------------
local function EnsureAdvancedCombatLogging()
    if C_CVar.GetCVar("advancedCombatLogging") == "1" then return end
    C_CVar.SetCVar("advancedCombatLogging", "1")
    DBG("Auto-log: enabled Advanced Combat Logging CVar")
end

------------------------------------------------------------------------
-- Apply the desired state via LoggingCombat(), retrying on rate limit.
-- LoggingCombat is limited to 5 calls / 10s shared across all addons and
-- returns nil (without changing state) when the limit is hit.
------------------------------------------------------------------------
local lastAppliedState = nil

local function TryApplyLogState(desired, retriesLeft)
    if desired then EnsureAdvancedCombatLogging() end
    local result = LoggingCombat(desired)
    if result == nil then
        -- Rate limited - try again shortly if we still have attempts left.
        if retriesLeft > 0 then
            C_Timer.After(2, function() TryApplyLogState(desired, retriesLeft - 1) end)
        else
            DBG("Auto-log: gave up applying state", tostring(desired), "(rate limited, will retry on next check)")
        end
        return
    end
    lastAppliedState = desired
    DBG("Auto-log:", desired and "started" or "stopped")
    if RollAwayDB and RollAwayDB.autoLogChatNotify then
        local RA_L = RA.RA_L
        print("|cff33ff99RollAway:|r " .. (desired and RA_L["qol_log_chat_started"] or RA_L["qol_log_chat_stopped"]))
    end
end

local function ApplyDesiredLogState()
    local desired = DetermineDesiredLogState()
    if desired == nil then return end          -- master toggle off, don't manage
    if desired == lastAppliedState then return end -- already in the right state
    TryApplyLogState(desired, 5)
end
RA.ApplyDesiredLogState = ApplyDesiredLogState

-- Re-evaluate on zone change. Not using hooksecurefunc(RA, "UpdateInstanceCache", ...)
-- here: Core.lua's own event handler calls the local UpdateInstanceCache()
-- upvalue directly (not RA.UpdateInstanceCache()), so a table-field hook
-- never actually fires on real zone changes. Register our own listener
-- instead and refresh the cache ourselves before evaluating.
--
-- Safety recheck: GetInstanceInfo() can still return stale/zero data on the
-- very first PLAYER_ENTERING_WORLD after a fast instance-to-instance zone
-- (e.g. Dungeon Finder instant requeue), which would silently skip logging
-- for the whole run since no further zone event may fire. Re-run the check
-- 1.5s later to catch that case.
local function CheckLogState()
    if not RA.initialized then return end
    if RA.UpdateInstanceCache then RA.UpdateInstanceCache() end
    ApplyDesiredLogState()
end

local logsEventFrame = CreateFrame("Frame")
logsEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
logsEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
logsEventFrame:SetScript("OnEvent", function()
    CheckLogState()
    C_Timer.After(1.5, CheckLogState)
end)
