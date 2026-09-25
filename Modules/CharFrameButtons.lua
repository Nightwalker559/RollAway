-- RollAway - Modules/CharFrameButtons.lua
-- Omniumfoliant and Great Vault buttons anchored to CharacterFrame's
-- bottom-right corner. Extracted from QoL.lua into its own file so the
-- three UI compatibility layers (Default UI, ElvUI, Chonky Character Sheet)
-- are easy to find and reason about separately.
--
-- Layer overview:
--   - Default UI: buttons anchor to the real CharacterFrame corner (see
--     GetCharFrameButtonAnchor below).
--   - ElvUI: no special anchoring needed here - ElvUI_Skin.lua re-skins the
--     buttons (backdrop/border/textures) via hooksecurefunc on
--     RA.ApplyOmniumfoliantFeature / RA.ApplyVaultButtonFeature, once they're
--     created below. Nothing in this file needs to know ElvUI is present.
--   - Chonky Character Sheet: see the "Chonky compat" section - it doesn't
--     resize the real CharacterFrame, only pushes CharacterFrameBg out via
--     its own "hpad" option, so we anchor to CharacterFrameBg instead when
--     Chonky is loaded, and Chonky's Titles/Equipment Manager panes don't
--     overlap our corner, so the Stats-only tab restriction is skipped too.

local RA       = _G["RollAway"]
local RA_L     = RA.RA_L
local DBG      = RA.DBG
local DBGError = RA.DBGError

local C_Timer_After    = RA.C_Timer_After

local omniCharButton
local vaultCharButton

