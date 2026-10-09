-- RollAway - Logs.lua
-- Automatic combat logging (LoggingCombat) by zone and difficulty (replaces MRT's feature).

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local MYTHIC_DUNGEON_DIFFICULTY_IDS = RA.MYTHIC_DUNGEON_DIFFICULTY_IDS

-- Raid difficulty ID -> its logging option.
local RAID_LOG_OPTION = {
    [16] = "autoLogRaidMythic",
    [15] = "autoLogRaidHeroic",
    [14] = "autoLogRaidNormal",
    [17] = "autoLogRaidLFR",
}

-- "Current season raids only" is on and this raid is not in the running season
-- (RA.IsCurrentSeasonRaid, Data/LegacyRaids.lua).
local function SkipLegacyRaid()
    return RollAwayDB.autoLogRaidCurrentOnly == true and not RA.IsCurrentSeasonRaid(RA.cachedInstanceID)
end

-- Should logging be on here? true/false, or nil when the master toggle is off (the
-- current state is not touched).
local function DetermineDesiredLogState()
    if not RollAwayDB or not RollAwayDB.autoLogEnabled then return nil end

    local db    = RollAwayDB
    local iType = RA.cachedInstanceType

    if iType == "raid" then
        if SkipLegacyRaid() then return false end
        local option = RAID_LOG_OPTION[RA.cachedDiffID]
        return option ~= nil and db[option] == true

    elseif iType == "party" then
        return db.autoLogMythicDungeon and MYTHIC_DUNGEON_DIFFICULTY_IDS[RA.cachedDiffID] and true or false

    elseif iType == "scenario" then
        -- Delves are scenario instances, so one option covers both.
        return db.autoLogScenario and true or false

    else
        -- Open world, battlegrounds, arenas: never.
        return false
    end
end

-- "Advanced Combat Logging" must be on before a log starts: without it the log lacks
-- details that warcraftlogs.com needs. Not a secure CVar.
local function EnsureAdvancedCombatLogging()
    if C_CVar.GetCVar("advancedCombatLogging") == "1" then return end
    C_CVar.SetCVar("advancedCombatLogging", "1")
    DBG("Auto-log: enabled Advanced Combat Logging CVar")
end

-- Applies the state via LoggingCombat(), retrying on the rate limit (5 calls / 10s for
-- all addons; returns nil without changing anything).
local lastAppliedState = nil

local function TryApplyLogState(desired, retriesLeft)
    if desired then EnsureAdvancedCombatLogging() end
    local result = LoggingCombat(desired)
    if result == nil then
        -- Rate limited: try again shortly.
        if retriesLeft > 0 then
            C_Timer.After(2, function()
                -- Zone changed meanwhile: the newer check has its own retry.
                if DetermineDesiredLogState() ~= desired then return end
                TryApplyLogState(desired, retriesLeft - 1)
            end)
        else
            DBG("Auto-log: gave up applying state", tostring(desired), "(rate limited, will retry on next check)")
        end
        return
    end
    -- First sync after login/reload: "stopped" is no news.
    local initialStop = (lastAppliedState == nil and not desired)
    lastAppliedState = desired
    DBG("Auto-log:", desired and "started" or "stopped")
    if not initialStop and RollAwayDB and RollAwayDB.autoLogChatNotify then
        RA.Print(desired and RA_L["qol_log_chat_started"] or RA_L["qol_log_chat_stopped"])
    end
end

local function ApplyDesiredLogState()
    local desired = DetermineDesiredLogState()
    if desired == nil then                     -- master toggle off
        lastAppliedState = nil                 -- re-sync once it is on again
        return
    end
    if desired == lastAppliedState then return end -- already in the right state
    -- Ask the game too: no call if logging already is as wanted (/reload, /combatlog).
    if C_ChatInfo.IsLoggingCombat() == desired then
        lastAppliedState = desired
        return
    end
    TryApplyLogState(desired, 5)
end

-- Advanced Combat Logging reminder: once per M+/raid instance while the CVar is still off
-- after ApplyDesiredLogState().
local TIMER_DURATION = 20
local advLogFrame

local function CreateAdvLogFrame()
    if advLogFrame then return end

    advLogFrame = RA.CreatePopupFrame({
        name     = "RollAwayAdvLogFrame",
        okayName = "RollAwayAdvLogOkay",
        width    = 300,
        height   = 110,
        yOffset  = -260,
        duration = TIMER_DURATION,
        fitHeight = function(self)
            return RA.POPUP_CHROME_HEIGHT + self.msg:GetStringHeight() + 8
        end,
    })

    advLogFrame.msg = RA.CreatePopupBodyText(advLogFrame)
    advLogFrame.msg:SetText(RA_L["advlog_reminder_msg"])

    RA.SetupInstanceReminderLifecycle(advLogFrame, "lastAdvLogReminderInstID")
end

-- Shared by RA.ShowAdvLogReminder and the dev test; stacked with the other popups.
local function ShowAdvLogFrameNow()
    CreateAdvLogFrame()
    RA.StackPopupFrame(advLogFrame)
    advLogFrame:Show()
end
RA.ShowAdvLogFrameNow = ShowAdvLogFrameNow

function RA.ShowAdvLogReminder()
    if not RollAwayDB or not RollAwayDBChar or not RollAwayDB.advLogReminderEnabled then return end

    local iType  = RA.cachedInstanceType
    local instID = RA.cachedInstanceID
    local isMPlus = iType == "party" and MYTHIC_DUNGEON_DIFFICULTY_IDS[RA.cachedDiffID]
    local isRaid  = iType == "raid"
    if not (isMPlus or isRaid) then
        -- Left the instance: the next visit shows it again.
        if iType == "none" then RollAwayDBChar.lastAdvLogReminderInstID = nil end
        return
    end
    -- Old raids are skipped by choice: nothing to remind about.
    if isRaid and RollAwayDB.autoLogEnabled and SkipLegacyRaid() then return end

    if RollAwayDBChar.lastAdvLogReminderInstID == instID then return end
    if C_CVar.GetCVar("advancedCombatLogging") == "1" then return end

    RollAwayDBChar.lastAdvLogReminderInstID = instID
    DBG("Advanced Combat Logging reminder | instanceID:", instID)

    ShowAdvLogFrameNow()
end

-- Re-evaluated on zone change with its own listener (the cache is refreshed first),
-- and again 1.5s later: GetInstanceInfo() can be stale right after a fast
-- instance-to-instance zone and would skip logging for the whole run.
-- Migration (3.0.9): delves are logged with scenarios, arena logging was dropped.
local function MigrateOldLogOptions()
    local db = RollAwayDB
    if db.autoLogDelve ~= nil then
        if db.autoLogDelve then db.autoLogScenario = true end
        db.autoLogDelve = nil
    end
    db.autoLogArena = nil
end

local function CheckLogState()
    if not RA.initialized then return end
    MigrateOldLogOptions()
    RA.UpdateInstanceCache()
    ApplyDesiredLogState()
    RA.ShowAdvLogReminder()
end

local logsEventFrame = CreateFrame("Frame")
logsEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
logsEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
logsEventFrame:SetScript("OnEvent", function()
    CheckLogState()
    C_Timer.After(1.5, CheckLogState)
end)
