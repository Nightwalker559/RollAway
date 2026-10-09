-- RollAway - VendorFilter.lua
-- "Vendor Filter Light": dims merchant items the player already owns (recipes, toys,
-- mounts, heirlooms, housing decor, pets at the maximum, items whose appearance is
-- collected). Toggle + alpha in Options > QoL > Filter.

local RA  = _G["RollAway"]
local DBG = RA.DBG

local DEFAULT_ALPHA = RA.defaults.profile.vendorFilterAlpha

-- Per-category "already known" checks

local function IsRecipeKnownViaSpellCheck(itemID)
    local ok, _, spellID = pcall(C_Item.GetItemSpell, itemID)
    if not (ok and spellID) then return false end

    local okRecipe, recipeInfo = pcall(C_TradeSkillUI.GetRecipeInfo, spellID)
    if okRecipe and recipeInfo and recipeInfo.learned ~= nil then
        return recipeInfo.learned and true or false
    end

    local okKnown, known = pcall(C_SpellBook.IsSpellKnown, spellID)
    return okKnown and known or false
end

-- Hidden scan tooltip (lazy). The merchant tooltip is the most reliable recipe check:
-- Blizzard shows the localized "Already Known" line once a recipe is learned.
local scanTooltip
local function GetScanTooltip()
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "RollAwayVendorScanTooltip", nil, "GameTooltipTemplate")
        scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    return scanTooltip
end

local KNOWN_RECIPE_STRINGS = {}
if _G.ITEM_SPELL_KNOWN then table.insert(KNOWN_RECIPE_STRINGS, _G.ITEM_SPELL_KNOWN) end
table.insert(KNOWN_RECIPE_STRINGS, "Bereits bekannt") -- deDE fallback
table.insert(KNOWN_RECIPE_STRINGS, "Already Known")   -- enUS fallback

local function IsRecipeKnownViaTooltip(index)
    if not index then return false end
    local tt = GetScanTooltip()
    tt:ClearLines()
    local ok = pcall(tt.SetMerchantItem, tt, index)
    if not ok then return false end

    for i = 1, tt:NumLines() do
        local line = _G["RollAwayVendorScanTooltipTextLeft"..i]
        local text = line and line:GetText()
        if text then
            for _, known in ipairs(KNOWN_RECIPE_STRINGS) do
                if known and text == known then return true end
            end
        end
    end
    return false
end

local function IsRecipeKnown(itemID, index)
    -- Item class first (no tooltip scan for non-recipes): the update fires often.
    local classID = select(6, C_Item.GetItemInfoInstant(itemID))
    if classID ~= Enum.ItemClass.Recipe then return false end

    -- Tooltip scan first; spell/TradeSkillUI check as fallback.
    if IsRecipeKnownViaTooltip(index) then return true end
    return IsRecipeKnownViaSpellCheck(itemID)
end

local function IsToyKnown(itemID)
    if not (C_ToyBox and C_ToyBox.GetToyInfo and C_ToyBox.GetToyInfo(itemID)) then return false end
    return (PlayerHasToy and PlayerHasToy(itemID)) or false
end

local function IsMountKnown(itemID)
    if not (C_MountJournal and C_MountJournal.GetMountFromItem) then return false end
    local mountID = C_MountJournal.GetMountFromItem(itemID)
    if not mountID then return false end
    local isCollected = select(11, C_MountJournal.GetMountInfoByID(mountID))
    return isCollected and true or false
end

local function IsPetKnown(itemID)
    if not (C_PetJournal and C_PetJournal.GetPetInfoByItemID) then return false end
    -- 13th return value = speciesID
    local speciesID = select(13, C_PetJournal.GetPetInfoByItemID(itemID))
    if not speciesID then return false end
    -- Battle pets can be owned several times: only "maxed" counts as known.
    local numCollected, limit = C_PetJournal.GetNumCollectedInfo(speciesID)
    return (numCollected or 0) > 0 and (numCollected or 0) >= (limit or 1)
end

