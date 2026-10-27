-- RollAway - Modules/QoL.lua
-- Quality of life: ready check / durability reminders, Auction House and Crafting
-- Orders expansion filter, Great Vault currency. Hiding Blizzard UI: HideUI.lua; quests:
-- Quests.lua; join reminder: JoinReminder.lua; Character panel buttons:
-- CharFrameButtons.lua.

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

-- "<Spec> – <loadout name>", or just "<Spec>" (starter build / no saved loadout).
-- Sources in the order of Blizzard's Talent UI:
-- 1) the Talent frame's dropdown selection (only once that frame exists)
-- 2) GetLastSelectedSavedConfigID (only after a loadout was selected this session)
-- 3) GetActiveConfigID (always there, but named like the spec - filtered below)
local function GetActiveTalentLabel()
    local specIndex = C_SpecializationInfo.GetSpecialization()
    if not specIndex then return nil end
    -- No "x and F(...)" here: it would cut the multiple return values to one.
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
    RA.SetToastText(talentFrame, "|cffFFFFFF" .. text .. "|r")
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

    local pctStr = "|cffFF4444" .. math.floor(pct * 100) .. "%|r"
    RA.SetToastText(durabilityFrame, string.format(RA_L["qol_durability_warning"], pctStr))
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
-- Auction House – "Current Expansion Only" filter. Blizzard keeps it between sessions
-- once it was set; we apply it on every AH open (first time, and after it was turned off).
-- The setters return false while the frames are not ready yet (RA.RunWhenReady tries again).
------------------------------------------------------------------------

local AH_FILTER_CEO = Enum.AuctionHouseFilter and Enum.AuctionHouseFilter.CurrentExpansionOnly

-- The AH filter state is the global g_auctionHouseFilters ("Clear Filters" replaces
-- the table, so it is looked up on every use).
local function GetAuctionHouseFilters()
    return g_auctionHouseFilters and g_auctionHouseFilters.filters
end

local function SetAHExpansionFilter()
    if not RollAwayDB or not RollAwayDB.expansionFilterAH then return end
    if not AH_FILTER_CEO then return end
    if not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then return false end

    local sb = AuctionHouseFrame.SearchBar
    if not (sb and sb:IsShown()) then return false end

    local filters = GetAuctionHouseFilters()
    if not filters then return false end
    if filters[AH_FILTER_CEO] then return end  -- already set
    filters[AH_FILTER_CEO] = true
    DBG("[QoL] AH expansion filter applied")
end

local function SetCraftingOrderExpansionFilter()
    if not RollAwayDB or not RollAwayDB.expansionFilterAH then return end
    if not AH_FILTER_CEO then return end

    local co = ProfessionsCustomerOrdersFrame
    if not co or not co:IsShown() then return false end

    local fd = co.BrowseOrders
               and co.BrowseOrders.SearchBar
               and co.BrowseOrders.SearchBar.FilterDropdown
    if not fd or not fd.filters then return false end

    if fd.filters[AH_FILTER_CEO] then return end -- already set (Show hook and interaction event both fire)
    fd.filters[AH_FILTER_CEO] = true
    if fd.UpdateSelections then fd:UpdateSelections() end
    if fd.Update then fd:Update() end
    if fd.ValidateResetState then fd:ValidateResetState() end
    DBG("[QoL] Crafting Orders expansion filter applied")
end

local function ApplyAHFilterWhenReady()
    RA.RunWhenReady(SetAHExpansionFilter, 0.2, 5)
end

local function ApplyCraftingOrderFilterWhenReady()
    RA.RunWhenReady(SetCraftingOrderExpansionFilter, 0.2, 5)
end

local function InitAHFilter()
    local f = CreateFrame("Frame")
    f:RegisterEvent("AUCTION_HOUSE_SHOW")
    f:SetScript("OnEvent", function()
        ApplyAHFilterWhenReady()
        -- SetDisplayMode hook (tab switches, e.g. Auctionator → Blizzard)
        if AuctionHouseFrame and not AuctionHouseFrame.raDisplayModeHooked then
            hooksecurefunc(AuctionHouseFrame, "SetDisplayMode", ApplyAHFilterWhenReady)
            AuctionHouseFrame.raDisplayModeHooked = true
            DBG("[QoL] AH SetDisplayMode hook set")
        end
    end)

    local function HookCraftingFrame()
        local co = ProfessionsCustomerOrdersFrame
        local bo = co and co.BrowseOrders
        if not bo then return false end
        hooksecurefunc(bo, "Show", ApplyCraftingOrderFilterWhenReady)
        DBG("[QoL] BrowseOrders:Show hook set")
        return true
    end

    -- NPC crafting boards
    local coEventFrame = CreateFrame("Frame")
    coEventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    coEventFrame:SetScript("OnEvent", function(_, _, interactionType)
        -- Fires for every NPC window (bank, vendor ...): only the crafting orders board counts.
        local customerOrders = Enum.PlayerInteractionType and Enum.PlayerInteractionType.ProfessionsCustomerOrders
        if customerOrders and interactionType == customerOrders then ApplyCraftingOrderFilterWhenReady() end
    end)

    if not HookCraftingFrame() then
        RA.WaitForAddon("Blizzard_ProfessionsCustomerOrders", HookCraftingFrame)
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
        -- ElvUI: bottom right, default UI: top right
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
        -- ElvUI font if available
        local fontPath = RA.GetQoLFont()
        text:SetFont(fontPath, 12, "OUTLINE")
        vaultCurrencyFrame.text = text
    end

    local qty    = info.quantity or 0
    local maxQty = info.maxQuantity or 0
    local earned = info.totalEarned or info.quantityEarnedThisWeek or 0
    -- Fallback while the earned value is not updated yet
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
    -- Show and SetShown can both fire for one open: one update.
    local updateQueued = false
    local function QueueVaultCurrencyUpdate()
        if updateQueued then return end
        updateQueued = true
        RunNextFrame(function()
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
        -- Already shown
        if WeeklyRewardsFrame:IsShown() then
            UpdateVaultCurrency()
        end
        DBG("[QoL] Vault currency hook set")
        return true
    end

    if not HookVaultFrame() then
        -- Wait for Blizzard_WeeklyRewards
        RA.WaitForAddon("Blizzard_WeeklyRewards", HookVaultFrame)
    end
end

------------------------------------------------------------------------
-- Initialization – called from Core/Core.lua ADDON_LOADED
------------------------------------------------------------------------

function RA.InitQoL()
    -- Ready check
    local f = CreateFrame("Frame")
    f:RegisterEvent("READY_CHECK")
    f:SetScript("OnEvent", ShowTalentReminder)

    -- Durability
    local d = CreateFrame("Frame")
    d:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    d:RegisterEvent("PLAYER_ENTERING_WORLD")
    d:SetScript("OnEvent", function() CheckDurability() end)

    -- AH filter
    InitAHFilter()

    InitVaultCurrency()

    DBG("QoL initialized")
end
