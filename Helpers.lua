-- RollAway - Helpers.lua
-- Generic, reusable utility functions with no bootstrapping/domain-state
-- logic of their own - popup frame factories, timers, table/util helpers.
-- Loads right after Core.lua so RA.DBG/RA.RA_L are already set.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local C_Timer_After    = C_Timer and C_Timer.After
local C_Timer_NewTimer = C_Timer and C_Timer.NewTimer

------------------------------------------------------------------------
-- Generic table/timer utilities
------------------------------------------------------------------------

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do copy[k] = DeepCopy(v) end
    return copy
end
RA.DeepCopy = DeepCopy

local function SafeCancelTimer(timer)
    if timer and type(timer) == "table" and timer.Cancel then
        pcall(timer.Cancel, timer)
    end
end
RA.SafeCancelTimer = SafeCancelTimer

-- StaticPopup names - shared by AutoRoll.lua and RollConfirm.lua to close
-- Blizzard's own BoP roll-confirmation popup after we've handled it ourselves.
local STATIC_POPUPS = {}
for i = 1, 10 do STATIC_POPUPS[i] = "StaticPopup"..i end
RA.STATIC_POPUPS = STATIC_POPUPS

-- Closes any shown native loot-roll/confirm-roll popup. Used right after we
-- programmatically roll or confirm a roll, so Blizzard's own popup for the
-- same action doesn't linger on screen.
local function CloseLootRollPopups(debugTag)
    for i = 1, 10 do
        local popup = _G[STATIC_POPUPS[i]]
        if popup and popup:IsShown() then
            local which = popup.which or ""
            if which:find("LOOT_ROLL") or which:find("CONFIRM_ROLL") then
                popup:Hide()
                DBG(debugTag or "[Core]", "Closed popup:", which)
            end
        end
    end
end
RA.CloseLootRollPopups = CloseLootRollPopups

-- Standard left-click-drag behavior for RollAway popups.
function RA.MakeDraggable(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
end

-- Runs fn() immediately, unless we're in combat (protected/secure API calls
-- like Settings.OpenToCategory are blocked during combat lockdown). In that
-- case fn is queued and runs automatically on the next PLAYER_REGEN_ENABLED.
-- Only one action can be queued at a time; a newer call replaces the older one.
function RA.RunProtectedOrQueue(fn)
    if InCombatLockdown() then
        RA.pendingProtectedAction = fn
        print("|cff33ff99RollAway:|r " .. RA_L["combat_action_queued"])
        return false
    end
    fn()
    return true
end

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

    local lastShownSecond = -1

    local function Stop()
        bar:SetScript("OnUpdate", nil)
        lastShownSecond = -1
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

