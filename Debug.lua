-- RollAway - Debug.lua
-- Developer tools: slash commands and event logger. Loaded last.

local RA   = _G["RollAway"]
local DBG  = RA.DBG

------------------------------------------------------------------------
-- Debug log window – scrollable, copyable EditBox that replaces plain
-- chat spam for DBG() output. Created lazily and auto-shown the first
-- time a log line comes in while RollAwayDB.debug is on; closing it
-- manually is respected (won't force itself back open). Not line-capped
-- by design (dev-only, cleared on /reload, relog, or manual Clear).
------------------------------------------------------------------------

local debugLogFrame
local debugLogEditBox
local debugLogScrollFrame

-- Grows the EditBox to fit its text and pins the scroll to the bottom so
-- the newest line is always visible (EditBox has no built-in auto-scroll).
local function ScrollDebugLogToBottom()
    if not debugLogEditBox or not debugLogScrollFrame then return end
    local _, fontHeight = debugLogEditBox:GetFont()
    local lineHeight = (fontHeight or 12) + 2
    local _, numNewlines = debugLogEditBox:GetText():gsub("\n", "")
    local neededHeight = (numNewlines + 1) * lineHeight
    debugLogEditBox:SetHeight(math.max(debugLogScrollFrame:GetHeight(), neededHeight))
    debugLogScrollFrame:UpdateScrollChildRect()
    debugLogScrollFrame:SetVerticalScroll(debugLogScrollFrame:GetVerticalScrollRange() or 0)
end

local function CreateDebugLogFrame()
    if debugLogFrame then return end

    local f = CreateFrame("Frame", "RollAwayDebugLogFrame", UIParent, "BackdropTemplate")
    f:SetSize(560, 360)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("|cff33ff99RollAway|r Debug Log")

    local closeBtn = CreateFrame("Button", "RollAwayDebugLogClose", f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    local scrollFrame = CreateFrame("ScrollFrame", "RollAwayDebugLogScroll", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -38)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 46)

    local editBox = CreateFrame("EditBox", "RollAwayDebugLogEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(scrollFrame:GetWidth())
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editBox:SetText("")
    scrollFrame:SetScrollChild(editBox)

    local selectAllBtn = CreateFrame("Button", "RollAwayDebugLogSelectAll", f, "UIPanelButtonTemplate")
    selectAllBtn:SetSize(100, 22)
    selectAllBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 14)
    selectAllBtn:SetText("Select All")
    selectAllBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    local clearBtn = CreateFrame("Button", "RollAwayDebugLogClear", f, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 22)
    clearBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function() RA.ClearDebugLog() end)

    debugLogFrame      = f
    debugLogEditBox    = editBox
    debugLogScrollFrame = scrollFrame

    f:Show()  -- auto-open on first log line
end

