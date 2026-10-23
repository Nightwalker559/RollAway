-- RollAway - Core/Helpers.lua
-- Shared helpers: popup/toast frame factories, timers, portal buttons, loot roll
-- buttons and small utilities. Loads right after Core/Core.lua.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

-- Skin hooks (Skin.Window, Skin.Button, Skin.CheckBox, ...): no-ops here, replaced by
-- Core/ElvUI_Skin.lua when ElvUI is loaded.
local function Noop() end
RA.Skin = setmetatable({}, { __index = function() return Noop end })

------------------------------------------------------------------------
-- Generic utilities
------------------------------------------------------------------------

-- Runs fn() once, when the load-on-demand Blizzard addon has loaded.
function RA.WaitForAddon(addonName, fn)
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, loadedAddon)
        if loadedAddon == addonName then
            self:UnregisterAllEvents()
            fn()
        end
    end)
end

-- Chat print for the few user-facing messages (DBG is dev-only, never in chat).
local function Print(msg)
    print("|cff33ff99RollAway:|r " .. msg)
end
RA.Print = Print

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do copy[k] = DeepCopy(v) end
    return copy
end
RA.DeepCopy = DeepCopy

-- C_Timer handles may be tables or userdata: cancel whatever answers Cancel().
local function SafeCancelTimer(timer)
    if timer then
        pcall(function() timer:Cancel() end)
    end
end
RA.SafeCancelTimer = SafeCancelTimer

-- 12.x "secret values" cannot be compared or indexed by addon code: false for
-- those, true for everything else.
function RA.IsAccessible(value)
    return not canaccessvalue or canaccessvalue(value)
end

-- Is the player max level?
function RA.IsMaxLevel()
    return UnitLevel("player") >= GetMaxPlayerLevel()
end

function RA.IsHunter()
    return select(2, UnitClass("player")) == "HUNTER"
end

-- Instance name plus the keystone level ("+14", gold) when known.
function RA.FormatInstanceWithKey(name, keyLevel)
    if not keyLevel then return name end
    return name .. " |cffFFD100+" .. keyLevel .. "|r"
end

-- The keystone in the player's bags: activity ID (a dungeon's lfgID) and level.
function RA.GetOwnedKeystone()
    if not C_LFGList then return nil, nil end
    local lfgID, _, level = C_LFGList.GetOwnedKeystoneActivityAndGroupAndLevel()
    return lfgID, level
end

-- A new array sorted by labelFn(entry): case-insensitive, byte order (umlauts
-- sort by byte). `list` is not changed.
function RA.SortByLabel(list, labelFn)
    local sorted = {}
    for i = 1, #list do sorted[i] = list[i] end
    table.sort(sorted, function(a, b)
        return (labelFn(a) or ""):lower() < (labelFn(b) or ""):lower()
    end)
    return sorted
end

-- StaticPopup with RollAway's defaults (no timeout, usable while dead, Escape
-- closes); `def` overrides them.
function RA.RegisterPopup(name, def)
    if def.timeout == nil        then def.timeout        = 0    end
    if def.whileDead == nil      then def.whileDead      = true end
    if def.hideOnEscape == nil   then def.hideOnEscape   = true end
    if def.preferredIndex == nil then def.preferredIndex = 3    end
    StaticPopupDialogs[name] = def
end

------------------------------------------------------------------------
-- Frame helpers
------------------------------------------------------------------------

