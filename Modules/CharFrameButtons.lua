-- RollAway - Modules/CharFrameButtons.lua
-- Omniumfoliant and Great Vault buttons in the bottom-right corner of the Character
-- panel (Stats view only). One idempotent RA.RefreshCharFrameButtons() decides from
-- the current state which buttons show; it is called from a few events (no timers,
-- no cached flags).
-- ElvUI: ElvUI_Skin.lua skins the buttons after each refresh. Chonky Character Sheet:
-- the buttons anchor to CharacterFrameBg and the Stats-only rule is skipped.

local RA       = _G["RollAway"]
local RA_L     = RA.RA_L
local DBG      = RA.DBG
local DBGError = RA.DBGError

local OMNI_ICON_FILEID       = 7554214  -- Omniumfoliant minimap icon
local GREATVAULT_ICON_FILEID = 2744751  -- Great Vault chest icon

-- Extra X nudge while Chonky is loaded (tune live with /rawchonkyoffset).
local chonkyXOffsetBonus = -260

local buttons = {}  -- [key] = button, created lazily

-- State helpers

local function IsChonkyLoaded()
    return C_AddOns.IsAddOnLoaded("ChonkyCharacterSheet")
end

local IsMaxLevel = RA.IsMaxLevel

-- Titles / Equipment Manager use the same corner: buttons only while the Stats pane
-- is visible (Chonky moves the panes elsewhere, so it is exempt).
local function IsStatsViewShown()
    if IsChonkyLoaded() then return true end
    return CharacterStatsPane ~= nil and CharacterStatsPane:IsShown()
end

-- Button factory

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
    -- Diagnostics: only a hide we did not do ourselves that is still in effect
    -- shortly after (OnHide also fires in brief cycles while Blizzard opens the panel).
    btn:HookScript("OnHide", function(self)
        if self.RA_ownHide then return end
        if not (RollAwayDB and (RollAwayDB.debug or RollAwayDB.debugErrorsOnly)) then return end
        local stack = (debugstack(2, 4, 0):gsub("\n", " <- "))
        C_Timer.After(0.5, function()
            if self:IsShown() or not IsStatsViewShown() or not (PaperDollFrame and PaperDollFrame:IsShown()) then return end
            DBGError("[CharFrameButtons]", globalName, "still hidden 0.5s after external hide | stack:", stack)
        end)
    end)
    btn.RA_ownHide = true
    btn:Hide()
    btn.RA_ownHide = nil
    return btn
end

-- Omniumfoliant: hide the minimap icon, offer a Character panel button

local function GetOmniMinimapButton()
    return _G["ExpansionLandingPageMinimapButton"]
end

local function OmniActive()
    return RollAwayDB and RollAwayDB.hideOmniumfoliantMinimap and IsMaxLevel()
end

-- Hide the Blizzard minimap icon? Below max level it is useless (its tooltip errors),
-- so always; at max level the option decides.
local function OmniMinimapHidden()
    return not IsMaxLevel() or (RollAwayDB and RollAwayDB.hideOmniumfoliantMinimap) and true or false
end

