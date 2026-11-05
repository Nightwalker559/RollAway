-- RollAway - Modules/HideUI.lua
-- Hides parts of Blizzard's UI on request (QoL page "Hide"): map overlays, crafting output
-- log, red error text, Talking Head, boss banner, event toasts, alerts. Each feature has an
-- RA.Apply<Feature>() that the options call when the checkbox changes; RA.InitHideUI()
-- applies them all at login.

local RA   = _G["RollAway"]
local DBG  = RA.DBG

------------------------------------------------------------------------
-- World Map: hide the faction activity button, the bounty board and the threat eye.
-- Blizzard creates them once as overlay frames of WorldMapFrame (tracker: a Button
-- with BountyDropdown; board: a Frame with BountyName; eye: a Frame with Eye) and
-- re-shows them in their Refresh(). They are found in WorldMapFrame.overlayFrames
-- and hidden again right after each Refresh() (no flash); the coordinates panel
-- moves along. Turning the option off needs no restore.
------------------------------------------------------------------------

local mapOverlays          -- the overlay frames found (any of them may be missing)
local mapOverlaysHooked

local function FindMapOverlays()
    if mapOverlays then return mapOverlays end
    local found = {}
    for _, frame in ipairs(WorldMapFrame and WorldMapFrame.overlayFrames or {}) do
        if frame.Refresh and frame.IsObjectType then
            -- Tracker and board share methods: tell them apart by their children.
            if frame.BountyDropdown and frame:IsObjectType("Button") then
                found[#found + 1] = frame
            elseif frame.BountyName and frame.CalculateNumActivitiesForSelectedBountyByMap then
                found[#found + 1] = frame
            elseif frame.Eye and frame.ModelSceneTop then
                found[#found + 1] = frame
            end
        end
    end
    if #found > 0 then mapOverlays = found end
    return found
end

local loggedMapOverlays = {}  -- log the first hide only

local function MapOverlayLabel(frame)
    return frame.BountyDropdown and "activity tracker" or frame.BountyName and "bounty board" or "threat eye"
end

local function HideMapOverlay(frame)
    if RollAwayDB and RollAwayDB.hideMapActivityTracker and frame:IsShown() then
        frame:Hide()
        if not loggedMapOverlays[frame] then
            loggedMapOverlays[frame] = true
            DBG("[QoL] Hid map overlay:", MapOverlayLabel(frame))
        end
    end
end

function RA.ApplyMapActivityTrackerFeature()
    -- Nothing to hook while the option is off and never was on.
    if not mapOverlaysHooked and not (RollAwayDB and RollAwayDB.hideMapActivityTracker) then return end

    local overlays = FindMapOverlays()
    if #overlays == 0 then
        DBG("[QoL] Map overlay frames not found – skipped")
        return
    end

    if not mapOverlaysHooked then
        mapOverlaysHooked = true
        for _, frame in ipairs(overlays) do
            hooksecurefunc(frame, "Refresh", HideMapOverlay)
        end
    end
    for _, frame in ipairs(overlays) do HideMapOverlay(frame) end
end

------------------------------------------------------------------------
-- Professions: hide the "Crafting Output Log" popup. Blizzard fills and opens it
-- through ProfessionsCraftingOutputLogMixin:FinalizeResultData() after every craft;
-- we hook that and hide the panel again. There are two instances (own crafting:
-- CraftingPage.CraftingOutputLog, orders: OrdersPage.OrderView.CraftingOutputLog);
-- hooksecurefunc(obj, ...) is per object, so each gets its own hook.
------------------------------------------------------------------------

local hookedOutputLogs = {}

local function ApplyToOutputLog(log)
    if not log then return end
    if not hookedOutputLogs[log] then
        hookedOutputLogs[log] = true
        hooksecurefunc(log, "FinalizeResultData", function(self)
            if RollAwayDB and RollAwayDB.hideCraftingOutputLog then
                self:Hide()
            end
        end)
        DBG("[QoL] CraftingOutputLog hide hook set")
    end
    if RollAwayDB and RollAwayDB.hideCraftingOutputLog and log:IsShown() then
        log:Hide()
    end
end

function RA.ApplyCraftingOutputLogFeature()
    local pf = ProfessionsFrame
    if not pf then return end
    ApplyToOutputLog(pf.CraftingPage and pf.CraftingPage.CraftingOutputLog)
    -- Crafting orders: separate instance.
    ApplyToOutputLog(pf.OrdersPage and pf.OrdersPage.OrderView and pf.OrdersPage.OrderView.CraftingOutputLog)
end

local function InitCraftingOutputLogHide()
    local function HookProfessionsFrame()
        RA.ApplyCraftingOutputLogFeature()
        -- The output logs are created lazily: retry on every relevant OnShow.
        ProfessionsFrame:HookScript("OnShow", RA.ApplyCraftingOutputLogFeature)
        if ProfessionsFrame.OrdersPage then
            ProfessionsFrame.OrdersPage:HookScript("OnShow", RA.ApplyCraftingOutputLogFeature)
            if ProfessionsFrame.OrdersPage.OrderView then
                ProfessionsFrame.OrdersPage.OrderView:HookScript("OnShow", RA.ApplyCraftingOutputLogFeature)
            end
        end
    end

    if ProfessionsFrame then
        HookProfessionsFrame()
        return
    end

    RA.WaitForAddon("Blizzard_Professions", HookProfessionsFrame)
end

------------------------------------------------------------------------
-- Hide the red error text in the middle of the screen. UIErrorsFrame's OnEvent
-- handler is wrapped once: unimportant UI_ERROR_MESSAGEs are swallowed, everything
-- else goes to Blizzard's handler. The option is checked per message (no /reload).
-- Not done by unregistering the event: BigWigs and ElvUI re-register it.
------------------------------------------------------------------------

-- Errors that stay visible: the only hint why a deliberate action did nothing.
-- Everything else (spell, resource, range, target) is hidden. Names of Blizzard's
-- localized global strings, so it works in every client language.
local KEPT_ERRORS = {
    -- No room / not enough money
    "ERR_INV_FULL", "ERR_BANK_FULL", "ERR_QUEST_LOG_FULL",
    "ERR_NOT_ENOUGH_MONEY",
    -- Loot
    "ERR_LOOT_CANT_LOOT_THAT",
    -- Quest turn-in refused (relevant for the quest automation)
    "ERR_QUEST_MUST_CHOOSE", "ERR_QUEST_FAILED_MISSING_ITEMS",
    "ERR_QUEST_FAILED_NOT_ENOUGH_MONEY",
    -- Dead (player or pet)
    "ERR_PLAYER_DEAD", "ERR_PET_SPELL_DEAD",
    -- Group restrictions
    "ERR_RAID_GROUP_ONLY", "ERR_PARTY_LFG_TELEPORT_IN_COMBAT",
    -- Vote kick in a Group Finder group
    "ERR_PARTY_LFG_BOOT_LIMIT", "ERR_PARTY_LFG_BOOT_DUNGEON_COMPLETE",
    "ERR_PARTY_LFG_BOOT_IN_COMBAT", "ERR_PARTY_LFG_BOOT_IN_PROGRESS",
    "ERR_PARTY_LFG_BOOT_LOOT_ROLLS", "ERR_PARTY_LFG_BOOT_TOO_FEW_PLAYERS",
    -- Vendor, mail and trade refusals
    "ERR_VENDOR_NOT_INTERESTED", "ERR_VENDOR_DOESNT_BUY",
    "ERR_MAIL_BOUND_ITEM", "ERR_TRADE_BOUND_ITEM",
    "ERR_TRADE_BAG_FULL", "ERR_TRADE_TARGET_BAG_FULL",
    -- Great Vault unavailable
    "ERR_USE_WEEKLY_REWARDS_DISABLED",
    -- Rogue pickpocketing
    "SPELL_FAILED_TARGET_NO_POCKETS", "ERR_ALREADY_PICKPOCKETED",
}

-- Kept errors with a variable part (%s / %d), matched by pattern.
local KEPT_ERROR_TEMPLATES = {
    "ERR_QUEST_FAILED_BAG_FULL_S", "ERR_QUEST_FAILED_MAX_COUNT_S",
    "ERR_PARTY_LFG_BOOT_COOLDOWN_S", "ERR_PARTY_LFG_BOOT_NOT_ELIGIBLE_S",
    "ERR_PARTY_LFG_BOOT_INPATIENT_TIMER_S",
}

-- Global string with %s / %d placeholders -> Lua pattern.
local function TemplateToPattern(template)
    local escaped = template:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    escaped = escaped:gsub("%%%%%d+%%%$[sd]", ".+"):gsub("%%%%[sd]", ".+")
    return "^" .. escaped .. "$"
end

local keptErrorText = {}      -- [exact text] = true
local keptErrorPatterns = {}  -- Lua patterns for the templates
for _, name in ipairs(KEPT_ERRORS) do
    if _G[name] then keptErrorText[_G[name]] = true end
end
for _, name in ipairs(KEPT_ERROR_TEMPLATES) do
    if _G[name] then keptErrorPatterns[#keptErrorPatterns + 1] = TemplateToPattern(_G[name]) end
end

local errorHandlerWrapped = false

local function IsKeptError(message)
    if keptErrorText[message] then return true end
    for _, pattern in ipairs(keptErrorPatterns) do
        if message:find(pattern) then return true end
    end
    return false
end

-- Should this error be swallowed? Messages we cannot inspect never are.
local function IsHiddenError(message)
    if not RA.IsAccessible(message) then return false end
    if type(message) ~= "string" then return false end
    return not IsKeptError(message)
end

function RA.ApplyHideErrorsFeature()
    if errorHandlerWrapped or not UIErrorsFrame then return end
    -- Untouched until the option is switched on once.
    if not (RollAwayDB and RollAwayDB.hideErrorMessages) then return end

    local blizzardHandler = UIErrorsFrame:GetScript("OnEvent")
    if not blizzardHandler then return end
    errorHandlerWrapped = true

    UIErrorsFrame:SetScript("OnEvent", function(self, event, ...)
        local db = RollAwayDB
        if db and db.hideErrorMessages then
            if event == "UI_ERROR_MESSAGE" and IsHiddenError((select(2, ...))) then
                return
            end
            -- Yellow info text (quest progress): sub-option
            if event == "UI_INFO_MESSAGE" and db.hideInfoMessages then
                return
            end
        end
        return blizzardHandler(self, event, ...)
    end)
    DBG("[QoL] UIErrorsFrame handler wrapped")
end

------------------------------------------------------------------------
-- Hide Talking Head, boss banner, event toasts and alerts: each Blizzard frame is
-- driven by game events; while its option is on the events are taken from the
-- frame and given back when it is off (no hooks, no /reload).
------------------------------------------------------------------------

local takenEvents = {}  -- [frame] = { [event] = true }: events we unregistered

local function SetFrameEventsTaken(frame, events, take)
    if not frame then return end
    if take then
        for _, event in ipairs(events) do
            if frame:IsEventRegistered(event) then
                frame:UnregisterEvent(event)
                takenEvents[frame] = takenEvents[frame] or {}
                takenEvents[frame][event] = true
            end
        end
    elseif takenEvents[frame] then
        for event in pairs(takenEvents[frame]) do frame:RegisterEvent(event) end
        takenEvents[frame] = nil
    end
end

-- Banner after a boss kill (with the loot list)
function RA.ApplyHideBossBannerFeature()
    SetFrameEventsTaken(BossBanner, { "BOSS_KILL", "ENCOUNTER_LOOT_RECEIVED" },
        RollAwayDB and RollAwayDB.hideBossBanner)
end

-- Bonus objective banner (part of the event toasts option). It is started by
-- TopBannerManager_Show -> PlayBanner, not by an event, and its animations drive
-- the alpha themselves. So it runs normally (it tells the objective tracker when
-- done) and only its regions are hidden; no Blizzard function is called (no taint).
-- The sound still plays.
local bonusBannerHooked = false
local hiddenBannerRegions = {}  -- [region] = true: regions we hid

local function SetBonusBannerHidden(hide)
    local banner = ObjectiveTrackerTopBannerFrame
    if not (banner and banner.GetRegions) then return end
    if hide then
        for _, region in ipairs({ banner:GetRegions() }) do
            if region:IsShown() then
                region:Hide()
                hiddenBannerRegions[region] = true
            end
        end
    else
        for region in pairs(hiddenBannerRegions) do region:Show() end
        wipe(hiddenBannerRegions)
    end
end

local function ApplyBonusBannerHiding(on)
    local banner = ObjectiveTrackerTopBannerFrame
    if not (banner and banner.PlayBanner) then return end
    if on and not bonusBannerHooked then
        bonusBannerHooked = true
        -- PlayBanner sets the texts again every time: hide them right after
        hooksecurefunc(banner, "PlayBanner", function()
            if RollAwayDB and RollAwayDB.hideEventToasts then SetBonusBannerHidden(true) end
        end)
        DBG("[QoL] Bonus objective banner hook set")
    end
    SetBonusBannerHidden(on)
end

-- Event toasts at the top of the screen and the bonus objective banner
function RA.ApplyHideEventToastsFeature()
    local on = RollAwayDB and RollAwayDB.hideEventToasts and true or false
    SetFrameEventsTaken(EventToastManagerFrame, { "DISPLAY_EVENT_TOASTS" }, on)
    ApplyBonusBannerHiding(on)
end

-- Alert pop-ups (loot, achievements, new mounts / pets / toys, ...): the events
-- AlertFrame listens to. PET_BATTLE_CLOSE stays (releases alerts held during pet battles).
local ALERT_EVENTS = {
    "ACHIEVEMENT_EARNED", "CRITERIA_EARNED", "LFG_COMPLETION_REWARD",
    "SCENARIO_COMPLETED", "LOOT_ITEM_ROLL_WON", "SHOW_LOOT_TOAST",
    "SHOW_LOOT_TOAST_UPGRADE", "SHOW_PVP_FACTION_LOOT_TOAST",
    "SHOW_RATED_PVP_REWARD_TOAST", "ENTITLEMENT_DELIVERED",
    "RAF_ENTITLEMENT_DELIVERED", "GARRISON_BUILDING_ACTIVATABLE",
    "GARRISON_TALENT_COMPLETE", "GARRISON_MISSION_FINISHED",
    "GARRISON_FOLLOWER_ADDED", "GARRISON_RANDOM_MISSION_ADDED",
    "NEW_RECIPE_LEARNED", "SHOW_LOOT_TOAST_LEGENDARY_LOOTED",
    "AZERITE_EMPOWERED_ITEM_LOOTED", "QUEST_TURNED_IN", "QUEST_LOOT_RECEIVED",
    "NEW_PET_ADDED", "NEW_MOUNT_ADDED", "NEW_TOY_ADDED",
    "NEW_WARBAND_SCENE_ADDED", "NEW_RUNEFORGE_POWER_ADDED",
    "TRANSMOG_COSMETIC_COLLECTION_SOURCE_ADDED",
    "TRANSMOG_COLLECTION_SOURCE_ADDED", "SKILL_LINE_SPECS_UNLOCKED",
    "PERKS_PROGRAM_CURRENCY_AWARDED", "PERKS_ACTIVITY_COMPLETED",
    "REQUESTED_GUILD_RENAME_RESULT", "INITIATIVE_TASK_COMPLETED",
}

function RA.ApplyHideAlertsFeature()
    SetFrameEventsTaken(AlertFrame, ALERT_EVENTS, RollAwayDB and RollAwayDB.hideAlerts)
end

-- Talking Head (TalkingHeadFrame is in Blizzard_FrameXML, always loaded).
function RA.ApplyHideTalkingHeadFeature()
    SetFrameEventsTaken(TalkingHeadFrame, { "TALKINGHEAD_REQUESTED" },
        RollAwayDB and RollAwayDB.hideTalkingHead)
end

------------------------------------------------------------------------
-- Initialization – called from Core/Core.lua ADDON_LOADED
------------------------------------------------------------------------

function RA.InitHideUI()
    RA.ApplyMapActivityTrackerFeature()
    InitCraftingOutputLogHide()

    -- Error text, Talking Head, boss banner, event toasts, alerts
    RA.ApplyHideErrorsFeature()
    RA.ApplyHideTalkingHeadFeature()
    RA.ApplyHideBossBannerFeature()
    RA.ApplyHideEventToastsFeature()
    RA.ApplyHideAlertsFeature()
end
