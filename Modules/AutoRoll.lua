-- RollAway - AutoRoll.lua
-- Legacy raid auto-roll (Dragonflight + The War Within).

local RA  = _G["RollAway"]
local DBG = RA.DBG

local GetLootRollItemInfo = GetLootRollItemInfo
local RollOnLoot          = RollOnLoot
local ConfirmLootRoll     = ConfirmLootRoll
local C_Timer_After       = RA.C_Timer_After

------------------------------------------------------------------------
-- ElvUI button cache
-- Built once at InitAutoRoll time; ElvUI_LootRollFrame children never change.
------------------------------------------------------------------------
local elvButtonCache = {}  -- [frameIndex] = { needBtn, greedBtn, transmogBtn }

local function BuildElvButtonCache()
    for i = 1, 5 do
        local elvFrame = _G["ElvUI_LootRollFrame"..i]
        if elvFrame then
            local needBtn, greedBtn, transmogBtn
            local children = { elvFrame:GetChildren() }
            for _, child in ipairs(children) do
                if child:GetObjectType() == "Button" then
                    local cname = child:GetName() or ""
                    if cname:find("Bedarf") or cname:find("Need") then
                        needBtn = child
                    elseif cname:find("Gier") or cname:find("Greed") then
                        greedBtn = child
                    elseif cname:find("Transmog") then
                        transmogBtn = child
                    end
                end
            end
            elvButtonCache[i] = { need = needBtn, greed = greedBtn, transmog = transmogBtn }
            DBG("[AutoRoll] Cached ElvUI_LootRollFrame"..i.." | need=",
                tostring(needBtn and needBtn:GetName()),
                "| greed=", tostring(greedBtn and greedBtn:GetName()),
                "| transmog=", tostring(transmogBtn and transmogBtn:GetName()))
        end
    end
end

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

    local clicked = false
    if actualRoll ~= 0 then
        for i = 1, 5 do
            -- Try native Blizzard frame first
            local nativeFrame = _G["GroupLootFrame"..i]
            if nativeFrame and nativeFrame:IsShown() and nativeFrame.rollID == rollID then
                local btn
                if actualRoll == 1 then btn = nativeFrame.NeedButton
                elseif actualRoll == 2 then btn = nativeFrame.GreedButton
                elseif actualRoll == 3 then btn = nativeFrame.TransmogButton
                end
                if btn then
                    DBG("[Legacy] Clicking native:", btn:GetName() or "unnamed")
                    btn:Click()
                    clicked = true
                else
                    DBG("[Legacy] Native frame matched but button nil for roll:", actualRoll)
                end
                break  -- rollID matched this frame, no need to check further
            end

            -- Try ElvUI frame using cached button references
            local elvFrame = _G["ElvUI_LootRollFrame"..i]
            if elvFrame and elvFrame:IsShown() and elvFrame.rollID == rollID then
                local cache = elvButtonCache[i]
                local btn
                if cache then
                    if actualRoll == 1 then btn = cache.need
                    elseif actualRoll == 2 then btn = cache.greed
                    elseif actualRoll == 3 then btn = cache.transmog
                    end
                end
                if btn then
                    DBG("[Legacy] Clicking ElvUI:", btn:GetName() or "unnamed")
                    btn:Click()
                    clicked = true
                else
                    DBG("[Legacy] ElvUI frame matched but button nil for roll:", actualRoll)
                end
                break  -- rollID matched this frame, no need to check further
            end
        end
    end

    -- Fallback: RollOnLoot API if no ElvUI frame found or roll is Pass.
    if not clicked then
        DBG("[Legacy] Fallback RollOnLoot roll:", actualRoll)
        local ok, err = pcall(RollOnLoot, rollID, actualRoll)
        if not ok then DBG("[Legacy] RollOnLoot failed:", err) end
    end

    -- BoP confirmation: popup needs ~0.15s to appear after the roll.
    if C_Timer_After then
        C_Timer_After(0.15, function()
            if ConfirmLootRoll then pcall(ConfirmLootRoll, rollID, actualRoll) end
            RA.CloseLootRollPopups("[Legacy]")
        end)
    else
        if ConfirmLootRoll then pcall(ConfirmLootRoll, rollID, actualRoll) end
    end
end

RA.ExecuteLegacyRoll = ExecuteLegacyRoll

------------------------------------------------------------------------
-- Initialization – called from Core.lua ADDON_LOADED
------------------------------------------------------------------------

function RA.InitAutoRoll()
    -- Cache ElvUI button references once. Delay slightly so ElvUI has
    -- finished building its frames before we inspect them.
    if C_Timer_After then
        C_Timer_After(0.5, BuildElvButtonCache)
    else
        BuildElvButtonCache()
    end
    DBG("AutoRoll initialized")
end
