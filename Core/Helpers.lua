-- RollAway - Core/Helpers.lua
-- Generic, reusable utility functions with no bootstrapping/domain-state
-- logic of their own - popup/toast frame factories, timers, portal buttons,
-- loot-roll button lookup, table/util helpers.
-- Loads right after Core/Core.lua so RA.DBG/RA.RA_L are already set.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

------------------------------------------------------------------------
-- Generic utilities
------------------------------------------------------------------------

-- Waits for an on-demand Blizzard addon to finish loading, then runs fn()
-- once and stops listening. Use when a frame/API from that addon isn't
-- available yet (e.g. a "HookXFrame()" attempt returned false) and there's
-- no more specific event to hang the retry on.
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

-- Shared chat-print prefix for the small set of genuinely user-facing
-- messages (auto-repair cost, manual-check "none found", etc.) - distinct
-- from DBG()/DBGError(), which are dev-only and never print to chat.
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

-- 12.x "secret values": during combat/encounters some API results can't be
-- compared, indexed or concatenated by addon code (doing so is a Lua error).
-- False for such a value; true for everything else (also on clients without
-- the secret-value API).
function RA.IsAccessible(value)
    return not canaccessvalue or canaccessvalue(value)
end

-- Shared "is the player max level" check (vault currency display, Omnium/
-- Vault Character panel buttons, options gating).
function RA.IsMaxLevel()
    return UnitLevel("player") >= GetMaxPlayerLevel()
end

-- Reminder text: instance name plus the listed keystone level ("+14", gold)
-- when one is known.
function RA.FormatInstanceWithKey(name, keyLevel)
    if not keyLevel then return name end
    return name .. " |cffFFD100+" .. keyLevel .. "|r"
end

-- The Mythic+ keystone currently in the player's bags, if any: activity ID
-- (matches a dungeon's lfgID) and keystone level.
function RA.GetOwnedKeystone()
    if not C_LFGList then return nil, nil end
    local lfgID, _, level = C_LFGList.GetOwnedKeystoneActivityAndGroupAndLevel()
    return lfgID, level
end

-- Returns a NEW array with the same elements as `list`, sorted by the
-- string labelFn(entry) returns - case-insensitive, plain byte order
-- (WoW's Lua sandbox has no locale-aware collation, so umlauts etc. sort
-- byte-wise; acceptable for short dungeon/addon-name lists). Does not
-- mutate `list`, so callers that need a stable index pairing with a
-- separate structure (e.g. a button pool built in the original order)
-- should sort before building that structure, not after.
function RA.SortByLabel(list, labelFn)
    local sorted = {}
    for i = 1, #list do sorted[i] = list[i] end
    table.sort(sorted, function(a, b)
        return (labelFn(a) or ""):lower() < (labelFn(b) or ""):lower()
    end)
    return sorted
end

-- Registers a StaticPopup with the defaults every RollAway dialog shares
-- (no timeout, usable while dead, closes on Escape, first free slot).
-- `def` overrides any of them.
function RA.RegisterPopup(name, def)
    if def.timeout == nil        then def.timeout        = 0    end
    if def.whileDead == nil      then def.whileDead      = true end
    if def.hideOnEscape == nil   then def.hideOnEscape   = true end
    if def.preferredIndex == nil then def.preferredIndex = 3    end
    StaticPopupDialogs[name] = def
end

-- Runs fn() immediately, unless we're in combat (protected/secure API calls
-- like Settings.OpenToCategory are blocked during combat lockdown). In that
-- case fn is queued and runs automatically on the next PLAYER_REGEN_ENABLED.
-- Only one action can be queued at a time; a newer call replaces the older one.
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

-- Hiding/showing a frame that has SecureActionButtonTemplate descendants
-- (our portal buttons) is a protected action while in combat lockdown -
-- regardless of what triggers the call (event handler, OnClick, slash
-- command). Calling frame:Hide()/:Show() directly during combat throws
-- ADDON_ACTION_BLOCKED. Use this everywhere instead for such frames; if
-- called during combat it just defers the change until combat ends.
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

