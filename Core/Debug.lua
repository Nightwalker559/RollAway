-- RollAway - Core/Debug.lua
-- Developer tools: debug log window, dev slash commands and event logger.
-- Loaded last.

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
    -- Size is remembered too (grip in the bottom right corner).
    local size = RollAwayDB.debugLogSize
    f:SetSize(size and size.w or 560, size and size.h or 360)
    f:SetResizable(true)
    f:SetResizeBounds(380, 200, 1400, 1000)
    -- Position is remembered across /reload and relog (like the Portal Overview).
    local pos = RollAwayDB.debugLogPos
    if pos then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint("CENTER")
    end
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    RA.MakeDraggable(f)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        RollAwayDB.debugLogPos = { point = point, relPoint = relPoint, x = x, y = y }
    end)
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
    clearBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 14)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function() RA.ClearDebugLog() end)

    -- Resize grip (bottom right corner): drag to change the window size.
    local grip = CreateFrame("Button", "RollAwayDebugLogResize", f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        RollAwayDB.debugLogSize = { w = math.floor(f:GetWidth() + 0.5), h = math.floor(f:GetHeight() + 0.5) }
    end)

    -- The text wraps to the new width and keeps the newest line in view.
    f:SetScript("OnSizeChanged", function()
        editBox:SetWidth(scrollFrame:GetWidth())
        ScrollDebugLogToBottom()
    end)

    debugLogFrame      = f
    debugLogEditBox    = editBox
    debugLogScrollFrame = scrollFrame

    f:Show()  -- auto-open on first log line
end

