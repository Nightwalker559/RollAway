-- RollAway - Core/Helpers.lua
-- Shared helpers: popup/toast frame factories, timers, portal buttons, loot roll
-- buttons and small utilities. Loads right after Core/Core.lua.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

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

-- Runs fn() now, or after combat (PLAYER_REGEN_ENABLED) when protected calls such
-- as Settings.OpenToCategory are blocked. One queued action; a newer one replaces it.
function RA.RunProtectedOrQueue(fn)
    if InCombatLockdown() then
        RA.pendingProtectedAction = fn
        Print(RA_L["combat_action_queued"])
        return false
    end
    fn()
    return true
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
    return f
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

-- Backdrop shared by the popup/portal frames.
local POPUP_BACKDROP = {
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

-- `frame` must have been created with "BackdropTemplate".
function RA.ApplyPopupBackdrop(frame)
    frame:SetBackdrop(POPUP_BACKDROP)
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
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
-- marker): draggable, ESC-closable, title with icon, countdown bar, Okay button.
-- Callers add their own content.
--
-- opts:
--   name, okayName  global names of the frame and the Okay button (ElvUI_Skin.lua
--                   looks them up)
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
RA.POPUP_CHROME_HEIGHT = 88

function RA.CreatePopupFrame(opts)
    local frame = CreateFrame("Frame", opts.name, UIParent, "BackdropTemplate")
    frame:SetSize(opts.width, opts.height)
    frame:SetPoint("TOP", UIParent, "TOP", 0, opts.yOffset)
    frame.defaultY = opts.yOffset  -- used by RA.StackPopupFrame
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    RA.MakeDraggable(frame)
    frame:Hide()

    -- ESC closes the frame
    tinsert(UISpecialFrames, opts.name)

    RA.ApplyPopupBackdrop(frame)

    -- Own holder, stays above ElvUI's backdrop child.
    local iconHolder = CreateFrame("Frame", nil, frame)
    iconHolder:SetSize(24, 24)
    iconHolder:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    frame.iconHolder = iconHolder

    local icon = iconHolder:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\AddOns\\RollAway\\Media\\Icon")
    frame.icon = icon

    -- Title
    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", iconHolder, "RIGHT", 6, 0)
    titleText:SetText("|cffD4AF37RollAway|r")
    frame.titleText = titleText

    -- Okay button (bottom right) - closes the popup
    local okayBtn = CreateFrame("Button", opts.okayName, frame, "UIPanelButtonTemplate")
    okayBtn:SetSize(80, 22)
    okayBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 18)
    okayBtn:SetText(RA_L["reminder_okay"])
    local hide = opts.hide or function(f) f:Hide() end
    okayBtn:SetScript("OnClick", function() hide(frame) end)
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

    -- ElvUI skin, once at creation.
    if RA.SkinPopupFrame then RA.SkinPopupFrame(frame) end

    return frame
end

-- Left-aligned, wrapping body text anchored below the popup header.
function RA.CreatePopupBodyText(frame)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT",  frame, "TOPLEFT",  10, -40)
    text:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -40)
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

-- Secure spell button; the caller adds the tooltip and calls RA.SetPortalSpell().
function RA.CreatePortalButton(globalName, parent, size)
    local btn = CreateFrame("Button", globalName, parent, "SecureActionButtonTemplate")
    btn:SetSize(size, size)

    local tex = btn:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.iconTexture = tex

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.25)

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints()
    btn.cooldown:SetDrawEdge(false)

    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("type", "spell")
    return btn
end

-- Not in combat (SetAttribute is protected).
function RA.SetPortalSpell(btn, spellID)
    btn.spellID = spellID
    btn:SetAttribute("spell", spellID)
    btn.iconTexture:SetTexture(C_Spell.GetSpellTexture(spellID))
end

-- Unlearned portals look locked; learned ones show their cooldown.
function RA.UpdatePortalButtonState(btn, isKnown, unknownAlpha)
    btn.iconTexture:SetDesaturated(not isKnown)
    btn:SetAlpha(isKnown and 1 or unknownAlpha)

    local start, duration
    if isKnown then start, duration = RA.GetPortalCooldown(btn.spellID) end
    if start then
        btn.cooldown:SetCooldown(start, duration)
    else
        btn.cooldown:Clear()
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