-- Same as RA.MakeDraggable, but respects RollAwayDB.qolReminderLockPosition -
-- checked live on every drag attempt, so toggling the "lock position" option
-- takes effect immediately with no per-frame bookkeeping. Used by the QoL
-- toast/join reminder popups, which the user can lock in place.
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

-- Dark tooltip-style backdrop shared by all RollAway popup/portal frames.
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

-- Countdown StatusBar for auto-hide popups. Returns { bar, barText, Start, Stop }.
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

-- Simple Start()/Stop() one-shot timer for short-lived QoL popups.
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
-- Shared popup-notification frame factory - Reminder.lua, Paragon.lua,
-- GreatVault.lua and Logs.lua (AdvLog) each show a small backdrop popup at
-- the top of the screen with the same chrome: draggable, ESC-closable, gold
-- "RollAway" title next to the addon icon, a countdown bar, and an "Okay"
-- button that hides the frame. This factory builds exactly that shared
-- chrome plus the OnShow/OnHide lifecycle (deferred height fit + countdown);
-- callers add their own content (message text, rows, extra buttons).
--
-- opts:
--   name      - global frame name (also used for the ESC-close registration)
--   okayName  - global name for the "Okay" button
--   width, height - initial size; height doubles as the minimum height
--   yOffset   - initial TOP anchor Y offset below UIParent's TOP
--   duration  - countdown in seconds before the popup hides itself
--   fitHeight - optional function(frame) -> total desired height, evaluated
--               one frame after OnShow (once the content is laid out). The
--               popup is never made smaller than `height`.
--   hide      - optional function(frame) that closes the popup, used by the
--               Okay button and the countdown (default: frame:Hide()). A popup
--               with secure buttons needs RA.SafeSetShown(frame, false) here.
--
-- Returns the frame with these extra fields already set up:
--   .iconHolder, .icon, .titleText - header chrome
--   .okayBtn                       - bottom-right button, closes the popup
--   .bar, .barText, .timer         - from RA.CreateTimerBar
-- Global frame/button names are kept explicit (not derived) so ElvUI_Skin.lua's
-- _G[...] lookups for these frames keep working unchanged.
------------------------------------------------------------------------

-- Fixed vertical space taken by header (icon/title) + footer (button, bar,
-- padding), for fitHeight callbacks: RA.POPUP_CHROME_HEIGHT + body height.
RA.POPUP_CHROME_HEIGHT = 88

function RA.CreatePopupFrame(opts)
    local frame = CreateFrame("Frame", opts.name, UIParent, "BackdropTemplate")
    frame:SetSize(opts.width, opts.height)
    frame:SetPoint("TOP", UIParent, "TOP", 0, opts.yOffset)
    frame.defaultY = opts.yOffset  -- where RA.StackPopupFrame puts it when nothing is above it
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    RA.MakeDraggable(frame)
    frame:Hide()

    -- ESC closes the frame
    tinsert(UISpecialFrames, opts.name)

    RA.ApplyPopupBackdrop(frame)

    -- Own holder frame to stay above ElvUI's backdrop child after skinning.
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

    -- Countdown status bar, started/stopped by OnShow/OnHide below.
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

    -- ElvUI skin (if loaded), applied once at creation - callers only run
    -- this factory once per frame.
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

-- The popup notifications always sit in this order, top to bottom. A fixed
-- order is what keeps the anchors free of loops: a frame is only ever
-- anchored below one that comes earlier in the list.
local POPUP_STACK_ORDER = {
    "RollAwayReminderFrame", "RollAwayParagonFrame", "RollAwayGreatVaultFrame",
    "RollAwayAdvLogFrame", "RollAwayTankMarkFrame",
}

-- Lays out `frame` (about to be shown) together with every popup that is
-- shown right now, in POPUP_STACK_ORDER: the first one at its own default TOP
-- position (opts.yOffset of CreatePopupFrame), each next one directly below
-- the previous. So any combination can be shown without overlapping, and a
-- new popup only has to be added to the list above. In combat only `frame`
-- is placed: popups with secure buttons must not be moved then.
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

