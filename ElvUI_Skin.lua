-- RollAway - ElvUI_Skin.lua
-- Optional ElvUI skin. Only active when ElvUI is loaded.

if not ElvUI then return end

local RA = _G["RollAway"]
local E  = unpack(ElvUI)
local S  = E:GetModule("Skins")

------------------------------------------------------------------------
-- Helper: ElvUI backdrop/border colors
------------------------------------------------------------------------

function RA.GetElvUIColors()
    local bg = (E and E.media and E.media.backdropcolor) or {0.1, 0.1, 0.1, 0.8}
    local bd = (E and E.media and E.media.bordercolor)  or {0.1, 0.1, 0.1}
    return bg, bd
end

------------------------------------------------------------------------
-- Tab styling helpers (used by Options.lua)
------------------------------------------------------------------------

local GOLD = { r = 0.85, g = 0.73, b = 0.25 }
local GRAY = { r = 0.5,  g = 0.5,  b = 0.5  }

function RA.ElvSkinTab(btn, tabPanels, key, classColor)
    S:HandleButton(btn)

    btn:SetNormalTexture("")
    btn:SetHighlightTexture("")
    btn:SetPushedTexture("")
    btn:SetDisabledTexture("")

    -- Idle tabs get a background a shade lighter than the panel behind them
    -- so they read as distinct buttons at rest, not just on hover/active.
    local function GetIdleColors()
        local bg, bd = RA.GetElvUIColors()
        local idleBg = {
            math.min((bg[1] or 0.1) + 0.08, 1),
            math.min((bg[2] or 0.1) + 0.08, 1),
            math.min((bg[3] or 0.1) + 0.08, 1),
            bg[4] or 1,
        }
        return idleBg, bd
    end

    local function ResetBackdrop()
        local idleBg, bd = GetIdleColors()
        if btn.SetBackdropColor then
            btn:SetBackdropColor(unpack(idleBg))
            btn:SetBackdropBorderColor(unpack(bd))
        end
        if btn.backdrop then
            btn.backdrop:SetBackdropColor(unpack(idleBg))
            btn.backdrop:SetBackdropBorderColor(unpack(bd))
        end
    end
    ResetBackdrop()

    local ApplyActive, ApplyInactive

    ApplyActive = function()
        -- Disabled tabs (season tabs while debug mode is off - see
        -- OptionsHelpers.lua MakeSeasonTabs) never get the active tint/
        -- border since they're not actually selectable, but they still
        -- show which season is current via the gold text.
        if btn.IsEnabled and not btn:IsEnabled() then
            ResetBackdrop()
            local t = btn:GetFontString()
            if t then t:SetTextColor(GOLD.r, GOLD.g, GOLD.b, 1) end
            return
        end
        -- Always tinted while active, not only on hover; hover (below) then
        -- brightens it further via full-alpha classColor.
        if classColor then
            if btn.SetBackdropColor then
                btn:SetBackdropColor(classColor.r, classColor.g, classColor.b, btn:IsMouseOver() and 1 or 0.35)
                btn:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
            end
            if btn.backdrop then
                btn.backdrop:SetBackdropColor(classColor.r, classColor.g, classColor.b, btn:IsMouseOver() and 1 or 0.35)
                btn.backdrop:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
            end
        else
            ResetBackdrop()
        end
        local t = btn:GetFontString()
        if t then t:SetTextColor(GOLD.r, GOLD.g, GOLD.b, 1) end
    end

    ApplyInactive = function()
        ResetBackdrop()
        local t = btn:GetFontString()
        if t then t:SetTextColor(GRAY.r, GRAY.g, GRAY.b, 1) end
    end

    btn.RA_ApplyActive   = ApplyActive
    btn.RA_ApplyInactive = ApplyInactive

    -- Re-applies the correct style for the tab's current active/inactive
    -- state - used after Enable()/Disable() toggles (debug checkbox) where
    -- nothing else would trigger a redraw until the next hover.
    btn.RA_Refresh = function()
        if tabPanels[key] and tabPanels[key]:IsShown() then
            ApplyActive()
        else
            ApplyInactive()
        end
    end

    -- HookScript runs after ElvUI's own OnEnter, so our color wins.
    btn:HookScript("OnEnter", function(self)
        if self.IsEnabled and not self:IsEnabled() then return end
        if classColor then
            if self.SetBackdropColor then
                self:SetBackdropColor(classColor.r, classColor.g, classColor.b, 1)
                self:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 0)
            end
            if self.backdrop then
                self.backdrop:SetBackdropColor(classColor.r, classColor.g, classColor.b, 1)
                self.backdrop:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 0)
            end
        end
        local t = self:GetFontString()
        if t then t:SetTextColor(GOLD.r, GOLD.g, GOLD.b, 1) end
    end)

    btn:HookScript("OnLeave", function(self)
        self.RA_Refresh()
    end)