-- Hooks the Blizzard minimap button once: hidden while OmniMinimapHidden(), tooltip guarded.
local function SetupOmniMinimapButton()
    local mm = GetOmniMinimapButton()
    if not mm then return nil end
    if mm.RA_hooked then return mm end
    mm.RA_hooked = true

    hooksecurefunc(mm, "Show", function(self)
        if OmniMinimapHidden() then self:Hide() end
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
        -- Blizzard's own tooltip, re-anchored.
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

-- Great Vault: opens WeeklyRewardsFrame

local function VaultActive()
    return RollAwayDB and RollAwayDB.vaultButtonCharFrame and IsMaxLevel()
end

local function ToggleGreatVault()
    C_AddOns.LoadAddOn("Blizzard_WeeklyRewards")
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

-- Refresh

-- key, X offset from the corner (vault left of the Omnium slot), creator, enabled?
local DEFS = {
    { key = "omni",  x = -8,  create = CreateOmniButton,  active = OmniActive  },
    { key = "vault", x = -36, create = CreateVaultButton, active = VaultActive },
}

local lastState = {}  -- [key] = last logged "shown" / "hidden (reason)"

-- Logs only state changes, with reason and trigger (a vanishing button leaves a trace).
local function LogState(key, wanted, featureOn, statsView, source, btn)
    local state
    if wanted then
        state = "shown"
    else
        state = "hidden (" .. (not featureOn and "option off/below max level"
            or not statsView and "not on Stats view" or "?") .. ")"
    end
    if btn and btn:IsShown() ~= (wanted and true or false) then
        state = state .. " [SetShown mismatch]"
    end
    if lastState[key] ~= state then
        lastState[key] = state
        DBGError("[CharFrameButtons]", key, state, "| trigger:", source or "?")
    end
end

local function Apply(source)
    -- Minimap icon: hidden by us while OmniMinimapHidden(), never force-shown.
    local mm = SetupOmniMinimapButton()
    if mm then
        if OmniMinimapHidden() then
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
        local featureOn = def.active() and true or false
        local wanted = featureOn and statsView
        if wanted and not btn then
            btn = def.create()
            buttons[def.key] = btn
            DBG("[CharFrameButtons] created", def.key)
        end
        if btn then
            if wanted then PlaceButton(btn, def.x) end
            btn.RA_ownHide = true
            btn:SetShown(wanted)
            btn.RA_ownHide = nil
        end
        LogState(def.key, wanted, featureOn, statsView, source, btn)
    end
end

-- Sets every button (and the minimap icon) to match options/level/view; safe to call
-- any time. `source` is for the log. Errors are caught and logged, never passed on to
-- Blizzard's OnShow chain.
function RA.RefreshCharFrameButtons(source)
    local ok, err = pcall(Apply, source)
    if not ok then
        DBGError("[CharFrameButtons] ERROR in refresh (", tostring(source), "):", err)
    end
end

-- /rawcharbtn: one line per button with everything that can hide it.
function RA.DescribeCharFrameButtons()
    local out = {}
    for _, def in ipairs(DEFS) do
        local b = buttons[def.key]
        if not b then
            out[#out + 1] = def.key .. ": not created (active=" .. tostring(def.active() and true or false) .. ")"
        else
            local p = b:GetParent()
            local pt, rel, relPt, x, y = b:GetPoint(1)
            local l, bt, w, h = b:GetRect()
            out[#out + 1] = ("%s: shown=%s visible=%s alpha=%.2f eff=%.2f parent=%s(%s) strata=%s lvl=%d size=%dx%d point=%s>%s:%s %s,%s rect=%s,%s,%s,%s"):format(
                def.key, tostring(b:IsShown()), tostring(b:IsVisible()), b:GetAlpha(), b:GetEffectiveAlpha(),
                tostring(p and p:GetName()), tostring(p and p:IsShown()), b:GetFrameStrata(), b:GetFrameLevel(),
                b:GetWidth(), b:GetHeight(), tostring(pt), tostring(rel and rel:GetName()), tostring(relPt),
                tostring(x), tostring(y), tostring(l), tostring(bt), tostring(w), tostring(h))
        end
    end
    return out
end

-- /rawchonkyoffset
function RA.SetChonkyOffset(n)
    chonkyXOffsetBonus = tonumber(n) or chonkyXOffsetBonus
    RA.RefreshCharFrameButtons("chonky offset")
    return chonkyXOffsetBonus
end

-- Init: the refresh runs on every event that can change its inputs

local paperDollHooked = false

-- The Character panel (Blizzard_UIPanels_Game) is always loaded.
local function HookPaperDoll()
    if paperDollHooked or not (PaperDollFrame and CharacterStatsPane) then return end
    paperDollHooked = true
    -- Panel opened, Stats pane shown/hidden.
    PaperDollFrame:HookScript("OnShow", function() RA.RefreshCharFrameButtons("PaperDollFrame OnShow") end)
    CharacterStatsPane:HookScript("OnShow", function() RA.RefreshCharFrameButtons("StatsPane OnShow") end)
    CharacterStatsPane:HookScript("OnHide", function() RA.RefreshCharFrameButtons("StatsPane OnHide") end)
    DBG("[CharFrameButtons] PaperDoll hooked")
end

function RA.InitCharacterFrameButtons()
    HookPaperDoll()
    RA.RefreshCharFrameButtons("init")

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_LEVEL_UP")
    f:SetScript("OnEvent", function(_, event)
        HookPaperDoll()
        -- UnitLevel can be stale on PLAYER_LEVEL_UP, and Blizzard's frame setup follows
        -- loading screens: let it settle.
        C_Timer.After(0.5, function() RA.RefreshCharFrameButtons(event) end)
    end)
end