-- Appends one formatted line. Forces the cursor to the end first, since
-- the player may have clicked into the box (e.g. to select text) and
-- moved it, which would otherwise corrupt the log order.
function RA.AppendDebugLog(...)
    CreateDebugLogFrame()

    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end
    local line = date("%H:%M:%S") .. "  " .. table.concat(parts, " ")

    debugLogEditBox:SetCursorPosition(#debugLogEditBox:GetText())
    debugLogEditBox:Insert(line .. "\n")
    ScrollDebugLogToBottom()
end

-- Inserts a colored divider line to visually separate log sections (e.g.
-- one per instance/zone entry). No-op if the log doesn't exist yet or is
-- still empty, so a fresh log never opens with a leading divider.
local SEPARATOR_LINE = "|cff666666------------------------------------------------------------|r"

function RA.AppendDebugLogSeparator()
    if not debugLogEditBox then return end
    if debugLogEditBox:GetText() == "" then return end
    debugLogEditBox:SetCursorPosition(#debugLogEditBox:GetText())
    debugLogEditBox:Insert(SEPARATOR_LINE .. "\n")
    ScrollDebugLogToBottom()
end

function RA.ClearDebugLog()
    if debugLogEditBox then debugLogEditBox:SetText("") end
    if debugLogScrollFrame then
        debugLogEditBox:SetHeight(debugLogScrollFrame:GetHeight())
        debugLogScrollFrame:SetVerticalScroll(0)
    end
end

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
    -- PLAYER_ENTERING_WORLD / ZONE_CHANGED_NEW_AREA intentionally excluded:
    -- Core.lua's LogInstanceSummary() already covers zone changes in one line.
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

-- These also mark the start of a new debug-log section (see
-- RA.NoteDebugLogSectionEvent in Core.lua) - group leave/join is as much
-- a context boundary as a zone change, and this event logger's handler
-- runs before Core.lua's own GROUP_LEFT reset logging.
local SECTION_START_EVENTS = {
    GROUP_LEFT   = true,
    GROUP_JOINED = true,
}

local eventLogFrame = CreateFrame("Frame")

local function RegisterEventLogger()
    for _, event in ipairs(LOGGED_EVENTS) do
        eventLogFrame:RegisterEvent(event)
    end
    eventLogFrame:SetScript("OnEvent", function(_, event, a1, a2)
        if not IsDevChar() then return end
        if not (RollAwayDB and RollAwayDB.debug) then return end
        if SECTION_START_EVENTS[event] and RA.NoteDebugLogSectionEvent then
            RA.NoteDebugLogSectionEvent()
        end
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
        if RA.LogInstanceSummary then RA.LogInstanceSummary() end
        if RA.TryAutoPass then RA.TryAutoPass() end
    end

    -- /rawdump → raw GetInstanceInfo field dump (manual, verbose - use when
    -- the compact zone-change summary line isn't enough detail)
    SLASH_RAWDUMP1 = "/rawdump"
    SlashCmdList["RAWDUMP"] = function()
        if not IsDevChar() or not (RollAwayDB and RollAwayDB.debug) then return end
        RA.UpdateInstanceCache()
        if RA.DebugInstanceDump then RA.DebugInstanceDump() end
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
        if RA.ShowGreatVaultFrame then RA.ShowGreatVaultFrame() end
        if RA.AdvLogTestShow then RA.AdvLogTestShow() end
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
        if RA.ShowTalentReminder then
            local savedReadyCheck = RollAwayDB.readyCheckReminder
            RollAwayDB.readyCheckReminder = true
            RA.ShowTalentReminder()
            RollAwayDB.readyCheckReminder = savedReadyCheck
        end
        RA.cachedInstanceType = savedType
        if RA.CheckDurability then
            local savedDura = RollAwayDB.durabilityWarning
            RollAwayDB.durabilityWarning = true
            RA.CheckDurability(true)
            RollAwayDB.durabilityWarning = savedDura
        end
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

    -- /rawlog → open/toggle the debug log window (in case it was closed
    -- manually). Dev-char gated only, independent of RollAwayDB.debug so
    -- it works even while debug logging itself is off. Still routes
    -- through AppendDebugLog so ElvUI_Skin.lua's skin hook still fires.
    SLASH_RAWLOG1 = "/rawlog"
    SlashCmdList["RAWLOG"] = function()
        if not IsDevChar() then return end
        local existed = _G["RollAwayDebugLogFrame"] ~= nil
        RA.AppendDebugLog("Log window toggled via /rawlog")
        local f = _G["RollAwayDebugLogFrame"]
        -- Only flip visibility if the window already existed - a fresh
        -- window was just auto-shown by AppendDebugLog, don't hide it again.
        if existed and f then f:SetShown(not f:IsShown()) end
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

    -- /rawcharwatchdog [break] → inspect or forcibly desync the Omnium/Vault
    -- CharacterFrame button watchdog (Modules/CharFrameButtons.lua) to test
    -- its heartbeat self-heal without waiting for a natural repro. No arg
    -- prints current state; "break" marks it stale (running=true, heartbeat
    -- backdated) - closing/reopening the Character panel should then still
    -- bring the buttons back instead of leaving them gone until /reload.
    SLASH_RAWCHARWATCHDOG1 = "/rawcharwatchdog"
    SlashCmdList["RAWCHARWATCHDOG"] = function(msg)
        if not IsDevChar() or not (RollAwayDB and RollAwayDB.debug) then return end
        msg = (msg or ""):match("^%s*(.-)%s*$")
        if msg == "break" then
            if RA.DebugBreakCharFrameWatchdog then
                RA.DebugBreakCharFrameWatchdog()
                DevPrint("Watchdog marked stale. Close and reopen the Character panel - buttons should still self-heal.")
            end
            return
        end
        if RA.DebugCharFrameWatchdogState then
            local running, _, age = RA.DebugCharFrameWatchdogState()
            local line = ("Watchdog running=%s | last tick %.1fs ago"):format(tostring(running), age)
            DevPrint(line)
            DBG("[CharFrameButtons]", line)
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
