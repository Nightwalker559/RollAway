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
    })

    advLogFrame.msg = advLogFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    advLogFrame.msg:SetPoint("TOPLEFT",  advLogFrame, "TOPLEFT",  10, -40)
    advLogFrame.msg:SetPoint("TOPRIGHT", advLogFrame, "TOPRIGHT", -10, -40)
    advLogFrame.msg:SetJustifyH("LEFT")
    advLogFrame.msg:SetNonSpaceWrap(true)
    advLogFrame.msg:SetText(RA.RA_L["advlog_reminder_msg"])

    advLogFrame:SetScript("OnShow", function(self)
        if RA.C_Timer_After then
            RA.C_Timer_After(0, function()
                if not self:IsShown() then return end
                local msgH = self.msg:GetStringHeight()
                -- top(10) + header(24) + gap(6) + msg + gap(8) + btn(22) + bar(8) + pad(18)
                self:SetHeight(math.max(110, 10 + 24 + 6 + msgH + 8 + 22 + 8 + 18))
            end)
        end
        self.timer.Start(TIMER_DURATION)
    end)
    advLogFrame:SetScript("OnHide", advLogFrame.timer.Stop)

    RA.SetupInstanceReminderLifecycle(advLogFrame, "lastAdvLogReminderInstID")
end

-- Shared by RA.ShowAdvLogReminder (real gating) and the dev test below.
-- Also stacks below any other popup notification already shown (Great
-- Vault/Paragon/Reminder), matching the same pattern those use, so
-- /rawreminder's four test popups never land on top of each other.
local function ShowAdvLogFrameNow()
    CreateAdvLogFrame()
    RA.StackPopupFrame(advLogFrame,
        { "RollAwayGreatVaultFrame", "RollAwayParagonFrame", "RollAwayReminderFrame" }, -260)
    advLogFrame:Show()
end
RA.ShowAdvLogFrameNow = ShowAdvLogFrameNow

function RA.ShowAdvLogReminder()
    if not RollAwayDB or not RollAwayDB.advLogReminderEnabled then return end

    local iType  = RA.cachedInstanceType
    local instID = RA.cachedInstanceID
    local isMPlus = iType == "party" and MYTHIC_DUNGEON_DIFFICULTY_IDS[RA.cachedDiffID]
    local isRaid  = iType == "raid"
    if not (isMPlus or isRaid) then return end

    if RollAwayDB.lastAdvLogReminderInstID == instID then return end
    if C_CVar.GetCVar("advancedCombatLogging") == "1" then return end

    RollAwayDB.lastAdvLogReminderInstID = instID
    DBG("Advanced Combat Logging reminder | instanceID:", instID)

    RA.ShowAdvLogFrameNow()
end

-- Dev-only test (/rawreminder): shows the frame regardless of settings,
-- instance type, cvar state, or per-instance dedup.
local function TestShow()
    RA.ShowAdvLogFrameNow()
end
RA.AdvLogTestShow = TestShow

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
    RA.ShowAdvLogReminder()
end

local logsEventFrame = CreateFrame("Frame")
logsEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
logsEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
logsEventFrame:SetScript("OnEvent", function()
    CheckLogState()
    C_Timer.After(1.5, CheckLogState)
end)