-- Show/hide for frames with secure children (portal buttons): protected in combat
-- (ADDON_ACTION_BLOCKED), so the change is deferred until combat ends.
function RA.SafeSetShown(frame, shouldShow)
    if not frame then return end
    if not InCombatLockdown() then
        frame.raPendingShown = nil  -- a newer direct change supersedes any deferred one
        frame:SetShown(shouldShow)
        return
    end
    frame.raPendingShown = shouldShow
    if not frame.raSafeShowInit then
        frame.raSafeShowInit = true
        frame:HookScript("OnEvent", function(self, event)
            if event == "PLAYER_REGEN_ENABLED" and self.raPendingShown ~= nil then
                self:SetShown(self.raPendingShown)
                self.raPendingShown = nil
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            end
        end)
    end
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-- Standard left-click-drag behavior for RollAway popups.
function RA.MakeDraggable(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
end

-- Window in the game's current standard style (DefaultPanelTemplate: stone background,
-- metal NineSlice border, title bar) with the standard close button (frame.CloseButton).
function RA.CreatePanelWindow(name, parent, width, height, title)
    local f = CreateFrame("Frame", name, parent, "DefaultPanelTemplate")
    f:SetSize(width, height)
    f:SetTitle(title)
    f.CloseButton = CreateFrame("Button", nil, f, "UIPanelCloseButtonDefaultAnchors")
    RA.Skin.Window(f)
    -- Windows of one strata overlap as a whole: opening or clicking one raises it with all
    -- its parts (title bar and border sit 500+ levels above the body, so without this they
    -- would be drawn through a neighbouring window). Windows parented to another frame follow it.
    if not parent or parent == UIParent then
        f:SetToplevel(true)
        f:HookScript("OnShow", f.Raise)
    end
    return f
end

-- The addon logo at the right end of an options page's header line (above it).
function RA.AddHeaderLogo(page, headerLine)
    local icon = page:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetTexture("Interface\\AddOns\\RollAway\\Media\\Icon")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    icon:SetPoint("BOTTOMRIGHT", headerLine, "TOPRIGHT", 0, 6)
    return icon
end

-- Like MakeDraggable, but honors qolReminderLockPosition (checked on every drag).
function RA.MakeLockableDraggable(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if RollAwayDB and RollAwayDB.qolReminderLockPosition then return end
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
end

------------------------------------------------------------------------
-- Timers
------------------------------------------------------------------------

-- Countdown bar for auto-hide popups: { bar, barText, Start, Stop }.
function RA.CreateTimerBar(parent, onExpire)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetPoint("BOTTOMLEFT",  parent, "BOTTOMLEFT",  8, 6)
    bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 6)
    bar:SetHeight(8)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.8, 0.7, 0.1, 0.9)

    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints(bar)
    barBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    barBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    local barText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    barText:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
    barText:SetTextColor(1, 1, 1, 0.9)

    local lastShownSecond

    local function Stop()
        bar:SetScript("OnUpdate", nil)
        lastShownSecond = nil
    end

    local function Start(duration)
        Stop()
        local elapsed = 0
        bar:SetMinMaxValues(0, duration)
        bar:SetValue(duration)
        lastShownSecond = duration
        barText:SetText(duration)

        bar:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt
            local remaining = duration - elapsed
            if remaining <= 0 then
                Stop()
                if onExpire then onExpire() end
                return
            end
            bar:SetValue(remaining)
            local ceiled = math.ceil(remaining)
            if ceiled ~= lastShownSecond then
                lastShownSecond = ceiled
                barText:SetText(ceiled)
            end
        end)
    end

    return { bar = bar, barText = barText, Start = Start, Stop = Stop }
end

-- One-shot timer with Start()/Stop().
function RA.CreateOneShotTimer(seconds, callback)
    local timer

    local function Stop()
        SafeCancelTimer(timer)
        timer = nil
    end

    local function Start()
        Stop()
        timer = C_Timer.NewTimer(seconds, function()
            timer = nil
            callback()
        end)
    end

    return { Start = Start, Stop = Stop }
end

------------------------------------------------------------------------
-- Popup frame factory (Reminder, Paragon, Great Vault, Advanced Logging, Tank
-- marker): game-style window (RA.CreatePanelWindow) with icon in the title bar,
-- draggable, ESC-closable, countdown bar, Okay button.
-- Callers add their own content.
--
-- opts:
--   name, okayName  global names of the frame and the Okay button
--   title           window title: what the popup is for (the RollAway logo marks the addon)
--   width, height   initial size; height is also the minimum
--   yOffset         initial TOP offset
--   duration        countdown in seconds
--   fitHeight       optional function(frame) -> desired height, evaluated one frame
--                   after OnShow (never below `height`)
--   hide            optional function(frame) for Okay/countdown (default: Hide;
--                   popups with secure buttons need RA.SafeSetShown(frame, false))
--
-- The frame gets .iconHolder, .icon, .titleText, .okayBtn, .bar, .barText, .timer.
------------------------------------------------------------------------

