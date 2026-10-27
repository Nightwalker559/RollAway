-- RollAway - Core/ElvUI_Skin.lua
-- ElvUI skin for RollAway's own frames. Every ElvUI call lives here: Helpers.lua defines
-- RA.Skin as a table of no-ops, and with ElvUI loaded the functions below replace them,
-- so the rest of the addon just calls RA.Skin.<Name>(widget) after creating a widget.
-- All of them follow ElvUI's "Blizzard skins" switch (off = the game's own look).

if not ElvUI then return end

local RA   = _G["RollAway"]
local E    = unpack(ElvUI)
local S    = E:GetModule("Skins")
local Skin = RA.Skin

local GOLD = RA.OptionsUI.GOLD
local GRAY = RA.OptionsUI.GRAY

local function Enabled()
    local skins = E.private and E.private.skins
    return skins and skins.blizzard and skins.blizzard.enable and true or false
end

-- S:<method>(obj, ...) if skins are on, the object exists and this ElvUI has the method.
local function Handle(method, obj, ...)
    if obj and Enabled() and S[method] then S[method](S, obj, ...) end
end

------------------------------------------------------------------------
-- Windows and widgets
------------------------------------------------------------------------

-- Window from RA.CreatePanelWindow / popups: flat ElvUI frame, its close button included.
function Skin.Window(frame) Handle("HandleFrame", frame) end

function Skin.Button(btn)    Handle("HandleButton", btn) end
function Skin.CheckBox(box)  Handle("HandleCheckBox", box) end
function Skin.EditBox(box)   Handle("HandleEditBox", box) end
function Skin.ScrollBar(bar) Handle("HandleTrimScrollBar", bar) end

-- Resize corner like ElvUI's own config window: its arrow texture turned towards the
-- bottom right corner, light gray, gold while hovered.
function Skin.ResizeGrip(grip)
    if not grip or not Enabled() or not E.Media.Textures.ArrowUp then return end
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
        local tex = grip[getter](grip)
        if tex then tex:SetAlpha(0) end
    end
    grip:SetSize(24, 24)
    grip:ClearAllPoints()
    grip:SetPoint("BOTTOMRIGHT", grip:GetParent(), "BOTTOMRIGHT", 1, -1)
    grip:SetFrameLevel(grip:GetParent():GetFrameLevel() + 20)

    local arrow = grip:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture(E.Media.Textures.ArrowUp)
    arrow:SetRotation(-2.35)
    arrow:SetAllPoints()
    arrow:SetVertexColor(1, 1, 1, 0.8)
    grip:HookScript("OnEnter", function() arrow:SetVertexColor(1, 0.82, 0, 1) end)
    grip:HookScript("OnLeave", function() arrow:SetVertexColor(1, 1, 1, 0.8) end)
end

-- MinimalSliderWithSteppersTemplate in ElvUI's own slider look (the one of its options):
-- thin dark track, small gold thumb, no stepper arrows. The track keeps the template's
-- 19px side margins, the value label (TopText) sits right above it.
function Skin.StepSlider(frame)
    if not Enabled() then return end
    local bar = frame.Slider
    if not bar then return end
    if frame.Back then frame.Back:Hide() end
    if frame.Forward then frame.Forward:Hide() end
    bar:ClearAllPoints()
    bar:SetPoint("LEFT", frame, "LEFT", 19, 0)
    bar:SetPoint("RIGHT", frame, "RIGHT", -19, 0)
    Handle("HandleSliderFrame", bar)
    if frame.TopText then
        frame.TopText:ClearAllPoints()
        frame.TopText:SetPoint("BOTTOM", bar, "TOP", 0, 4)
    end
end

-- Dropdown button (WowStyle1DropdownTemplate); ElvUI forces the width. Its arrow is
-- tinted gold like in ElvUI's own options.
function Skin.Dropdown(dropdown, width)
    if not Enabled() then return end
    Handle("HandleDropDownBox", dropdown, width)
    for _, region in ipairs({ dropdown:GetRegions() }) do
        if region.GetTexture and region:GetTexture() == E.Media.Textures.ArrowUp then
            region:SetVertexColor(1, 0.82, 0)
        end
    end
end

function Skin.StatusBar(bar, r, g, b, a)
    if not Enabled() then return end
    Handle("HandleStatusBar", bar)
    bar:SetStatusBarColor(r, g, b, a)