------------------------------------------------------------------------
-- Chonky Character Sheet compat
------------------------------------------------------------------------
-- Chonky doesn't actually resize the real CharacterFrame - only
-- CharacterFrameBg (a reference/background frame) gets pushed right via its
-- own "hpad" option (CharacterFrameBg:SetPoint("BOTTOMRIGHT", CharacterFrame,
-- "BOTTOMRIGHT", hpad+65, 0) in Chonky's characterSheet.lua). Chonky itself
-- re-anchors its own close button to CharacterFrameBg for the same reason.
-- Anchoring our buttons there too means they track any future hpad change
-- automatically - no guessed pixel offset needed for the base position.
------------------------------------------------------------------------

local function IsChonkyLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded("ChonkyCharacterSheet")
end
RA.IsChonkyLoaded = IsChonkyLoaded

local function GetCharFrameButtonAnchor()
    if IsChonkyLoaded() and _G["CharacterFrameBg"] then
        return _G["CharacterFrameBg"]
    end
    return CharacterFrame -- Default UI (and anything else): real CharacterFrame corner
end

-- Extra rightward nudge on top of the anchor-frame fix above, only applied
-- when Chonky is loaded (never touches Default UI/other-skin positioning).
-- Default confirmed via live testing (/rawchonkyoffset). Adjust the same way
-- if a future Chonky update shifts CharacterFrameBg differently.
local chonkyXOffsetBonus = -260

-- Guards every self-heal entry point below (watchdog tick, OnShow hooks,
-- spec-change reapply) against a stray Lua error. Without this, a single
-- error thrown inside ReapplyCharFrameButtons (e.g. a transient nil from
-- ElvUI or another addon reacting to the same event) stops the watchdog's
-- self-rescheduling C_Timer_After chain permanently for that session - the
-- buttons then stay gone until /reload, matching reports of them vanishing
-- "randomly" only with certain addon combos (e.g. ElvUI) active.
local function SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        DBGError("[CharFrameButtons] self-heal error (caught, continuing):", err)
    end
    return ok
end

-- Full self-heal for one button: some external UI code (combat-log driven
-- PaperDollFrame redraws, other addons enumerating/hiding "unknown" children,
-- etc.) has been observed to leave the button's frame object intact but with
-- its parent, strata, or anchor points reset/invalidated. A plain :Show()
-- on such a button does nothing visible, which is why toggling the option
-- off/on in Settings previously failed to bring it back (only /reload, which
-- recreates everything from scratch, fixed it). Re-asserting parent/strata/
-- level/points every time - not just Show() - makes this self-correcting.
local function HealCharFrameButton(btn, xOffset)
    if not btn or not PaperDollFrame then return end
    local anchor = GetCharFrameButtonAnchor()
    local bonus = IsChonkyLoaded() and chonkyXOffsetBonus or 0
    if btn:GetParent() ~= PaperDollFrame then
        btn:SetParent(PaperDollFrame)
        DBG("[CharFrameButtons]", btn:GetName(), "reparented back to PaperDollFrame (was detached)")
    end
    btn:SetFrameStrata("DIALOG")
    btn:SetFrameLevel(PaperDollFrame:GetFrameLevel() + 10)
    btn:ClearAllPoints()
    btn:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", xOffset + bonus, 8)
end

local function RepositionCharFrameButtons()
    if omniCharButton then HealCharFrameButton(omniCharButton, -8) end
    if vaultCharButton then HealCharFrameButton(vaultCharButton, -36) end
end
RA.RepositionCharFrameButtons = RepositionCharFrameButtons

function RA.SetChonkyOffset(n)
    chonkyXOffsetBonus = tonumber(n) or chonkyXOffsetBonus
    RepositionCharFrameButtons()
    DBG("[CharFrameButtons] Chonky button offset bonus set to", chonkyXOffsetBonus)
    return chonkyXOffsetBonus
end

------------------------------------------------------------------------
-- Sidebar tab gating (Default UI)
------------------------------------------------------------------------
-- Titles/Equipment Manager are sub-views of the Character tab (PaperDollFrame
-- stays shown for all three), so on Default UI we only show the buttons on
-- Stats to avoid overlapping those panes' own bottom-right content.
-- Chonky Character Sheet repositions Titles/Equipment Manager into its own
-- panes elsewhere in the frame (not near our corner), so this restriction
-- doesn't apply there - see the IsChonkyLoaded() bypass below.
------------------------------------------------------------------------

local statsTabActive = true  -- Stats is the default sub-view on open

-- Query the sidebar tabs' live checked state instead of relying only on our
-- own click-tracked flag. Bug (Default UI): closing the panel while on
-- Titles/Equipment and reopening on Stats never fires a fresh OnClick on
-- tab1, so a click-tracked flag can go stale. Reading GetChecked() directly
-- is always correct, regardless of how the panel got back to the Stats view.
local function CharFrameButtonsAllowed()
    if IsChonkyLoaded() then return true end
    if PaperDollSidebarTab1 and PaperDollSidebarTab1.GetChecked then
        return PaperDollSidebarTab1:GetChecked() and true or false
    end
    return statsTabActive
end

local sidebarHooked = false
local function HookPaperDollSidebarTabs()
    if sidebarHooked then return end
    local tab1, tab2, tab3 = PaperDollSidebarTab1, PaperDollSidebarTab2, PaperDollSidebarTab3
    if not (tab1 and tab2 and tab3) then return end

    local function OnTabClicked(tabIndex)
        return function()
            statsTabActive = (tabIndex == 1)
            RA.ApplyOmniumfoliantFeature()
            RA.ApplyVaultButtonFeature()
        end
    end

    tab1:HookScript("OnClick", OnTabClicked(1))
    tab2:HookScript("OnClick", OnTabClicked(2))
    tab3:HookScript("OnClick", OnTabClicked(3))
    sidebarHooked = true
    DBG("[CharFrameButtons] PaperDoll sidebar tabs hooked for Omnium/Vault button gating")
end

------------------------------------------------------------------------
-- Shared button factory
------------------------------------------------------------------------

-- Shared factory for the icon buttons anchored to CharacterFrame's bottom-right
-- corner (Omniumfoliant, Great Vault). Both buttons are visually and
-- structurally identical, only differing in icon/position/click/tooltip.
-- ElvUI skinning is applied afterward by ElvUI_Skin.lua, not here.
local function CreateCharFrameIconButton(globalName, xOffset, iconFileID, debugLabel, onClick, onEnter)
    -- Parented to PaperDollFrame, not CharacterFrame (shown on every tab),
    -- so the button only leaks onto Character, not Reputation/Currencies/etc.
    if not PaperDollFrame then return nil end
    HookPaperDollSidebarTabs()

    local btn = CreateFrame("Button", globalName, PaperDollFrame)
    btn:SetSize(24, 24)
    -- Anchored to CharacterFrame (or CharacterFrameBg under Chonky, see
    -- above) rather than PaperDollFrame: CharacterFrame_Expand() widens
    -- CharacterFrame itself when the stats pane is shown (default state),
    -- while PaperDollFrame stays at its narrower width. Anchoring here keeps
    -- the button at the frame's actual visible corner instead of getting
    -- buried under the stats/item-slot column.
    local anchor = GetCharFrameButtonAnchor()
    local bonus = IsChonkyLoaded() and chonkyXOffsetBonus or 0
    btn:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", xOffset + bonus, 8)
    btn:SetFrameStrata("DIALOG")
    btn:SetFrameLevel(PaperDollFrame:GetFrameLevel() + 10)

    btn:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    btn:GetNormalTexture():SetAllPoints()
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexture(iconFileID)
    btn.icon = icon

    btn:SetScript("OnClick", onClick)
    btn:SetScript("OnEnter", onEnter)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Child of PaperDollFrame: follows Character-tab Show/Hide automatically.
    btn:Show()
    DBG("[CharFrameButtons]", debugLabel, "CharacterFrame button created")
    return btn
end

------------------------------------------------------------------------
-- Omniumfoliant button
-- Works with Default UI and ElvUI alike (ElvUI not required since 2.6.0).
------------------------------------------------------------------------

local function GetOmniMinimapButton()
    return _G["ExpansionLandingPageMinimapButton"]
end

local function OmniumfoliantAllowed()
    -- Blizzard's tooltip errors pre-max-level (no landing page data yet).
    return RA.IsMaxLevel and RA.IsMaxLevel()
end

local OMNI_ICON_FILEID = 7554214  -- current Omniumfoliant minimap icon

local function CreateOmniCharButton()
    if omniCharButton then return omniCharButton end
    omniCharButton = CreateCharFrameIconButton(
        "RollAwayOmniumfoliantButton", -8, OMNI_ICON_FILEID, "Omniumfoliant",
        function()
            local btn = GetOmniMinimapButton()
            if btn then btn:Click() end
        end,
        -- Reuse Blizzard's own tooltip text (correctly localized), just re-anchor it.
        function(self)
            local btn = GetOmniMinimapButton()
            local onEnter = btn and btn:GetScript("OnEnter")
            if onEnter then
                onEnter(btn)
                GameTooltip:ClearAllPoints()
                GameTooltip:SetPoint("BOTTOMRIGHT", self, "TOPLEFT", 0, 4)
            else
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText("Omniumfoliant")
                GameTooltip:Show()
            end
        end
    )
    return omniCharButton
end

local function ApplyOmniumfoliantFeature()
    local btn = GetOmniMinimapButton()
    if not btn then return false end

    if not btn.RA_hooked then
        hooksecurefunc(btn, "Show", function(self)
            if RollAwayDB and RollAwayDB.hideOmniumfoliantMinimap and OmniumfoliantAllowed() then
                self:Hide()
            end
        end)
        btn.RA_hooked = true
    end

    if not btn.RA_tooltipGuarded then
        -- Blizzard's SetTooltip errors pre-max-level; wrap OnEnter to skip it.
        local origOnEnter = btn:GetScript("OnEnter")
        if origOnEnter then
            btn:SetScript("OnEnter", function(self)
                if OmniumfoliantAllowed() then
                    origOnEnter(self)
                end
            end)
        end
        btn.RA_tooltipGuarded = true
    end

    local active = RollAwayDB and RollAwayDB.hideOmniumfoliantMinimap and OmniumfoliantAllowed()
    if active then
        btn:Hide()
        btn.RA_forceHidden = true
        CreateOmniCharButton()
        if omniCharButton then
            HealCharFrameButton(omniCharButton, -8)
            if CharFrameButtonsAllowed() then
                omniCharButton:Show()
            else
                omniCharButton:Hide()
            end
        end
    else
        -- Only undo our own Hide(); never force-show, Blizzard controls default visibility.
        if btn.RA_forceHidden then
            btn:Show()
            btn.RA_forceHidden = false
        end
        if omniCharButton then omniCharButton:Hide() end
    end
    return true
end
RA.ApplyOmniumfoliantFeature = ApplyOmniumfoliantFeature

function RA.InitOmniumfoliant()
    local function TryInit(attempt)
        attempt = attempt or 1
        if ApplyOmniumfoliantFeature() then
            DBG("[CharFrameButtons] Omniumfoliant button hooked (attempt "..attempt..")")
            return
        end
        if attempt >= 10 then
            DBG("[CharFrameButtons] Omniumfoliant minimap button not found after", attempt, "attempts")
            return
        end
        if C_Timer_After then
            C_Timer_After(1, function() TryInit(attempt + 1) end)
        end
    end
    TryInit()
end

------------------------------------------------------------------------
-- Great Vault button - opens WeeklyRewardsFrame directly.
-- Works with Default UI and ElvUI alike (ElvUI not required since 2.6.0).
------------------------------------------------------------------------

local GREATVAULT_ICON_FILEID = 2744751  -- current Great Vault chest icon

local function GreatVaultButtonAllowed()
    -- Vault is irrelevant pre-max-level; keep consistent with Omniumfoliant gating.
    return RA.IsMaxLevel and RA.IsMaxLevel()
end

local function OpenGreatVault()
    if C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("Blizzard_WeeklyRewards")
    end
    if not WeeklyRewardsFrame then return end
    if WeeklyRewardsFrame:IsShown() then
        WeeklyRewardsFrame:Hide()
    else
        WeeklyRewardsFrame:Show()
    end
end

local function CreateVaultCharButton()
    if vaultCharButton then return vaultCharButton end
    -- Fixed slot to the left of the Omniumfoliant button's slot (-8) –
    -- independent of whether that button actually exists.
    vaultCharButton = CreateCharFrameIconButton(
        "RollAwayVaultButton", -36, GREATVAULT_ICON_FILEID, "Great Vault",
        OpenGreatVault,
        function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(RA_L["qol_vault_button_tooltip"])
            GameTooltip:Show()
        end
    )
    return vaultCharButton
end

local function ApplyVaultButtonFeature()
    local active = RollAwayDB and RollAwayDB.vaultButtonCharFrame and GreatVaultButtonAllowed()
    if active then
        CreateVaultCharButton()
        if vaultCharButton then
            HealCharFrameButton(vaultCharButton, -36)
            if CharFrameButtonsAllowed() then
                vaultCharButton:Show()
            else
                vaultCharButton:Hide()
            end
        end
    else
        if vaultCharButton then vaultCharButton:Hide() end
    end
end
RA.ApplyVaultButtonFeature = ApplyVaultButtonFeature

------------------------------------------------------------------------
-- Reapply / watchdog / spec-change orchestration (shared by both buttons)
------------------------------------------------------------------------

-- Blizzard_CharacterFrame (PaperDollFrame) is load-on-demand and typically isn't
-- loaded yet at InitQoL() (login). ApplyOmniumfoliantFeature() still reports success
-- at that point because it only checks the minimap button, so CreateOmniCharButton()/
-- CreateVaultCharButton() fail silently and nothing retries until the next zone or
-- level-up. Re-apply as soon as the Character panel addon actually loads.
local function ReapplyCharFrameButtons()
    -- Each wrapped separately so one feature erroring doesn't block the other.
    SafeCall(RA.ApplyOmniumfoliantFeature)
    SafeCall(RA.ApplyVaultButtonFeature)
end

-- Self-rescheduling watchdog: as long as CharacterFrame stays open, keep
-- forcing the buttons back every second. This is a safety net for cases
-- where neither OnShow hook below fires (e.g. Blizzard toggling internal
-- sub-frames without a fresh Show(), or something external wiping the
-- buttons while the panel is already open) - buttons self-heal instead of
-- staying gone until the next open/close cycle.
local charFrameWatchdogRunning  = false
local charFrameWatchdogLastTick = 0

-- How long a heartbeat can go quiet before StartCharFrameWatchdog() treats
-- the tick chain as dead and restarts it anyway. Covers a desync where
-- charFrameWatchdogRunning never gets reset to false even though the
-- C_Timer_After chain itself silently stopped (e.g. a callback dropped
-- across a loading screen/zone change while the panel was open) - a plain
-- boolean guard alone would then refuse to ever restart it, matching
-- reports of buttons staying gone with no error logged at all.
local WATCHDOG_STALE_SECONDS = 3

local function CharFrameWatchdogTick()
    charFrameWatchdogLastTick = GetTime()
    if not (CharacterFrame and CharacterFrame:IsShown()) then
        charFrameWatchdogRunning = false
        return
    end
    SafeCall(ReapplyCharFrameButtons)
    -- Rescheduling always happens, even if the reapply above errored, so the
    -- watchdog itself can never die mid-session.
    if C_Timer_After then
        C_Timer_After(1, CharFrameWatchdogTick)
    else
        charFrameWatchdogRunning = false
    end
end
local function StartCharFrameWatchdog()
    if charFrameWatchdogRunning and (GetTime() - charFrameWatchdogLastTick) < WATCHDOG_STALE_SECONDS then
        return
    end
    charFrameWatchdogRunning = true
    CharFrameWatchdogTick()
end

-- Debug/test helpers (see /rawcharwatchdog in Debug.lua): let a dev force
-- the exact desync above - flag stuck "running" but heartbeat stale -
-- without needing a real Lua error or a natural loading-screen repro.
function RA.DebugBreakCharFrameWatchdog()
    charFrameWatchdogRunning  = true
    charFrameWatchdogLastTick = GetTime() - (WATCHDOG_STALE_SECONDS + 1)
    DBG("[CharFrameButtons] Watchdog forcibly marked stale for testing (running=true, heartbeat backdated)")
end

function RA.DebugCharFrameWatchdogState()
    return charFrameWatchdogRunning, charFrameWatchdogLastTick, GetTime() - charFrameWatchdogLastTick
end

local charFrameShowHooked = false
local specChangeHooked = false

local function DebugLogCharFrameButtonState(context)
    DBG("[CharFrameButtons] CharFrame button check:", context,
        "| CharacterFrame shown:", CharacterFrame and CharacterFrame:IsShown(),
        "| omni shown:", omniCharButton and omniCharButton:IsShown(),
        "| omni parent:", omniCharButton and omniCharButton:GetParent() and omniCharButton:GetParent():GetName(),
        "| vault shown:", vaultCharButton and vaultCharButton:IsShown(),
        "| vault parent:", vaultCharButton and vaultCharButton:GetParent() and vaultCharButton:GetParent():GetName())
end

local function HookSpecChangeReapply()
    -- Some third-party CharacterFrame skins (e.g. Chonky Character Sheet) redraw
    -- their overlay on spec change and, in doing so, appear to wipe unknown
    -- child buttons of PaperDollFrame - our Omnium/Vault buttons vanish even
    -- though CharacterFrame itself stays open (watchdog alone doesn't catch
    -- this if it only re-parents/hides without ever hiding CharacterFrame).
    -- Small delay lets the third-party redraw finish first, so our reapply
    -- isn't immediately undone by it.
    if specChangeHooked then return end
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:SetScript("OnEvent", function()
        DebugLogCharFrameButtonState("before spec-change reapply")
        if C_Timer_After then
            C_Timer_After(0.2, function()
                SafeCall(ReapplyCharFrameButtons)
                DebugLogCharFrameButtonState("after spec-change reapply")
            end)
        else
            SafeCall(ReapplyCharFrameButtons)
        end
    end)
    specChangeHooked = true
    DBG("[CharFrameButtons] PLAYER_SPECIALIZATION_CHANGED hooked for Omnium/Vault button gating")
end

local function HookCharFrameReapply()
    -- Belt-and-suspenders: re-apply every time the Character panel is opened,
    -- not just on login/zone/level-up. Covers any case where Blizzard resets
    -- button state between those events (e.g. portal use) without us knowing.
    -- Cheap and idempotent, so safe to run on every single OnShow.
    if charFrameShowHooked or not PaperDollFrame then return end
    PaperDollFrame:HookScript("OnShow", function()
        SafeCall(ReapplyCharFrameButtons)
        SafeCall(StartCharFrameWatchdog)
    end)
    -- Also hook CharacterFrame itself: PaperDollFrame's OnShow doesn't
    -- necessarily refire on every CharacterFrame open (e.g. reopening on a
    -- tab that was already the active one), so this is a second entry point
    -- into the same reapply/watchdog logic.
    if CharacterFrame then
        CharacterFrame:HookScript("OnShow", function()
            SafeCall(ReapplyCharFrameButtons)
            SafeCall(StartCharFrameWatchdog)
        end)
    end
    charFrameShowHooked = true
end

function RA.InitCharacterFrameButtons()
    -- RA.ApplyOmniumfoliantFeature / RA.ApplyVaultButtonFeature (not the local
    -- upvalues) since ApplyVaultButtonFeature is only declared later in this file;
    -- both RA fields are populated by the time this ever runs.
    --
    -- NOTE: C_AddOns.IsAddOnLoaded("Blizzard_CharacterFrame") is unreliable here -
    -- it can still report false for a brief window even after PaperDollFrame
    -- already exists (confirmed via live testing), which caused this function to
    -- take the "not loaded yet" branch and register an ADDON_LOADED listener that
    -- then never fires (the event already fired before we listened). Result:
    -- HookCharFrameReapply() never runs, so OnShow hooks/watchdog never attach,
    -- and buttons silently stop self-healing - intermittently, based on addon
    -- load-order timing. Check PaperDollFrame's existence directly instead, and
    -- ALWAYS also register the ADDON_LOADED listener as a fallback for the case
    -- where PaperDollFrame genuinely isn't loaded yet. HookCharFrameReapply()
    -- guards against being hooked twice, so calling it from both paths is safe.
    if PaperDollFrame then
        SafeCall(ReapplyCharFrameButtons)
        HookCharFrameReapply()
        HookSpecChangeReapply()
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, loadedAddon)
        if loadedAddon == "Blizzard_CharacterFrame" then
            SafeCall(ReapplyCharFrameButtons)
            HookCharFrameReapply()
            HookSpecChangeReapply()
            self:UnregisterAllEvents()
        end
    end)
end