------------------------------------------------------------------------
-- Shared popup-notification frame factory - Reminder.lua, Paragon.lua and
-- GreatVault.lua each show a small backdrop popup at the top of the screen
-- with the same chrome: draggable, ESC-closable, gold "RollAway" title next
-- to the addon icon, a countdown bar, and an "Okay" button that hides the
-- frame. This factory builds exactly that shared chrome; callers add their
-- own content (message text, rows, extra buttons) and are still responsible
-- for the OnShow height calc and starting/stopping the returned timer,
-- since those differ per popup.
--
-- opts:
--   name      - global frame name (also used for the ESC-close registration)
--   okayName  - global name for the "Okay" button
--   width, height - initial SetSize (height is typically recalculated by
--                   the caller's OnShow once content is laid out)
--   yOffset   - initial TOP anchor Y offset below UIParent's TOP
--
-- Returns the frame with these extra fields already set up:
--   .iconHolder, .icon, .titleText - header chrome
--   .okayBtn                       - bottom-right button, wired to Hide()
--   .bar, .barText, .timer         - from RA.CreateTimerBar (timer = {Start, Stop})
-- Global frame/button names are kept explicit (not derived) so ElvUI_Skin.lua's
-- _G[...] lookups for these frames keep working unchanged.
------------------------------------------------------------------------
function RA.CreatePopupFrame(opts)
    local frame = CreateFrame("Frame", opts.name, UIParent, "BackdropTemplate")
    frame:SetSize(opts.width, opts.height)
    frame:SetPoint("TOP", UIParent, "TOP", 0, opts.yOffset)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    RA.MakeDraggable(frame)
    frame:Hide()

    -- ESC closes the frame
    tinsert(UISpecialFrames, opts.name)

    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

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
    okayBtn:SetScript("OnClick", function() frame:Hide() end)
    frame.okayBtn = okayBtn

    -- Countdown status bar - caller starts/stops it (duration and OnShow/OnHide differ per popup).
    local timer = RA.CreateTimerBar(frame, function() frame:Hide() end)
    frame.bar     = timer.bar
    frame.barText = timer.barText
    frame.timer   = timer

    -- ElvUI skin (if loaded): applied once, right here at creation, instead
    -- of each caller hooking its own Show function individually. Skinning
    -- at construction time (this factory only ever runs once per frame -
    -- callers guard with "if xFrame then return end") is simpler and safer
    -- than hooksecurefunc: there's no local-upvalue-vs-table-field pitfall
    -- to get wrong, since nothing needs hooking in the first place.
    if RA.SkinPopupFrame then RA.SkinPopupFrame(frame) end

    return frame
end

-- Stacks `frame` directly below the first currently-shown frame among
-- `aboveNames` (checked in priority order, by global name), or at `frame`'s
-- own default TOP position if none of them are shown. Shared by the popup
-- notifications (Reminder/Paragon/GreatVault/AdvLog) so any combination
-- can be shown together without overlapping - a new popup only needs to
-- list what it should stack below, not re-implement the chain.
function RA.StackPopupFrame(frame, aboveNames, defaultYOffset)
    frame:ClearAllPoints()
    for _, name in ipairs(aboveNames) do
        local above = _G[name]
        if above and above:IsShown() then
            frame:SetPoint("TOP", above, "BOTTOM", 0, -10)
            return
        end
    end
    frame:SetPoint("TOP", UIParent, "TOP", 0, defaultYOffset)
end

------------------------------------------------------------------------
-- Shared helper for "show once per instance" reminder popups built on
-- RA.CreatePopupFrame (currently: Reminder.lua's Voidcore reminder and
-- Logs.lua's Advanced Combat Logging reminder).
------------------------------------------------------------------------

-- Wires the common popup lifecycle: hide on pull (PLAYER_REGEN_DISABLED),
-- and clear the dedup key on GROUP_LEFT/GROUP_JOINED so the reminder can
-- fire again for the next instance.
-- Note: GROUP_JOINED does NOT hide the frame. When queuing as a partial
-- group (e.g. 2 of 5) via the automatic Dungeon Finder, Blizzard merges
-- everyone into a new group right around the time you enter the instance -
-- GROUP_JOINED can fire a moment after the reminder is shown and was
-- hiding it immediately (reminder appeared to "never show"). Only the
-- dedup key needs resetting there; a currently-shown reminder is still
-- valid for the instance you're actually standing in.
function RA.SetupInstanceReminderLifecycle(frame, dedupKey)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("GROUP_LEFT")
    frame:RegisterEvent("GROUP_JOINED")
    frame:SetScript("OnEvent", function(self, event)
        if event ~= "GROUP_JOINED" then
            self:Hide()
        end
        if event == "GROUP_LEFT" or event == "GROUP_JOINED" then
            RollAwayDB[dedupKey] = nil
        end
    end)
end

-- Simple Start()/Stop() one-shot timer for short-lived QoL popups.
function RA.CreateOneShotTimer(seconds, callback)
    local timer

    local function Stop()
        if timer then SafeCancelTimer(timer); timer = nil end
    end

    local function Start()
        Stop()
        if C_Timer_NewTimer then
            timer = C_Timer_NewTimer(seconds, function()
                timer = nil
                callback()
            end)
        elseif C_Timer_After then
            C_Timer_After(seconds, callback)
        end
    end

    return { Start = Start, Stop = Stop }
end
