-- RollAway - QoL.lua
-- Quality of Life features: Ready Check / durability reminders, Auction House
-- and Crafting Orders expansion filter, Great Vault currency display, and
-- Blizzard UI clean-ups (world map activity tracker, crafting output log,
-- red error text). Quest automation lives in Modules\Quests.lua.
-- The instance join reminder lives in Modules\JoinReminder.lua, the Character
-- panel buttons in Modules\CharFrameButtons.lua.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

-- Equipment slots that can have durability
local DURA_SLOTS    = { 1, 3, 5, 6, 7, 8, 9, 10, 15, 16, 17 }
local DURA_THRESHOLD = 0.30  -- 30%

------------------------------------------------------------------------
-- Ready Check – "Check Talents" reminder
------------------------------------------------------------------------

local talentFrame, talentTimer  -- QoL toast (RA.CreateToastFrame), created on first show

-- "<Spec> – <loadout name>", or just "<Spec>" for the starter build / no
-- saved loadout. Three sources, in the same priority order Blizzard's own
-- Talent UI uses (see PlayerSpellsFrame.TalentsFrame.LoadSystem):
-- 1) the Talent frame's own dropdown selection - only populated once that
--    frame has been created (i.e. Talents UI opened this session)
-- 2) GetLastSelectedSavedConfigID - only set once a loadout has been
--    (re)selected via that dropdown this session; nil otherwise, which is
--    the common case and why relying on it alone showed no name at all
-- 3) GetActiveConfigID - always available but named after the spec itself,
--    not the loadout (filtered out below via the loadoutName ~= specName
--    check, so it never produces the "Spec – Spec" duplicate)
local function GetActiveTalentLabel()
    local specIndex = C_SpecializationInfo.GetSpecialization()
    if not specIndex then return nil end
    -- NOTE: must NOT write "specIndex and C_SpecializationInfo.GetSpecializationInfo(...)"
    -- here - Lua's `and`/`or` truncate a multi-return to a single value, so a
    -- guard like that silently drops every return after the first (this is
    -- exactly what caused specID to come through but specName to stay nil).
    local specID, specName = C_SpecializationInfo.GetSpecializationInfo(specIndex)
    if not specName then return nil end

    local loadSystem = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
        and PlayerSpellsFrame.TalentsFrame.LoadSystem
    local uiConfigID     = loadSystem and loadSystem.GetSelectionID and loadSystem:GetSelectionID()
    local lastConfigID   = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
    local activeConfigID = C_ClassTalents.GetActiveConfigID()
    local configID = uiConfigID or lastConfigID or activeConfigID

    local loadoutName
    if configID and configID > 0 then
        local configInfo = C_Traits.GetConfigInfo(configID)
        loadoutName = configInfo and configInfo.name
    end

    if loadoutName and loadoutName ~= "" and loadoutName ~= specName then
        return specName .. " – " .. loadoutName
    end
    return specName
end

local function ShowTalentReminder()
    if not RollAwayDB or not RollAwayDB.readyCheckReminder then return end
    local itype = RA.cachedInstanceType
    if itype ~= "party" and itype ~= "raid" then return end

    DBG("[QoL] Ready check – showing talent reminder")
    if not talentFrame then
        talentFrame, talentTimer = RA.CreateToastFrame("RollAwayTalentFrame", 280, 36, 180)
    end

    local label = RollAwayDB.readyCheckShowSpec and GetActiveTalentLabel()
    local text = label and string.format(RA_L["qol_check_talents_fmt"], label) or RA_L["qol_check_talents"]
    talentFrame.text:SetText("|cffFFFFFF" .. text .. "|r")

    local fontPath, fontSize = RA.GetQoLFont()
    talentFrame.text:SetFont(fontPath, fontSize, "OUTLINE")
    talentFrame:Show()

    talentTimer.Start()
end

------------------------------------------------------------------------
-- Durability warning
------------------------------------------------------------------------

local durabilityFrame, durabilityTimer  -- QoL toast, created on first show

local function GetLowestDurability()
    local lowest = 1.0
    for _, slot in ipairs(DURA_SLOTS) do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            local pct = cur / max
            if pct < lowest then lowest = pct end
        end
    end
    return lowest
end