end

------------------------------------------------------------------------
-- Skin WhatsNew frame
------------------------------------------------------------------------

local function SkinWhatsNewFrame()
    local f = _G["RollAwayWhatsNewFrame"]
    if not f then return end
    if S.HandleFrame then S:HandleFrame(f) end
    local okayBtn = _G["RollAwayWhatsNewOkay"]
    if okayBtn and S.HandleButton then S:HandleButton(okayBtn) end
end

------------------------------------------------------------------------
-- Skin popup frames built on RA.CreatePopupFrame (Reminder, Paragon,
-- GreatVault, AdvLog). Called directly from CreatePopupFrame itself right
-- after construction - not via hooksecurefunc on each module's own Show
-- function, since that pattern requires every caller to route through the
-- RA.table field consistently (a local-upvalue slip breaks it silently,
-- as happened with the AdvLog reminder). One call site, no such pitfall.
------------------------------------------------------------------------

function RA.SkinPopupFrame(frame)
    if not (E.private.skins and E.private.skins.blizzard and E.private.skins.blizzard.enable) then return end
    if S.HandleFrame then S:HandleFrame(frame) end
    -- ElvUI's backdrop child can sit above our directly-parented icon
    -- texture; force the icon's holder frame above it explicitly.
    if frame.iconHolder then
        frame.iconHolder:SetFrameLevel(frame:GetFrameLevel() + 10)
        if frame.icon then frame.icon:Show() end
    end
    if frame.bar then
        if S.HandleStatusBar then S:HandleStatusBar(frame.bar) end
        frame.bar:SetStatusBarColor(0.8, 0.7, 0.1, 0.9)
    end
    if frame.okayBtn and S.HandleButton then S:HandleButton(frame.okayBtn) end
end

