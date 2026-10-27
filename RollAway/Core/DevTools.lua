-- RollAway - Core/DevTools.lua
-- Developer tools for the dev characters: event logger, dev slash commands (/rawtest,
-- /rawraids, ...) and the Encounter Journal / season / name dumps. They write to the debug
-- log window (Core/Debug.lua). Loaded last.

local RA   = _G["RollAway"]
local DBG  = RA.DBG
local RA_L = RA.RA_L

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

-- Registers a dev-only slash command; it only runs with debug mode on.
-- Also kept in RA.DevCommands so the Developer settings panel can run the
-- same command from a button (RA.RunDevCommand).
RA.DevCommands = {}

local function RegisterDevCommand(name, handler)
    _G["SLASH_"..name.."1"] = "/"..name:lower()
    local function Run(msg)
        if RollAwayDB.debug then handler(msg) end
    end
    SlashCmdList[name] = Run
    RA.DevCommands[name] = { run = Run }
end

-- Runs a dev command by name with the same debug-mode check as typing it; false if unknown.
function RA.RunDevCommand(name, msg)
    local command = RA.DevCommands[name]
    if not command then return false end
    command.run(msg or "")
    return true
end

-- Does the command work right now? It needs debug mode on.
function RA.DevCommandAvailable(name)
    return RA.DevCommands[name] ~= nil and RollAwayDB.debug == true
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
        local dungeon = RA.GetActiveSeasonDungeons()[1]
        RA.ShowTeleportReminder(RA_L["dungeon_"..dungeon.key], dungeon, 14)
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

-- /rawnames: the game's own names for every locale key that holds a game name, one line
-- each (`[Names] <key> | <id> | <name>`), in the client's language. Run it in deDE and enUS,
-- save both logs (Claude Tools\RollAway\locale/data) and compare with locale_names_check.lua.
-- Dungeons without a map ID in the data are checked
-- against `ejdungeon` lines: every journal dungeon (map ID | name).
local function DumpNames()
    local function Log(...) RA.AppendDebugLogUnfiltered(...) end
    local function Line(key, id, name)
        Log(string.format("[Names] %s | %s | %s", key, tostring(id or "-"), tostring(name or "?")))
    end
    local function ZoneName(mapID)
        local name = mapID and GetRealZoneText(mapID)
        return (name and name ~= "") and name or nil
    end

    Log("[Names] locale | " .. GetLocale() .. " | build " .. tostring((select(2, GetBuildInfo()))))

    for i, key in ipairs(EXPANSION_KEYS) do
        if key ~= "classic" then Line("expansion_" .. key, i - 1, _G["EXPANSION_NAME" .. (i - 1)]) end
    end
    for _, list in pairs(RA.DUNGEONS) do
        for _, d in ipairs(list) do Line("dungeon_" .. d.key, d.mapID, ZoneName(d.mapID)) end
    end
    for _, d in ipairs(RA.LEGACY_DUNGEON_TELEPORTS) do
        if d.mapID then Line("dungeon_" .. d.key, d.mapID, ZoneName(d.mapID)) end
    end
    for mapID, raidKey in pairs(RA.REMINDER_RAID_MAP_IDS) do Line("raid_" .. raidKey, mapID, ZoneName(mapID)) end
    for mapID, raidKey in pairs(RA.LEGACY_RAID_INSTANCES) do Line("legacy_raid_" .. raidKey, mapID, ZoneName(mapID)) end
    for _, list in pairs(RA.DELVES) do
        for _, d in ipairs(list) do Line("delve_" .. d.key, d.mapID, ZoneName(d.mapID)) end
    end

    -- Journal: every dungeon (name per map ID) and the encounter names of every raid.
    local restore = SaveJournalSelection()
    local seenMap, seenBoss = {}, {}
    for tier = 1, EJ_GetNumTiers() do
        EJ_SelectTier(tier)
        local index = 1
        while true do
            local journalID, name, _, _, _, _, _, _, _, _, mapID = EJ_GetInstanceByIndex(index, false)
            if not journalID then break end
            if mapID and not seenMap[mapID] then
                seenMap[mapID] = true
                Line("ejdungeon", mapID, name)
            end
            index = index + 1
        end
        index = 1
        while true do
            local journalID = EJ_GetInstanceByIndex(index, true)
            if not journalID then break end
            for _, boss in ipairs(JournalBosses(journalID)) do
                if boss.encounterID and not seenBoss[boss.encounterID] then
                    seenBoss[boss.encounterID] = true
                    Line("ejboss", boss.encounterID, boss.name)
                end
            end
            index = index + 1
        end
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
        RA.Print(ok and RA_L["cmd_rawraids_done"] or ("/rawraids: " .. tostring(err)))
    end)

    -- /rawseason → paste-ready Lua for the running season's dungeons and raid bosses
    RegisterDevCommand("RAWSEASON", function()
        local ok, err = pcall(DumpSeasonData)
        RA.Print(ok and RA_L["cmd_rawseason_done"] or ("/rawseason: " .. tostring(err)))
    end)

    -- /rawbosses [tier|all] → raid bosses with their encounter IDs into the log
    RegisterDevCommand("RAWBOSSES", function(msg)
        local ok, err = pcall(DumpRaidBosses, strtrim(msg or ""):lower())
        RA.Print(ok and RA_L["cmd_rawbosses_done"] or ("/rawbosses: " .. tostring(err)))
    end)

    -- /rawnames → the game's names for every locale key that holds one (see DumpNames)
    RegisterDevCommand("RAWNAMES", function()
        local ok, err = pcall(DumpNames)
        RA.Print(ok and RA_L["cmd_rawnames_done"] or ("/rawnames: " .. tostring(err)))
    end)

    -- /rawdungeons → Encounter Journal tiers, dungeons and the Mythic+ pool into the log
    RegisterDevCommand("RAWDUNGEONS", function()
        local ok, err = pcall(DumpJournalTiers, false)
        RA.Print(ok and RA_L["cmd_rawdungeons_done"] or ("/rawdungeons: " .. tostring(err)))
    end)

    -- /rawreset → reset reminder state
    RegisterDevCommand("RAWRESET", function()
        RollAwayDBChar.lastReminderInstID = nil
        DBG("Reminder reset – will show again on next instance entry.")
    end)

    RegisterDevCommand("RAWQOL", TestQoLReminders)
    RegisterDevCommand("RAWWHATS", function() RA.ShowWhatsNew() end)

    -- /rawlog → open/toggle the log window
    RegisterDevCommand("RAWLOG", RA.ToggleDebugLogWindow)

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
    end)
end

------------------------------------------------------------------------
-- Initialization – called from Core/Core.lua ADDON_LOADED
------------------------------------------------------------------------

function RA.InitDevTools()
    if RA.DEV_CHARS[UnitName("player")] then RegisterEventLogger() end
    RegisterSlashCommands()
    DBG("DevTools initialized")
end
