-- RollAway - Core/Debug.lua
-- Developer tools: debug log window, dev slash commands and event logger.
-- Loaded last.

local RA   = _G["RollAway"]
local DBG  = RA.DBG

------------------------------------------------------------------------
-- Debug log window: scrollable, copyable EditBox for DBG() output. Created and
-- shown on the first log line; closing it by hand is respected. Not line-capped
-- (dev-only; cleared on /reload, relog or Clear).
------------------------------------------------------------------------

local debugLogFrame
local debugLogEditBox
local debugLogScrollFrame
local debugLogTitle

local LOG_TITLE        = "|cff33ff99RollAway|r Debug Log"
local LOG_TITLE_PAUSED = LOG_TITLE .. " |cffff8800(paused while selecting - press Esc)|r"

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
    selectAllBtn:SetText("Select All")
    RA.Skin.Button(selectAllBtn)
    selectAllBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    local clearBtn = CreateFrame("Button", "RollAwayDebugLogClear", f, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 22)
    clearBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 14)
    clearBtn:SetText("Clear")
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
    AppendLine(date("%H:%M:%S") .. string.format(".%03d", (GetTime() % 1) * 1000) .. "  " .. table.concat(parts, " "))
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

------------------------------------------------------------------------
-- Event logger
------------------------------------------------------------------------