local function ShowDurabilityWarning(pct)
    if not RollAwayDB or not RollAwayDB.durabilityWarning then return end

    DBG("[QoL] Durability warning:", math.floor(pct * 100) .. "%")
    if not durabilityFrame then
        durabilityFrame, durabilityTimer = RA.CreateToastFrame("RollAwayDurabilityFrame", 320, 36, 140)
    end

    local fontPath, fontSize = RA.GetQoLFont()
    durabilityFrame.text:SetFont(fontPath, fontSize, "OUTLINE")

    local pctStr = "|cffFF4444" .. math.floor(pct * 100) .. "%|r"
    durabilityFrame.text:SetText(string.format(RA_L["qol_durability_warning"], pctStr))

    durabilityFrame:Show()

    durabilityTimer.Start()
end

local function CheckDurability(force)
    if not RollAwayDB or not RollAwayDB.durabilityWarning then return end
    local pct = GetLowestDurability()
    if force or pct <= DURA_THRESHOLD then
        ShowDurabilityWarning(force and 0.25 or pct)
    elseif durabilityFrame and durabilityFrame:IsShown() then
        durabilityFrame:Hide()
    end
end

-- Expose for test command
RA.CheckDurability    = CheckDurability
RA.ShowTalentReminder = ShowTalentReminder

