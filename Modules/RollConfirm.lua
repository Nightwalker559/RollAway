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

local GetLootRollItemInfo = GetLootRollItemInfo
local ConfirmLootRoll     = ConfirmLootRoll
local C_Timer_After       = RA.C_Timer_After

------------------------------------------------------------------------
-- Roll type definitions: DB key, RollOnLoot rollType id (used only for
-- the follow-up ConfirmLootRoll call), native button field, ElvUI button
-- name fragments (localized), type label locale key.
--
-- Note: Transmog uses rollType 2, the same id as Greed, for the
-- ConfirmLootRoll fallback. rollType 3 is Disenchant and must never be
-- used here.
------------------------------------------------------------------------
local ROLL_TYPES = {
    { dbKey = "need",     rollType = 1, nativeField = "NeedButton",     elvNames = { "Bedarf", "Need" },  labelKey = "confirm_type_need" },
    { dbKey = "greed",    rollType = 2, nativeField = "GreedButton",    elvNames = { "Gier", "Greed" },   labelKey = "confirm_type_greed" },
    { dbKey = "transmog", rollType = 2, nativeField = "TransmogButton", elvNames = { "Transmog" },        labelKey = "confirm_type_transmog" },
    { dbKey = "pass",     rollType = 0, nativeField = "PassButton",     elvNames = { "Passen", "Pass" },  labelKey = "confirm_type_pass" },
}

------------------------------------------------------------------------
-- Confirmation popup (shared by all roll types)
------------------------------------------------------------------------
StaticPopupDialogs["ROLLAWAY_CONFIRM_ROLL"] = {
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
        local function DoConfirm()
            if ConfirmLootRoll then pcall(ConfirmLootRoll, rollID, rollType) end
            for i = 1, 10 do
                local popup = _G[STATIC_POPUPS[i]]
                if popup and popup:IsShown() then
                    local which = popup.which or ""
                    if which:find("LOOT_ROLL") or which:find("CONFIRM_ROLL") then
                        popup:Hide()
                        DBG("[RollConfirm] Closed native BoP popup:", which)
                    end
                end
            end
        end
        if C_Timer_After then C_Timer_After(0.15, DoConfirm) else DoConfirm() end
    end,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    showAlert    = true,
}

------------------------------------------------------------------------
-- Click-catcher overlays, tracked per roll type so Options can toggle
-- each type independently.
------------------------------------------------------------------------
local overlaysByType = { need = {}, greed = {}, transmog = {}, pass = {} }

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
        StaticPopup_Show("ROLLAWAY_CONFIRM_ROLL", RA_L[rollDef.labelKey], name or "?", { rollID = rollID, rollType = rollDef.rollType, btn = btn })
    end)

    btn.raRollOverlay = overlay
    overlaysByType[rollDef.dbKey][#overlaysByType[rollDef.dbKey] + 1] = overlay
end

-- Single pass over an ElvUI roll frame's children, matching all 4 button
-- types at once (cheaper than scanning the children list per type).
local function FindElvButtons(elvFrame)
    local found = {}
    for _, child in ipairs({ elvFrame:GetChildren() }) do
        if child:GetObjectType() == "Button" then
            local cname = child:GetName() or ""
            for _, rollDef in ipairs(ROLL_TYPES) do
                if not found[rollDef.dbKey] then
                    for _, frag in ipairs(rollDef.elvNames) do
                        if cname:find(frag) then
                            found[rollDef.dbKey] = child
                            break
                        end
                    end
                end
            end
        end
    end
    return found
end

local function BuildOverlays()
    for i = 1, 5 do
        local nativeFrame = _G["GroupLootFrame"..i]
        local elvFrame     = _G["ElvUI_LootRollFrame"..i]
        local elvButtons   = elvFrame and FindElvButtons(elvFrame)

        for _, rollDef in ipairs(ROLL_TYPES) do
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
local function SetEnabled(dbKey, enabled)
    for _, overlay in ipairs(overlaysByType[dbKey] or {}) do
        overlay:EnableMouse(enabled)
    end
end
RA.SetRollConfirmEnabled = SetEnabled

------------------------------------------------------------------------
-- Init - called from Core.lua on ADDON_LOADED
------------------------------------------------------------------------
function RA.InitRollConfirm()
    -- Delay slightly so ElvUI has finished building its frames (same
    -- reasoning as AutoRoll's BuildElvButtonCache).
    if RA.C_Timer_After then
        RA.C_Timer_After(0.5, BuildOverlays)
    else
        BuildOverlays()
    end
    DBG("RollConfirm initialized")
end
