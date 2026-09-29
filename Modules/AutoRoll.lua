-- RollAway - AutoRoll.lua
-- Legacy raid auto-roll (Dragonflight + The War Within).

local RA  = _G["RollAway"]
local DBG = RA.DBG

-- RollOnLoot roll type -> RA.ROLL_BUTTONS dbKey (0 = pass has no button click)
local ROLL_KEY = { [1] = "need", [2] = "greed", [3] = "transmog" }

------------------------------------------------------------------------
-- Execute legacy roll on a given rollID
------------------------------------------------------------------------

local function ExecuteLegacyRoll(rollID)
    if not RollAwayDB or not RollAwayDB.legacy then return end
    if not RollOnLoot then
        DBG("[Legacy] RollOnLoot API not available")
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

    -- Priority: Need > Greed > Transmog > Pass
    local actualRoll = 0
    if RollAwayDB.legacyNeed and canNeed then
        actualRoll = 1; DBG("[Legacy] Rolling Need")
    elseif RollAwayDB.legacyGreed and canGreed then
        actualRoll = 2; DBG("[Legacy] Rolling Greed")
    elseif RollAwayDB.legacyTransmog and canTransmog then
        actualRoll = 3; DBG("[Legacy] Rolling Transmog")
    else
        DBG("[Legacy] No matching roll type – passing")
    end

    DBG("[Legacy] RollOnLoot rollID:", rollID, "| roll:", actualRoll)

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

    -- Fallback: RollOnLoot API if no roll frame/button found or roll is Pass.
    if not clicked then
        DBG("[Legacy] Fallback RollOnLoot roll:", actualRoll)
        local ok, err = pcall(RollOnLoot, rollID, actualRoll)
        if not ok then DBG("[Legacy] RollOnLoot failed:", err) end
    end

    -- BoP confirmation: popup needs ~0.15s to appear after the roll.
    C_Timer.After(0.15, function()
        pcall(ConfirmLootRoll, rollID, actualRoll)
        RA.CloseLootRollPopups("[Legacy]")
    end)
end

RA.ExecuteLegacyRoll = ExecuteLegacyRoll
