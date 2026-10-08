-- RollAway - AutoPass.lua
-- Bonus Roll auto-pass for dungeons, delves, raids (per-boss or whole
-- difficulty bucket), and Prey.

local RA   = _G["RollAway"]
local DBG  = RA.DBG

local DUNGEON_MAP        = RA.DUNGEON_MAP
local DELVE_MAP          = RA.DELVE_MAP
local RAID_ENCOUNTER_MAP = RA.RAID_ENCOUNTER_MAP
local RAID_DIFFICULTY_BUCKET = RA.RAID_DIFFICULTY_BUCKET

-- Difficulty IDs of old raids (10/25 player, LFR). Only used by the developer
-- test switch RA.devTest.oldRaidAutoPass, to try the auto-pass in e.g. MoP.
local OLD_RAID_DIFFICULTY_BUCKET = {
    [3] = "normal", [4] = "normal",   -- 10 / 25 player
    [5] = "heroic", [6] = "heroic",   -- 10 / 25 player heroic
    [7] = "lfr",
}

------------------------------------------------------------------------
-- Instance matching helpers
------------------------------------------------------------------------

local function GetCurrentDungeonKey()
    if RA.cachedInstanceID == 0 then return nil end
    return DUNGEON_MAP[RA.cachedInstanceID]
end

local function GetCurrentDelveKey()
    if RA.cachedInstanceType ~= "scenario" or RA.cachedInstanceID == 0 then return nil end
    return DELVE_MAP[RA.cachedInstanceID]
end

-- Boss of the raid bonus roll: the one Blizzard names for the open prompt
-- (RA.bonusRollEncounterID), else the last kill seen via ENCOUNTER_END.
local function GetCurrentRaidBossKey()
    local encounterID = RA.bonusRollEncounterID or RA.lastEncounterID
    if encounterID == 0 then return nil end
    return RAID_ENCOUNTER_MAP[encounterID]
end

-- World map (uiMapID) of every Midnight zone. Prey auto-pass only counts
-- there; add the new zone's map here with each patch (12.1: Coiled Isle).
local MIDNIGHT_ZONE_MAPS = {
    -- 12.0: Silvermoon City, Eversong Woods, Voidstorm, Harandar,
    -- Isle of Quel'Danas, Zul'Aman (2479 / 2480: second maps of Voidstorm / Harandar)
    [2393] = true, [2395] = true, [2405] = true, [2479] = true,
    [2413] = true, [2480] = true, [2424] = true, [2437] = true,
    -- 12.1
    [2512] = true,  -- The Coiled Isle
}

-- Is the player in a Midnight zone? A map is Midnight when it or one of its
-- parent maps is in the list (covers sub-zones). Returns true / false, and
-- the player's map ID; nil when the map is not known (e.g. while loading).
function RA.IsInMidnightZone()
    local playerMap = C_Map.GetBestMapForUnit("player")
    local mapID, hops = playerMap, 0
    while mapID and mapID ~= 0 and hops < 10 do
        if MIDNIGHT_ZONE_MAPS[mapID] then return true, playerMap end
        local info = C_Map.GetMapInfo(mapID)
        mapID = info and info.parentMapID
        hops = hops + 1
    end
    if not playerMap then return nil end
    return false, playerMap
end

-- Continent map (uiMapID) -> expansion index (EXPANSION_NAMEn): only for the
-- debug log's "Zone: Name (Expansion)". Midnight zones are recognised by
-- RA.IsInMidnightZone, the Eastern Kingdoms / Kalimdor count as Classic.
local CONTINENT_EXPANSION = {
    [12] = 0, [13] = 0,                  -- Kalimdor, Eastern Kingdoms
    [101] = 1,                           -- Outland
    [113] = 2,                           -- Northrend
    [948] = 3,                           -- The Maelstrom
    [424] = 4,                           -- Pandaria
    [572] = 5,                           -- Draenor
    [619] = 6, [905] = 6,                -- Broken Isles, Argus
    [875] = 7, [876] = 7,                -- Zandalar, Kul Tiras
    [1550] = 8,                          -- The Shadowlands
    [1978] = 9,                          -- Dragon Isles
    [2274] = 10,                         -- Khaz Algar
    [2537] = 11,                         -- Quel'Thalas (Midnight), also where the map is not a zone yet
}

-- "Zone name (Expansion)" of the player's current map for the debug log; the
-- expansion is left out when it is not known.
function RA.GetZoneLabel()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return "?" end
    local info = C_Map.GetMapInfo(mapID)
    local name = info and info.name or tostring(mapID)

    local expansion
    if RA.IsInMidnightZone() then
        expansion = EXPANSION_NAME11 or "Midnight"
    else
        local id, hops = mapID, 0
        while id and id ~= 0 and hops < 10 do
            local index = CONTINENT_EXPANSION[id]
            if index then
                expansion = _G["EXPANSION_NAME" .. index]
                break
            end
            local parent = C_Map.GetMapInfo(id)
            id = parent and parent.parentMapID
            hops = hops + 1
        end
    end
    return expansion and string.format("%s (%s)", name, expansion) or name
end

------------------------------------------------------------------------
-- Auto-pass matching logic – pure/read-only. Shared by TryAutoPass (which
-- acts on the result) and Core/Core.lua's zone-change debug summary (which only
-- previews it). Keeping this in one place means the debug preview can
-- never drift out of sync with what actually gets auto-passed.
------------------------------------------------------------------------