end

-- Row of PanelTabButtonTemplate tabs (tabs[1] is the left one, anchored below a window).
-- S:HandleTab does not touch anchoring: it insets the tab backdrop, so the tabs need a
-- matching negative gap and the row starts 3px left of the window edge so it lines up
-- flush with it (same values as ElvUI's own tab skins).
function Skin.TabRow(tabs)
    if not Enabled() then return end
    for _, tab in ipairs(tabs) do Handle("HandleTab", tab) end
    local point, relativeTo, relativePoint = tabs[1]:GetPoint(1)
    if relativeTo then
        tabs[1]:ClearAllPoints()
        tabs[1]:SetPoint(point, relativeTo, relativePoint, -3, 0)
    end
    local gap = (E.Modern or E.Retail) and -5 or -19
    for i = 2, #tabs do
        tabs[i]:ClearAllPoints()
        tabs[i]:SetPoint("TOPLEFT", tabs[i - 1], "TOPRIGHT", gap, 0)
    end
end

------------------------------------------------------------------------
-- Portal buttons: ElvUI's flat action button look (1px template border, cropped icon,
-- hover tint) instead of the game's rounded icon frame. The border carries the
-- keystone highlight (gold).
------------------------------------------------------------------------

-- btn: RA.CreatePortalButton button; icon / highlight: its icon and hover textures.
-- Returns true when skinned (the caller then skips the game's own frame art).
function Skin.PortalButton(btn, icon, highlight)
    if not Enabled() or not btn.SetTemplate then return false end
    btn:SetTemplate("Default")
    -- The template's backdrop fill is a BACKGROUND texture too, created after the icon:
    -- on the same layer it can end up on top and hide the icon.
    icon:SetDrawLayer("ARTWORK")
    if icon.SetTexCoords then icon:SetTexCoords() else icon:SetTexCoord(unpack(E.TexCoords)) end
    if icon.SetInside then icon:SetInside(btn) end
    highlight:Hide()
    if btn.StyleButton then btn:StyleButton(false, true, true) end -- hover tint only
    btn.raElvSkinned = true
    return true
end

-- Small icon button (Character panel: Great Vault / Omniumfoliant): the cropped icon on
-- ElvUI's transparent template, class-colored border while hovered. Without the template
-- fill the icon would float on the dark ElvUI panel. uncropped: keep the icon's full
-- texture (art that fills the image). Returns true when skinned (the caller then skips
-- the game's Quickslot art).
function Skin.IconButton(btn, icon, uncropped)
    if not Enabled() or not btn.SetTemplate then return false end
    btn:SetNormalTexture("")
    btn:SetPushedTexture("")
    btn:SetHighlightTexture("")
    -- Transparent template: its fill sets the button off the panel, the border (ElvUI's
    -- normal one) only takes the class color while hovered.
    btn:SetTemplate("Transparent")
    icon:SetDrawLayer("ARTWORK")
    if not uncropped then
        if icon.SetTexCoords then icon:SetTexCoords() else icon:SetTexCoord(unpack(E.TexCoords)) end
    end
    if icon.SetInside then icon:SetInside(btn) end
    if btn.StyleButton then btn:StyleButton(false, true, true) end -- hover tint only
    -- Class-colored border while hovered, like ElvUI's own buttons and the options tabs
    -- (HookScript: the buttons' own OnEnter/OnLeave are set later with SetScript).
    local classColor = Skin.ClassColor()
    if classColor then
        btn:HookScript("OnEnter", function(self) self:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b) end)
        btn:HookScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(E.media.bordercolor)) end)
    end
    return true
end

-- Gold border while `shown`, else ElvUI's normal border. False for an unskinned button.
function Skin.PortalKeyHighlight(btn, shown)
    if not btn.raElvSkinned then return false end
    if shown then
        btn:SetBackdropBorderColor(1, 0.82, 0)
    else
        btn:SetBackdropBorderColor(unpack(E.media.bordercolor))
    end
    return true
end

------------------------------------------------------------------------
-- Options tabs / category buttons (class-colored when active)
------------------------------------------------------------------------

