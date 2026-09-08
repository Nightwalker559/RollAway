-- RollAway - AutoPass.lua
-- Bonus Roll auto-pass for dungeons, delves, raids (per-boss or whole
-- difficulty bucket), and Prey.

local RA   = _G["RollAway"]
local DBG  = RA.DBG

local DUNGEON_MAP        = RA.DUNGEON_MAP
local DELVE_MAP          = RA.DELVE_MAP
local RAID_ENCOUNTER_MAP = RA.RAID_ENCOUNTER_MAP
local RAID_DIFFICULTY_BUCKET = RA.RAID_DIFFICULTY_BUCKET
local C_Timer_After      = RA.C_Timer_After

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

local function GetCurrentRaidBossKey()
    if RA.lastEncounterID == 0 then return nil end
    return RAID_ENCOUNTER_MAP[RA.lastEncounterID]
end

------------------------------------------------------------------------
-- Auto-pass main function
------------------------------------------------------------------------

local function TryAutoPass()
    if not RollAwayDB or not RollAwayDBChar then return end
    if not RA.BONUS_ROLLS_ENABLED then
        DBG("AutoPass: Bonus Rolls disabled for this season – skipping")
        return
    end

    local shouldPass = false
    local reason     -- only built when debug is on

    -- 1. Dungeon (party, matched by mapID) - either the specific dungeon is
    -- checked, OR the "auto-pass all dungeons" master switch is on.
    local key = GetCurrentDungeonKey()
    if key and (
        (RollAwayDBChar.dungeons    and RollAwayDBChar.dungeons[key]) or
        (RollAwayDBChar.dungeons_s2 and RollAwayDBChar.dungeons_s2[key]) or
        RollAwayDBChar.dungeonAutoPassAll
    ) then
        shouldPass = true
        if RollAwayDB.debug then
            reason = RollAwayDBChar.dungeonAutoPassAll and "dungeon_all" or ("dungeon:" .. key)
        end
    end

    -- 2. Delve (scenario, matched by mapID) - either the specific delve is
    -- checked, OR the "auto-pass all delves" master switch is on.
    if not shouldPass then
        key = GetCurrentDelveKey()
        if key and (
            (RollAwayDBChar.delves    and RollAwayDBChar.delves[key]) or
            (RollAwayDBChar.delves_s2 and RollAwayDBChar.delves_s2[key]) or
            RollAwayDBChar.delveAutoPassAll
        ) then
            shouldPass = true
            if RollAwayDB.debug then
                reason = RollAwayDBChar.delveAutoPassAll and "delve_all" or ("delve:" .. key)
            end
        end
    end

    -- 3. Raid boss (matched by lastEncounterID from ENCOUNTER_END) - either
    -- the specific boss is checked, OR the whole difficulty bucket is.
    if not shouldPass then
        key = GetCurrentRaidBossKey()
        if key and RollAwayDBChar.raids and RollAwayDBChar.raids[key] then
            shouldPass = true
            if RollAwayDB.debug then reason = "raid:" .. key end
        elseif RA.cachedInstanceType == "raid" then
            local bucket = RAID_DIFFICULTY_BUCKET[RA.cachedDiffID]
            if bucket and RollAwayDBChar.raidAutoPassDifficulty
               and RollAwayDBChar.raidAutoPassDifficulty[bucket] then
                shouldPass = true
                if RollAwayDB.debug then reason = "raid_difficulty:" .. bucket end
            end
        end
    end

    -- 4. Prey (open world – any BonusRollFrame outside an instance)
    if not shouldPass and RA.cachedInstanceType == "none" and RollAwayDBChar.prey then
        shouldPass = true
        if RollAwayDB.debug then reason = "prey" end
    end

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
    else
        DBG("[AutoPass] x PassButton not visible")
    end
end

RA.TryAutoPass = TryAutoPass

------------------------------------------------------------------------
-- Initialization – called from Core.lua ADDON_LOADED
------------------------------------------------------------------------

function RA.InitAutoPass()
    local promptFrame = BonusRollFrame and BonusRollFrame.PromptFrame
    if promptFrame then
        RA.hooksecurefunc(promptFrame, "Show", function()
            DBG("[AutoPass] BonusRollFrame.PromptFrame:Show() fired")
            if C_Timer_After then
                C_Timer_After(0.1, TryAutoPass)
            else
                TryAutoPass()
            end
        end)
        DBG("BonusRollFrame hook set")
    else
        DBG("WARNING: BonusRollFrame not found – hook not set")
    end
end
