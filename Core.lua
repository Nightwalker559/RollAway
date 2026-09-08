-- RollAway - Core.lua
-- Shared state, data, utilities and event handling.

local addonName = ...

-- Locale fallback: missing keys return the key itself to prevent UI crashes.
local RA_L = _G["RollAwayLocale"] or {}
setmetatable(RA_L, { __index = function(_, k) return k end })

-- Shared namespace, reused if Data/*.lua already created it.
local RA = _G["RollAway"] or {}
_G["RollAway"] = RA

RA.RA_L               = RA_L
RA.addonName          = addonName
RA.VOIDCORE_CURRENCY_ID = 3418  -- Nebulous Voidcore currency

------------------------------------------------------------------------
-- Season configuration
-- Season 2 is live; no date gate needed anymore.
-- BONUS_ROLLS_ENABLED: Bonus Rolls were disabled in S1, re-enabled for S2.
------------------------------------------------------------------------
RA.BONUS_ROLLS_ENABLED       = true
RA.ACTIVE_SEASON = 2 -- Season 2 is active

------------------------------------------------------------------------
-- Debug output – only for designated developer/tester characters
------------------------------------------------------------------------
local DEV_CHARS = {
    ["Thal\195\174ndra"] = true, -- "Thalîndra", byte-escaped for encoding safety
    ["Asiamonatina"]     = true,
    ["Luckyone"]         = true,
    ["Urannok"]          = true,
    ["Frostbryn"]        = true,
    ["Nirakita"]         = true,
}
RA.DEV_CHARS = DEV_CHARS

local function DBG(...)
    if RollAwayDB and RollAwayDB.debug and DEV_CHARS[UnitName("player")] then
        print("|cff33ff99RollAway-DEBUG:|r", ...)
    end
end
RA.DBG = DBG

------------------------------------------------------------------------
-- API upvalues (resolved once at load time)
------------------------------------------------------------------------
local GetLootRollItemLink = GetLootRollItemLink
local GetInstanceInfo     = GetInstanceInfo
local hooksecurefunc      = hooksecurefunc
local C_Timer_After       = C_Timer and C_Timer.After
local C_Timer_NewTimer    = C_Timer and C_Timer.NewTimer

RA.GetLootRollItemLink = GetLootRollItemLink
RA.hooksecurefunc      = hooksecurefunc
RA.C_Timer_After       = C_Timer_After
RA.C_Timer_NewTimer    = C_Timer_NewTimer

------------------------------------------------------------------------
-- Content data now lives in Data/*.lua (see .toc). Add seasons there.
------------------------------------------------------------------------
local SEASON1_DUNGEONS      = RA.DUNGEONS[1]
local SEASON2_DUNGEONS      = RA.DUNGEONS[2]
local SEASON1_DELVES        = RA.DELVES[1]
local SEASON2_DELVES        = RA.DELVES[2]
local SEASON1_RAIDS         = RA.RAIDS[1]
local SEASON2_RAIDS         = RA.RAIDS[2]
local SEASON1_LEGACY_RAIDS  = RA.LEGACY_RAIDS

------------------------------------------------------------------------
-- Lookup maps – O(1) matching, built once at load time
------------------------------------------------------------------------
local DUNGEON_MAP         = {}
local DUNGEON_ENTRY_MAP   = {}  -- mapID -> full dungeon entry (for cmID/lfgID lookup)
local DELVE_MAP           = {}
local RAID_ENCOUNTER_MAP  = {}
local LEGACY_ENCOUNTER_MAP = {}

for _, d in ipairs(SEASON1_DUNGEONS)     do DUNGEON_MAP[d.mapID] = d.key ; DUNGEON_ENTRY_MAP[d.mapID] = d end
for _, d in ipairs(SEASON2_DUNGEONS)     do DUNGEON_MAP[d.mapID] = d.key ; DUNGEON_ENTRY_MAP[d.mapID] = d end
for _, d in ipairs(SEASON1_DELVES)       do DELVE_MAP[d.mapID]                = d.key  end
for _, d in ipairs(SEASON2_DELVES)       do if d.mapID then DELVE_MAP[d.mapID] = d.key end end
for _, b in ipairs(SEASON1_RAIDS)        do RAID_ENCOUNTER_MAP[b.encounterID] = b.key  end
for _, b in ipairs(SEASON2_RAIDS)        do if b.encounterID then RAID_ENCOUNTER_MAP[b.encounterID] = b.key end end
for _, b in ipairs(SEASON1_LEGACY_RAIDS) do LEGACY_ENCOUNTER_MAP[b.encounterID] = b.raid end

RA.DUNGEON_MAP          = DUNGEON_MAP
RA.DELVE_MAP            = DELVE_MAP
RA.RAID_ENCOUNTER_MAP   = RAID_ENCOUNTER_MAP
RA.LEGACY_ENCOUNTER_MAP = LEGACY_ENCOUNTER_MAP

------------------------------------------------------------------------
-- Raid difficulty bucket map – groups the various difficultyIDs seen
-- across normal raids and raid-instance Lairs/World Bosses into 4 UI
-- buckets. 233 (Mythic Flex) folds into "mythic", 250 (World) folds into
-- "lfr" - both driven by cachedDiffID at ENCOUNTER_END/zone change.
------------------------------------------------------------------------
RA.RAID_DIFFICULTY_BUCKET = {
    [14]  = "normal",
    [15]  = "heroic",
    [16]  = "mythic",
    [17]  = "lfr",
    [233] = "mythic", -- Mythic Flex (Lairs)
    [250] = "lfr",    -- World (Lairs)
}

------------------------------------------------------------------------
-- State variables – shared across all modules
------------------------------------------------------------------------
RA.cachedInstanceType = "none"
RA.cachedInstanceID   = 0
RA.cachedDiffID       = 0
RA.lastEncounterID    = 0
RA.lastLegacyEncounterID = 0
RA.closeTimer            = nil
RA.isHooked              = false
RA.ElvLootModule         = nil
RA.activeRolls           = {}
RA.rollTimers            = {}

------------------------------------------------------------------------
-- Saved variable defaults
------------------------------------------------------------------------
RA.defaults = {
    delay              = 5,
    hideInRaidBuckets  = { lfr = false, normal = false, heroic = false, mythic = false },
    rollTimeout        = 60,
    lootFrameAutoCloseDisabled = false,
    legacy             = false,
    legacyNeed         = false,
    legacyGreed        = true,
    legacyTransmog     = false,
    legacyAccountWide  = false,
    showReminder       = true,
    readyCheckReminder = true,
    lastReminderInstID = nil,
    durabilityWarning    = true,
    expansionFilterAH    = false,
    vaultCurrencyDisplay = true,
    instanceJoinReminder = false,
    joinReminderKeyAddon = "bigwigs", -- "none" | "bigwigs" | "details" | "teleport" – mutually exclusive
    premadeKeyAddon      = "none",    -- "none" | "bigwigs" | "details" – separate choice for manually formed (premade) groups; teleport reminder not offered here (no LFG activity to resolve the exact dungeon)
    lfgQuickCreate       = false,
    lfgAutoPlaystyle     = false,
    lfgDefaultPlaystyle  = 0,
    hideOmniumfoliantMinimap = false,
    vaultButtonCharFrame     = false,
    hideMapActivityTracker   = false,
    hideCraftingOutputLog    = false,
    paragonAlert             = false,
    greatVaultAlert          = false,
    talentFontSize     = 20,
    autoLogEnabled       = false,
    autoLogScenario      = false,
    autoLogMythicDungeon = false,
    autoLogRaidMythic    = true,
    autoLogRaidHeroic    = true,
    autoLogRaidNormal    = false,
    autoLogRaidLFR       = false,
    autoLogDelve         = false,
    autoLogArena         = false,
    autoLogChatNotify    = true,
    debug              = false,
    whatsNewSeen       = "",
    vendorFilterEnabled = false,
    vendorFilterAlpha   = 0.35,
    confirmRoll         = { need = false, greed = false, transmog = false, pass = false },
}

RA.defaultsChar = {
    dungeons     = {},
    dungeons_s2  = {},
    dungeonAutoPassAll = false,
    delves       = {},
    delves_s2    = {},
    delveAutoPassAll = false,
    raids        = {},
    raidAutoPassDifficulty = { lfr = false, normal = false, heroic = false, mythic = false },
    legacy_raids = {},
    prey         = false,
}

-- Active Legacy Raids table: account-wide or per-character.
local function GetLegacyRaidsDB()
    if RollAwayDB and RollAwayDB.legacyAccountWide then
        return RollAwayDB.legacy_raids
    end
    return RollAwayDBChar and RollAwayDBChar.legacy_raids
end
RA.GetLegacyRaidsDB = GetLegacyRaidsDB

------------------------------------------------------------------------
-- Utility functions
------------------------------------------------------------------------

-- StaticPopup names – shared by AutoRoll.lua and RollConfirm.lua to close
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

local function SafeCancelTimer(timer)
    if timer and type(timer) == "table" and timer.Cancel then
        pcall(timer.Cancel, timer)
    end
end
RA.SafeCancelTimer = SafeCancelTimer

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
    okayBtn:SetText(RA.RA_L["reminder_okay"])
    okayBtn:SetScript("OnClick", function() frame:Hide() end)
    frame.okayBtn = okayBtn

    -- Countdown status bar - caller starts/stops it (duration and OnShow/OnHide differ per popup).
    local timer = RA.CreateTimerBar(frame, function() frame:Hide() end)
    frame.bar     = timer.bar
    frame.barText = timer.barText
    frame.timer   = timer

    return frame
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

local function UpdateInstanceCache()
    local ok, instName, instType, diffID, _, _, _, _, instanceID = pcall(GetInstanceInfo)
    RA.cachedInstanceType = (ok and instType)   or "none"
    RA.cachedInstanceID   = (ok and instanceID) or 0
    RA.cachedDiffID       = (ok and diffID)     or 0
    DBG("Instance:", (ok and instName) or "?", "| Type:", RA.cachedInstanceType, "| ID:", RA.cachedInstanceID, "| Diff:", RA.cachedDiffID)
end
RA.UpdateInstanceCache = UpdateInstanceCache

-- Full GetInstanceInfo dump – only called on zone change or via /rawtest.
local function DebugInstanceDump()
    if not RollAwayDB or not RollAwayDB.debug then return end
    local ok, instName, instType, diffID, diffName, maxPlayers, dynDiff, isDynamic, instanceID, groupSize, lfgID = pcall(GetInstanceInfo)
    if not ok then
        DBG("--- GetInstanceInfo dump --- pcall failed:", instName)
        return
    end
    DBG("--- GetInstanceInfo dump ---")
    DBG("  name        =", tostring(instName))
    DBG("  instanceType=", tostring(instType))
    DBG("  difficultyID=", tostring(diffID))
    DBG("  diffName    =", tostring(diffName))
    DBG("  maxPlayers  =", tostring(maxPlayers))
    DBG("  dynDiff     =", tostring(dynDiff))
    DBG("  isDynamic   =", tostring(isDynamic))
    DBG("  instanceID  =", tostring(instanceID))
    DBG("  groupSize   =", tostring(groupSize))
    DBG("  lfgDungeonID=", tostring(lfgID))
    DBG("  cmID (live) =", tostring(C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID()))
    DBG("----------------------------")
    local id = instanceID or 0
    if id ~= 0 then
        local dungKey  = DUNGEON_MAP[id]
        local delveKey = DELVE_MAP[id]
        if dungKey then
            DBG("-> Dungeon matched:", RA_L["dungeon_"..dungKey])
            local entry = DUNGEON_ENTRY_MAP[id]
            DBG("->   cmID =", entry and tostring(entry.cmID)  or "n/a")
            DBG("->   lfgID=", entry and tostring(entry.lfgID) or "n/a")
            DBG("-> Auto-pass:", tostring(RollAwayDBChar and RollAwayDBChar.dungeons and RollAwayDBChar.dungeons[dungKey]))
        elseif delveKey then
            DBG("-> Delve matched:", RA_L["delve_"..delveKey])
            DBG("-> Auto-pass:", tostring(RollAwayDBChar and RollAwayDBChar.delves and RollAwayDBChar.delves[delveKey]))
        else
            DBG("-> No Season 1 dungeon/delve (ID:", id, ")")
        end
    end
    if RA.lastEncounterID ~= 0 then
        local bossKey = RAID_ENCOUNTER_MAP[RA.lastEncounterID]
        if bossKey then
            DBG("-> Raid boss:", RA_L["boss_"..bossKey])
            DBG("-> Auto-pass:", tostring(RollAwayDBChar and RollAwayDBChar.raids and RollAwayDBChar.raids[bossKey]))
        end
    end
end
RA.DebugInstanceDump = DebugInstanceDump

local function HasActiveRolls()
    for _ in pairs(RA.activeRolls) do return true end
    return false
end
RA.HasActiveRolls = HasActiveRolls

-- Deferred by one tick (C_Timer_After 0) so our Hide() call runs on a fresh,
-- untainted execution stack instead of directly inside whatever event handler
-- (START_LOOT_ROLL, ENCOUNTER_END, etc.) triggered it. Calling Hide() on
-- GroupLootHistoryFrame synchronously from insecure code taints that frame's
-- execution context, which later surfaces as unrelated "secret number value"
-- arithmetic errors in Blizzard's own tooltip/layout code (GetUnscaledFrameRect,
-- GameTooltip_InsertFrame) when the player hovers a loot history row.
local function DoHideHistoryFrame()
    if GroupLootHistoryFrame and GroupLootHistoryFrame:IsShown() then
        DBG("Hiding loot history frame")
        GroupLootHistoryFrame:Hide()
    end
    if RA.ElvLootModule and RA.ElvLootModule.GroupLootHistoryFrame
    and RA.ElvLootModule.GroupLootHistoryFrame:IsShown() then
        RA.ElvLootModule.GroupLootHistoryFrame:Hide()
    end
end

local function HideHistoryFrame()
    if C_Timer_After then
        C_Timer_After(0, DoHideHistoryFrame)
    else
        DoHideHistoryFrame()
    end
end
RA.HideHistoryFrame = HideHistoryFrame

local function CancelAllRollTimers()
    for rollID, t in pairs(RA.rollTimers) do
        DBG("Watchdog cancelled:", rollID)
        SafeCancelTimer(t)
    end
    wipe(RA.rollTimers)
end
RA.CancelAllRollTimers = CancelAllRollTimers

-- Resets roll state and timers – does not touch the loot history frame.
local function ResetState(reason)
    DBG("ResetState:", reason)
    CancelAllRollTimers()
    if RA.closeTimer then SafeCancelTimer(RA.closeTimer); RA.closeTimer = nil end
    wipe(RA.activeRolls)
    RA.lastEncounterID = 0
end
RA.ResetState = ResetState

-- Full reset including hiding the loot history frame (group/raid leave only).
local function FullReset(reason)
    DBG("FullReset:", reason)
    ResetState(reason)
    RA.lastLegacyEncounterID = 0
    -- Clear reminder state so the next raid/dungeon entry shows the reminder again.
    if RollAwayDB then
        RollAwayDB.lastReminderInstID = nil
        DBG("Reminder reset: FullReset triggered by:", reason)
    end
    HideHistoryFrame()
end
RA.FullReset = FullReset

local function ShouldHideInInstance()
    if not RollAwayDB or RollAwayDB.lootFrameAutoCloseDisabled then return false end
    if RA.cachedInstanceType ~= "raid" then return false end
    local bucket = RA.RAID_DIFFICULTY_BUCKET[RA.cachedDiffID]
    if not bucket or not RollAwayDB.hideInRaidBuckets then return false end
    return RollAwayDB.hideInRaidBuckets[bucket] == true
end
RA.ShouldHideInInstance = ShouldHideInInstance

local function TryStartCloseTimer()
    if RollAwayDB and RollAwayDB.lootFrameAutoCloseDisabled then return end
    if HasActiveRolls() or RA.closeTimer then return end
    DBG("Starting close timer:", RollAwayDB.delay, "sec")
    if C_Timer_NewTimer then
        RA.closeTimer = C_Timer_NewTimer(RollAwayDB.delay, function()
            DBG("Close timer expired")
            HideHistoryFrame()
            RA.closeTimer = nil
        end)
    elseif C_Timer_After then
        C_Timer_After(RollAwayDB.delay, function()
            if not HasActiveRolls() then
                DBG("Close timer expired (After fallback)")
                HideHistoryFrame()
            end
            RA.closeTimer = nil
        end)
        RA.closeTimer = true
    else
        DBG("WARNING: No timer API available")
    end
end
RA.TryStartCloseTimer = TryStartCloseTimer

-- Called once after all rolls complete to decide whether to start close timer.
local function CheckAndClose()
    if not HasActiveRolls() then
        wipe(RA.activeRolls)
        if not ShouldHideInInstance() then TryStartCloseTimer() end
    end
end

------------------------------------------------------------------------
-- Event handler
------------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("START_LOOT_ROLL")
f:RegisterEvent("LOOT_ROLLS_COMPLETE")
f:RegisterEvent("ENCOUNTER_END")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("GROUP_LEFT")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")

f:SetScript("OnEvent", function(_, event, ...)
    local arg1 = (...)

    if event == "START_LOOT_ROLL" then
        DBG("START_LOOT_ROLL rollID:", arg1)

        RA.activeRolls[arg1] = true

        if RA.closeTimer then SafeCancelTimer(RA.closeTimer); RA.closeTimer = nil end

        -- Watchdog: force-closes frame if LOOT_ROLLS_COMPLETE never fires cleanly.
        -- Skipped entirely if the whole auto-close feature is disabled in Options.
        if C_Timer_NewTimer and not RA.rollTimers[arg1] and not (RollAwayDB and RollAwayDB.lootFrameAutoCloseDisabled) then
            local wdID = arg1
            RA.rollTimers[wdID] = C_Timer_NewTimer(RollAwayDB.rollTimeout, function()
                DBG("Watchdog expired for rollID", wdID)
                RA.rollTimers[wdID] = nil
                RA.activeRolls[wdID] = nil
                if not HasActiveRolls() then
                    wipe(RA.activeRolls)
                    CancelAllRollTimers()
                    HideHistoryFrame()
                end
            end)
        end

        if ShouldHideInInstance() then HideHistoryFrame() end

        -- Legacy auto-roll
        if RollAwayDB and RollAwayDB.legacy and RA.ExecuteLegacyRoll then
            local raidKey = LEGACY_ENCOUNTER_MAP[RA.lastLegacyEncounterID]
            local legacyRaidsDB = GetLegacyRaidsDB()
            if raidKey and legacyRaidsDB and legacyRaidsDB[raidKey] then
                DBG("[Legacy] Auto-roll for rollID:", arg1, "| raid:", raidKey)
                RA.ExecuteLegacyRoll(arg1)
            end
        end

    elseif event == "LOOT_ROLLS_COMPLETE" then
        DBG("LOOT_ROLLS_COMPLETE arg1:", arg1)

        -- Remove the completed roll and its watchdog.
        RA.activeRolls[arg1] = nil
        SafeCancelTimer(RA.rollTimers[arg1])
        RA.rollTimers[arg1] = nil

        -- Clean up stale rolls with no valid item link (concurrent rolls only).
        if next(RA.activeRolls) then
            for rollID in pairs(RA.activeRolls) do
                if not GetLootRollItemLink(rollID) then
                    SafeCancelTimer(RA.rollTimers[rollID])
                    RA.rollTimers[rollID] = nil
                    RA.activeRolls[rollID] = nil
                end
            end
        end

        if C_Timer_After then C_Timer_After(0.1, CheckAndClose) else CheckAndClose() end

    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName, _, _, endStatus = ...
        if endStatus == 1 then
            DBG("ENCOUNTER_END kill | encounterID:", encounterID, "| name:", encounterName)
            if RAID_ENCOUNTER_MAP[encounterID] then
                RA.lastEncounterID = encounterID
            elseif LEGACY_ENCOUNTER_MAP[encounterID] then
                RA.lastLegacyEncounterID = encounterID
                DBG("[Legacy] Raid matched:", LEGACY_ENCOUNTER_MAP[encounterID])
            end
        end

    elseif event == "GROUP_LEFT" then
        FullReset("GROUP_LEFT")

    elseif event == "PLAYER_REGEN_DISABLED" then
        ResetState("PLAYER_REGEN_DISABLED")
        if ShouldHideInInstance() then
            DBG("Combat in raid (hidden difficulty) – hiding frame")
            HideHistoryFrame()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if RA.pendingProtectedAction then
            local fn = RA.pendingProtectedAction
            RA.pendingProtectedAction = nil
            fn()
        end

    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if not RA.initialized then return end  -- wait for ADDON_LOADED
        UpdateInstanceCache()
        ResetState(event)
        RA.lastLegacyEncounterID = 0
        -- Note: lastReminderInstID is only reset on GROUP_LEFT (see Reminder.lua)
        DBG("Zone changed: instanceType=", RA.cachedInstanceType, "instanceID=", RA.cachedInstanceID)
        DebugInstanceDump()
        if ShouldHideInInstance() then HideHistoryFrame() end
        C_Timer_After(2, function()
            if RA.ShowReminder then RA.ShowReminder() end
        end)

    elseif event == "ADDON_LOADED" and arg1 == addonName then

        _G.RollAwayDB = _G.RollAwayDB or {}
        RollAwayDB = _G.RollAwayDB

        -- Migration (pre-2.6.3): joinReminderBigWigs (boolean) -> joinReminderKeyAddon (string).
        if RollAwayDB.joinReminderKeyAddon == nil and RollAwayDB.joinReminderBigWigs ~= nil then
            RollAwayDB.joinReminderKeyAddon = RollAwayDB.joinReminderBigWigs and "bigwigs" or "none"
        end
        RollAwayDB.joinReminderBigWigs = nil

        -- Migration (pre-3.0.0): premadeKeyAddon didn't exist yet - default it
        -- from the old single joinReminderKeyAddon so users who already had
        -- BigWigs/Details working for premade groups keep that behavior.
        -- "teleport" isn't carried over: it can't resolve a specific dungeon
        -- for a manually formed group, so it wasn't useful there anyway.
        if RollAwayDB.premadeKeyAddon == nil then
            local old = RollAwayDB.joinReminderKeyAddon
            RollAwayDB.premadeKeyAddon = (old == "bigwigs" or old == "details") and old or "none"
        end

        -- Migration (pre-2.9.0): hideInRaid (single bool) -> hideInRaidBuckets (per-difficulty).
        if RollAwayDB.hideInRaidBuckets == nil and RollAwayDB.hideInRaid ~= nil then
            local v = RollAwayDB.hideInRaid
            RollAwayDB.hideInRaidBuckets = { lfr = v, normal = v, heroic = v, mythic = v }
        end
        RollAwayDB.hideInRaid = nil

        for k, v in pairs(RA.defaults) do
            if RollAwayDB[k] == nil then RollAwayDB[k] = v end
        end

        _G.RollAwayDBChar = _G.RollAwayDBChar or {}
        RollAwayDBChar = _G.RollAwayDBChar
        for k, v in pairs(RA.defaultsChar) do
            if RollAwayDBChar[k] == nil then RollAwayDBChar[k] = v end
        end

        if type(RollAwayDBChar.dungeons) ~= "table" then RollAwayDBChar.dungeons = {} end
        if type(RollAwayDBChar.dungeons_s2) ~= "table" then RollAwayDBChar.dungeons_s2 = {} end
        for _, d in ipairs(SEASON2_DUNGEONS) do
            if RollAwayDBChar.dungeons_s2[d.key] == nil then RollAwayDBChar.dungeons_s2[d.key] = false end
        end
        for _, d in ipairs(SEASON1_DUNGEONS) do
            if RollAwayDBChar.dungeons[d.key] == nil then RollAwayDBChar.dungeons[d.key] = false end
        end

        if type(RollAwayDBChar.delves) ~= "table" then RollAwayDBChar.delves = {} end
        for _, d in ipairs(SEASON1_DELVES) do
            if d.removedAfterS1 and RA.ACTIVE_SEASON >= 2 then
                RollAwayDBChar.delves[d.key] = false -- no longer obtainable in-game, keep disabled
            elseif RollAwayDBChar.delves[d.key] == nil then
                RollAwayDBChar.delves[d.key] = false
            end
        end

        if type(RollAwayDBChar.delves_s2) ~= "table" then RollAwayDBChar.delves_s2 = {} end
        for _, d in ipairs(SEASON2_DELVES) do
            if RollAwayDBChar.delves_s2[d.key] == nil then RollAwayDBChar.delves_s2[d.key] = false end
        end

        if type(RollAwayDBChar.raids) ~= "table" then RollAwayDBChar.raids = {} end
        for _, b in ipairs(SEASON1_RAIDS) do
            if RollAwayDBChar.raids[b.key] == nil then RollAwayDBChar.raids[b.key] = false end
        end
        for _, b in ipairs(SEASON2_RAIDS) do
            if RollAwayDBChar.raids[b.key] == nil then RollAwayDBChar.raids[b.key] = false end
        end

        if type(RollAwayDBChar.legacy_raids) ~= "table" then RollAwayDBChar.legacy_raids = {} end
        for _, b in ipairs(SEASON1_LEGACY_RAIDS) do
            if RollAwayDBChar.legacy_raids[b.raid] == nil then
                RollAwayDBChar.legacy_raids[b.raid] = false
            end
        end

        -- Account-wide mirror of legacy_raids (used when legacyAccountWide is enabled).
        if type(RollAwayDB.legacy_raids) ~= "table" then RollAwayDB.legacy_raids = {} end
        for _, b in ipairs(SEASON1_LEGACY_RAIDS) do
            if RollAwayDB.legacy_raids[b.raid] == nil then
                RollAwayDB.legacy_raids[b.raid] = false
            end
        end

        if RollAwayDBChar.prey == nil then RollAwayDBChar.prey = false end

        if type(RollAwayDBChar.raidAutoPassDifficulty) ~= "table" then
            RollAwayDBChar.raidAutoPassDifficulty = { lfr = false, normal = false, heroic = false, mythic = false }
        end

        if type(RollAwayDB.confirmRoll) ~= "table" then
            RollAwayDB.confirmRoll = { need = false, greed = false, transmog = false, pass = false }
        else
            for _, k in ipairs({ "need", "greed", "transmog", "pass" }) do
                if RollAwayDB.confirmRoll[k] == nil then RollAwayDB.confirmRoll[k] = false end
            end
        end

        -- Sort dungeons and delves alphabetically by localized name.
        table.sort(SEASON1_DUNGEONS, function(a, b)
            return RA_L["dungeon_"..a.key] < RA_L["dungeon_"..b.key]
        end)
        table.sort(SEASON1_DELVES, function(a, b)
            return RA_L["delve_"..a.key] < RA_L["delve_"..b.key]
        end)

        if ElvUI then
            local E = unpack(ElvUI)
            if E and E.GetModule then RA.ElvLootModule = E:GetModule("Loot", true) end
        end

        if RA.InitWhatsNew         then RA.InitWhatsNew()         end
        if RA.InitAutoPass        then RA.InitAutoPass()        end
        if RA.InitAutoRoll        then RA.InitAutoRoll()        end
        if RA.InitRollConfirm     then RA.InitRollConfirm()     end
        if RA.InitReminder        then RA.InitReminder()        end
        if RA.InitTeleportReminder then RA.InitTeleportReminder() end
        if RA.InitQoL             then RA.InitQoL()             end
        if RA.InitVendorFilter    then RA.InitVendorFilter()    end
        if RA.InitParagon         then RA.InitParagon()         end
        if RA.InitGreatVault      then RA.InitGreatVault()      end
        if RA.InitLFGQuickCreate  then RA.InitLFGQuickCreate()  end
        if RA.InitOptions         then RA.InitOptions()         end
        if RA.InitDebug           then RA.InitDebug()           end

        -- Hook Show at startup so auto-hide works on the first roll too.
        if GroupLootHistoryFrame then
            hooksecurefunc(GroupLootHistoryFrame, "Show", function()
                if ShouldHideInInstance() and HasActiveRolls() then
                    HideHistoryFrame()
                end
            end)
            RA.isHooked = true
        end

        RA.initialized = true
        DBG("RollAway initialized")
    end
end)