local function ElvColors()
    local function Rgba(c, r, g, b, a)
        if not c then return { r, g, b, a } end
        return { c.r or c[1] or r, c.g or c[2] or g, c.b or c[3] or b, c.a or c[4] or a }
    end
    local m = E.media
    return Rgba(m and m.backdropcolor, 0.1, 0.1, 0.1, 0.8), Rgba(m and m.bordercolor, 0.1, 0.1, 0.1, 1)
end

-- bg/bd: { r, g, b [, a] }, applied to the frame and to its ElvUI backdrop child.
local function SetBackdropColors(frame, bg, bd)
    if frame.SetBackdropColor then
        frame:SetBackdropColor(unpack(bg))
        frame:SetBackdropBorderColor(unpack(bd))
    end
    if frame.backdrop then
        frame.backdrop:SetBackdropColor(unpack(bg))
        frame.backdrop:SetBackdropBorderColor(unpack(bd))
    end
end

local function SetTextColor(btn, color)
    local text = btn:GetFontString()
    if text then text:SetTextColor(color.r, color.g, color.b, 1) end
end

-- ElvUI button with a fill a shade lighter than the panel (so it reads as a button); the
-- border takes classColor while `highlight` is true (hover / active tab).
local function PaintLifted(btn, highlight, classColor)
    local bg, bd = ElvColors()
    local border = (highlight and classColor) and { classColor.r, classColor.g, classColor.b, 1 } or bd
    SetBackdropColors(btn, {
        math.min((bg[1] or 0.1) + 0.08, 1),
        math.min((bg[2] or 0.1) + 0.08, 1),
        math.min((bg[3] or 0.1) + 0.08, 1),
        bg[4] or 1,
    }, border)
end

local function StripButtonArt(btn)
    btn:SetNormalTexture("")
    btn:SetHighlightTexture("")
    btn:SetPushedTexture("")
    btn:SetDisabledTexture("")
end

-- Plain action button (Features, Default, ...) in the lifted tab look: lighter fill,
-- class-colored border on hover.
function Skin.LiftedButton(btn, classColor)
    if not Enabled() then return end
    S:HandleButton(btn)
    StripButtonArt(btn)
    PaintLifted(btn, false, classColor)
    btn:HookScript("OnEnter", function(self)
        if self.IsEnabled and not self:IsEnabled() then return end
        PaintLifted(self, true, classColor)
    end)
    btn:HookScript("OnLeave", function(self) PaintLifted(self, false, classColor) end)
end

-- btn: UIPanelButtonTemplate button that shows panels[key] on click. The fill stays ElvUI's
-- (a shade lighter than the panel so tabs read as buttons); the border takes classColor on
-- hover and while the tab is active, and the text turns gold. Adds btn.raApplyActive /
-- raApplyInactive / raRefresh.
function Skin.OptionTab(btn, panels, key, classColor)
    if not Enabled() then return end
    S:HandleButton(btn)
    StripButtonArt(btn)

    -- highlight: class-colored border instead of ElvUI's default one.
    local function Paint(highlight) PaintLifted(btn, highlight, classColor) end
    Paint(false)

    -- Disabled tabs (season tabs without debug mode) get no border; the gold text still
    -- marks the current one.
    local function ApplyActive()
        Paint(not (btn.IsEnabled and not btn:IsEnabled()))
        SetTextColor(btn, GOLD)
    end

    local function ApplyInactive()
        Paint(false)
        SetTextColor(btn, GRAY)
    end

    btn.raApplyActive   = ApplyActive
    btn.raApplyInactive = ApplyInactive
    -- Re-applies the style for the current state (after Enable()/Disable()).
    btn.raRefresh = function()
        if panels[key] and panels[key]:IsShown() then ApplyActive() else ApplyInactive() end
    end

    -- HookScript runs after ElvUI's own OnEnter, so our color wins.
    btn:HookScript("OnEnter", function(self)
        if self.IsEnabled and not self:IsEnabled() then return end
        Paint(true)
        SetTextColor(self, GOLD)
    end)
    btn:HookScript("OnLeave", function(self) self.raRefresh() end)
end

-- The player's class color while the ElvUI look applies (tab highlight), else nil.
function Skin.ClassColor()
    if not Enabled() then return nil end
    local _, className = UnitClass("player")
    return RAID_CLASS_COLORS and RAID_CLASS_COLORS[className]
end
