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
-- by design (dev-only, cleared on /reload, relog, or manual Clear) and never
-- overwritten (see logLines).
------------------------------------------------------------------------

local debugLogFrame
local debugLogEditBox
local debugLogScrollFrame
local debugLogTitle

local LOG_TITLE        = "|cff33ff99RollAway|r Debug Log"
local LOG_TITLE_PAUSED = LOG_TITLE .. " |cffff8800(paused while selecting - press Esc)|r"

-- The log itself lives in this table; the EditBox is only a view of it. Lines
-- used to be written straight into the EditBox (Insert), which replaces
-- whatever the player has selected in it - so selecting text to copy while new
-- lines came in overwrote parts of the log. Nothing here is ever modified or
-- dropped except by Clear.
local logLines = {}
local viewRefreshQueued = false

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

-- Rewrites the EditBox from the log lines. Skipped while the box has keyboard
-- focus (the player is selecting or copying text): the lines stay in the table
-- and the view catches up when the focus is gone (OnEditFocusLost).
local function RefreshLogView()
    viewRefreshQueued = false
    if not debugLogEditBox or debugLogEditBox:HasFocus() then return end
    local text = table.concat(logLines, "\n")
    if #logLines > 0 then text = text .. "\n" end
    debugLogEditBox:SetText(text)
    ScrollDebugLogToBottom()
end

-- One refresh per frame, however many lines came in.
local function QueueLogViewRefresh()
    if viewRefreshQueued then return end
    viewRefreshQueued = true
    RunNextFrame(RefreshLogView)
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
    title:SetText(LOG_TITLE)
    debugLogTitle = title

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
    editBox:SetScript("OnEditFocusGained", function() debugLogTitle:SetText(LOG_TITLE_PAUSED) end)
    editBox:SetScript("OnEditFocusLost", function()
        debugLogTitle:SetText(LOG_TITLE)
        QueueLogViewRefresh()
    end)
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