-- Heirlooms (Blizzard greys out an owned one itself; dim it like the rest).
local function IsHeirloomKnown(itemID)
    if not (C_Heirloom and C_Heirloom.IsItemHeirloom and C_Heirloom.IsItemHeirloom(itemID)) then return false end
    return C_Heirloom.PlayerHasHeirloom(itemID) and true or false
end

-- Any item whose appearance is collected (armor, tabards, illusions).
local function IsTransmogKnown(itemID)
    if not (C_TransmogCollection and C_TransmogCollection.PlayerHasTransmog) then return false end
    local ok, known = pcall(C_TransmogCollection.PlayerHasTransmog, itemID)
    return ok and known or false
end

-- Housing decor: Blizzard's own "known" checkmark (totalNumStored > 0); the API has
-- no per-item maximum.
local function IsHousingDecorKnown(itemID)
    if not (C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem) then return false end
    local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, itemID)
    if not ok or not info then return false end
    return (info.totalNumStored or 0) > 0
end

local function IsMerchantItemKnown(itemID, index)
    if not itemID then return false end
    if IsRecipeKnown(itemID, index) then return true end
    if IsToyKnown(itemID) then return true end
    if IsMountKnown(itemID) then return true end
    if IsPetKnown(itemID) then return true end
    if IsHeirloomKnown(itemID) then return true end
    if IsTransmogKnown(itemID) then return true end
    if IsHousingDecorKnown(itemID) then return true end
    return false
end

-- Applying the dim to merchant buttons

-- Log only when a button's result changed (the update fires many times while item
-- data streams in).
local lastDebugState = {}

local function ApplyVendorFilterButton(button, itemButton)
    -- The merchant index is the ID of the child "...ItemButton" (robust for any
    -- slots-per-page, ElvUI included).
    local index = itemButton and itemButton:GetID()
    local name  = button:GetName()

    if not index or index <= 0 then
        button:SetAlpha(1)
        return
    end

    local itemID = GetMerchantItemID(index)
    local known = itemID and IsMerchantItemKnown(itemID, index)

    local alpha = 1
    if known then
        alpha = (RollAwayDB and RollAwayDB.vendorFilterAlpha) or DEFAULT_ALPHA
    end
    button:SetAlpha(alpha)

    if RollAwayDB and RollAwayDB.debug then
        local state = index .. ":" .. tostring(itemID) .. ":" .. tostring(known)
        if lastDebugState[name] ~= state then
            lastDebugState[name] = state
            DBG("[VendorFilter]", name, "index:", index, "itemID:", tostring(itemID), "known:", tostring(known))
        end
    end
end

-- Every existing MerchantItemN row and its ItemButton (the count varies with frame/skin).
local function ForEachMerchantButton(callback)
    local i = 1
    local button = _G["MerchantItem"..i]
    while button do
        callback(button, _G["MerchantItem"..i.."ItemButton"])
        i = i + 1
        button = _G["MerchantItem"..i]
    end
end

-- All merchant buttons back to full opacity (option off, window closed).
function RA.ResetVendorFilterButtons()
    ForEachMerchantButton(function(button) button:SetAlpha(1) end)
    wipe(lastDebugState)
end

function RA.ApplyVendorFilterFeature()
    if not (RollAwayDB and RollAwayDB.vendorFilterEnabled) then
        RA.ResetVendorFilterButtons()
        return
    end
    if not (MerchantFrame and MerchantFrame:IsShown()) then return end

    ForEachMerchantButton(ApplyVendorFilterButton)

    -- Blizzard sets some slot IDs one frame later: a second pass catches buttons that read 0.
    RunNextFrame(function()
        if MerchantFrame and MerchantFrame:IsShown() and RollAwayDB and RollAwayDB.vendorFilterEnabled then
            ForEachMerchantButton(ApplyVendorFilterButton)
        end
    end)
end

-- Initialization

function RA.InitVendorFilter()
    -- Central refresh point Blizzard calls on open, page change, and buy.
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", RA.ApplyVendorFilterFeature)

    local f = CreateFrame("Frame")
    f:RegisterEvent("MERCHANT_CLOSED")
    f:SetScript("OnEvent", RA.ResetVendorFilterButtons)

    DBG("[VendorFilter] initialized")
end