-- For any extra button a caller adds to a popup frame after CreatePopupFrame
-- already returned (e.g. Reminder.lua's "Options" button) - same skin, on
-- demand, called right where the button is created.
function RA.SkinPopupButton(btn)
    if not btn then return end
    if not (E.private.skins and E.private.skins.blizzard and E.private.skins.blizzard.enable) then return end
    if S.HandleButton then S:HandleButton(btn) end
end

------------------------------------------------------------------------
-- Skin Teleport Reminder frame
------------------------------------------------------------------------

local function SkinTeleportReminderFrame()
    local f = _G["RollAwayTeleportReminderFrame"]
    if not f then return end
    if S.HandleFrame then S:HandleFrame(f) end
    if S.HandleCloseButton then
        local closeBtn = _G["RollAwayTeleportReminderClose"]
        if closeBtn then S:HandleCloseButton(closeBtn) end
    end
end

------------------------------------------------------------------------
-- Skin Portal Overview frame (own-frame Mythic+ portal picker, RA.ShowPortalOverview)
------------------------------------------------------------------------

local function SkinPortalOverviewFrame()
    local f = _G["RollAwayPortalOverviewFrame"]
    if not f or f.RA_ElvSkinned then return end
    if S.HandleFrame then S:HandleFrame(f) end
    if S.HandleCloseButton then
        local closeBtn = _G["RollAwayPortalOverviewClose"]
        if closeBtn then S:HandleCloseButton(closeBtn) end
    end
    for i = 1, (f.numTabs or 0) do
        local tab = _G[f:GetName().."Tab"..i]
        if tab and S.HandleTab then S:HandleTab(tab) end
    end
    -- S:HandleTab only reskins the button (flat backdrop instead of the
    -- Blizzard tab texture); it doesn't touch anchoring. Re-anchor here so
    -- the ElvUI-skinned tabs sit correctly - ElvUI insets the tab backdrop
    -- by 5px on Retail (10px on other clients), so tabs need a matching
    -- negative gap to butt up against each other instead of the wider
    -- Blizzard-style gap set in PortalOverview.lua.
    local offset = E.Retail and -5 or -19
    local prevTab
    for i = 1, (f.numTabs or 0) do
        local tab = _G[f:GetName().."Tab"..i]
        if tab then
            if prevTab then
                tab:ClearAllPoints()
                tab:SetPoint("TOPLEFT", prevTab, "TOPRIGHT", offset, 0)
            end
            prevTab = tab
        end
    end
    -- Scrollbar is force-hidden in PortalOverview.lua (mouse-wheel scroll
    -- only), so there's nothing to skin there.
    f.RA_ElvSkinned = true
end

------------------------------------------------------------------------
-- Skin Debug Log window (dev-only, /rawlog)
------------------------------------------------------------------------

local function SkinDebugLogFrame()
    local f = _G["RollAwayDebugLogFrame"]
    if not f or f.RA_ElvSkinned then return end
    if S.HandleFrame then S:HandleFrame(f) end

    local scrollBar = _G["RollAwayDebugLogScrollScrollBar"]
    if scrollBar and S.HandleScrollBar then S:HandleScrollBar(scrollBar) end

    local editBox = _G["RollAwayDebugLogEditBox"]
    if editBox and S.HandleEditBox then S:HandleEditBox(editBox) end

    local closeBtn = _G["RollAwayDebugLogClose"]
    if closeBtn and S.HandleCloseButton then S:HandleCloseButton(closeBtn) end

    local selectAllBtn = _G["RollAwayDebugLogSelectAll"]
    if selectAllBtn and S.HandleButton then S:HandleButton(selectAllBtn) end

    local clearBtn = _G["RollAwayDebugLogClear"]
    if clearBtn and S.HandleButton then S:HandleButton(clearBtn) end

    f.RA_ElvSkinned = true
end

-- AppendDebugLog fires on every log line; SkinDebugLogFrame's guard above
-- keeps this a no-op after the first (lazy-created) call.
hooksecurefunc(RA, "AppendDebugLog", function()
    if E.private.skins and E.private.skins.blizzard and E.private.skins.blizzard.enable then
        SkinDebugLogFrame()
    end
end)

------------------------------------------------------------------------
-- Skin Omniumfoliant / Great Vault CharacterFrame buttons
------------------------------------------------------------------------

local function SkinCharFrameButton(globalName)
    local btn = _G[globalName]
    if not btn or btn.RA_ElvSkinned then return end
    if S.HandleButton then S:HandleButton(btn) end
    -- HandleButton alone doesn't strip the manually-set Quickslot textures;
    -- clear them so ElvUI's backdrop/border shows instead of the default one.
    btn:SetNormalTexture("")
    btn:SetPushedTexture("")
    btn:SetHighlightTexture("")
    btn.RA_ElvSkinned = true
end

local function SkinOmniumfoliantButton()
    SkinCharFrameButton("RollAwayOmniumfoliantButton")
end

local function SkinVaultButton()
    SkinCharFrameButton("RollAwayVaultButton")
end

------------------------------------------------------------------------
-- No checkbox/slider color forcing anymore. Both attempts (fixed accent,
-- then real class color) fought ElvUI's own AceGUI skin hook unreliably.
-- Left as plain ElvUI-native styling now, matching what ElvUI does by
-- default for every other addon's options.
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Apply remaining skins
-- Reminder/Paragon/GreatVault/AdvLog are skinned directly inside
-- RA.CreatePopupFrame (see RA.SkinPopupFrame above) - no hook needed here.
-- TeleportReminder/WhatsNew use a different frame shape, so they still get
-- their own hook.
------------------------------------------------------------------------

-- Skin Teleport Reminder frame on first show (frame is created lazily)
hooksecurefunc(RA, "ShowTeleportReminder", function()
    if E.private.skins and E.private.skins.blizzard and E.private.skins.blizzard.enable then
        SkinTeleportReminderFrame()
    end
end)

-- Skin WhatsNew frame on first show (frame is created lazily)
hooksecurefunc(RA, "ShowWhatsNew", function()
    if E.private.skins and E.private.skins.blizzard and E.private.skins.blizzard.enable then
        SkinWhatsNewFrame()
    end
end)

-- Skin Portal Overview frame on first show (frame is created lazily)
hooksecurefunc(RA, "ShowPortalOverview", function()
    if E.private.skins and E.private.skins.blizzard and E.private.skins.blizzard.enable then
        SkinPortalOverviewFrame()
    end
end)

-- Buttons are lazy-created by QoL.lua; skinned-once guard avoids re-skinning
-- on every toggle.
hooksecurefunc(RA, "ApplyOmniumfoliantFeature", function()
    if E.private.skins and E.private.skins.blizzard and E.private.skins.blizzard.enable then
        SkinOmniumfoliantButton()
    end
end)

hooksecurefunc(RA, "ApplyVaultButtonFeature", function()
    if E.private.skins and E.private.skins.blizzard and E.private.skins.blizzard.enable then
        SkinVaultButton()
    end
end)