-- Height of header + footer, for fitHeight: RA.POPUP_CHROME_HEIGHT + body height.
RA.POPUP_CHROME_HEIGHT = 78

function RA.CreatePopupFrame(opts)
    local frame = RA.CreatePanelWindow(opts.name, UIParent, opts.width, opts.height, opts.title or "RollAway")
    frame:SetPoint("TOP", UIParent, "TOP", 0, opts.yOffset)
    frame.defaultY = opts.yOffset  -- used by RA.StackPopupFrame
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    RA.MakeDraggable(frame)
    frame:Hide()

    -- ESC closes the frame
    tinsert(UISpecialFrames, opts.name)

    -- Icon in the title bar (own holder: it must sit above the window border).
    local iconHolder = CreateFrame("Frame", nil, frame)
    iconHolder:SetSize(18, 18)
    iconHolder:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -3)
    iconHolder:SetFrameLevel(520)  -- above the panel's border (NineSlice is level 500)
    frame.iconHolder = iconHolder

    local icon = iconHolder:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\AddOns\\RollAway\\Media\\Icon")
    frame.icon = icon

    frame.titleText = frame:GetTitleText()

    -- Okay button (bottom right) - closes the popup
    local okayBtn = CreateFrame("Button", opts.okayName, frame, "UIPanelButtonTemplate")
    okayBtn:SetSize(80, 22)
    okayBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 18)
    okayBtn:SetText(RA_L["reminder_okay"])
    local hide = opts.hide or function(f) f:Hide() end
    okayBtn:SetScript("OnClick", function() hide(frame) end)
    frame.CloseButton:SetScript("OnClick", function() hide(frame) end)
    frame.okayBtn = okayBtn

    -- Countdown bar (OnShow/OnHide).
    local timer = RA.CreateTimerBar(frame, function() hide(frame) end)
    frame.bar     = timer.bar
    frame.barText = timer.barText
    frame.timer   = timer

    frame:SetScript("OnShow", function(self)
        if opts.fitHeight then
            RunNextFrame(function()
                if not self:IsShown() then return end
                self:SetHeight(math.max(opts.height, opts.fitHeight(self)))
            end)
        end
        timer.Start(opts.duration)
    end)
    frame:SetScript("OnHide", timer.Stop)

    RA.Skin.Button(okayBtn)
    RA.Skin.StatusBar(timer.bar, 0.8, 0.7, 0.1, 0.9)

    return frame
end

-- Left-aligned, wrapping body text anchored below the popup header.
function RA.CreatePopupBodyText(frame)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT",  frame, "TOPLEFT",  12, -32)
    text:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -32)
    text:SetJustifyH("LEFT")
    text:SetNonSpaceWrap(true)
    return text
end

-- Popups sit in this order, top to bottom (a fixed order keeps anchors loop-free).
local POPUP_STACK_ORDER = {
    "RollAwayReminderFrame", "RollAwayParagonFrame", "RollAwayGreatVaultFrame",
    "RollAwayAdvLogFrame", "RollAwayTankMarkFrame",
}

-- Stacks `frame` (about to be shown) and every shown popup in POPUP_STACK_ORDER:
-- the first at its default position, each next directly below. In combat only
-- `frame` is placed (secure popups must not be moved).
function RA.StackPopupFrame(frame)
    local inCombat = InCombatLockdown()
    local above
    for _, name in ipairs(POPUP_STACK_ORDER) do
        local f = _G[name]
        local isNew = (f == frame)
        if f and (isNew or f:IsShown()) then
            if isNew or not inCombat then
                f:ClearAllPoints()
                if above then
                    f:SetPoint("TOP", above, "BOTTOM", 0, -10)
                else
                    f:SetPoint("TOP", UIParent, "TOP", 0, f.defaultY or -180)
                end
            end
            above = f
        end
    end
