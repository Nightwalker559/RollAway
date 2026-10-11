-- RollAway - CraftingSalvage.lua
-- Professions: salvage recipes (e.g. Cooking "Thalassian Filet", fish -> fillets)
-- need an item put into the slot by hand. This fills the slot with the first item
-- you own, in the order of Blizzard's own list (name, then item ID), once a stack
-- is big enough. Refills when the stack is used up. Only the crafting page.
-- Everything runs one frame after Blizzard's code and only sets what the slot's
-- own click handler sets.

local RA  = _G["RollAway"]
local DBG = RA.DBG

local pending = false
local autoGUID  -- item GUID we put in the slot (to tell "used up" from "removed by the player")

local function GetForm()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    return page and page.SchematicForm
end

-- First owned item with a full stack, sorted like Blizzard's flyout.
local function PickItem(schematic)
    local itemIDs = C_TradeSkillUI.GetSalvagableItemIDs(schematic.recipeID)
    if not itemIDs or #itemIDs == 0 then return nil end

    local need = schematic.quantityMax or 1
    local best, bestName, bestID
    for _, target in ipairs(C_TradeSkillUI.GetCraftingTargetItems(itemIDs)) do
        local item = Item:CreateFromItemGUID(target.itemGUID)
        if item:GetStackCount() >= need then
            local name = C_Item.GetItemNameByID(target.itemID) or tostring(target.itemID)
            local c = best and strcmputf8i(name, bestName) or -1
            if c < 0 or (c == 0 and target.itemID < bestID) then
                best, bestName, bestID = item, name, target.itemID
            end
        end
    end
    return best
end

-- fromInit: the recipe was just (re)selected, so fill even if the player cleared the slot.
local function TryFill(fromInit)
    pending = false
    if not (RollAwayDB and RollAwayDB.autoSalvageSlot) then return end

    local form = GetForm()
    if not form or not form:IsVisible() then return end
    local transaction = form:GetTransaction()
    local schematic = transaction and transaction:GetRecipeSchematic()
    local slot = form.salvageSlot
    if not schematic or schematic.recipeType ~= Enum.TradeskillRecipeType.Salvage
        or not slot or not slot:IsShown() then
        autoGUID = nil
        return
    end
    if transaction:GetSalvageAllocation() then return end
    -- Empty slot after our own fill: refill only when that stack is gone.
    if not fromInit and autoGUID and C_Item.IsItemGUIDInInventory(autoGUID) then return end

    local item = PickItem(schematic)
    autoGUID = item and item:GetItemGUID() or nil
    if not item then return end

    transaction:SetSalvageAllocation(item)
    slot:SetItem(item)
    form:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
    DBG("[Salvage] slot filled: " .. tostring(item:GetItemID()))
end

local function Schedule(fromInit)
    if pending and not fromInit then return end
    pending = true
    RunNextFrame(function() TryFill(fromInit) end)
end

function RA.ApplyCraftingSalvageFeature()
    if GetForm() then Schedule(true) end
end

function RA.InitCraftingSalvage()
    local function HookProfessionsFrame()
        local form = GetForm()
        if not form then return end

        -- Recipe selected / page refreshed.
        hooksecurefunc(form, "Init", function() Schedule(true) end)

        -- Items used up by crafting; only while the window is open.
        local ev = CreateFrame("Frame")
        ev:SetScript("OnEvent", function() Schedule(false) end)
        ProfessionsFrame:HookScript("OnShow", function() ev:RegisterEvent("BAG_UPDATE_DELAYED") end)
        ProfessionsFrame:HookScript("OnHide", function()
            ev:UnregisterAllEvents()
            autoGUID = nil
        end)
        if ProfessionsFrame:IsShown() then ev:RegisterEvent("BAG_UPDATE_DELAYED") end
    end

    if ProfessionsFrame then
        HookProfessionsFrame()
    else
        RA.WaitForAddon("Blizzard_Professions", HookProfessionsFrame)
    end
end
