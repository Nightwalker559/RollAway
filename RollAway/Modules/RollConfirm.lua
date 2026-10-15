-- RollAway - RollConfirm.lua
-- Optional "are you sure?" popups before rolling Need, Greed, Transmog or Pass on group
-- loot, for any roll frame; each type is toggled separately. On confirm the real roll
-- button (native or ElvUI) is clicked, not RollOnLoot (the Transmog button may run
-- extra logic), as in AutoRoll.lua.

local RA   = _G["RollAway"]
local DBG  = RA.DBG
local RA_L = RA.RA_L

-- Confirmation popup (all roll types)
RA.RegisterPopup("ROLLAWAY_CONFIRM_ROLL", {
    text         = RA_L["confirm_roll_popup"],
    button1      = YES,
    button2      = NO,
    OnAccept     = function(_, data)
        if not (data and data.btn) then return end

        -- BoP items (most Transmog rolls) need ConfirmLootRoll after the roll: armed first.
        RA.ArmRollConfirm(data.rollID)

        -- The real button, with whatever logic Blizzard/ElvUI runs on it.
        local ok, err = pcall(data.btn.Click, data.btn)
        if not ok then DBG("[RollConfirm] Button click failed:", err) end
    end,
    showAlert    = true,
})

-- Click-catcher overlays per roll type (Options toggles them).
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
            { rollID = rollID, btn = btn })
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

-- Toggled live from Options.
function RA.SetRollConfirmEnabled(dbKey, enabled)
    for _, overlay in ipairs(overlaysByType[dbKey] or {}) do
        overlay:EnableMouse(enabled)
    end
end

-- Init (Core.lua, ADDON_LOADED)
function RA.InitRollConfirm()
    -- Blizzard's roll frames exist already; ElvUI builds its own a moment later.
    BuildOverlays()
    if ElvUI then C_Timer.After(0.5, BuildOverlays) end
    DBG("RollConfirm initialized")
end