end

-- "Once per instance" popup lifecycle: hides on pull and GROUP_LEFT; the dedup key
-- is cleared on GROUP_LEFT/GROUP_JOINED. GROUP_JOINED does not hide: a Dungeon
-- Finder group is merged right around entering, and the reminder still applies.
function RA.SetupInstanceReminderLifecycle(frame, dedupKey)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("GROUP_LEFT")
    frame:RegisterEvent("GROUP_JOINED")
    frame:SetScript("OnEvent", function(self, event)
        if event ~= "GROUP_JOINED" then
            self:Hide()
        end
        if event == "GROUP_LEFT" or event == "GROUP_JOINED" then
            if RollAwayDBChar then RollAwayDBChar[dedupKey] = nil end
        end
    end)
end

------------------------------------------------------------------------
-- QoL toast frames (Ready Check, Durability, Instance Join): centered, draggable
-- (lockable), text only, hidden by a 6s timer the caller starts. All are
-- registered for the "reset position" button.
------------------------------------------------------------------------

function RA.GetQoLFont()
    local fontSize = (RollAwayDB and RollAwayDB.talentFontSize) or 20
    local fontPath = "Fonts\\FRIZQT__.TTF"
    if ElvUI then
        local E = unpack(ElvUI)
        fontPath = (E and E.media and E.media.normFont) or fontPath
    end
    return fontPath, fontSize
end

local toastFrames = {}

-- Returns frame, timer ({Start, Stop}); frame.text is the centered FontString.
function RA.CreateToastFrame(globalName, width, height, yOffset)
    local frame = CreateFrame("Frame", globalName, UIParent)
    frame:SetSize(width, height)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, yOffset)
    frame.defaultY = yOffset
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    RA.MakeLockableDraggable(frame)
    local timer = RA.CreateOneShotTimer(6, function() frame:Hide() end)
    frame:SetScript("OnHide", timer.Stop)
    frame:Hide()

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.text = text

    toastFrames[#toastFrames + 1] = frame
    return frame, timer
end

-- Only toasts created so far (lazily, on first show).
function RA.ResetToastPositions()
    for _, frame in ipairs(toastFrames) do
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, frame.defaultY)
    end
end

------------------------------------------------------------------------
-- Portal (dungeon teleport) buttons, shared by Teleport Reminder and Portal Overview.
------------------------------------------------------------------------

-- Durations up to the GCD are no real cooldown.
local PORTAL_COOLDOWN_THRESHOLD = 3

-- startTime, duration of a real (non-GCD) cooldown on the spell, or nil.
function RA.GetPortalCooldown(spellID)
    local cd = C_Spell.GetSpellCooldown(spellID)
    if not cd or not (RA.IsAccessible(cd.startTime) and RA.IsAccessible(cd.duration)) then return end
    if cd.startTime > 0 and cd.duration > PORTAL_COOLDOWN_THRESHOLD then
        return cd.startTime, cd.duration
    end
end

function RA.IsPortalOnCooldown(spellID)
    return RA.GetPortalCooldown(spellID) ~= nil
end

local PORTAL_FRAME_ATLAS = "UI-HUD-ActionBar-IconFrame"

-- Compact cooldown text ("8h"): the Cooldown frame's own countdown puts a space between
-- number and unit. The units come from the game's own strings (right in every client
-- language), spaces removed. Also on ElvUI buttons (ElvUI's own timer is switched off,
-- its font is used).
local COOLDOWN_UNITS = {   -- seconds per unit, game string, fallback
    { 86400, "COOLDOWN_DURATION_DAYS", "%dd" },
    { 3600,  "COOLDOWN_DURATION_HOURS", "%dh" },
    { 60,    "COOLDOWN_DURATION_MIN", "%dm" },
    { 1,     "COOLDOWN_DURATION_SEC", "%ds" },
}

