-- RollAway - Modules/CharFrameButtons.lua
-- Omniumfoliant and Great Vault buttons in the bottom-right corner of the
-- Character panel (Stats view only).
--
-- Design: one idempotent RA.RefreshCharFrameButtons() decides, from current
-- state only, whether each button should be shown, and applies it. It is
-- called from a few event triggers (see InitCharacterFrameButtons) - no
-- timers, no watchdog, no cached "which tab is active" flags.
--
-- Compat:
--   - ElvUI: ElvUI_Skin.lua skins the buttons after each refresh.
--   - Chonky Character Sheet: only CharacterFrameBg is pushed out, so the
--     buttons anchor to it and the Stats-only restriction is skipped.

local RA       = _G["RollAway"]
local RA_L     = RA.RA_L
local DBG      = RA.DBG
local C_Timer_After = RA.C_Timer_After

local OMNI_ICON_FILEID       = 7554214  -- Omniumfoliant minimap icon
local GREATVAULT_ICON_FILEID = 2744751  -- Great Vault chest icon

-- Extra X nudge while Chonky is loaded (tune live with /rawchonkyoffset).
local chonkyXOffsetBonus = -260

local buttons = {}  -- [key] = button, created lazily

------------------------------------------------------------------------
-- State helpers
------------------------------------------------------------------------

local function IsChonkyLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded("ChonkyCharacterSheet")
end
RA.IsChonkyLoaded = IsChonkyLoaded

local function IsMaxLevel()
    return RA.IsMaxLevel and RA.IsMaxLevel()
end

-- Titles / Equipment Manager are sub-views of the Character tab and use the
-- same corner, so the buttons only show while the Stats pane is visible
-- (Blizzard: GetPaperDollSideBarFrame(1) == CharacterStatsPane). Chonky moves
-- those panes elsewhere, so it is exempt.
local function IsStatsViewShown()
    if IsChonkyLoaded() then return true end
    return CharacterStatsPane ~= nil and CharacterStatsPane:IsShown()
end

------------------------------------------------------------------------
-- Button factory
------------------------------------------------------------------------

local function PlaceButton(btn, xOffset)
    local anchor = CharacterFrame
    local bonus  = 0
    if IsChonkyLoaded() then
        anchor = _G["CharacterFrameBg"] or CharacterFrame
        bonus  = chonkyXOffsetBonus
    end
    btn:ClearAllPoints()
    btn:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", xOffset + bonus, 8)
end

local function CreateButton(globalName, icon, onClick, onEnter)
    local btn = CreateFrame("Button", globalName, PaperDollFrame)
    btn:SetSize(24, 24)
    btn:SetFrameStrata("DIALOG")
    btn:SetFrameLevel(PaperDollFrame:GetFrameLevel() + 10)

    btn:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    btn:GetNormalTexture():SetAllPoints()
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 3, -3)
    tex:SetPoint("BOTTOMRIGHT", -3, 3)
    tex:SetTexture(icon)
    btn.icon = tex

    btn:SetScript("OnClick", onClick)
    btn:SetScript("OnEnter", onEnter)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:Hide()
    return btn
end

------------------------------------------------------------------------
-- Omniumfoliant: hide the minimap icon, offer a Character panel button
------------------------------------------------------------------------

local function GetOmniMinimapButton()
    return _G["ExpansionLandingPageMinimapButton"]
end

local function OmniActive()
    return RollAwayDB and RollAwayDB.hideOmniumfoliantMinimap and IsMaxLevel()
end

-- Hooks the Blizzard minimap button once: keeps it hidden while the option
-- is active and guards its tooltip (errors below max level).
local function SetupOmniMinimapButton()
    local mm = GetOmniMinimapButton()
    if not mm then return nil end
    if mm.RA_hooked then return mm end
    mm.RA_hooked = true

    hooksecurefunc(mm, "Show", function(self)
        if OmniActive() then self:Hide() end
    end)

    local origOnEnter = mm:GetScript("OnEnter")
    if origOnEnter then
        mm:SetScript("OnEnter", function(self)
            if IsMaxLevel() then origOnEnter(self) end
        end)
    end
    return mm
end