------------------------------------------------------------------------
-- Auction House – Current Expansion Only filter
-- 12.1+: Blizzard persists this filter across AH sessions, but only once it
-- has been set active at least once (won't turn itself on from scratch).
-- We still check/re-apply on every AH open so it (a) gets activated the
-- first time and (b) gets restored if it was turned off since.
------------------------------------------------------------------------

local AH_FILTER_CEO = Enum.AuctionHouseFilter and Enum.AuctionHouseFilter.CurrentExpansionOnly

-- 12.1.0 moved AH filter state out of SearchBar.FilterButton and into this global
-- saved table. "Clear Filters" replaces the whole table, so resolve it fresh on
-- every use instead of caching a reference.
local function GetAuctionHouseFilters()
    return g_auctionHouseFilters and g_auctionHouseFilters.filters
end

local function SetAHExpansionFilter()
    if not RollAwayDB or not RollAwayDB.expansionFilterAH then return end
    if not AH_FILTER_CEO then return end
    if not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then return end

    local sb = AuctionHouseFrame.SearchBar
    if not (sb and sb:IsShown()) then return end

    local filters = GetAuctionHouseFilters()
    if filters then
        if filters[AH_FILTER_CEO] then return end  -- already set, avoid duplicate apply/log
        filters[AH_FILTER_CEO] = true
        DBG("[QoL] AH expansion filter applied")
    end
end

local function SetCraftingOrderExpansionFilter()
    if not RollAwayDB or not RollAwayDB.expansionFilterAH then return end
    if not AH_FILTER_CEO then return end

    local co = ProfessionsCustomerOrdersFrame
    if not co or not co:IsShown() then return end

    local fd = co.BrowseOrders
               and co.BrowseOrders.SearchBar
               and co.BrowseOrders.SearchBar.FilterDropdown
    if not fd or not fd.filters then return end

    if fd.filters[AH_FILTER_CEO] then return end -- already set, avoid duplicate apply/log (Show hook + PLAYER_INTERACTION_MANAGER_FRAME_SHOW both fire)
    fd.filters[AH_FILTER_CEO] = true
    if fd.UpdateSelections then fd:UpdateSelections() end
    if fd.Update then fd:Update() end
    if fd.ValidateResetState then fd:ValidateResetState() end
    DBG("[QoL] Crafting Orders expansion filter applied")
end

local function InitAHFilter()
    local f = CreateFrame("Frame")
    f:RegisterEvent("AUCTION_HOUSE_SHOW")
    f:SetScript("OnEvent", function()
        C_Timer.After(0.2, SetAHExpansionFilter)
        -- Hook SetDisplayMode once when AH opens (catches tab switches e.g. Auctionator → Blizzard)
        if AuctionHouseFrame and not AuctionHouseFrame.RA_displayModeHooked then
            hooksecurefunc(AuctionHouseFrame, "SetDisplayMode", function()
                C_Timer.After(0.1, SetAHExpansionFilter)
            end)
            AuctionHouseFrame.RA_displayModeHooked = true
            DBG("[QoL] AH SetDisplayMode hook set")
        end
    end)

    local function HookCraftingFrame()
        local co = ProfessionsCustomerOrdersFrame
        local bo = co and co.BrowseOrders
        if not bo then return false end
        hooksecurefunc(bo, "Show", function()
            C_Timer.After(0.2, SetCraftingOrderExpansionFilter)
        end)
        DBG("[QoL] BrowseOrders:Show hook set")
        return true
    end

    -- PLAYER_INTERACTION_MANAGER_FRAME_SHOW catches NPC crafting board opens
    local coEventFrame = CreateFrame("Frame")
    coEventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    coEventFrame:SetScript("OnEvent", function()
        C_Timer.After(0.5, SetCraftingOrderExpansionFilter)
    end)

    if not HookCraftingFrame() then
        RA.WaitForAddon("Blizzard_ProfessionsUI", HookCraftingFrame)
    end

    DBG("[QoL] AH/Crafting Orders expansion filter hook ready")
end

------------------------------------------------------------------------
-- Weekly Rewards (Great Vault) – Voidcore currency display
------------------------------------------------------------------------

local vaultCurrencyFrame

local function UpdateVaultCurrency()
    local enabled = RollAwayDB and RollAwayDB.vaultCurrencyDisplay
        and RA.BONUS_ROLLS_ENABLED and RA.IsMaxLevel()
    if not enabled then
        if vaultCurrencyFrame then vaultCurrencyFrame:Hide() end
        return
    end

    local info = C_CurrencyInfo.GetCurrencyInfo(RA.VOIDCORE_CURRENCY_ID)
    if not info then return end

    if not vaultCurrencyFrame then
        vaultCurrencyFrame = CreateFrame("Frame", "RollAwayVaultCurrencyFrame", WeeklyRewardsFrame)
        vaultCurrencyFrame:SetSize(240, 24)
        -- ElvUI: bottom right / Default UI: top right
        if ElvUI then
            vaultCurrencyFrame:SetPoint("BOTTOMRIGHT", WeeklyRewardsFrame, "BOTTOMRIGHT", 40, 20)
        else
            vaultCurrencyFrame:SetPoint("TOPRIGHT", WeeklyRewardsFrame, "TOPRIGHT", 40, -60)
        end

        local icon = vaultCurrencyFrame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT", vaultCurrencyFrame, "LEFT", 0, 0)
        vaultCurrencyFrame.icon = icon

        local text = vaultCurrencyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
        text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        text:SetJustifyH("LEFT")
        -- Use ElvUI general font if available
        local fontPath = RA.GetQoLFont()
        text:SetFont(fontPath, 12, "OUTLINE")
        vaultCurrencyFrame.text = text
    end

    local qty    = info.quantity or 0
    local maxQty = info.maxQuantity or 0
    local earned = info.totalEarned or info.quantityEarnedThisWeek or 0
    -- Fallback: if earned not yet updated by API but quantity exists
    if earned == 0 and qty > 0 then earned = qty end
    local iconID = info.iconFileID

    if iconID then
        vaultCurrencyFrame.icon:SetTexture(iconID)
        vaultCurrencyFrame.icon:Show()
    else
        vaultCurrencyFrame.icon:Hide()
    end

    local color = "|cffffd100"
    local label = RA_L["qol_vault_currency_name"]
    if maxQty > 0 then
        vaultCurrencyFrame.text:SetText(color .. label .. ": " .. qty .. " (" .. earned .. "/" .. maxQty .. ")|r")
    else
        vaultCurrencyFrame.text:SetText(color .. label .. ": " .. qty .. "|r")
    end

    vaultCurrencyFrame:Show()
    DBG("[QoL] Vault currency updated:", qty, "/", maxQty)
end

local function InitVaultCurrency()
    -- Show and SetShown can both fire for one open; coalesce into one update.
    local updateQueued = false
    local function QueueVaultCurrencyUpdate()
        if updateQueued then return end
        updateQueued = true
        C_Timer.After(0.1, function()
            updateQueued = false
            UpdateVaultCurrency()
        end)
    end

    local function HookVaultFrame()
        if not WeeklyRewardsFrame then return false end
        hooksecurefunc(WeeklyRewardsFrame, "Show", QueueVaultCurrencyUpdate)
        hooksecurefunc(WeeklyRewardsFrame, "SetShown", function(_, shown)
            if shown then QueueVaultCurrencyUpdate() end
        end)
        -- Apply immediately if frame is already shown
        if WeeklyRewardsFrame:IsShown() then
            UpdateVaultCurrency()
        end
        DBG("[QoL] Vault currency hook set")
        return true
    end

    if not HookVaultFrame() then
        -- Frame not loaded yet, wait for Blizzard_WeeklyRewards
        RA.WaitForAddon("Blizzard_WeeklyRewards", HookVaultFrame)
    end
end

------------------------------------------------------------------------
-- World Map: hide tracked-faction activity button (bottom-left)
-- EXPERIMENTAL (12.1): no fixed global name (anonymous WorldMapActivityTrackerTemplate),
-- so we detect it by scanning for a BOTTOMLEFT-anchored Button after every map draw.
------------------------------------------------------------------------

local mapActivityHooked = false
local hiddenMapActivityButtons = {}
local hookedActivityButtons = {}

-- Anonymous button (no GetName); identified by texture signature
-- (IconBorder/IconMask/BackgroundMask) since its anchor moves between patches.
local function IsActivityTrackerButton(frame)
    if not (frame.IsObjectType and frame:IsObjectType("Button")) then return false end
    if frame.GetName and frame:GetName() then return false end -- must be anonymous
    local iconBorder, iconMask, bgMask = false, false, false
    for _, region in ipairs({ frame:GetRegions() }) do
        local dbgName = region.GetDebugName and region:GetDebugName() or ""
        if dbgName:match("IconBorder$") then iconBorder = true end
        if dbgName:match("IconMask$") then iconMask = true end
        if dbgName:match("BackgroundMask$") then bgMask = true end
    end
    return iconBorder and iconMask and bgMask
end

-- NOTE (12.1): a cursor-coordinates widget anchors to this button's IsShown()
-- state. Hide() breaks its anchor, so fade instead (alpha 0, mouse disabled).
local function SetButtonFaded(child, faded)
    child:SetAlpha(faded and 0 or 1)
    if child.EnableMouse then child:EnableMouse(not faded) end
end

local function ScanAndHide(parent)
    if not parent then return end
    for _, child in ipairs({ parent:GetChildren() }) do
        if IsActivityTrackerButton(child) then
            if not hookedActivityButtons[child] then
                hookedActivityButtons[child] = true
                -- Re-fade instantly on Show to avoid a one-frame flash.
                hooksecurefunc(child, "Show", function(self)
                    if RollAwayDB and RollAwayDB.hideMapActivityTracker then
                        SetButtonFaded(self, true)
                    end
                end)
            end
            if child:IsShown() and child:GetAlpha() > 0 then
                SetButtonFaded(child, true)
                hiddenMapActivityButtons[child] = true
                DBG("[QoL] Hid map activity tracker button")
            end
        end
    end
end

local function HideMapActivityTracker()
    if not (RollAwayDB and RollAwayDB.hideMapActivityTracker) then return end
    if not WorldMapFrame then return end

    ScanAndHide(WorldMapFrame)
    if WorldMapFrame.GetCanvasContainer then
        ScanAndHide(WorldMapFrame:GetCanvasContainer())
    end
end

-- Re-shows any buttons we previously hid, e.g. when the option is turned off
local function RestoreMapActivityTracker()
    for btn in pairs(hiddenMapActivityButtons) do
        SetButtonFaded(btn, false)
    end
    wipe(hiddenMapActivityButtons)
end

function RA.ApplyMapActivityTrackerFeature()
    if InCombatLockdown() then
        C_Timer.After(1, RA.ApplyMapActivityTrackerFeature)
        return
    end
    if not WorldMapFrame then return end

    if not (RollAwayDB and RollAwayDB.hideMapActivityTracker) then
        RestoreMapActivityTracker()
        return
    end

    if not mapActivityHooked then
        mapActivityHooked = true
        local function DeferredHide() C_Timer.After(0, HideMapActivityTracker) end
        WorldMapFrame:HookScript("OnShow", DeferredHide)
        if WorldMapFrame.OnMapChanged then
            hooksecurefunc(WorldMapFrame, "OnMapChanged", DeferredHide)
        end
    end

    if WorldMapFrame:IsShown() then
        HideMapActivityTracker()
    end
end

------------------------------------------------------------------------
-- Professions: hide "Crafting Output Log" popup (Handwerksergebnisse)
-- ProfessionsCraftingOutputLogMixin:FinalizeResultData() is the function
-- Blizzard calls after every craft to populate + open this panel (via
-- ScrollingFlatPanelMixin:Open() -> Show()). We hook it directly and hide
-- the panel again immediately afterwards. Confirmed against Blizzard's
-- source (Blizzard_Professions/Blizzard_ProfessionsCraftingOutputLog.lua)
-- and matches the approach used by the "Profession Shopping List" addon.
--
-- Blizzard uses two separate instances of this same mixin/template:
--   - ProfessionsFrame.CraftingPage.CraftingOutputLog   (own crafting)
--   - ProfessionsFrame.OrdersPage.OrderView.CraftingOutputLog (crafting orders)
-- hooksecurefunc(obj, "Method") only hooks that specific object, so both
-- need their own hook even though they share the same mixin function.
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
    -- Crafting orders (Handwerksaufträge) use a separate frame instance.
    ApplyToOutputLog(pf.OrdersPage and pf.OrdersPage.OrderView and pf.OrdersPage.OrderView.CraftingOutputLog)
end

local function InitCraftingOutputLogHide()
    local function HookProfessionsFrame()
        RA.ApplyCraftingOutputLogFeature()
        -- CraftingOutputLog (either instance) is created lazily on first
        -- use, so retry on every relevant OnShow in case it didn't exist yet.
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
-- Hide the red error text in the middle of the screen
-- Blizzard's UIErrorsFrame listens to UI_ERROR_MESSAGE on its own. While the
-- option is on we take that event away from it and listen ourselves; only
-- the important errors below are handed back to Blizzard's own handler, so
-- they look exactly as usual. Turning the option off gives the event back
-- (no /reload needed).
------------------------------------------------------------------------

local ALWAYS_SHOWN_ERRORS = {}
for _, globalName in ipairs({
    "ERR_INV_FULL",         -- bags full
    "ERR_QUEST_LOG_FULL",   -- quest log full
    "ERR_ITEM_MAX_COUNT",   -- can't carry more of this item
    "ERR_PLAYER_DEAD",      -- can't do that while dead
    "ERR_PET_SPELL_DEAD",
}) do
    local text = _G[globalName]
    if text then ALWAYS_SHOWN_ERRORS[text] = true end
end

local errorFilterFrame

local function OnErrorMessage(event, errorType, message, ...)
    -- Messages we are not allowed to inspect are never hidden.
    local inspectable = message ~= nil and (not canaccessvalue or canaccessvalue(message))
    if inspectable and not ALWAYS_SHOWN_ERRORS[message] then return end

    local blizzardHandler = UIErrorsFrame:GetScript("OnEvent")
    if blizzardHandler then
        blizzardHandler(UIErrorsFrame, event, errorType, message, ...)
    end
end

function RA.ApplyHideErrorsFeature()
    if not UIErrorsFrame then return end
    -- Option off and never switched on this session: leave Blizzard alone.
    if not errorFilterFrame and not (RollAwayDB and RollAwayDB.hideErrorMessages) then return end

    if not errorFilterFrame then
        errorFilterFrame = CreateFrame("Frame")
        errorFilterFrame:SetScript("OnEvent", function(_, event, ...)
            if event == "PLAYER_REGEN_ENABLED" then
                -- ElvUI's own "hide error text" option gives the event back
                -- to UIErrorsFrame after combat; take it away again.
                C_Timer.After(0.5, RA.ApplyHideErrorsFeature)
            else
                OnErrorMessage(event, ...)
            end
        end)
    end

    if RollAwayDB and RollAwayDB.hideErrorMessages then
        UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
        errorFilterFrame:RegisterEvent("UI_ERROR_MESSAGE")
        errorFilterFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        errorFilterFrame:UnregisterAllEvents()
        UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
    end
end

------------------------------------------------------------------------
-- Initialization – called from Core.lua ADDON_LOADED
------------------------------------------------------------------------

function RA.InitQoL()
    -- Ready Check
    local f = CreateFrame("Frame")
    f:RegisterEvent("READY_CHECK")
    f:SetScript("OnEvent", ShowTalentReminder)

    -- Durability
    local d = CreateFrame("Frame")
    d:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    d:RegisterEvent("PLAYER_ENTERING_WORLD")
    d:SetScript("OnEvent", function() CheckDurability() end)

    -- AH Current Expansion Only filter
    InitAHFilter()

    -- Great Vault currency display
    InitVaultCurrency()

    -- Instance join reminder / keystone companion addon
    RA.InitJoinReminder()

    -- Omniumfoliant / Great Vault Character panel buttons
    RA.InitCharacterFrameButtons()

    -- World Map: hide tracked-faction activity button
    RA.ApplyMapActivityTrackerFeature()

    -- Professions: hide "Crafting Output Log" popup
    InitCraftingOutputLogHide()

    -- Red error text filter
    RA.ApplyHideErrorsFeature()

    DBG("QoL initialized")
end