local function FormatCooldownTime(seconds)
    for _, unit in ipairs(COOLDOWN_UNITS) do
        if seconds >= unit[1] or unit[1] == 1 then
            local fmt = _G[unit[2]]
            if type(fmt) ~= "string" or not fmt:find("%%d") then fmt = unit[3] end
            return (fmt:gsub("\194\160", ""):gsub("%s", "")):format(math.ceil(seconds / unit[1]))
        end
    end
end

local function RefreshCooldownText(btn)
    local remaining = btn.cooldownEnd - GetTime()
    if remaining > 0 then
        btn.cooldownText:SetText(FormatCooldownTime(remaining))
    else
        btn.cooldownTextHolder:Hide()
    end
end

-- Created on first use, above the cooldown swipe. Refreshed once a second, only while shown.
local function ShowCooldownText(btn, start, duration)
    if not btn.cooldownTextHolder then
        local holder = CreateFrame("Frame", nil, btn)
        holder:SetAllPoints()
        holder:SetFrameLevel(btn.cooldown:GetFrameLevel() + 1)
        local fs = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetPoint("CENTER")
        btn.cooldownText, btn.cooldownTextHolder = fs, holder
        btn.cooldownTextFont = btn.raElvSkinned and (RA.GetQoLFont()) or (fs:GetFont())

        local elapsed = 0
        holder:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt
            if elapsed < 1 then return end
            elapsed = 0
            RefreshCooldownText(btn)
        end)
    end
    btn.cooldownText:SetFont(btn.cooldownTextFont, math.max(10, math.floor(btn:GetWidth() * 0.36)), "OUTLINE")
    btn.cooldownEnd = start + duration
    btn.cooldownTextHolder:Show()
    RefreshCooldownText(btn)
end

-- Secure spell button; the caller adds the tooltip and calls RA.SetPortalSpell().
function RA.CreatePortalButton(globalName, parent, size)
    local btn = CreateFrame("Button", globalName, parent, "SecureActionButtonTemplate")
    btn:SetSize(size, size)

    local tex = btn:CreateTexture(nil, "BACKGROUND")
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.iconTexture = tex

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")

    if RA.Skin.PortalButton(btn, tex, highlight) then
        -- ElvUI's flat look (Core/ElvUI_Skin.lua): nothing more to build.
    elseif C_Texture.GetAtlasInfo(PORTAL_FRAME_ATLAS) then
        -- The action buttons' own look: rounded icon (mask) with the game's icon frame on
        -- top; the frame atlas is 46x45 and sits at the top left like on an action button.
        tex:SetAllPoints()
        local mask = btn:CreateMaskTexture()
        mask:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask")
        mask:SetPoint("CENTER", tex)
        tex:AddMaskTexture(mask)
        -- Like the action button: the mask keeps its atlas size (larger than the icon, so it
        -- only rounds the corners), scaled with the button (the game's button is 45px).
        local maskInfo = C_Texture.GetAtlasInfo("UI-HUD-ActionBar-IconFrame-Mask")
        local function FitMask()
            local scale = btn:GetWidth() / 45
            mask:SetSize(maskInfo.width * scale, maskInfo.height * scale)
        end
        if maskInfo then
            FitMask()
            btn:HookScript("OnSizeChanged", FitMask)
        else
            mask:SetAllPoints(tex)
        end

        local frameTex = btn:CreateTexture(nil, "ARTWORK", nil, 1)
        frameTex:SetAtlas(PORTAL_FRAME_ATLAS)
        frameTex:SetPoint("TOPLEFT")
        frameTex:SetPoint("BOTTOMRIGHT", 1, 0)

        highlight:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
        highlight:SetPoint("TOPLEFT")
        highlight:SetPoint("BOTTOMRIGHT", 1, 0)
    else
        -- Fallback without the atlas: 1px gray frame, the icon inset by 1px.
        local border = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
        border:SetAllPoints()
        border:SetColorTexture(0.45, 0.45, 0.45, 1)
        tex:SetPoint("TOPLEFT", 1, -1)
        tex:SetPoint("BOTTOMRIGHT", -1, 1)
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.25)
    end

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints()
    btn.cooldown:SetDrawEdge(false)
    btn.cooldown:SetHideCountdownNumbers(true)  -- own text, see ShowCooldownText
    btn.cooldown.noCooldownCount = true         -- ElvUI's cooldown timer stays off too

    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("type", "spell")
    return btn
