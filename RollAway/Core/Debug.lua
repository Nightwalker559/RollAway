-- RollAway - Core/Debug.lua
-- Debug log: the window DBG() writes to (RA.AppendDebugLog) and the category filter.
-- The dev commands and dumps that use it: Core/DevTools.lua. Loaded last.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L

------------------------------------------------------------------------
-- Debug log window: scrollable, copyable EditBox for DBG() output. Created and
-- shown on the first log line; closing it by hand is respected. Not line-capped
-- (dev-only; cleared on /reload, relog or Clear).
------------------------------------------------------------------------

local debugLogFrame
local debugLogEditBox
local debugLogScrollFrame
local debugLogTitle

local LOG_TITLE        = "|cff33ff99RollAway|r " .. RA_L["dev_log_title"]
local LOG_TITLE_PAUSED = LOG_TITLE .. " |cffff8800" .. RA_L["dev_log_paused"] .. "|r"

-- The log lives in this table; the EditBox is only a view of it (writing into
-- the EditBox would overwrite the player's selection). Only Clear drops lines.
local logLines = {}
local viewRefreshQueued = false

-- Sizes the EditBox to its text and scrolls to the newest line.
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

-- Rewrites the EditBox from the log lines; skipped while it has focus (selecting
-- or copying), the view catches up on OnEditFocusLost.
local function RefreshLogView()
    viewRefreshQueued = false
    if not debugLogEditBox or debugLogEditBox:HasFocus() then return end
    local text = table.concat(logLines, "\n")
    if #logLines > 0 then text = text .. "\n" end
    debugLogEditBox:SetText(text)
    ScrollDebugLogToBottom()
end

-- One refresh per frame.
local function QueueLogViewRefresh()
    if viewRefreshQueued then return end
    viewRefreshQueued = true
    RunNextFrame(RefreshLogView)
end

local function CreateDebugLogFrame()
    if debugLogFrame then return end

    -- Size and position are remembered.
    local size = RollAwayDB.debugLogSize
    local f = RA.CreatePanelWindow("RollAwayDebugLogFrame", UIParent,
        size and size.w or 560, size and size.h or 360, LOG_TITLE)
    f:SetResizable(true)
    f:SetResizeBounds(380, 200, 1400, 1000)
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
    debugLogTitle = f:GetTitleText()

    local scrollFrame = CreateFrame("ScrollFrame", "RollAwayDebugLogScroll", f, "ScrollFrameTemplate")
    scrollFrame.ScrollBar:SetHideIfUnscrollable(true)
    RA.Skin.ScrollBar(scrollFrame.ScrollBar)
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -34)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 46)

    local editBox = CreateFrame("EditBox", "RollAwayDebugLogEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(scrollFrame:GetWidth())
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnEditFocusGained", function() debugLogTitle:SetText(LOG_TITLE_PAUSED) end)
    editBox:SetScript("OnEditFocusLost", function()
        debugLogTitle:SetText(LOG_TITLE)
        QueueLogViewRefresh()
    end)
    editBox:SetText("")
    scrollFrame:SetScrollChild(editBox)
    RA.Skin.EditBox(editBox)

    local selectAllBtn = CreateFrame("Button", "RollAwayDebugLogSelectAll", f, "UIPanelButtonTemplate")
    selectAllBtn:SetSize(100, 22)
    selectAllBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 14)
    selectAllBtn:SetText(RA_L["dev_log_select_all"])
    RA.Skin.Button(selectAllBtn)
    selectAllBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    local clearBtn = CreateFrame("Button", "RollAwayDebugLogClear", f, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 22)
    clearBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 14)
    clearBtn:SetText(RA_L["dev_log_clear"])
    RA.Skin.Button(clearBtn)
    clearBtn:SetScript("OnClick", function() RA.ClearDebugLog() end)

    -- Resize grip
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
    RA.Skin.ResizeGrip(grip)

    -- Re-wrap on resize.
    f:SetScript("OnSizeChanged", function()
        editBox:SetWidth(scrollFrame:GetWidth())
        ScrollDebugLogToBottom()
    end)

    debugLogFrame      = f
    debugLogEditBox    = editBox
    debugLogScrollFrame = scrollFrame

    f:Show()  -- auto-open on first log line
