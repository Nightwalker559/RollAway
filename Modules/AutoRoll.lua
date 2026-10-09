-- RollAway - AutoRoll.lua
-- Legacy raid auto-roll (Dragonflight + The War Within).

local RA  = _G["RollAway"]
local DBG = RA.DBG

-- RollOnLoot roll type (Blizzard's button ids: 1 Need, 2 Greed, 4 Transmog;
-- 3 is Disenchant and is never used) -> RA.ROLL_BUTTONS dbKey. 0 = pass has no
-- button click.
local ROLL_NEED, ROLL_GREED, ROLL_TRANSMOG = 1, 2, 4
local ROLL_KEY = { [ROLL_NEED] = "need", [ROLL_GREED] = "greed", [ROLL_TRANSMOG] = "transmog" }

-- Legacy roll for a rollID

local function ExecuteLegacyRoll(rollID)
    if not RollAwayDB or not RollAwayDB.legacy then return end
    if not RollOnLoot then
        DBG("[Legacy] RollOnLoot API not available")
        return
    end

    -- Nothing chosen: left to the player.
    local db = RollAwayDB
    if not (db.legacyPass or db.legacyNeed or db.legacyGreed or db.legacyTransmog) then
        DBG("[Legacy] No roll type selected – leaving the roll alone")
        return
    end

    local _, name, _, _, _, canNeed, canGreed, _, _, _, _, _, canTransmog = GetLootRollItemInfo(rollID)

    if not name then
        DBG("[Legacy] GetLootRollItemInfo returned nil for rollID:", rollID)
        return
    end

    DBG("[Legacy] Item:", name,
        "| canNeed:", tostring(canNeed),
        "| canGreed:", tostring(canGreed),
        "| canTransmog:", tostring(canTransmog))

    -- Pass overrides; else Need > Greed > Transmog, Pass if none is available.
    local actualRoll = 0
    if db.legacyPass then
        DBG("[Legacy] Passing (Pass selected)")
    elseif db.legacyNeed and canNeed then
        actualRoll = ROLL_NEED; DBG("[Legacy] Rolling Need")
    elseif db.legacyGreed and canGreed then
        actualRoll = ROLL_GREED; DBG("[Legacy] Rolling Greed")
    elseif db.legacyTransmog and canTransmog then
        actualRoll = ROLL_TRANSMOG; DBG("[Legacy] Rolling Transmog")
    else
        DBG("[Legacy] No matching roll type – passing")
    end

    DBG("[Legacy] RollOnLoot rollID:", rollID, "| roll:", actualRoll)

    -- BoP items ask for a confirmation after the roll: armed first.
    if actualRoll ~= 0 then RA.ArmRollConfirm(rollID) end

    -- Click the real button (native or ElvUI roll frame) when there is one.
    local clicked = false
    if actualRoll ~= 0 then
        local btn = RA.FindRollButton(rollID, ROLL_KEY[actualRoll])
        if btn then
            DBG("[Legacy] Clicking:", btn:GetName() or "unnamed")
            btn:Click()
            clicked = true
        else
            DBG("[Legacy] No roll button found for roll:", actualRoll)
        end
    end

    -- Fallback: RollOnLoot when there is no button or it is a pass.
    if not clicked then
        DBG("[Legacy] Fallback RollOnLoot roll:", actualRoll)
        local ok, err = pcall(RollOnLoot, rollID, actualRoll)
        if not ok then DBG("[Legacy] RollOnLoot failed:", err) end
    end
end

RA.ExecuteLegacyRoll = ExecuteLegacyRoll
