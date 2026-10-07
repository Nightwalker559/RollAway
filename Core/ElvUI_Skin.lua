-- RollAway - Core/ElvUI_Skin.lua
-- Optional ElvUI skin. Only active when ElvUI is loaded.

if not ElvUI then return end

local RA = _G["RollAway"]
local E  = unpack(ElvUI)
local S  = E:GetModule("Skins")

local GOLD = RA.OptionsUI.GOLD
local GRAY = RA.OptionsUI.GRAY

-- Whether ElvUI's Blizzard-frame skinning is enabled (our frames follow it).
local function SkinsEnabled()
    return E.private.skins and E.private.skins.blizzard and E.private.skins.blizzard.enable
end

-- S:<method>(obj) if the object exists and this ElvUI version has the method.
local function Handle(method, obj)
    if obj and S[method] then S[method](S, obj) end
end

------------------------------------------------------------------------
-- Tab styling (used by Options)
------------------------------------------------------------------------

-- ElvUI backdrop/border colors
local function GetElvUIColors()
    local bg = (E.media and E.media.backdropcolor) or {0.1, 0.1, 0.1, 0.8}
    local bd = (E.media and E.media.bordercolor)  or {0.1, 0.1, 0.1}
    return bg, bd
end

-- bg/bd: { r, g, b [, a] } - applied to the frame and to its ElvUI backdrop child.
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

function RA.ElvSkinTab(btn, tabPanels, key, classColor)
    S:HandleButton(btn)

    btn:SetNormalTexture("")
    btn:SetHighlightTexture("")
    btn:SetPushedTexture("")
    btn:SetDisabledTexture("")

    -- Idle tabs get a background a shade lighter than the panel behind them
    -- so they read as distinct buttons at rest, not just on hover/active.
    local function ResetBackdrop()
        local bg, bd = GetElvUIColors()
        local idleBg = {
            math.min((bg[1] or 0.1) + 0.08, 1),
            math.min((bg[2] or 0.1) + 0.08, 1),
            math.min((bg[3] or 0.1) + 0.08, 1),
            bg[4] or 1,
        }
        SetBackdropColors(btn, idleBg, bd)
    end
    ResetBackdrop()

    local function ApplyActive()
        -- Disabled tabs (season tabs while debug mode is off - see
        -- OptionsHelpers.lua MakeSeasonTabs) never get the active tint/
        -- border since they're not actually selectable, but they still
        -- show which season is current via the gold text.
        if btn.IsEnabled and not btn:IsEnabled() then
            ResetBackdrop()
        -- Always tinted while active, not only on hover; hover (below) then
        -- brightens it further via full-alpha classColor.
        elseif classColor then
            SetBackdropColors(btn,
                { classColor.r, classColor.g, classColor.b, btn:IsMouseOver() and 1 or 0.35 },
                { classColor.r, classColor.g, classColor.b, 1 })
        else
            ResetBackdrop()
        end
        SetTextColor(btn, GOLD)
    end

    local function ApplyInactive()
        ResetBackdrop()
        SetTextColor(btn, GRAY)
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
            SetBackdropColors(self,
                { classColor.r, classColor.g, classColor.b, 1 },
                { classColor.r, classColor.g, classColor.b, 0 })
        end
        SetTextColor(self, GOLD)
    end)

    btn:HookScript("OnLeave", function(self)
        self.RA_Refresh()
    end)
end

------------------------------------------------------------------------
-- Skin popup frames built on RA.CreatePopupFrame (Reminder, Paragon,
-- GreatVault, AdvLog). Called directly from CreatePopupFrame right after
-- construction, so no per-module Show hook is needed.
------------------------------------------------------------------------

function RA.SkinPopupFrame(frame)
    if not SkinsEnabled() then return end
    Handle("HandleFrame", frame)
    -- ElvUI's backdrop child can sit above our directly-parented icon
    -- texture; force the icon's holder frame above it explicitly.
    if frame.iconHolder then
        frame.iconHolder:SetFrameLevel(frame:GetFrameLevel() + 10)
        if frame.icon then frame.icon:Show() end
    end
    if frame.bar then
        Handle("HandleStatusBar", frame.bar)
        frame.bar:SetStatusBarColor(0.8, 0.7, 0.1, 0.9)
    end
    Handle("HandleButton", frame.okayBtn)
end

