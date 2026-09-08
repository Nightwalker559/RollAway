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
    -- ElvUI sometimes stores its highlight in btn.backdrop; reset to defaults.
    if btn.backdrop then
        local bg, bd = RA.GetElvUIColors()
        btn.backdrop:SetBackdropColor(unpack(bg))
        btn.backdrop:SetBackdropBorderColor(unpack(bd))
    end

    local function ResetBackdrop()
        local bg, bd = RA.GetElvUIColors()
        if btn.SetBackdropColor then
            btn:SetBackdropColor(unpack(bg))
            btn:SetBackdropBorderColor(unpack(bd))
        end
        if btn.backdrop then
            btn.backdrop:SetBackdropColor(unpack(bg))
            btn.backdrop:SetBackdropBorderColor(unpack(bd))
        end
    end

    local function ApplyActive()
        if not btn:IsMouseOver() then
            ResetBackdrop()
        else
            if classColor then
                if btn.SetBackdropColor then
                    btn:SetBackdropColor(classColor.r, classColor.g, classColor.b, 1)
                    btn:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 0)
                end
                if btn.backdrop then
                    btn.backdrop:SetBackdropColor(classColor.r, classColor.g, classColor.b, 1)
                    btn.backdrop:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 0)
                end
            end
        end
        local t = btn:GetFontString()
        if t then t:SetTextColor(GOLD.r, GOLD.g, GOLD.b, 1) end
    end

    local function ApplyInactive()
        ResetBackdrop()
        local t = btn:GetFontString()
        if t then t:SetTextColor(GRAY.r, GRAY.g, GRAY.b, 1) end
    end

    btn.RA_ApplyActive   = ApplyActive
    btn.RA_ApplyInactive = ApplyInactive

    -- HookScript runs after ElvUI's own OnEnter, so our color wins.
    btn:HookScript("OnEnter", function(self)
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
        if tabPanels[key] and tabPanels[key]:IsShown() then
            ApplyActive()
        else
            ApplyInactive()
        end
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
-- Skin Reminder frame
------------------------------------------------------------------------

local function SkinReminderFrame()
    local f = _G["RollAwayReminderFrame"]
    if not f then return end
    if S.HandleFrame then S:HandleFrame(f) end
    -- ElvUI's backdrop child can sit above our directly-parented icon
    -- texture; force the icon's holder frame above it explicitly.
    if f.iconHolder then
        f.iconHolder:SetFrameLevel(f:GetFrameLevel() + 10)
        if f.icon then f.icon:Show() end
    end
    local bar = f.bar
    if bar then
        if S.HandleStatusBar then S:HandleStatusBar(bar) end
        bar:SetStatusBarColor(0.8, 0.7, 0.1, 0.9)
    end
    local okayBtn = _G["RollAwayReminderOkay"]
    if okayBtn and S.HandleButton then S:HandleButton(okayBtn) end
    local optBtn = _G["RollAwayReminderBtn"]
    if optBtn and S.HandleButton then S:HandleButton(optBtn) end
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
-- Skin Paragon frame
------------------------------------------------------------------------

local function SkinParagonFrame()
    local f = _G["RollAwayParagonFrame"]
    if not f then return end
    if S.HandleFrame then S:HandleFrame(f) end
    if f.iconHolder then
        f.iconHolder:SetFrameLevel(f:GetFrameLevel() + 10)
        if f.icon then f.icon:Show() end
    end
    local bar = f.bar
    if bar then
        if S.HandleStatusBar then S:HandleStatusBar(bar) end
        bar:SetStatusBarColor(0.8, 0.7, 0.1, 0.9)
    end
    local okayBtn = _G["RollAwayParagonOkay"]
    if okayBtn and S.HandleButton then S:HandleButton(okayBtn) end
end

------------------------------------------------------------------------
-- Skin Great Vault reminder frame
------------------------------------------------------------------------

local function SkinGreatVaultFrame()
    local f = _G["RollAwayGreatVaultFrame"]
    if not f then return end
    if S.HandleFrame then S:HandleFrame(f) end
    if f.iconHolder then
        f.iconHolder:SetFrameLevel(f:GetFrameLevel() + 10)
        if f.icon then f.icon:Show() end
    end
    local bar = f.bar
    if bar then
        if S.HandleStatusBar then S:HandleStatusBar(bar) end
        bar:SetStatusBarColor(0.8, 0.7, 0.1, 0.9)
    end
    local okayBtn = _G["RollAwayGreatVaultOkay"]
    if okayBtn and S.HandleButton then S:HandleButton(okayBtn) end
end

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
-- Force AceGUI checkboxes to ElvUI's default accent color instead of
-- class color, regardless of the user's own "use class color" setting.
-- ElvUI skins every AceGUI:Create() widget globally via its own hook;
-- this runs after that hook (called last in Options.lua's MakeCB) and
-- overrides the checked-texture's vertex color.
------------------------------------------------------------------------

function RA.ForceCheckboxDefaultColor(cb)
    if not cb then return end
    local color = (E.media and E.media.rgbvaluecolor) or { 0.85, 0.73, 0.25 }
    if cb.check   then cb.check:SetVertexColor(unpack(color)) end
    if cb.checkbg then cb.checkbg:SetVertexColor(1, 1, 1, 1) end
    if cb.frame and cb.frame.SetBackdropBorderColor then
        local bg, bd = RA.GetElvUIColors()
        cb.frame:SetBackdropColor(unpack(bg))
        cb.frame:SetBackdropBorderColor(unpack(bd))
    end
end

-- Same neutralization for sliders (native Blizzard OptionsSliderTemplate or
-- an AceGUI Slider widget's inner .slider frame) - overrides the thumb
-- texture's vertex color back to ElvUI's default accent, not class color.
function RA.ForceSliderDefaultColor(slider)
    if not slider then return end
    local color = (E.media and E.media.rgbvaluecolor) or { 0.85, 0.73, 0.25 }
    local thumb = (slider.GetThumbTexture and slider:GetThumbTexture()) or slider.thumb
    if thumb then thumb:SetVertexColor(unpack(color)) end
    if slider.StatusBar then slider.StatusBar:SetStatusBarColor(unpack(color)) end
end

------------------------------------------------------------------------
-- Apply all skins
-- Reminder/Paragon/WhatsNew are lazy-created, so skinning happens via
-- hooksecurefunc on Show below, not at ADDON_LOADED.
------------------------------------------------------------------------

-- Re-skin reminder frame whenever it is shown
hooksecurefunc(RA, "ShowReminder", function()
    if E.private.skins and E.private.skins.blizzard and E.private.skins.blizzard.enable then
        SkinReminderFrame()
    end
end)

-- Skin Teleport Reminder frame on first show (frame is created lazily)
hooksecurefunc(RA, "ShowTeleportReminder", function()
    if E.private.skins and E.private.skins.blizzard and E.private.skins.blizzard.enable then
        SkinTeleportReminderFrame()
    end
end)

-- Skin Paragon frame on first show (frame is created lazily)
hooksecurefunc(RA, "ShowParagonFrame", function()
    if E.private.skins and E.private.skins.blizzard and E.private.skins.blizzard.enable then
        SkinParagonFrame()
    end
end)

-- Skin Great Vault reminder frame on first show (frame is created lazily)
hooksecurefunc(RA, "ShowGreatVaultFrame", function()
    if E.private.skins and E.private.skins.blizzard and E.private.skins.blizzard.enable then
        SkinGreatVaultFrame()
    end
end)

-- Skin WhatsNew frame on first show (frame is created lazily)
hooksecurefunc(RA, "ShowWhatsNew", function()
    if E.private.skins and E.private.skins.blizzard and E.private.skins.blizzard.enable then
        SkinWhatsNewFrame()
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