-- Wires the common "show once per instance" popup lifecycle (Reminder.lua's
-- Voidcore reminder, Logs.lua's Advanced Combat Logging reminder): hide on
-- pull (PLAYER_REGEN_DISABLED) and on GROUP_LEFT, and clear the dedup key on
-- GROUP_LEFT/GROUP_JOINED so the reminder can fire again for the next
-- instance.
-- GROUP_JOINED deliberately does NOT hide the frame: when queuing as a
-- partial group via the Dungeon Finder, Blizzard merges everyone into a new
-- group around the time you enter the instance, so it can fire right after
-- the reminder was shown - which is still valid for that instance.
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
-- QoL "toast" frames (Ready Check, Durability, Instance Join): centered,
-- draggable (lockable), text-only, auto-hidden by a 6s one-shot timer the
-- caller starts. Every toast is registered so the options' "reset position"
-- button can move them all back to their default spot.
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

-- Only touches toasts that were already created (lazily, on first show) -
-- uncreated ones are still at their default position.
function RA.ResetToastPositions()
    for _, frame in ipairs(toastFrames) do
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, frame.defaultY)
    end
end

------------------------------------------------------------------------
-- Portal (dungeon teleport) buttons - shared by the Teleport Reminder and
-- the Portal Overview.
------------------------------------------------------------------------

-- Ignore GetSpellCooldown durations at/below the GCD - those aren't a real
-- "on cooldown" state, just the brief global cooldown after any cast.
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

-- Secure spell button with icon, hover highlight and cooldown swirl. The
-- caller adds the tooltip and calls RA.SetPortalSpell().
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

-- SetAttribute is protected in combat - callers must not run this then.
function RA.SetPortalSpell(btn, spellID)
    btn.spellID = spellID
    btn:SetAttribute("spell", spellID)
    btn.iconTexture:SetTexture(C_Spell.GetSpellTexture(spellID))
end

-- Locked look (desaturated/dimmed) for unlearned portals, cooldown swirl for
-- learned ones that are really on cooldown.
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
-- Loot roll buttons - shared by AutoRoll.lua and RollConfirm.lua. A roll is
-- shown either by Blizzard's GroupLootFrameN or, with ElvUI, by
-- ElvUI_LootRollFrameN (whose buttons have no fixed field names, only
-- localized global-name fragments).
------------------------------------------------------------------------

-- dbKey, native button field, ElvUI button name fragments (localized).
RA.ROLL_BUTTONS = {
    { dbKey = "need",     nativeField = "NeedButton",     elvNames = { "Bedarf", "Need" } },
    { dbKey = "greed",    nativeField = "GreedButton",    elvNames = { "Gier", "Greed" } },
    { dbKey = "transmog", nativeField = "TransmogButton", elvNames = { "Transmog" } },
    { dbKey = "pass",     nativeField = "PassButton",     elvNames = { "Passen", "Pass" } },
}

local NATIVE_FIELD_BY_KEY = {}
for _, def in ipairs(RA.ROLL_BUTTONS) do NATIVE_FIELD_BY_KEY[def.dbKey] = def.nativeField end

local elvRollButtons = {}  -- [frameIndex] = { need = btn, greed = btn, ... }

-- ElvUI_LootRollFrame<i>'s buttons keyed by dbKey (one pass over its children,
-- cached - they never change), or nil while that frame doesn't exist (yet).
function RA.GetElvRollButtons(i)
    if elvRollButtons[i] then return elvRollButtons[i] end
    local elvFrame = _G["ElvUI_LootRollFrame"..i]
    if not elvFrame then return nil end

    local found = {}
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

-- The visible roll-frame button (native or ElvUI) of type dbKey for rollID,
-- or nil if that roll isn't shown / the button couldn't be found.
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

-- Auto-confirms the bind-on-pickup prompt of a roll RollAway rolled itself.
-- Call RA.ArmRollConfirm(rollID) right before the roll; when the game asks for
-- the confirmation (CONFIRM_LOOT_ROLL) the roll is confirmed and Blizzard's
-- own popup for it is dropped. Rolls that were not armed are left alone.
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
    -- Blizzard's handler for the same event shows its popup; drop it once it exists.
    RunNextFrame(function() StaticPopup_Hide("CONFIRM_LOOT_ROLL", rollID) end)
end)