local function ComputeAutoPassState()
    if not RollAwayDB or not RollAwayDBChar then return false end
    if not RA.BONUS_ROLLS_ENABLED then return false end

    -- 1. Dungeon (party, matched by mapID) - either the specific dungeon is
    -- checked, OR the "auto-pass all dungeons" master switch is on.
    local key = GetCurrentDungeonKey()
    if key and (RollAwayDBChar.dungeons[key] or RollAwayDBChar.dungeons_s2[key]
                or RollAwayDBChar.dungeonAutoPassAll) then
        return true, RollAwayDBChar.dungeonAutoPassAll and "dungeon_all" or ("dungeon:" .. key)
    end

    -- 2. Delve (scenario, matched by mapID) - either the specific delve is
    -- checked, OR the "auto-pass all delves" master switch is on.
    key = GetCurrentDelveKey()
    if key and (RollAwayDBChar.delves[key] or RollAwayDBChar.delves_s2[key]
                or RollAwayDBChar.delveAutoPassAll) then
        return true, RollAwayDBChar.delveAutoPassAll and "delve_all" or ("delve:" .. key)
    end

    -- 3. Raid boss (matched by lastEncounterID from ENCOUNTER_END) - either
    -- the specific boss is checked, OR the whole difficulty bucket is.
    key = GetCurrentRaidBossKey()
    if key and RollAwayDBChar.raids[key] then
        return true, "raid:" .. key
    elseif RA.cachedInstanceType == "raid" then
        local bucket = RAID_DIFFICULTY_BUCKET[RA.cachedDiffID]
            or (RA.devTest.oldRaidAutoPass and OLD_RAID_DIFFICULTY_BUCKET[RA.cachedDiffID])
        if bucket and RollAwayDBChar.raidAutoPassDifficulty[bucket] then
            return true, "raid_difficulty:" .. bucket
        end
    end

    -- 4. Prey (open world - a BonusRollFrame outside an instance, in a
    -- Midnight zone only; an unknown map (nil) keeps the old behaviour)
    if RA.cachedInstanceType == "none" and RollAwayDBChar.prey
       and RA.IsInMidnightZone() ~= false then
        return true, "prey"
    end

    return false
end
RA.ComputeAutoPassState = ComputeAutoPassState

------------------------------------------------------------------------
-- Auto-pass main function
------------------------------------------------------------------------

local function TryAutoPass()
    if not RollAwayDB or not RollAwayDBChar then return end
    if not RA.BONUS_ROLLS_ENABLED then
        DBG("AutoPass: Bonus Rolls disabled for this season – skipping")
        return
    end

    local shouldPass, reason = ComputeAutoPassState()

    if RollAwayDB.debug then
        DBG("[AutoPass] Check | instanceID:", RA.cachedInstanceID,
            "| type:", RA.cachedInstanceType,
            "| lastEncounterID:", RA.lastEncounterID)
        if shouldPass then
            DBG("[AutoPass] v Triggered by:", reason)
        else
            DBG("[AutoPass] x No auto-pass active for current content")
        end
    end

    if not shouldPass then return end

    local promptFrame = BonusRollFrame and BonusRollFrame.PromptFrame
    if not promptFrame then return end

    if promptFrame.PassButton and promptFrame.PassButton:IsVisible() then
        DBG("[AutoPass] v Clicking PassButton!")
        promptFrame.PassButton:Click()
        -- The server needs a moment to answer the pass before Blizzard closes the
        -- prompt; keep it from flashing up meanwhile (Blizzard resets the alpha
        -- itself when the next bonus roll starts).
        promptFrame:SetAlpha(0)
    else
        DBG("[AutoPass] x PassButton not visible")
    end
end

RA.TryAutoPass = TryAutoPass

------------------------------------------------------------------------
-- Initialization – called from Core/Core.lua ADDON_LOADED
------------------------------------------------------------------------

-- DungeonEncounterID (the key of RAID_ENCOUNTER_MAP) of the boss the open
-- bonus roll belongs to. Blizzard stores the Encounter Journal ID of that
-- boss on BonusRollFrame; nil when it has none.
local function GetBonusRollEncounterID()
    local journalEncounterID = BonusRollFrame and BonusRollFrame.encounterID
    if not journalEncounterID or journalEncounterID == 0 then return nil end
    local dungeonEncounterID = select(7, EJ_GetEncounterInfo(journalEncounterID))
    if dungeonEncounterID and dungeonEncounterID ~= 0 then return dungeonEncounterID end
end

function RA.InitAutoPass()
    if not (BonusRollFrame and BonusRollFrame.PromptFrame) then
        DBG("WARNING: BonusRollFrame not found – hook not set")
        return
    end
    -- Runs after Blizzard has fully set the prompt up (SPELL_CONFIRMATION_PROMPT),
    -- so one frame later the Pass button is ready to click.
    hooksecurefunc("BonusRollFrame_StartBonusRoll", function(spellID)
        DBG("[AutoPass] BonusRollFrame_StartBonusRoll | spellID:", spellID)
        RA.bonusRollEncounterID = GetBonusRollEncounterID()
        RunNextFrame(function()
            TryAutoPass()
            RA.bonusRollEncounterID = nil  -- only meant for this prompt
        end)
    end)
    DBG("BonusRollFrame hook set")
end
