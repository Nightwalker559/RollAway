-- RollAway - VendorFilter.lua
-- QoL: "Vendor Filter Light" - passively dims merchant items the player
-- already knows/owns (recipes, toys, mounts, pets, tabards, illusions,
-- housing decor). No dropdown/category UI by design - just toggle + alpha,
-- configurable in Options > QoL > Filter.

local RA  = _G["RollAway"]
local DBG = RA.DBG

local C_Item                = C_Item
local C_ToyBox               = C_ToyBox
local C_MountJournal         = C_MountJournal
local C_PetJournal           = C_PetJournal
local C_TransmogCollection   = C_TransmogCollection
local C_HousingCatalog       = C_HousingCatalog
local C_SpellBook            = C_SpellBook
local C_TradeSkillUI         = C_TradeSkillUI

local DEFAULT_ALPHA = 0.35

------------------------------------------------------------------------
-- Per-category "already known/maxed" checks
------------------------------------------------------------------------

local function IsRecipeKnownViaSpellCheck(itemID)
    if not itemID then return false end
    local spellID
    if C_Item and C_Item.GetItemSpell then
        local ok, _, sID = pcall(C_Item.GetItemSpell, itemID)
        if ok then spellID = sID end
    end
    if not spellID then return false end

    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        local ok, recipeInfo = pcall(C_TradeSkillUI.GetRecipeInfo, spellID)
        if ok and recipeInfo and recipeInfo.learned ~= nil then
            return recipeInfo.learned and true or false
        end
    end

    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        return ok and known or false
    end
    return false
end

-- Hidden scanning tooltip, created lazily. Reading the merchant tooltip is
-- the most reliable way to detect an already-known recipe: Blizzard itself
-- replaces the profession/skill requirement line with the localized
-- "Already Known" string the moment a recipe is learned, regardless of
-- which internal system (classic spellbook vs. newer TradeSkillUI-tracked
-- profession recipes) actually tracks that recipe's known-state.
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
    -- Tooltip scan first (matches Blizzard's own "Already Known" indicator
    -- exactly); falls back to the spellID/TradeSkillUI check if the tooltip
    -- couldn't be scanned for some reason.
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
    -- name, icon, petType, creatureID, sourceText, description, isWild,
    -- canBattle, isTradeable, isUnique, obtainable, displayID, speciesID
    local speciesID = select(13, C_PetJournal.GetPetInfoByItemID(itemID))
    if not speciesID then return false end
    local numCollected = C_PetJournal.GetNumCollectedInfo and C_PetJournal.GetNumCollectedInfo(speciesID)
    return (numCollected or 0) > 0
end

-- Covers both Tabards and Illusions - both resolve via itemID here.
local function IsTransmogKnown(itemID)
    if not (C_TransmogCollection and C_TransmogCollection.PlayerHasTransmog) then return false end
    local ok, known = pcall(C_TransmogCollection.PlayerHasTransmog, itemID)
    return ok and known or false
end

-- Housing decor: matches Blizzard's own "already known" checkmark on the
-- vendor icon (info.totalNumStored > 0 = already own at least one copy of
-- this catalog entry). There is no per-entry "max owned" concept in this
-- API - GetDecorMaxOwnedCount() is a global storage-chest cap, not tied to
-- an individual item - so we don't try to gate on that; matching Blizzard's
-- own checkmark is the correct signal here.
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
    if IsTransmogKnown(itemID) then return true end
    if IsHousingDecorKnown(itemID) then return true end
    return false
end

------------------------------------------------------------------------
-- Applying the dim to merchant buttons
------------------------------------------------------------------------

local function GetMerchantItemID(index)
    local link = GetMerchantItemLink and GetMerchantItemLink(index)
    if not link then return nil end
    return C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(link)
end

local function ApplyVendorFilterButton(button, itemButton)
    -- The merchant index lives on the child "...ItemButton" (set by
    -- Blizzard's own UpdateMerchantItemButton code), not on the row
    -- container itself - reading it from there is robust regardless of how
    -- many item slots the current frame/skin displays per page (ElvUI,
    -- wider frames, etc.), unlike recomputing it from a fixed
    -- items-per-page constant.
    local index = itemButton and itemButton:GetID()
    if not index or index <= 0 then
        button:SetAlpha(1)
        if RollAwayDB and RollAwayDB.debug then
            DBG("[VendorFilter]", button:GetName(), "skipped - index:", tostring(index))
        end
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
        DBG("[VendorFilter]", button:GetName(), "index:", index, "itemID:", tostring(itemID), "known:", tostring(known))
    end
end

-- Discovers every currently-existing MerchantItemN row (and its ItemButton
-- child), however many there are - the 12.1 merchant frame can show a
-- variable number of slots per page depending on frame width/skin, so we
-- don't assume a fixed count.
local function ForEachMerchantButton(callback)
    local i = 1
    local button = _G["MerchantItem"..i]
    while button do
        callback(button, _G["MerchantItem"..i.."ItemButton"])
        i = i + 1
        button = _G["MerchantItem"..i]
    end
end

-- Resets all merchant item buttons back to full opacity (option turned off,
-- or the merchant window closes).
function RA.ResetVendorFilterButtons()
    ForEachMerchantButton(function(button) button:SetAlpha(1) end)
end

function RA.ApplyVendorFilterFeature()
    if not (RollAwayDB and RollAwayDB.vendorFilterEnabled) then
        RA.ResetVendorFilterButtons()
        return
    end
    if not (MerchantFrame and MerchantFrame:IsShown()) then return end

    ForEachMerchantButton(ApplyVendorFilterButton)

    -- Blizzard assigns some slots' IDs (observed: 11/12) one frame later
    -- than the rest during MerchantFrame_UpdateMerchantInfo, so a second
    -- deferred pass catches any button that still read index 0 just now.
    if RA.C_Timer_After then
        RA.C_Timer_After(0, function()
            if MerchantFrame and MerchantFrame:IsShown() and RollAwayDB and RollAwayDB.vendorFilterEnabled then
                ForEachMerchantButton(ApplyVendorFilterButton)
            end
        end)
    end
end

------------------------------------------------------------------------
-- Initialization
------------------------------------------------------------------------

function RA.InitVendorFilter()
    -- Central refresh point Blizzard calls on open, page change, and buy.
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", RA.ApplyVendorFilterFeature)

    local f = CreateFrame("Frame")
    f:RegisterEvent("MERCHANT_CLOSED")
    f:SetScript("OnEvent", RA.ResetVendorFilterButtons)

    DBG("[VendorFilter] initialized")
end