end

-- Short dungeon name (RA.DUNGEON_SHORT_NAMES) along the button's bottom edge, above the
-- cooldown swipe; empty when the dungeon has none or the option (portalLabels) is off.
-- fontSize: nil = by button size (at least 9).
function RA.SetPortalLabel(btn, dungeonKey, fontSize)
    local text = RA.DUNGEON_SHORT_NAMES[dungeonKey]
    if RollAwayDB and RollAwayDB.portalLabels == false then text = nil end
    if not btn.label then
        if not text then return end
        local holder = CreateFrame("Frame", nil, btn)
        holder:SetAllPoints()
        holder:SetFrameLevel(btn.cooldown:GetFrameLevel() + 1)
        local fs = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.labelFontPath = (fs:GetFont())
        fs:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
        btn.label = fs
    end
    btn.label:SetFont(btn.labelFontPath, fontSize or math.max(9, math.floor(btn:GetWidth() / 4.5)), "OUTLINE")
    btn.label:SetText(text or "")
end

-- Gold highlight (e.g. the dungeon's keystone is in the bags), like the game's own
-- action button states: the icon frame's border atlas tinted gold plus the additive
-- "spell highlight" glow (UI-HUD-ActionBar-IconFrame-Border / -Mouseover, 40%); with
-- ElvUI a gold button border.
function RA.SetPortalKeyHighlight(btn, shown)
    if RA.Skin.PortalKeyHighlight(btn, shown) then return end  -- ElvUI: gold border
    if not btn.keyHighlight then
        if not shown then return end
        local border = btn:CreateTexture(nil, "ARTWORK", nil, 2)
        local glow   = btn:CreateTexture(nil, "OVERLAY", nil, 1)
        if C_Texture.GetAtlasInfo(PORTAL_FRAME_ATLAS) then
            border:SetAtlas("UI-HUD-ActionBar-IconFrame-Border")
            border:SetVertexColor(1, 0.82, 0)
            border:SetPoint("TOPLEFT")
            border:SetPoint("BOTTOMRIGHT", 1, 0)
            glow:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
            glow:SetBlendMode("ADD")
            glow:SetAlpha(0.4)
            glow:SetPoint("TOPLEFT")
            glow:SetPoint("BOTTOMRIGHT", 1, 0)
        else
            glow:SetAllPoints()
            glow:SetColorTexture(1, 0.82, 0, 0.38)
        end
        btn.keyHighlight = { border, glow }
    end
    for _, tex in ipairs(btn.keyHighlight) do tex:SetShown(shown) end
end

-- Not in combat (SetAttribute is protected).
function RA.SetPortalSpell(btn, spellID)
    btn.spellID = spellID
    btn:SetAttribute("spell", spellID)
    btn.iconTexture:SetTexture(C_Spell.GetSpellTexture(spellID) or 134400)  -- 134400: question mark
end

-- Unlearned portals look locked; learned ones show their cooldown.
function RA.UpdatePortalButtonState(btn, isKnown, unknownAlpha)
    if btn.raElvSkinned then
        -- ElvUI: the icon is only darkened (tint); the button's backdrop and border stay
        -- as they are, no button alpha or desaturation.
        local shade = isKnown and 1 or 0.4
        btn.iconTexture:SetVertexColor(shade, shade, shade)
        btn:SetAlpha(1)
    else
        btn.iconTexture:SetDesaturated(not isKnown)
        btn:SetAlpha(isKnown and 1 or unknownAlpha)
    end

    local start, duration
    if isKnown then start, duration = RA.GetPortalCooldown(btn.spellID) end
    if start then
        btn.cooldown:SetCooldown(start, duration)
        ShowCooldownText(btn, start, duration)
    else
        btn.cooldown:Clear()
        if btn.cooldownTextHolder then btn.cooldownTextHolder:Hide() end
    end
end

------------------------------------------------------------------------
-- Loot roll buttons (AutoRoll, RollConfirm): Blizzard's GroupLootFrameN or, with
-- ElvUI, ElvUI_LootRollFrameN (buttons: fields bar.need/greed/transmog/pass, older
-- ElvUI: found by name fragments).
------------------------------------------------------------------------

-- dbKey (also ElvUI's bar field), native button field, ElvUI button name fragments (localized).
RA.ROLL_BUTTONS = {
    { dbKey = "need",     nativeField = "NeedButton",     elvNames = { "Bedarf", "Need" } },
    { dbKey = "greed",    nativeField = "GreedButton",    elvNames = { "Gier", "Greed" } },
    { dbKey = "transmog", nativeField = "TransmogButton", elvNames = { "Transmog" } },
    { dbKey = "pass",     nativeField = "PassButton",     elvNames = { "Passen", "Pass" } },
}

local NATIVE_FIELD_BY_KEY = {}
for _, def in ipairs(RA.ROLL_BUTTONS) do NATIVE_FIELD_BY_KEY[def.dbKey] = def.nativeField end

local elvRollButtons = {}  -- [frameIndex] = { need = btn, greed = btn, ... }

-- Buttons of ElvUI_LootRollFrame<i> by dbKey (cached), nil while it does not exist.
function RA.GetElvRollButtons(i)
    if elvRollButtons[i] then return elvRollButtons[i] end
    local elvFrame = _G["ElvUI_LootRollFrame"..i]
    if not elvFrame then return nil end

    local found = {}
    for _, def in ipairs(RA.ROLL_BUTTONS) do
        local btn = elvFrame[def.dbKey]
        if type(btn) == "table" and btn.GetObjectType and btn:GetObjectType() == "Button" then
            found[def.dbKey] = btn
        end
    end
    for _, child in ipairs({ elvFrame:GetChildren() }) do
        if child:GetObjectType() == "Button" then
            local cname = child:GetName() or ""
            for _, def in ipairs(RA.ROLL_BUTTONS) do
                if not found[def.dbKey] then
                    for _, frag in ipairs(def.elvNames) do
                        if cname:find(frag) then
                            found[def.dbKey] = child
                            break
                        end
                    end
                end
            end
        end
    end
    elvRollButtons[i] = found
    return found
end

-- The roll frame's button (native or ElvUI) of type dbKey for rollID, or nil.
function RA.FindRollButton(rollID, dbKey)
    for i = 1, 5 do
        local nativeFrame = _G["GroupLootFrame"..i]
        if nativeFrame and nativeFrame:IsShown() and nativeFrame.rollID == rollID then
            return nativeFrame[NATIVE_FIELD_BY_KEY[dbKey]]
        end
        local elvFrame = _G["ElvUI_LootRollFrame"..i]
        if elvFrame and elvFrame:IsShown() and elvFrame.rollID == rollID then
            local buttons = RA.GetElvRollButtons(i)
            return buttons and buttons[dbKey]
        end
    end
end

-- Confirms the bind-on-pickup prompt of a roll RollAway rolled itself: arm it
-- right before rolling; other rolls are left alone.
local armedRolls = {}

function RA.ArmRollConfirm(rollID)
    armedRolls[rollID] = true
end

local confirmFrame = CreateFrame("Frame")
confirmFrame:RegisterEvent("CONFIRM_LOOT_ROLL")
confirmFrame:SetScript("OnEvent", function(_, _, rollID, rollType)
    if not armedRolls[rollID] then return end
    armedRolls[rollID] = nil
    DBG("[Roll] Confirming rollID:", rollID, "| rollType:", rollType)
    pcall(ConfirmLootRoll, rollID, rollType)
    -- Drop Blizzard's own popup for the same event.
    RunNextFrame(function() StaticPopup_Hide("CONFIRM_LOOT_ROLL", rollID) end)
end)