end

-- Appends one line.
local function AppendLine(text)
    logLines[#logLines + 1] = text
    QueueLogViewRefresh()
end

------------------------------------------------------------------------
-- Log filter: a line's category is its "[Tag]" or a known start of text.
-- Switched off in the Developer panel (RollAwayDB.debugFilter[key] = false).
-- Only the full debug log is filtered; RA.AppendDebugLogUnfiltered (errors,
-- window messages, tool output) always shows.
------------------------------------------------------------------------

-- In Developer panel order (label: locale key "dev_filter_<key>"); no match = "other".
RA.DEBUG_CATEGORIES = {
    { key = "zone",     prefixes = { "Instance:", "[Season]", "[Raids]", "[Dungeons]", "[Bosses]", "--- GetInstanceInfo", "  ", "->", "----" } },
    { key = "loot",     prefixes = { "START_LOOT_ROLL", "LOOT_ROLLS_COMPLETE", "CANCEL_LOOT_ROLL",
                                     "CANCEL_ALL_LOOT_ROLLS", "Roll finished", "ENCOUNTER_END", "Watchdog",
                                     "ResetState", "FullReset", "Close timer", "Starting close",
                                     "Hiding loot history", "Loot history frame shown", "Entering combat" } },
    { key = "autopass", prefixes = { "[AutoPass]", "AutoPass:", "BonusRollFrame", "WARNING: BonusRollFrame",
                                     "Manual auto-pass" } },
    { key = "roll",     prefixes = { "[Legacy", "[Roll", "RollConfirm" } },
    { key = "reminder", prefixes = { "Reminder", "Showing reminder", "Teleport reminder", "Showing teleport",
                                     "Advanced Combat Logging reminder" } },
    { key = "logs",     prefixes = { "Auto-log" } },
    { key = "lfg",      prefixes = { "[LFGQuickCreate]" } },
    { key = "tank",     prefixes = { "[TankMarker" } },
    { key = "gilvl",    prefixes = { "[GroupIlvl]" } },
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

-- Wall clock + GetTime() are not in sync, so seconds (date) and milliseconds
-- (GetTime) came from two clocks and could run backwards. One whole-second
-- offset ties both to GetTime(); it is at most 1s off the real clock.
local clockOffset

local function DebugTimestamp()
    local t = GetTime()
    clockOffset = clockOffset or (time() - math.floor(t))
    local now = clockOffset + t
    return date("%H:%M:%S", math.floor(now)) .. string.format(".%03d", (now % 1) * 1000)
end

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
    AppendLine(DebugTimestamp() .. "  " .. table.concat(parts, " "))
end

-- Same, but never filtered: errors, window messages, tool output.
function RA.AppendDebugLogUnfiltered(...)
    bypassFilter = true
    RA.AppendDebugLog(...)
    bypassFilter = false
end

-- Divider line between log sections; not at the start of an empty log.
local SEPARATOR_LINE = "|cff666666------------------------------------------------------------|r"

function RA.AppendDebugLogSeparator()
    if #logLines == 0 then return end
    AppendLine(SEPARATOR_LINE)
end

-- /rawlog: opens the window or toggles it (a fresh window is created and shown by AppendDebugLog).
function RA.ToggleDebugLogWindow()
    local existed = debugLogFrame ~= nil
    RA.AppendDebugLogUnfiltered("Log window toggled")
    -- A fresh window was just shown by AppendDebugLog.
    if existed then debugLogFrame:SetShown(not debugLogFrame:IsShown()) end
end

-- Default size and centre; forgets the saved ones.
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
    wipe(logLines)
    if debugLogEditBox then
        debugLogEditBox:ClearFocus()
        RefreshLogView()
    end
    if debugLogScrollFrame then
        debugLogEditBox:SetHeight(debugLogScrollFrame:GetHeight())
        debugLogScrollFrame:SetVerticalScroll(0)
    end
end

