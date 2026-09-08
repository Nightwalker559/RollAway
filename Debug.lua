-- RollAway - Debug.lua
-- Developer tools: slash commands and event logger. Loaded last.

local RA   = _G["RollAway"]
local DBG  = RA.DBG

------------------------------------------------------------------------
-- Guard: only active for dev characters
------------------------------------------------------------------------

local function IsDevChar()
    return RA.DEV_CHARS and RA.DEV_CHARS[UnitName("player")]
end

local function DevPrint(msg)
    print("|cff33ff99RollAway:|r " .. msg)
end

------------------------------------------------------------------------
-- Event logger
------------------------------------------------------------------------

local LOGGED_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
    "GROUP_LEFT",
    "GROUP_JOINED",
    "READY_CHECK",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "AUCTION_HOUSE_SHOW",
    "LFG_LIST_APPLICATION_STATUS_UPDATED",
    "ENCOUNTER_START",
    "ENCOUNTER_END",
}

local eventLogFrame = CreateFrame("Frame")

local function RegisterEventLogger()
    for _, event in ipairs(LOGGED_EVENTS) do
        eventLogFrame:RegisterEvent(event)
    end
    eventLogFrame:SetScript("OnEvent", function(_, event, a1, a2)
        if not IsDevChar() then return end
        if not (RollAwayDB and RollAwayDB.debug) then return end
        if a1 ~= nil and a2 ~= nil then
            DBG("[Event]", event, "|", a1, a2)
        elseif a1 ~= nil then
            DBG("[Event]", event, "|", a1)
        else
            DBG("[Event]", event)
        end
    end)
end

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------

local function RegisterSlashCommands()

    -- /raw / /rollaway → open options
    SLASH_ROLLAWAY1 = "/raw"
    SLASH_ROLLAWAY2 = "/rollaway"
    SlashCmdList["ROLLAWAY"] = function()
        RA.RunProtectedOrQueue(function()
            Settings.OpenToCategory(RA.RA_CategoryID)
        end)
    end

    -- /rawtest → manual auto-pass test
    SLASH_RAWAUTOPASSTEST1 = "/rawtest"
    SlashCmdList["RAWAUTOPASSTEST"] = function()
        if not IsDevChar() or not (RollAwayDB and RollAwayDB.debug) then return end
        DevPrint("Manual auto-pass test...")
        RA.UpdateInstanceCache()
        RA.DebugInstanceDump()
        if RA.TryAutoPass then RA.TryAutoPass() end
    end

    -- /rawreminder → test reminder popup
    SLASH_RAWREMINDER1 = "/rawreminder"
    SlashCmdList["RAWREMINDER"] = function()
        if not IsDevChar() or not (RollAwayDB and RollAwayDB.debug) then return end
        if not RA.ShowReminder then return end
        local savedType   = RA.cachedInstanceType
        local savedID     = RA.cachedInstanceID
        local savedDiff   = RA.cachedDiffID
        local savedInstID = RollAwayDB.lastReminderInstID
        RA.cachedInstanceType         = "party"
        RA.cachedInstanceID           = 2805
        RA.cachedDiffID               = 8
        RollAwayDB.lastReminderInstID = nil
        local origGetCurrencyInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
        if C_CurrencyInfo then
            C_CurrencyInfo.GetCurrencyInfo = function(id)
                if id == 3418 then return { quantity = 3 } end
                return origGetCurrencyInfo and origGetCurrencyInfo(id)
            end
        end
        RA.ShowReminder()
        RA.cachedInstanceType         = savedType
        RA.cachedInstanceID           = savedID
        RA.cachedDiffID               = savedDiff
        RollAwayDB.lastReminderInstID = savedInstID
        if C_CurrencyInfo and origGetCurrencyInfo then
            C_CurrencyInfo.GetCurrencyInfo = origGetCurrencyInfo
        end
        DevPrint("Reminder test triggered.")

        if RA.ParagonTestShow then RA.ParagonTestShow() end
    end

    -- /rawreset → reset reminder state
    SLASH_RAWRESET1 = "/rawreset"
    SlashCmdList["RAWRESET"] = function()
        if not IsDevChar() or not (RollAwayDB and RollAwayDB.debug) then return end
        RollAwayDB.lastReminderInstID = nil
        DevPrint("Reminder reset – will show again on next instance entry.")
    end

    -- /rawqol → test all QoL reminders
    SLASH_RAWQOL1 = "/rawqol"
    SlashCmdList["RAWQOL"] = function()
        if not IsDevChar() or not (RollAwayDB and RollAwayDB.debug) then return end
        DevPrint("QoL test triggered.")
        local savedType = RA.cachedInstanceType
        RA.cachedInstanceType = "party"
        if RA.ShowTalentReminder then RA.ShowTalentReminder() end
        RA.cachedInstanceType = savedType
        if RA.CheckDurability then RA.CheckDurability(true) end
        if RA.ShowJoinReminder then
            local savedJoin = RollAwayDB.instanceJoinReminder
            RollAwayDB.instanceJoinReminder = true
            RA.ShowJoinReminder("Windrunner Spire", true)  -- true = force immediate timer (test mode)
            RollAwayDB.instanceJoinReminder = savedJoin
        end
        if RA.ShowTeleportReminder then
            local savedJoin = RollAwayDB.instanceJoinReminder
            local savedAddon = RollAwayDB.joinReminderKeyAddon
            RollAwayDB.instanceJoinReminder = true
            RollAwayDB.joinReminderKeyAddon = "teleport"
            local dungeon = RA.DUNGEONS[RA.ACTIVE_SEASON][1]
            RA.ShowTeleportReminder(RA.RA_L["dungeon_"..dungeon.key], dungeon)
            RollAwayDB.instanceJoinReminder = savedJoin
            RollAwayDB.joinReminderKeyAddon = savedAddon
        end
    end

    SLASH_RAWWHATS1 = "/rawwhats"
    SlashCmdList["RAWWHATS"] = function()
        if not IsDevChar() or not (RollAwayDB and RollAwayDB.debug) then return end
        if RA.ShowWhatsNew then RA.ShowWhatsNew() end
    end

    -- /rawchonkyoffset <n> → live-tune the extra rightward nudge applied to
    -- the Omnium/Vault CharacterFrame buttons when Chonky Character Sheet is
    -- loaded. Dev-only, for finding the right value before hardcoding it.
    SLASH_RAWCHONKYOFFSET1 = "/rawchonkyoffset"
    SlashCmdList["RAWCHONKYOFFSET"] = function(msg)
        if not IsDevChar() or not (RollAwayDB and RollAwayDB.debug) then return end
        local n = tonumber(msg)
        if not n then
            DevPrint("Usage: /rawchonkyoffset <pixels>")
            return
        end
        if RA.SetChonkyOffset then
            local applied = RA.SetChonkyOffset(n)
            DevPrint("Chonky button offset bonus set to "..tostring(applied)..". Reopen the Character panel if it doesn't move immediately.")
        end
    end

end

------------------------------------------------------------------------
-- Initialization – called from Core.lua ADDON_LOADED
------------------------------------------------------------------------

function RA.InitDebug()
    RegisterEventLogger()
    RegisterSlashCommands()
    DBG("Debug initialized")
end
