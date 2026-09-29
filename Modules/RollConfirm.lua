-- RollAway - RollConfirm.lua
-- Optional "are you sure?" confirmation popups before rolling Need, Greed,
-- Transmog or Pass on group loot. Global: applies to any loot roll frame
-- (current-tier and legacy raids/dungeons alike), independent of the
-- season/boss tracking data. Each roll type is toggled independently.
--
-- Implementation note: on confirm, we click the real roll button (native
-- or ElvUI-skinned) instead of calling RollOnLoot ourselves. Blizzard's
-- Transmog button shares rollType 2 with Greed but may run additional
-- internal logic on click (e.g. for BoP confirmation), so replicating the
-- exact click - same as AutoRoll.lua already does for legacy auto-rolling -
-- is more reliable than guessing the RollOnLoot arguments.

local RA   = _G["RollAway"]
local DBG  = RA.DBG
local RA_L = RA.RA_L

------------------------------------------------------------------------
-- Confirmation popup (shared by all roll types)
------------------------------------------------------------------------
RA.RegisterPopup("ROLLAWAY_CONFIRM_ROLL", {
    text         = RA_L["confirm_roll_popup"],
    button1      = YES,
    button2      = NO,
    OnAccept     = function(_, data)
        if not (data and data.btn) then return end

        -- Click the real button - reuses whatever internal logic
        -- Blizzard/ElvUI runs on that click (same approach as AutoRoll).
        local ok, err = pcall(data.btn.Click, data.btn)
        if not ok then DBG("[RollConfirm] Button click failed:", err) end

        -- BoP items (most Transmog rolls) fire CONFIRM_LOOT_ROLL after
        -- the roll and need an explicit ConfirmLootRoll to actually
        -- complete it. The popup needs ~0.15s to appear.
        local rollID, rollType = data.rollID, data.rollType
        C_Timer.After(0.15, function()
            pcall(ConfirmLootRoll, rollID, rollType)
            RA.CloseLootRollPopups("[RollConfirm]")
        end)
    end,
    showAlert    = true,
})

------------------------------------------------------------------------
-- Click-catcher overlays, tracked per roll type so Options can toggle
-- each type independently.
------------------------------------------------------------------------
local overlaysByType = {}
for _, rollDef in ipairs(RA.ROLL_BUTTONS) do overlaysByType[rollDef.dbKey] = {} end

local function AttachOverlay(btn, getRollID, rollDef)
    if not btn or btn.raRollOverlay then return end

    local overlay = CreateFrame("Button", nil, btn)
    overlay:SetAllPoints(btn)
    overlay:SetFrameLevel(btn:GetFrameLevel() + 5)
    overlay:RegisterForClicks("LeftButtonUp")
    overlay:EnableMouse(RollAwayDB and RollAwayDB.confirmRoll and RollAwayDB.confirmRoll[rollDef.dbKey] or false)
    overlay:SetScript("OnClick", function()
        local rollID = getRollID()
        if not rollID then return end
        local _, name = GetLootRollItemInfo(rollID)
        StaticPopup_Show("ROLLAWAY_CONFIRM_ROLL", RA_L["confirm_type_"..rollDef.dbKey], name or "?",
            { rollID = rollID, rollType = rollDef.rollType, btn = btn })
    end)

    btn.raRollOverlay = overlay
    local overlays = overlaysByType[rollDef.dbKey]
    overlays[#overlays + 1] = overlay
end

local function BuildOverlays()
    for i = 1, 5 do
        local nativeFrame = _G["GroupLootFrame"..i]
        local elvFrame    = _G["ElvUI_LootRollFrame"..i]
        local elvButtons  = RA.GetElvRollButtons(i)

        for _, rollDef in ipairs(RA.ROLL_BUTTONS) do
            if nativeFrame and nativeFrame[rollDef.nativeField] then
                AttachOverlay(nativeFrame[rollDef.nativeField], function() return nativeFrame.rollID end, rollDef)
            end
            if elvButtons and elvButtons[rollDef.dbKey] then
                AttachOverlay(elvButtons[rollDef.dbKey], function() return elvFrame.rollID end, rollDef)
            end
        end
    end
    DBG("[RollConfirm] Overlays built")
end

-- Toggled live from Options when a setting changes.
function RA.SetRollConfirmEnabled(dbKey, enabled)
    for _, overlay in ipairs(overlaysByType[dbKey] or {}) do
        overlay:EnableMouse(enabled)
    end
end

------------------------------------------------------------------------
-- Init - called from Core.lua on ADDON_LOADED
------------------------------------------------------------------------
function RA.InitRollConfirm()
    -- Delay slightly so ElvUI has finished building its frames.
    C_Timer.After(0.5, BuildOverlays)
    DBG("RollConfirm initialized")
end
