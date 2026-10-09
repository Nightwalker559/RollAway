-- RollAway - Logs.lua
-- Automatic combat logging (LoggingCombat) based on the zone/difficulty the
-- player is currently in. Mirrors Method Raid Tools' "gespeicherte Logs"
-- feature so MRT is no longer required just for this.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local MYTHIC_DUNGEON_DIFFICULTY_IDS = RA.MYTHIC_DUNGEON_DIFFICULTY_IDS

-- Raid difficulty ID -> the option that enables logging for it.
local RAID_LOG_OPTION = {
    [16] = "autoLogRaidMythic",
    [15] = "autoLogRaidHeroic",
    [14] = "autoLogRaidNormal",
    [17] = "autoLogRaidLFR",
}

-- "Current season raids only" is on and the player is in a raid that is not
-- part of the running season (the game's own season list, see
-- Data/LegacyRaids.lua).
local function SkipLegacyRaid()
    return RollAwayDB.autoLogRaidCurrentOnly == true and not RA.IsCurrentSeasonRaid(RA.cachedInstanceID)
end

------------------------------------------------------------------------
-- Decide whether logging should be on/off for the current zone.
-- Returns true/false, or nil if the master toggle is off (i.e. "don't touch
-- whatever state the player/another addon has set").
------------------------------------------------------------------------
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
        -- "none", "pvp" (battlegrounds), "arena", etc. - never auto-log.
        return false
    end
end

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
            C_Timer.After(2, function()
                -- Zone changed in the meantime: this retry is stale, the
                -- newer check has its own.
                if DetermineDesiredLogState() ~= desired then return end
                TryApplyLogState(desired, retriesLeft - 1)
            end)
        else
            DBG("Auto-log: gave up applying state", tostring(desired), "(rate limited, will retry on next check)")
        end
        return
    end
    -- First sync after login/reload: "stopped" is no news, stay quiet.
    local initialStop = (lastAppliedState == nil and not desired)
    lastAppliedState = desired
    DBG("Auto-log:", desired and "started" or "stopped")
    if not initialStop and RollAwayDB and RollAwayDB.autoLogChatNotify then
        RA.Print(desired and RA_L["qol_log_chat_started"] or RA_L["qol_log_chat_stopped"])
    end
end

local function ApplyDesiredLogState()
    local desired = DetermineDesiredLogState()
    if desired == nil then                     -- master toggle off, don't manage
        lastAppliedState = nil                 -- forget it, re-sync once it is turned back on
        return
    end
    if desired == lastAppliedState then return end -- already in the right state
    -- Ask the game too: no call (and no rate-limit use) if logging already is
    -- as wanted, e.g. after /reload or a manual /combatlog.
    if C_ChatInfo.IsLoggingCombat() == desired then
        lastAppliedState = desired
        return
    end
    TryApplyLogState(desired, 5)
end

------------------------------------------------------------------------
-- Advanced Combat Logging reminder popup - shown once per M+/raid instance
-- if advancedCombatLogging is still off after ApplyDesiredLogState() ran
-- (i.e. RollAway's own auto-log isn't handling this content/isn't enabled).
------------------------------------------------------------------------
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

-- Shared by RA.ShowAdvLogReminder (real gating) and the dev test below.
-- Also stacks in the shared popup order (Core/Helpers.lua), so
-- /rawreminder's test popups never land on top of each other.
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
        -- Left the instance: the next visit gets the reminder again.
        if iType == "none" then RollAwayDBChar.lastAdvLogReminderInstID = nil end
        return
    end
    -- Old raids are not logged by choice, so there is nothing to remind about.
    if isRaid and RollAwayDB.autoLogEnabled and SkipLegacyRaid() then return end

    if RollAwayDBChar.lastAdvLogReminderInstID == instID then return end
    if C_CVar.GetCVar("advancedCombatLogging") == "1" then return end

    RollAwayDBChar.lastAdvLogReminderInstID = instID
    DBG("Advanced Combat Logging reminder | instanceID:", instID)

    ShowAdvLogFrameNow()
end

-- Re-evaluate on zone change with our own listener (Core/Core.lua calls its local
-- UpdateInstanceCache directly, so hooking RA.UpdateInstanceCache would never
-- fire); the cache is refreshed here before evaluating.
--
-- Safety recheck: GetInstanceInfo() can still return stale/zero data on the
-- first PLAYER_ENTERING_WORLD after a fast instance-to-instance zone (e.g.
-- Dungeon Finder instant requeue), which would skip logging for the whole
-- run. Re-run the check 1.5s later to catch that.
-- 3.0.9: Delves are logged together with scenarios and Arena logging was
-- dropped. An old "Delves" choice carries over to the merged option; the
-- removed keys are cleaned out of the saved profile.
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