local LOGGED_EVENTS = {
    -- Zone changes are covered by LogInstanceSummary (Core.lua).
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

-- Events that also start a new log section (RA.NoteDebugLogSectionEvent).
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

-- Runs a dev command by name with the same debug-mode check as typing it; false if unknown.
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
    -- Mythic raid (The Venomous Abyss), general reminder off, Mythic auto-pass on:
    -- the popup shown is the auto-pass warning (red status line).
    RA.cachedInstanceType         = "raid"
    RA.cachedInstanceID           = 3004
    RA.cachedDiffID               = 16
    RollAwayDBChar.lastReminderInstID = nil

    -- Pretend to own 3 Voidcores (restored even if ShowReminder errors).
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

-- Encounter Journal dumps (/rawraids, /rawdungeons, /rawbosses, /rawseason).
-- Reading the journal selects tiers and raids; the user's selection is put back.
local function SaveJournalSelection()
    local tier = EJ_GetCurrentTier()
    local instance = EJ_GetCurrentInstance and EJ_GetCurrentInstance()
    return function()
        if tier then EJ_SelectTier(tier) end
        if instance and instance ~= 0 then EJ_SelectInstance(instance) end
    end
end

-- Bosses of a journal raid: { { name =, encounterID = }, ... }. The encounterID is
-- the DungeonEncounterID that ENCOUNTER_END reports (Data/Raids.lua).
local function JournalBosses(journalID)
    EJ_SelectInstance(journalID)
    local bosses, index = {}, 1
    while true do
        local name, _, journalBossID = EJ_GetEncounterInfoByIndex(index)
        if not name then break end
        bosses[#bosses + 1] = { name = name, encounterID = select(7, EJ_GetEncounterInfo(journalBossID)) }
        index = index + 1
    end
    return bosses
end

-- The key the addon uses for a boss (current or legacy raid); nil when unknown.
local function KnownBossKey(encounterID)
    return encounterID and (RA.RAID_ENCOUNTER_MAP[encounterID] or RA.LEGACY_ENCOUNTER_MAP[encounterID])
end

-- /rawraids and /rawdungeons: every journal tier with its raids or dungeons (name +
-- map ID = the instanceID of GetInstanceInfo), marking the current season and what
-- the addon knows.
local function DumpJournalTiers(isRaid)
    local function Log(...) RA.AppendDebugLogUnfiltered(...) end
    local tag = isRaid and "[Raids]" or "[Dungeons]"
    local here = RA.cachedInstanceID
    local current = RA.GetCurrentSeasonInstances(isRaid)
    local restore = SaveJournalSelection()
    Log(tag, "Encounter Journal tiers:", EJ_GetNumTiers(), "| selected before:", EJ_GetCurrentTier(),
        "| you are in instance:", here, "| current season set:", current and "yes" or "empty")
    for tier = 1, EJ_GetNumTiers() do
        EJ_SelectTier(tier)
        local entries, index = {}, 1
        while true do
            local journalID, name, _, _, _, _, _, _, _, _, mapID = EJ_GetInstanceByIndex(index, isRaid)
            if not journalID then break end
            local marks = {}
            if isRaid and RA.LEGACY_RAID_INSTANCES[mapID] then marks[#marks + 1] = "legacy list" end
            if not isRaid and RA.DUNGEON_MAP[mapID] then marks[#marks + 1] = "addon: " .. RA.DUNGEON_MAP[mapID] end
            if current and current[mapID] then marks[#marks + 1] = "SEASON" end
            if mapID == here then marks[#marks + 1] = "HERE" end
            entries[#entries + 1] = string.format("%s [map %s%s%s]", name, tostring(mapID),
                #marks > 0 and ", " or "", table.concat(marks, ", "))
            index = index + 1
        end
        Log(string.format("%s tier %d %s: %s", tag, tier, tostring((EJ_GetTierInfo(tier))),
            #entries > 0 and table.concat(entries, "; ") or "-"))
    end
    restore()

    -- Dungeons: the game's Mythic+ pool and the addon season each matches.
    if not isRaid and C_ChallengeMode then
        local pool = {}
        for _, cmID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
            local name, _, _, _, _, mapID = C_ChallengeMode.GetMapUIInfo(cmID)
            local seasons = {}
            for season, list in pairs(RA.DUNGEONS) do
                for _, d in ipairs(list) do
                    if d.cmID == cmID then seasons[#seasons + 1] = tostring(season) end
                end
            end
            table.sort(seasons)
            pool[#pool + 1] = string.format("%s [cm %s, map %s, addon season: %s]", tostring(name), cmID,
                tostring(mapID), #seasons > 0 and table.concat(seasons, "+") or "NONE")
        end
        Log(tag, "Mythic+ pool (" .. #pool .. "):", #pool > 0 and table.concat(pool, "; ") or "-")
    end
end

-- /rawbosses [tier|all]: the bosses of every raid of a journal tier (default: the
-- last = current season) with their encounter IDs; known bosses show their key.
local function DumpRaidBosses(arg)
    local function Log(...) RA.AppendDebugLogUnfiltered(...) end
    local numTiers = EJ_GetNumTiers()
    local first, last = numTiers, numTiers
    if arg == "all" then
        first = 1
    elseif tonumber(arg) then
        first, last = tonumber(arg), tonumber(arg)
    end
    local restore = SaveJournalSelection()
    for tier = first, last do
        EJ_SelectTier(tier)
        Log("[Bosses] tier", tier, tostring((EJ_GetTierInfo(tier))))
        local raidIndex = 1
        while true do
            local journalID, raidName, _, _, _, _, _, _, _, _, mapID = EJ_GetInstanceByIndex(raidIndex, true)
            if not journalID then break end
            local bosses = {}
            for _, boss in ipairs(JournalBosses(journalID)) do
                local known = KnownBossKey(boss.encounterID)
                bosses[#bosses + 1] = string.format("%s = %s%s", boss.name, tostring(boss.encounterID),
                    known and (" (" .. tostring(known) .. ")") or " (NEW)")
            end
            Log(string.format("[Bosses] %s [map %s]: %s", raidName, tostring(mapID),
                #bosses > 0 and table.concat(bosses, "; ") or "-"))
            raidIndex = raidIndex + 1
        end
    end
    restore()
end

-- /rawseason: paste-ready Lua for the running season, read from the game:
--   * RA.DUNGEONS[n] entries (Data/Dungeons.lua) for the Mythic+ pool: mapID, cmID,
--     lfgID (Group Finder) and expansion (journal)
--   * RA.RAIDS[n] entries (Data/Raids.lua) for the season's bosses the addon does not know
-- By hand: the key (rename the guess to the English name), portalSpellID (no API)
-- and the locale texts.
local EXPANSION_KEYS = { "classic", "tbc", "wrath", "cataclysm", "mop", "wod", "legion", "bfa",
                         "shadowlands", "dragonflight", "tww", "midnight" }
local ACCENTS = { ["ä"] = "ae", ["ö"] = "oe", ["ü"] = "ue", ["ß"] = "ss", ["é"] = "e", ["è"] = "e",
                  ["ê"] = "e", ["à"] = "a", ["â"] = "a", ["ô"] = "o", ["û"] = "u", ["ç"] = "c", ["ñ"] = "n" }

-- "Altar der Fänge" -> "altar_der_faenge"
local function KeyFromName(name)
    local key = tostring(name):lower()
    for from, to in pairs(ACCENTS) do key = key:gsub(from, to) end
    key = key:gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    return key ~= "" and key or "unknown"
end

-- Group Finder activities of the Mythic+ dungeons: map ID -> activity ID (= lfgID).
-- Every dungeon has its own activity group, so the groups are listed first, as
-- Blizzard's Group Finder does.
local function CollectMythicPlusActivities()
    local filters = {
        Enum.LFGListFilter.CurrentSeason + Enum.LFGListFilter.PvE,
        Enum.LFGListFilter.CurrentExpansion + Enum.LFGListFilter.NotCurrentSeason + Enum.LFGListFilter.PvE,
        Enum.LFGListFilter.PvE,
        Enum.LFGListFilter.Recommended + Enum.LFGListFilter.NotRecommended,
    }
    local byMap = {}
    for _, filter in ipairs(filters) do
        local groups = { 0 }
        for _, groupID in ipairs(C_LFGList.GetAvailableActivityGroups(GROUP_FINDER_CATEGORY_ID_DUNGEONS, filter) or {}) do
            groups[#groups + 1] = groupID
        end
        for _, groupID in ipairs(groups) do
            for _, activityID in ipairs(C_LFGList.GetAvailableActivities(GROUP_FINDER_CATEGORY_ID_DUNGEONS, groupID, filter) or {}) do
                local info = C_LFGList.GetActivityInfoTable(activityID)
                if info and info.isMythicPlusActivity and info.mapID and not byMap[info.mapID] then
                    byMap[info.mapID] = activityID
                end
            end
        end
    end
    return byMap
end

local function DumpSeasonData()
    local function Log(...) RA.AppendDebugLogUnfiltered(...) end
    local numTiers = EJ_GetNumTiers()
    local maxExpansionTier = math.min(numTiers, (LE_EXPANSION_LEVEL_CURRENT or (numTiers - 2)) + 1)
    local restore = SaveJournalSelection()

    -- Highest expansion tier that lists each dungeon (a revived dungeon counts for
    -- the expansion it is revived in).
    local expansionOf = {}
    for tier = 1, maxExpansionTier do
        EJ_SelectTier(tier)
        local index = 1
        while true do
            local journalID, _, _, _, _, _, _, _, _, _, mapID = EJ_GetInstanceByIndex(index, false)
            if not journalID then break end
            if mapID then expansionOf[mapID] = EXPANSION_KEYS[tier] or "?" end
            index = index + 1
        end
    end

    local nextSeason = 1
    for season in pairs(RA.DUNGEONS) do nextSeason = math.max(nextSeason, season + 1) end

    local pool = {}
    for _, cmID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
        local name, _, _, _, _, mapID = C_ChallengeMode.GetMapUIInfo(cmID)
        pool[#pool + 1] = { name = name or "?", cmID = cmID, mapID = mapID }
    end
    table.sort(pool, function(a, b) return a.name < b.name end)
    local activityOf = CollectMythicPlusActivities()
    Log("[Season] Paste into Data/Dungeons.lua as RA.DUNGEONS[" .. nextSeason .. "] (pool of " .. #pool
        .. "; set key, portalSpellID and check lfgID):")
    for _, d in ipairs(pool) do
        Log(string.format('    { key = "%s", mapID = %s, cmID = %s, lfgID = %s, portalSpellID = 0, expansion = "%s" }, -- %s',
            KeyFromName(d.name), tostring(d.mapID), d.cmID, tostring(activityOf[d.mapID] or "?"),
            expansionOf[d.mapID] or "?", d.name))
    end

    local missing = false
    for _, d in ipairs(pool) do if not activityOf[d.mapID] then missing = true end end
    if missing then
        local seen = {}
        for mapID, activityID in pairs(activityOf) do seen[#seen + 1] = string.format("%s=map %s", activityID, mapID) end
        table.sort(seen)
        Log("[Season] lfgID missing for some dungeons; Mythic+ activities the Group Finder lists (activity=map):",
            #seen > 0 and table.concat(seen, ", ") or "none")
    end

    -- Raid bosses of the season's raids that the addon does not know yet.
    EJ_SelectTier(numTiers)
    Log("[Season] Raid bosses unknown to the addon in the current season (Data/Raids.lua, RA.RAIDS[n]; skip world bosses):")
    local raidIndex = 1
    while true do
        local journalID, raidName, _, _, _, _, _, _, _, _, mapID = EJ_GetInstanceByIndex(raidIndex, true)
        if not journalID then break end
        local lines, known = {}, 0
        for _, boss in ipairs(JournalBosses(journalID)) do
            if KnownBossKey(boss.encounterID) then
                known = known + 1
            elseif boss.encounterID then
                lines[#lines + 1] = string.format('    { key = "%s", encounterID = %s, raid = "%s" }, -- %s',
                    KeyFromName(boss.name), tostring(boss.encounterID), KeyFromName(raidName), boss.name)
            end
        end
        Log(string.format("[Season] -- %s (mapID %s): %d unknown, %d known", raidName, tostring(mapID), #lines, known))
        for _, line in ipairs(lines) do Log(line) end
        raidIndex = raidIndex + 1
    end

    restore()
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

    -- /rawdump → raw GetInstanceInfo field dump
    RegisterDevCommand("RAWDUMP", function()
        RA.UpdateInstanceCache()
        RA.DebugInstanceDump()
    end)

    RegisterDevCommand("RAWREMINDER", TestReminders)

    -- /rawraids → Encounter Journal tiers and raids into the log
    RegisterDevCommand("RAWRAIDS", function()
        local ok, err = pcall(DumpJournalTiers, true)
        RA.Print(ok and RA.RA_L["cmd_rawraids_done"] or ("/rawraids: " .. tostring(err)))
    end, true)

    -- /rawseason → paste-ready Lua for the running season's dungeons and raid bosses
    RegisterDevCommand("RAWSEASON", function()
        local ok, err = pcall(DumpSeasonData)
        RA.Print(ok and RA.RA_L["cmd_rawseason_done"] or ("/rawseason: " .. tostring(err)))
    end, true)

    -- /rawbosses [tier|all] → raid bosses with their encounter IDs into the log
    RegisterDevCommand("RAWBOSSES", function(msg)
        local ok, err = pcall(DumpRaidBosses, strtrim(msg or ""):lower())
        RA.Print(ok and RA.RA_L["cmd_rawbosses_done"] or ("/rawbosses: " .. tostring(err)))
    end, true)

    -- /rawdungeons → Encounter Journal tiers, dungeons and the Mythic+ pool into the log
    RegisterDevCommand("RAWDUNGEONS", function()
        local ok, err = pcall(DumpJournalTiers, false)
        RA.Print(ok and RA.RA_L["cmd_rawdungeons_done"] or ("/rawdungeons: " .. tostring(err)))
    end, true)

    -- /rawreset → reset reminder state
    RegisterDevCommand("RAWRESET", function()
        RollAwayDBChar.lastReminderInstID = nil
        DBG("Reminder reset – will show again on next instance entry.")
    end)

    RegisterDevCommand("RAWQOL", TestQoLReminders)
    RegisterDevCommand("RAWWHATS", function() RA.ShowWhatsNew() end)

    -- /rawlog → open/toggle the log window (works with debug logging off)
    RegisterDevCommand("RAWLOG", RA.ToggleDebugLogWindow, true)

    -- /rawchonkyoffset <n> → live-tune the button offset next to Chonky Character Sheet
    RegisterDevCommand("RAWCHONKYOFFSET", function(msg)
        local n = tonumber(msg)
        if not n then
            DBG("Usage: /rawchonkyoffset <pixels>")
            return
        end
        local applied = RA.SetChonkyOffset(n)
        DBG("Chonky button offset bonus set to "..tostring(applied)..". Reopen the Character panel if it doesn't move immediately.")
    end)

    -- /rawcharbtn → state of the Character panel buttons into the log
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
