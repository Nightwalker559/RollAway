-- RollAway - AutoPass.lua
-- Bonus roll auto-pass: dungeons, delves, raids (per boss or whole difficulty) and Prey.

local RA   = _G["RollAway"]
local DBG  = RA.DBG

local DUNGEON_MAP        = RA.DUNGEON_MAP
local DELVE_MAP          = RA.DELVE_MAP
local RAID_ENCOUNTER_MAP = RA.RAID_ENCOUNTER_MAP
local RAID_DIFFICULTY_BUCKET = RA.RAID_DIFFICULTY_BUCKET

-- Difficulty IDs of old raids; only for the developer switch RA.devTest.oldRaidAutoPass.
local OLD_RAID_DIFFICULTY_BUCKET = {
    [3] = "normal", [4] = "normal",   -- 10 / 25 player
    [5] = "heroic", [6] = "heroic",   -- 10 / 25 player heroic
    [7] = "lfr",
}

-- Instance matching helpers

local function GetCurrentDungeonKey()
    if RA.cachedInstanceID == 0 then return nil end
    return DUNGEON_MAP[RA.cachedInstanceID]
end

local function GetCurrentDelveKey()
    if RA.cachedInstanceType ~= "scenario" or RA.cachedInstanceID == 0 then return nil end
    return DELVE_MAP[RA.cachedInstanceID]
end

-- Boss of the raid bonus roll: the open prompt's (RA.bonusRollEncounterID), else the
-- last kill seen via ENCOUNTER_END.
local function GetCurrentRaidBossKey()
    local encounterID = RA.bonusRollEncounterID or RA.lastEncounterID
    if encounterID == 0 then return nil end
    return RAID_ENCOUNTER_MAP[encounterID]
end

-- uiMapID of every Midnight zone (Prey auto-pass counts only there); add new zones per patch.
local MIDNIGHT_ZONE_MAPS = {
    -- 12.0: Silvermoon City, Eversong Woods, Voidstorm, Harandar, Isle of Quel'Danas,
    -- Zul'Aman (2479 / 2480: second maps of Voidstorm / Harandar)
    [2393] = true, [2395] = true, [2405] = true, [2479] = true,
    [2413] = true, [2480] = true, [2424] = true, [2437] = true,
    -- 12.1
    [2512] = true,  -- The Coiled Isle
}

-- In a Midnight zone (the map or a parent map is listed)? Returns true/false and the map
-- ID; nil while the map is unknown.
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

-- Continent uiMapID -> expansion index (EXPANSION_NAMEn), for the debug log only.
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

-- "Zone name (Expansion)" for the debug log.
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

-- Auto-pass matching, read-only: used by TryAutoPass and by Core's zone summary, so the
-- preview cannot drift from what is passed.

-- Difficulty bucket of the current raid (old raids only with the developer switch).
local function GetRaidDifficultyBucket()
    return RAID_DIFFICULTY_BUCKET[RA.cachedDiffID]
        or (RA.devTest.oldRaidAutoPass and OLD_RAID_DIFFICULTY_BUCKET[RA.cachedDiffID])
end

local function ComputeAutoPassState()
    if not RollAwayDB or not RollAwayDBChar then return false end
    if not RA.BONUS_ROLLS_ENABLED then return false end

    -- 1. Dungeon (by mapID): the dungeon is checked or "all dungeons" is on.
    local key = GetCurrentDungeonKey()
    if key and (RollAwayDBChar.dungeons[key] or RollAwayDBChar.dungeons_s2[key]
                or RollAwayDBChar.dungeonAutoPassAll) then
        return true, RollAwayDBChar.dungeonAutoPassAll and "dungeon_all" or ("dungeon:" .. key)
    end

    -- 2. Delve (by mapID): the delve is checked or "all delves" is on.
    key = GetCurrentDelveKey()
    if key and (RollAwayDBChar.delves[key] or RollAwayDBChar.delves_s2[key]
                or RollAwayDBChar.delveAutoPassAll) then
        return true, RollAwayDBChar.delveAutoPassAll and "delve_all" or ("delve:" .. key)
    end

    -- 3. Raid boss: the boss is checked or the whole difficulty is.
    key = GetCurrentRaidBossKey()
    if key and RollAwayDBChar.raids[key] then
        return true, "raid:" .. key
    elseif RA.cachedInstanceType == "raid" then
        local bucket = GetRaidDifficultyBucket()
        if bucket and RollAwayDBChar.raidAutoPassDifficulty[bucket] then
            return true, "raid_difficulty:" .. bucket
        end
    end

    -- 4. Prey (open world, Midnight zones only; an unknown map counts as Midnight)
    if RA.cachedInstanceType == "none" and RollAwayDBChar.prey
       and RA.IsInMidnightZone() ~= false then
        return true, "prey"
    end

    return false
end
RA.ComputeAutoPassState = ComputeAutoPassState

-- Auto-pass

local function TryAutoPass()
    if not RollAwayDB or not RollAwayDBChar then return end
    if not RA.BONUS_ROLLS_ENABLED then
        DBG("AutoPass: Bonus Rolls disabled for this season – skipping")
        return
    end

    local shouldPass, reason = ComputeAutoPassState()

    if RollAwayDB.debug then
        local diffID = RA.cachedDiffID
        local bucket = GetRaidDifficultyBucket()
        DBG("[AutoPass] Check | instanceID:", RA.cachedInstanceID,
            "| type:", RA.cachedInstanceType,
            "| diffID:", diffID,
            "| bucket:", bucket or "none",
            "| bucketOn:", bucket and RollAwayDBChar.raidAutoPassDifficulty[bucket] or false,
            "| oldRaidTest:", RA.devTest.oldRaidAutoPass,
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
        -- The server answers the pass a moment later: keep the prompt from flashing up
        -- meanwhile (Blizzard resets the alpha with the next bonus roll).
        promptFrame:SetAlpha(0)
    else
        DBG("[AutoPass] x PassButton not visible")
    end
end

RA.TryAutoPass = TryAutoPass

-- Initialization (Core.lua, ADDON_LOADED)

-- DungeonEncounterID (key of RAID_ENCOUNTER_MAP) of the open bonus roll's boss, from the
-- Encounter Journal ID Blizzard keeps on BonusRollFrame; nil when there is none.
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
    -- After Blizzard has set the prompt up; one frame later the Pass button is ready.
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