-- Appends `text` as one line to the log.
local function AppendLine(text)
    logLines[#logLines + 1] = text
    QueueLogViewRefresh()
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
    { key = "zone",     prefixes = { "Instance:", "[Season]", "[Raids]", "[Dungeons]", "[Bosses]", "--- GetInstanceInfo", "  ", "->", "----" } },
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
    AppendLine(date("%H:%M:%S") .. string.format(".%03d", (GetTime() % 1) * 1000) .. "  " .. table.concat(parts, " "))
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
    if #logLines == 0 then return end
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

-- /rawraids and /rawdungeons: every Encounter Journal tier with its raids or
-- dungeons (name + map ID, the ID GetInstanceInfo returns as instanceID), to see
-- which tier counts as "current" and whether the addon's data agrees. The
-- journal's selected tier is put back afterwards.
local function DumpJournalTiers(isRaid)
    local function Log(...) RA.AppendDebugLogUnfiltered(...) end
    local tag = isRaid and "[Raids]" or "[Dungeons]"
    local here = RA.cachedInstanceID
    local current = RA.GetCurrentSeasonInstances(isRaid)
    local previous = EJ_GetCurrentTier()
    Log(tag, "Encounter Journal tiers:", EJ_GetNumTiers(), "| selected before:", previous,
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
    if previous then EJ_SelectTier(previous) end

    -- Dungeons: the Mythic+ pool the game reports, with the season it matches
    -- in Data/Dungeons.lua (map ID and challenge mode ID).
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

-- /rawbosses [tier|all]: the bosses of every raid of one Encounter Journal tier
-- (default: the last one = current season) with the DungeonEncounterID that
-- ENCOUNTER_END reports - the ID Data/Raids.lua and Data/LegacyRaids.lua use.
-- Bosses the addon already knows are marked with their key. These IDs live in
-- the game's data, not in Blizzard's UI source. The journal's selected tier
-- and raid are put back afterwards.
local function DumpRaidBosses(arg)
    local function Log(...) RA.AppendDebugLogUnfiltered(...) end
    local numTiers = EJ_GetNumTiers()
    local first, last = numTiers, numTiers
    if arg == "all" then
        first = 1
    elseif tonumber(arg) then
        first, last = tonumber(arg), tonumber(arg)
    end
    local previousTier = EJ_GetCurrentTier()
    local previousInstance = EJ_GetCurrentInstance and EJ_GetCurrentInstance()
    for tier = first, last do
        EJ_SelectTier(tier)
        Log("[Bosses] tier", tier, tostring((EJ_GetTierInfo(tier))))
        local raidIndex = 1
        while true do
            local journalID, raidName, _, _, _, _, _, _, _, _, mapID = EJ_GetInstanceByIndex(raidIndex, true)
            if not journalID then break end
            EJ_SelectInstance(journalID)
            local bosses, bossIndex = {}, 1
            while true do
                local bossName, _, journalBossID = EJ_GetEncounterInfoByIndex(bossIndex)
                if not bossName then break end
                local encounterID = select(7, EJ_GetEncounterInfo(journalBossID))
                local known = encounterID and (RA.RAID_ENCOUNTER_MAP[encounterID] or RA.LEGACY_ENCOUNTER_MAP[encounterID])
                bosses[#bosses + 1] = string.format("%s = %s%s", bossName, tostring(encounterID),
                    known and (" (" .. tostring(known) .. ")") or " (NEW)")
                bossIndex = bossIndex + 1
            end
            Log(string.format("[Bosses] %s [map %s]: %s", raidName, tostring(mapID),
                #bosses > 0 and table.concat(bosses, "; ") or "-"))
            raidIndex = raidIndex + 1
        end
    end
    if previousTier then EJ_SelectTier(previousTier) end
    if previousInstance and previousInstance ~= 0 then EJ_SelectInstance(previousInstance) end
end

-- /rawseason: ready-to-paste Lua for the running season, read from the game:
--   * RA.DUNGEONS[n] entries (Data/Dungeons.lua) for the Mythic+ pool: mapID and
--     cmID from the pool, lfgID from the Group Finder, expansion from the journal
--   * RA.RAIDS[n] entries (Data/Raids.lua) for the bosses of the season's raids
--     that the addon does not know yet
-- Left to fill in by hand: the key (a guess from the name - rename it to the
-- English name), portalSpellID (no API for it) and the locale texts.
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

-- Group Finder activity of a Mythic+ dungeon: its ID is the lfgID of Data/Dungeons.lua.
local function FindMythicPlusActivity(mapID)
    if not (C_LFGList and C_LFGList.GetAvailableActivities) then return nil end
    -- Recommended + NotRecommended, PvE, CurrentSeason: together every dungeon activity
    for _, filter in ipairs({ 3, 4, 7, 64 }) do
        for _, activityID in ipairs(C_LFGList.GetAvailableActivities(GROUP_FINDER_CATEGORY_ID_DUNGEONS, 0, filter) or {}) do
            local info = C_LFGList.GetActivityInfoTable(activityID)
            if info and info.isMythicPlusActivity and info.mapID == mapID then return activityID end
        end
    end
end

local function DumpSeasonData()
    local function Log(...) RA.AppendDebugLogUnfiltered(...) end
    local numTiers = EJ_GetNumTiers()
    local maxExpansionTier = math.min(numTiers, (LE_EXPANSION_LEVEL_CURRENT or (numTiers - 2)) + 1)
    local previousTier = EJ_GetCurrentTier()
    local previousInstance = EJ_GetCurrentInstance and EJ_GetCurrentInstance()

    -- highest expansion tier that lists each dungeon (a revived old dungeon
    -- counts for the expansion it is revived in)
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
    Log("[Season] Paste into Data/Dungeons.lua as RA.DUNGEONS[" .. nextSeason .. "] (pool of " .. #pool
        .. "; set key, portalSpellID and check lfgID):")
    for _, d in ipairs(pool) do
        Log(string.format('    { key = "%s", mapID = %s, cmID = %s, lfgID = %s, portalSpellID = 0, expansion = "%s" }, -- %s',
            KeyFromName(d.name), tostring(d.mapID), d.cmID, tostring(FindMythicPlusActivity(d.mapID) or "?"),
            expansionOf[d.mapID] or "?", d.name))
    end

    -- raid bosses of the season's raids that the addon does not know yet
    EJ_SelectTier(numTiers)
    Log("[Season] Raid bosses unknown to the addon in the current season (Data/Raids.lua, RA.RAIDS[n]; skip world bosses):")
    local raidIndex, unknown = 1, 0
    while true do
        local journalID, raidName, _, _, _, _, _, _, _, _, mapID = EJ_GetInstanceByIndex(raidIndex, true)
        if not journalID then break end
        EJ_SelectInstance(journalID)
        local lines, known, bossIndex = {}, 0, 1
        while true do
            local bossName, _, journalBossID = EJ_GetEncounterInfoByIndex(bossIndex)
            if not bossName then break end
            local encounterID = select(7, EJ_GetEncounterInfo(journalBossID))
            if encounterID and (RA.RAID_ENCOUNTER_MAP[encounterID] or RA.LEGACY_ENCOUNTER_MAP[encounterID]) then
                known = known + 1
            elseif encounterID then
                lines[#lines + 1] = string.format('    { key = "%s", encounterID = %s, raid = "%s" }, -- %s',
                    KeyFromName(bossName), tostring(encounterID), KeyFromName(raidName), bossName)
            end
            bossIndex = bossIndex + 1
        end
        Log(string.format("[Season] -- %s (mapID %s): %d unknown, %d known", raidName, tostring(mapID), #lines, known))
        for _, line in ipairs(lines) do Log(line) end
        unknown = unknown + #lines
        raidIndex = raidIndex + 1
    end

    if previousTier then EJ_SelectTier(previousTier) end
    if previousInstance and previousInstance ~= 0 then EJ_SelectInstance(previousInstance) end

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