local function CreateOmniButton()
    return CreateButton("RollAwayOmniumfoliantButton", OMNI_ICON_FILEID,
        function()
            local mm = GetOmniMinimapButton()
            if mm then mm:Click() end
        end,
        -- Reuse Blizzard's own (localized) tooltip, just re-anchor it.
        function(self)
            local mm = GetOmniMinimapButton()
            local onEnter = mm and mm:GetScript("OnEnter")
            if onEnter then
                onEnter(mm)
                GameTooltip:ClearAllPoints()
                GameTooltip:SetPoint("BOTTOMRIGHT", self, "TOPLEFT", 0, 4)
            else
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText("Omniumfoliant")
                GameTooltip:Show()
            end
        end)
end

------------------------------------------------------------------------
-- Great Vault: opens WeeklyRewardsFrame directly
------------------------------------------------------------------------

local function VaultActive()
    return RollAwayDB and RollAwayDB.vaultButtonCharFrame and IsMaxLevel()
end

local function ToggleGreatVault()
    if C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("Blizzard_WeeklyRewards")
    end
    if not WeeklyRewardsFrame then return end
    WeeklyRewardsFrame:SetShown(not WeeklyRewardsFrame:IsShown())
end

local function CreateVaultButton()
    return CreateButton("RollAwayVaultButton", GREATVAULT_ICON_FILEID,
        ToggleGreatVault,
        function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(RA_L["qol_vault_button_tooltip"])
            GameTooltip:Show()
        end)
end

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------

-- key, X offset from the corner (vault sits left of the Omnium slot),
-- creator, and whether the feature is enabled.
local DEFS = {
    { key = "omni",  x = -8,  create = CreateOmniButton,  active = OmniActive  },
    { key = "vault", x = -36, create = CreateVaultButton, active = VaultActive },
}

-- Single source of truth: sets every button (and the minimap icon) to match
-- current options/level/view. Safe to call any time, any number of times.
function RA.RefreshCharFrameButtons()
    -- Minimap icon: only hidden by us while the option is active; never
    -- force-shown otherwise (Blizzard controls default visibility).
    local mm = SetupOmniMinimapButton()
    if mm then
        if OmniActive() then
            mm:Hide()
            mm.RA_forceHidden = true
        elseif mm.RA_forceHidden then
            mm.RA_forceHidden = false
            mm:Show()
        end
    end

    if not (PaperDollFrame and CharacterFrame) then return end

    local statsView = IsStatsViewShown()
    for _, def in ipairs(DEFS) do
        local btn = buttons[def.key]
        local wanted = def.active() and statsView
        if wanted and not btn then
            btn = def.create()
            buttons[def.key] = btn
            DBG("[CharFrameButtons] created", def.key)
        end
        if btn then
            if wanted then PlaceButton(btn, def.x) end
            btn:SetShown(wanted and true or false)
        end
    end
end

-- Dev helper for /rawchonkyoffset.
function RA.SetChonkyOffset(n)
    chonkyXOffsetBonus = tonumber(n) or chonkyXOffsetBonus
    RA.RefreshCharFrameButtons()
    return chonkyXOffsetBonus
end

------------------------------------------------------------------------
-- Init: wire the refresh to every event that can change its inputs
------------------------------------------------------------------------

local paperDollHooked = false

-- Blizzard_CharacterFrame is load-on-demand; hook its frames once they exist.
local function HookPaperDoll()
    if paperDollHooked or not (PaperDollFrame and CharacterStatsPane) then return end
    paperDollHooked = true
    local function refresh() RA.RefreshCharFrameButtons() end
    -- Panel opened, and Stats pane shown/hidden (view switch by click, addon
    -- or reopen) - the pane's own visibility is what the gate reads.
    PaperDollFrame:HookScript("OnShow", refresh)
    CharacterStatsPane:HookScript("OnShow", refresh)
    CharacterStatsPane:HookScript("OnHide", refresh)
    DBG("[CharFrameButtons] PaperDoll hooked")
end

function RA.InitCharacterFrameButtons()
    HookPaperDoll()
    RA.RefreshCharFrameButtons()

    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_LEVEL_UP")
    f:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 ~= "Blizzard_CharacterFrame"
            and arg1 ~= "Blizzard_ExpansionLandingPage" then
            return
        end
        HookPaperDoll()
        -- UnitLevel can be stale in the same frame as PLAYER_LEVEL_UP, and
        -- Blizzard's own frame setup runs after ADDON_LOADED/loading screens,
        -- so let it settle first.
        C_Timer_After(0.5, function() RA.RefreshCharFrameButtons() end)
    end)
end