-- Appends `text` as one line. Forces the cursor to the end first, since
-- the player may have clicked into the box (e.g. to select text) and
-- moved it, which would otherwise corrupt the log order.
local function AppendLine(text)
    debugLogEditBox:SetCursorPosition(#debugLogEditBox:GetText())
    debugLogEditBox:Insert(text .. "\n")
    ScrollDebugLogToBottom()
end

------------------------------------------------------------------------
-- Log filter. Every line belongs to a category: its "[Tag]" prefix or, for the
-- older untagged lines, a known start of text. Categories can be switched off
-- in the Developer panel (RollAwayDB.debugFilter[key] = false; missing = on).
-- Only the full debug log is filtered: lines of the errors-only channel, the
-- log window messages and tool output (RA.AppendDebugLogUnfiltered) always show.
------------------------------------------------------------------------

-- In the order of the Developer panel. The label is the locale key
-- "dev_filter_<key>"; a line that matches nothing is "other".
RA.DEBUG_CATEGORIES = {
    { key = "zone",     prefixes = { "Instance:", "--- GetInstanceInfo", "  ", "->", "----" } },
    { key = "loot",     prefixes = { "START_LOOT_ROLL", "LOOT_ROLLS_COMPLETE", "ENCOUNTER_END", "Watchdog",
                                     "ResetState", "FullReset", "Close timer", "Starting close",
                                     "Hiding loot history", "Entering combat" } },
    { key = "autopass", prefixes = { "[AutoPass]", "AutoPass:", "BonusRollFrame", "WARNING: BonusRollFrame",
                                     "Manual auto-pass" } },
    { key = "roll",     prefixes = { "[Legacy", "[Roll", "RollConfirm" } },
    { key = "reminder", prefixes = { "Reminder", "Showing reminder", "Teleport reminder", "Showing teleport",
                                     "Advanced Combat Logging reminder" } },
    { key = "logs",     prefixes = { "Auto-log" } },
    { key = "lfg",      prefixes = { "[LFGQuickCreate]" } },
    { key = "tank",     prefixes = { "[TankMarker" } },
    { key = "qol",      prefixes = { "[QoL]", "[Misc]", "[VendorFilter]", "[Quests]", "[GreatVault]",
                                     "[Paragon]", "[CharFrameButtons]", "QoL" } },
    { key = "events",   prefixes = { "[Event]" } },
    { key = "other",    prefixes = {} },
}

-- Category key of a log line (judged by its first value).
local function DebugCategoryOf(first)
    if type(first) == "string" then
        for _, category in ipairs(RA.DEBUG_CATEGORIES) do
            for _, prefix in ipairs(category.prefixes) do
                if first:sub(1, #prefix) == prefix then return category.key end
            end
        end
    end
    return "other"
end

function RA.IsDebugCategoryOn(key)
    local filter = RollAwayDB and RollAwayDB.debugFilter
    return not (filter and filter[key] == false)
end

function RA.SetDebugCategory(key, on)
    RollAwayDB.debugFilter = RollAwayDB.debugFilter or {}
    RollAwayDB.debugFilter[key] = on and true or false
end

function RA.SetAllDebugCategories(on)
    for _, category in ipairs(RA.DEBUG_CATEGORIES) do RA.SetDebugCategory(category.key, on) end
end

local bypassFilter = false

-- Appends one formatted line.
function RA.AppendDebugLog(...)
    if not bypassFilter and RollAwayDB.debug and not RA.IsDebugCategoryOn(DebugCategoryOf((...))) then
        return
    end
    CreateDebugLogFrame()

    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end
    AppendLine(date("%H:%M:%S") .. "  " .. table.concat(parts, " "))
end

-- Same, but never filtered: errors, window messages, tool output.
function RA.AppendDebugLogUnfiltered(...)
    bypassFilter = true
    RA.AppendDebugLog(...)
    bypassFilter = false
end

-- Inserts a colored divider line to visually separate log sections (e.g.
-- one per instance/zone entry). No-op if the log doesn't exist yet or is
-- still empty, so a fresh log never opens with a leading divider.
local SEPARATOR_LINE = "|cff666666------------------------------------------------------------|r"

function RA.AppendDebugLogSeparator()
    if not debugLogEditBox then return end
    if debugLogEditBox:GetText() == "" then return end
    AppendLine(SEPARATOR_LINE)
end

-- Opens the log window, or toggles it when it already exists (the /rawlog
-- behaviour). Still routes through AppendDebugLog so ElvUI_Skin.lua's skin
-- hook fires on a fresh window.
function RA.ToggleDebugLogWindow()
    local existed = debugLogFrame ~= nil
    RA.AppendDebugLogUnfiltered("Log window toggled")
    -- Only flip visibility if the window already existed - a fresh window was
    -- just auto-shown by AppendDebugLog, don't hide it again.
    if existed then debugLogFrame:SetShown(not debugLogFrame:IsShown()) end
end

-- Back to the default size and the screen centre (also forgets the saved ones).
function RA.ResetDebugLogWindow()
    RollAwayDB.debugLogSize = nil
    RollAwayDB.debugLogPos  = nil
    if debugLogFrame then
        debugLogFrame:SetSize(560, 360)
        debugLogFrame:ClearAllPoints()
        debugLogFrame:SetPoint("CENTER")
    end
end

function RA.ClearDebugLog()
    if debugLogEditBox then debugLogEditBox:SetText("") end
    if debugLogScrollFrame then
        debugLogEditBox:SetHeight(debugLogScrollFrame:GetHeight())
        debugLogScrollFrame:SetVerticalScroll(0)
    end
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

local function RegisterEventLogger()
    local eventLogFrame = CreateFrame("Frame")
    for _, event in ipairs(LOGGED_EVENTS) do
        eventLogFrame:RegisterEvent(event)
    end
    eventLogFrame:SetScript("OnEvent", function(_, event, a1, a2)
        if not RollAwayDB.debug then return end
        if SECTION_START_EVENTS[event] then
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

-- Registers a dev-only slash command. Most also need debug mode on;
-- `alwaysOn` commands (log window, diagnostics) only need a dev character.
-- Also kept in RA.DevCommands so the Developer settings panel can run the
-- same command from a button (RA.RunDevCommand).
RA.DevCommands = {}

local function RegisterDevCommand(name, handler, alwaysOn)
    _G["SLASH_"..name.."1"] = "/"..name:lower()
    local function Run(msg)
        if alwaysOn or RollAwayDB.debug then handler(msg) end
    end
    SlashCmdList[name] = Run
    RA.DevCommands[name] = { run = Run, alwaysOn = alwaysOn and true or false }
end

-- Runs a registered dev command by name ("RAWTEST", ...), with the same
-- debug-mode check as typing it. Returns false when it is unknown.
function RA.RunDevCommand(name, msg)
    local command = RA.DevCommands[name]
    if not command then return false end
    command.run(msg or "")
    return true
end

-- Does the command work right now? Most need debug mode on.
function RA.DevCommandAvailable(name)
    local command = RA.DevCommands[name]
    return command ~= nil and (command.alwaysOn or RollAwayDB.debug == true)
end

-- Runs fn() with RollAwayDB[key] = value for each pair in `overrides`, then
-- restores the saved settings (even if fn errors).
local function WithSettings(overrides, fn)
    local keys, saved = {}, {}
    for key, value in pairs(overrides) do
        keys[#keys + 1] = key
        saved[key] = RollAwayDB[key]
        RollAwayDB[key] = value
    end
    local ok, err = pcall(fn)
    for _, key in ipairs(keys) do RollAwayDB[key] = saved[key] end
    if not ok then error(err, 0) end
end

-- /rawreminder → test all the popup reminders at once
local function TestReminders()
    local savedType   = RA.cachedInstanceType
    local savedID     = RA.cachedInstanceID
    local savedDiff   = RA.cachedDiffID
    local savedInstID = RollAwayDBChar.lastReminderInstID
    -- Mythic raid (The Venomous Abyss) with the standalone auto-pass warning:
    -- the general reminder is forced off and "Mythic" auto-pass forced on, so
    -- the popup you see is the safety-net one (red status line).
    RA.cachedInstanceType         = "raid"
    RA.cachedInstanceID           = 3004
    RA.cachedDiffID               = 16
    RollAwayDBChar.lastReminderInstID = nil

    -- Pretend to own 3 Voidcores while the reminder decides what to show;
    -- restored even if ShowReminder errors.
    local origGetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo
    C_CurrencyInfo.GetCurrencyInfo = function(id)
        if id == RA.VOIDCORE_CURRENCY_ID then return { quantity = 3 } end
        return origGetCurrencyInfo(id)
    end
    local savedMythicPass = RollAwayDBChar.raidAutoPassDifficulty.mythic
    RollAwayDBChar.raidAutoPassDifficulty.mythic = true
    local ok, err = pcall(WithSettings, { showReminder = false, autoPassWarning = true }, RA.ShowReminder)
    RollAwayDBChar.raidAutoPassDifficulty.mythic = savedMythicPass
    C_CurrencyInfo.GetCurrencyInfo = origGetCurrencyInfo

    RA.cachedInstanceType         = savedType
    RA.cachedInstanceID           = savedID
    RA.cachedDiffID               = savedDiff
    RollAwayDBChar.lastReminderInstID = savedInstID
    DBG(ok and "Reminder test triggered." or ("Reminder test failed: " .. tostring(err)))

    RA.ParagonTestShow()
    RA.ShowGreatVaultFrame()
    RA.ShowAdvLogFrameNow()
end

-- /rawqol → test all QoL reminders
local function TestQoLReminders()
    DBG("QoL test triggered.")

    local savedType = RA.cachedInstanceType
    RA.cachedInstanceType = "party"
    WithSettings({ readyCheckReminder = true }, RA.ShowTalentReminder)
    RA.cachedInstanceType = savedType

    WithSettings({ durabilityWarning = true }, function() RA.CheckDurability(true) end)

    WithSettings({ instanceJoinReminder = true }, function()
        RA.ShowJoinReminder("Windrunner Spire", true, 14)  -- true = force immediate timer (test mode)
    end)

    WithSettings({ instanceJoinReminder = true, joinReminderKeyAddon = "teleport" }, function()
        local dungeon = RA.DUNGEONS[RA.ACTIVE_SEASON][1]
        RA.ShowTeleportReminder(RA.RA_L["dungeon_"..dungeon.key], dungeon, 14)
    end)
end

local function RegisterSlashCommands()
    -- Dev/tester characters only.
    if not RA.DEV_CHARS[UnitName("player")] then return end

    -- /rawtest → manual auto-pass test
    RegisterDevCommand("RAWTEST", function()
        DBG("Manual auto-pass test...")
        RA.UpdateInstanceCache()
        RA.LogInstanceSummary()
        RA.TryAutoPass()
    end)

    -- /rawdump → raw GetInstanceInfo field dump (manual, verbose - use when
    -- the compact zone-change summary line isn't enough detail)
    RegisterDevCommand("RAWDUMP", function()
        RA.UpdateInstanceCache()
        RA.DebugInstanceDump()
    end)

    RegisterDevCommand("RAWREMINDER", TestReminders)

    -- /rawreset → reset reminder state
    RegisterDevCommand("RAWRESET", function()
        RollAwayDBChar.lastReminderInstID = nil
        DBG("Reminder reset – will show again on next instance entry.")
    end)

    RegisterDevCommand("RAWQOL", TestQoLReminders)
    RegisterDevCommand("RAWWHATS", function() RA.ShowWhatsNew() end)

    -- /rawlog → open/toggle the debug log window (in case it was closed
    -- manually). Works even while debug logging itself is off. Still routes
    -- through AppendDebugLog so ElvUI_Skin.lua's skin hook still fires.
    RegisterDevCommand("RAWLOG", RA.ToggleDebugLogWindow, true)

    -- /rawchonkyoffset <n> → live-tune the extra rightward nudge applied to
    -- the Omnium/Vault CharacterFrame buttons when Chonky Character Sheet is
    -- loaded. For finding the right value before hardcoding it.
    RegisterDevCommand("RAWCHONKYOFFSET", function(msg)
        local n = tonumber(msg)
        if not n then
            DBG("Usage: /rawchonkyoffset <pixels>")
            return
        end
        local applied = RA.SetChonkyOffset(n)
        DBG("Chonky button offset bonus set to "..tostring(applied)..". Reopen the Character panel if it doesn't move immediately.")
    end)

    -- /rawcharbtn → dump the visibility state of the Omnium/Vault Character
    -- panel buttons to the log (run it while they are missing).
    RegisterDevCommand("RAWCHARBTN", function()
        for _, line in ipairs(RA.DescribeCharFrameButtons()) do
            RA.AppendDebugLogUnfiltered("[CharFrameButtons] " .. line)
        end
    end, true)
end

------------------------------------------------------------------------
-- Initialization – called from Core/Core.lua ADDON_LOADED
------------------------------------------------------------------------

function RA.InitDebug()
    if RA.DEV_CHARS[UnitName("player")] then RegisterEventLogger() end
    RegisterSlashCommands()
    DBG("Debug initialized")
end