-- For any extra button a caller adds to a popup frame after CreatePopupFrame
-- already returned (e.g. Reminder.lua's "Options" button) - same skin, on
-- demand, called right where the button is created.
function RA.SkinPopupButton(btn)
    if SkinsEnabled() then Handle("HandleButton", btn) end
end

------------------------------------------------------------------------
-- Dropdown lists (RA.OptionsUI.MakeDropdown). ElvUI skins the dropdown box
-- and the list frame, but not the entries: they keep Blizzard's gold tick
-- and yellow quest highlight. Entries get a flat gold square and a soft
-- white hover, like ElvUI's checkboxes.
------------------------------------------------------------------------

local function SkinDropdownItem(item)
    if item.RA_ElvSkinned then return end
    item.RA_ElvSkinned = true

    local check = item.check
    if check then
        check:SetTexture(E.Media.Textures.White8x8)
        check:SetVertexColor(1, .82, 0, 0.8)
        check:SetSize(8, 8)
        check:ClearAllPoints()
        check:SetPoint("LEFT", item.frame, "LEFT", 7, 0)
    end

    local highlight = item.highlight
    if highlight then
        highlight:SetTexture(E.Media.Textures.White8x8)
        highlight:SetVertexColor(1, 1, 1, 0.12)
    end
end

-- dd: AceGUI Dropdown. Follows ElvUI's Ace3 skin switch, like the dropdown box.
function RA.SkinDropdownList(dd)
    if not (E.private.skins and E.private.skins.ace3Enable) or not dd.pullout then return end
    for _, item in dd.pullout:IterateItems() do SkinDropdownItem(item) end
    hooksecurefunc(dd.pullout, "AddItem", function(_, item) SkinDropdownItem(item) end)
end

------------------------------------------------------------------------
-- Frames created lazily on first show/use. Each is skinned once, by the
-- hook registered below (SkinOnShow) right after the function that creates
-- or shows it.
------------------------------------------------------------------------

-- Runs skin(frame) once for the global frame `name`, if it exists yet.
local function SkinOnce(name, skin)
    local f = _G[name]
    if not f or f.RA_ElvSkinned then return end
    skin(f)
    f.RA_ElvSkinned = true
end

local function SkinWhatsNewFrame(f)
    Handle("HandleFrame", f)
    Handle("HandleButton", _G["RollAwayWhatsNewOkay"])
end

local function SkinTeleportReminderFrame(f)
    Handle("HandleFrame", f)
    Handle("HandleCloseButton", _G["RollAwayTeleportReminderClose"])
end

-- Own-frame Mythic+ portal picker, RA.ShowPortalOverview
local function SkinPortalOverviewFrame(f)
    Handle("HandleFrame", f)
    Handle("HandleCloseButton", _G["RollAwayPortalOverviewClose"])

    local tabs = {}
    for i = 1, (f.numTabs or 0) do
        tabs[i] = _G[f:GetName().."Tab"..i]
        Handle("HandleTab", tabs[i])
    end
    -- S:HandleTab only reskins the button (flat backdrop instead of the
    -- Blizzard tab texture); it doesn't touch anchoring. Re-anchor here so
    -- the ElvUI-skinned tabs sit correctly - ElvUI insets the tab backdrop
    -- by 5px on Retail (10px on other clients), so tabs need a matching
    -- negative gap to butt up against each other instead of the wider
    -- Blizzard-style gap set in PortalOverview.lua.
    local offset = E.Retail and -5 or -19
    for i = 2, #tabs do
        tabs[i]:ClearAllPoints()
        tabs[i]:SetPoint("TOPLEFT", tabs[i - 1], "TOPRIGHT", offset, 0)
    end
    -- Scrollbar is force-hidden in PortalOverview.lua (mouse-wheel scroll
    -- only), so there's nothing to skin there.
end

-- Dev-only debug log window (/rawlog)
local function SkinDebugLogFrame(f)
    Handle("HandleFrame", f)
    Handle("HandleScrollBar", _G["RollAwayDebugLogScrollScrollBar"])
    Handle("HandleEditBox", _G["RollAwayDebugLogEditBox"])
    Handle("HandleCloseButton", _G["RollAwayDebugLogClose"])
    Handle("HandleButton", _G["RollAwayDebugLogSelectAll"])
    Handle("HandleButton", _G["RollAwayDebugLogClear"])
end

-- Omniumfoliant / Great Vault CharacterFrame buttons
local function SkinCharFrameButton(btn)
    Handle("HandleButton", btn)
    -- HandleButton alone doesn't strip the manually-set Quickslot textures;
    -- clear them so ElvUI's backdrop/border shows instead of the default one.
    btn:SetNormalTexture("")
    btn:SetPushedTexture("")
    btn:SetHighlightTexture("")
end

------------------------------------------------------------------------
-- Checkboxes/sliders keep ElvUI's native AceGUI styling (no color forcing).
-- Reminder/Paragon/GreatVault/AdvLog are skinned inside RA.CreatePopupFrame;
-- the frames below have a different shape, so each gets a hook.
------------------------------------------------------------------------

-- Hooks RA[funcName] (called through the RA table by its owner) to skin the
-- frame it creates/shows, once, after each call.
local function SkinOnShow(funcName, frameName, skin)
    hooksecurefunc(RA, funcName, function()
        if SkinsEnabled() then SkinOnce(frameName, skin) end
    end)
end

SkinOnShow("ShowTeleportReminder", "RollAwayTeleportReminderFrame", SkinTeleportReminderFrame)
SkinOnShow("ShowWhatsNew",         "RollAwayWhatsNewFrame",         SkinWhatsNewFrame)
SkinOnShow("ShowPortalOverview",   "RollAwayPortalOverviewFrame",   SkinPortalOverviewFrame)
-- AppendDebugLog fires on every log line; SkinOnce keeps it cheap after the
-- first (lazy-created) call.
SkinOnShow("AppendDebugLog",       "RollAwayDebugLogFrame",         SkinDebugLogFrame)

-- Buttons are lazy-created by CharFrameButtons.lua; skinned-once guard avoids
-- re-skinning on every refresh.
hooksecurefunc(RA, "RefreshCharFrameButtons", function()
    if SkinsEnabled() then
        SkinOnce("RollAwayOmniumfoliantButton", SkinCharFrameButton)
        SkinOnce("RollAwayVaultButton", SkinCharFrameButton)
    end
end)
