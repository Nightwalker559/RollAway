-- RollAway - AutoRoll.lua
-- Legacy raid auto-roll (Dragonflight + The War Within).

local RA  = _G["RollAway"]
local DBG = RA.DBG

-- RollOnLoot roll type (Blizzard's button ids: 1 Need, 2 Greed, 4 Transmog;
-- 3 is Disenchant and is never used) -> RA.ROLL_BUTTONS dbKey. 0 = pass has no
-- button click.
local ROLL_NEED, ROLL_GREED, ROLL_TRANSMOG = 1, 2, 4
local ROLL_KEY = { [ROLL_NEED] = "need", [ROLL_GREED] = "greed", [ROLL_TRANSMOG] = "transmog" }

------------------------------------------------------------------------
-- Execute legacy roll on a given rollID
------------------------------------------------------------------------

local function ExecuteLegacyRoll(rollID)
    if not RollAwayDB or not RollAwayDB.legacy then return end
    if not RollOnLoot then
        DBG("[Legacy] RollOnLoot API not available")
        return
    end

    -- Nothing chosen = leave the roll to the player (passing is its own choice).
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

    -- Pass overrides the rest; otherwise Need > Greed > Transmog, and Pass when
    -- none of the chosen types is available for this item.
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

    -- BoP items ask for a confirmation after the roll (CONFIRM_LOOT_ROLL);
    -- armed first so the event cannot be missed.
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

    -- Fallback: RollOnLoot API if no roll frame/button found or roll is Pass.
    if not clicked then
        DBG("[Legacy] Fallback RollOnLoot roll:", actualRoll)
        local ok, err = pcall(RollOnLoot, rollID, actualRoll)
        if not ok then DBG("[Legacy] RollOnLoot failed:", err) end
    end
end

RA.ExecuteLegacyRoll = ExecuteLegacyRoll
