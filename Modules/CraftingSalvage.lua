-- RollAway - CraftingSalvage.lua
-- Professions: fills the slot of salvage recipes (e.g. Cooking fish -> fillets) with the
-- first owned item that is ticked in the material list (Blizzard's order: name, item ID)
-- and has a big enough stack; refills when the stack is used up. Nothing ticked = nothing
-- filled. Next to "Reagents:": checkbox (on/off) + red text that opens the list.
-- Runs one frame after Blizzard's code and only sets what the slot's click handler sets.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local pending = false
local autoGUID  -- item GUID we put in the slot (to tell "used up" from "removed by the player")
local currentRecipeID

local function GetForm()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    return page and page.SchematicForm
end

-- Ticked item IDs (profile-wide).
local function Allowed()
    if not RollAwayDB.salvageAllowed then RollAwayDB.salvageAllowed = {} end
    return RollAwayDB.salvageAllowed
end

-- First owned, ticked item with a full stack, sorted like Blizzard's flyout.
local function PickItem(schematic)
    local itemIDs = C_TradeSkillUI.GetSalvagableItemIDs(schematic.recipeID)
    if not itemIDs or #itemIDs == 0 then return nil end

    local allowed = Allowed()
    local need = schematic.quantityMax or 1
    local best, bestName, bestID
    for _, target in ipairs(C_TradeSkillUI.GetCraftingTargetItems(itemIDs)) do
        if allowed[target.itemID] then
            local item = Item:CreateFromItemGUID(target.itemGUID)
            if item:GetStackCount() >= need then
                local name = C_Item.GetItemNameByID(target.itemID) or tostring(target.itemID)
                local c = best and strcmputf8i(name, bestName) or -1
                if c < 0 or (c == 0 and target.itemID < bestID) then
                    best, bestName, bestID = item, name, target.itemID
                end
            end
        end
    end
    return best
end

local Schedule

------------------------------------------------------------------------
-- Material list (opened by the red text): one icon per possible item of the
-- recipe, ticked = may be filled in automatically.
------------------------------------------------------------------------

local COLS, CELL = 8, 40
local panel
local buttons = {}
local relayoutPending = false
local UpdateToggleLook

local function SetItemLook(b)
    local r, g, bl = 0.25, 0.25, 0.25
    if Allowed()[b.itemID] then r, g, bl = 0.1, 0.8, 0.1 end
    for _, edge in ipairs(b.edges) do edge:SetColorTexture(r, g, bl, 1) end
    b.icon:SetDesaturated(b.owned == 0)
    b.icon:SetAlpha(b.owned == 0 and 0.45 or 1)
end

local function OnItemClick(b)
    local allowed = Allowed()
    allowed[b.itemID] = (not allowed[b.itemID]) or nil
    SetItemLook(b)
    UpdateToggleLook()
    Schedule(true)
end

local function GetItemButton(i)
    local b = buttons[i]
    if b then return b end
    b = CreateFrame("Button", nil, panel.grid)
    b:SetSize(CELL - 4, CELL - 4)
    -- 2px border: green = allowed, grey = not allowed.
    b.edges = {}
    for n = 1, 4 do b.edges[n] = b:CreateTexture(nil, "BORDER") end
    b.edges[1]:SetPoint("TOPLEFT");     b.edges[1]:SetPoint("TOPRIGHT");     b.edges[1]:SetHeight(2)
    b.edges[2]:SetPoint("BOTTOMLEFT");  b.edges[2]:SetPoint("BOTTOMRIGHT");  b.edges[2]:SetHeight(2)
    b.edges[3]:SetPoint("TOPLEFT");     b.edges[3]:SetPoint("BOTTOMLEFT");   b.edges[3]:SetWidth(2)
    b.edges[4]:SetPoint("TOPRIGHT");    b.edges[4]:SetPoint("BOTTOMRIGHT");  b.edges[4]:SetWidth(2)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.count:SetPoint("BOTTOMRIGHT", -3, 3)
    b:SetScript("OnClick", OnItemClick)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(RA_L["salvage_panel_tip"], 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    buttons[i] = b
    return b
end

-- Fills the grid for recipeID (names may still be loading: re-sorted once they are).
local function Layout(recipeID)
    if not panel or not recipeID then return end
    local itemIDs = C_TradeSkillUI.GetSalvagableItemIDs(recipeID) or {}

    local entries = {}
    for _, id in ipairs(itemIDs) do
        local name = C_Item.GetItemNameByID(id)
        if not name then
            Item:CreateFromItemID(id):ContinueOnItemLoad(function()
                if relayoutPending then return end
                relayoutPending = true
                RunNextFrame(function()
                    relayoutPending = false
                    if panel:IsShown() then Layout(currentRecipeID) end
                end)
            end)
        end
        entries[#entries + 1] = { id = id, name = name or tostring(id) }
    end
    table.sort(entries, function(a, b)
        local c = strcmputf8i(a.name, b.name)
        if c ~= 0 then return c < 0 end
        return a.id < b.id
    end)

    for i, e in ipairs(entries) do
        local b = GetItemButton(i)
        b.itemID = e.id
        b.owned  = C_Item.GetItemCount(e.id) or 0
        b.icon:SetTexture(C_Item.GetItemIconByID(e.id))
        b.count:SetText(b.owned > 0 and b.owned or "")
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", panel.grid, "TOPLEFT", ((i - 1) % COLS) * CELL, -math.floor((i - 1) / COLS) * CELL)
        SetItemLook(b)
        b:Show()
    end
    for i = #entries + 1, #buttons do buttons[i]:Hide() end

    local rows = math.max(1, math.ceil(#entries / COLS))
    panel.grid:SetSize(COLS * CELL, rows * CELL)
    panel:SetHeight(panel.gridTop + rows * CELL + 46)
end

local function SetAll(on)
    local allowed = Allowed()
    for _, b in ipairs(buttons) do
        if b:IsShown() then allowed[b.itemID] = on or nil end
    end
    Layout(currentRecipeID)
    UpdateToggleLook()
    Schedule(true)
end

local function CreatePanel()
    panel = RA.CreatePanelWindow("RollAwaySalvagePanel", ProfessionsFrame, COLS * CELL + 28, 200,
        RA_L["salvage_panel_title"])
    panel:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 4, 0)
    panel:SetFrameStrata("HIGH")

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", 14, -30)
    hint:SetWidth(COLS * CELL)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(1, 0.25, 0.25)
    hint:SetText(RA_L["salvage_panel_hint"])
    panel.hint = hint
    panel.gridTop = 30 + 36

    panel.grid = CreateFrame("Frame", nil, panel)
    panel.grid:SetPoint("TOPLEFT", 14, -panel.gridTop)

    local allBtn = CreateFrame("Button", "RollAwaySalvageAll", panel, "UIPanelButtonTemplate")
    allBtn:SetSize(80, 22)
    allBtn:SetPoint("BOTTOMLEFT", 14, 12)
    allBtn:SetText(RA_L["salvage_panel_all"])
    allBtn:SetScript("OnClick", function() SetAll(true) end)

    local noneBtn = CreateFrame("Button", "RollAwaySalvageNone", panel, "UIPanelButtonTemplate")
    noneBtn:SetSize(80, 22)
    noneBtn:SetPoint("LEFT", allBtn, "RIGHT", 6, 0)
    noneBtn:SetText(RA_L["salvage_panel_none"])
    noneBtn:SetScript("OnClick", function() SetAll(false) end)

    if RA.SkinSalvagePanel then RA.SkinSalvagePanel(panel, allBtn, noneBtn) end
end

local function TogglePanel()
    if panel and panel:IsShown() then
        panel:Hide()
        return
    end
    if not panel then CreatePanel() end
    Layout(currentRecipeID)
    panel:Show()
end

------------------------------------------------------------------------
-- Checkbox + red text next to "Reagents:"
------------------------------------------------------------------------

local toggle, link

local function CountAllowed()
    local itemIDs = currentRecipeID and C_TradeSkillUI.GetSalvagableItemIDs(currentRecipeID)
    if not itemIDs then return 0 end
    local allowed, n = Allowed(), 0
    for _, id in ipairs(itemIDs) do
        if allowed[id] then n = n + 1 end
    end
    return n
end

function UpdateToggleLook()
    if not toggle then return end
    local on = RollAwayDB.salvageSlotActive
    toggle:SetChecked(on)
    toggle.Text:SetText(string.format(RA_L["qol_salvage_slot_warning"], CountAllowed()))
    if on then
        toggle.Text:SetTextColor(1, 0.25, 0.25)
    else
        toggle.Text:SetTextColor(0.5, 0.5, 0.5)
    end
end

local function SetToggle(form, show)
    if not show then
        if toggle then toggle:Hide() end
        if panel then panel:Hide() end
        return
    end
    local container = form.Reagents
    if not container or not container.Label then return end
    if not toggle then
        toggle = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
        toggle:SetSize(22, 22)
        if RA.SkinCheckBox then RA.SkinCheckBox(toggle) end
        toggle:SetScript("OnClick", function(self)
            RollAwayDB.salvageSlotActive = self:GetChecked() and true or false
            UpdateToggleLook()
            Schedule(true)
        end)

        -- The text opens the material list.
        link = CreateFrame("Button", nil, toggle)
        link:SetAllPoints(toggle.Text)
        link:SetScript("OnClick", TogglePanel)
        link:SetScript("OnEnter", function()
            toggle.Text:SetTextColor(1, 1, 1)
            GameTooltip:SetOwner(link, "ANCHOR_TOP")
            GameTooltip:AddLine(RA_L["salvage_panel_link_tip"])
            GameTooltip:Show()
        end)
        link:SetScript("OnLeave", function()
            GameTooltip_Hide()
            UpdateToggleLook()
        end)
    end
    toggle:ClearAllPoints()
    toggle:SetPoint("LEFT", container.Label, "LEFT", container.Label:GetStringWidth() + 6, 0)
    UpdateToggleLook()
    toggle:Show()
    if panel and panel:IsShown() then Layout(currentRecipeID) end
end

-- fromInit: the recipe was just (re)selected, so fill even if the player cleared the slot.
local function TryFill(fromInit)
    pending = false
    local form = GetForm()
    if not (RollAwayDB and RollAwayDB.autoSalvageSlot) then
        if form then SetToggle(form, false) end
        return
    end

    if not form or not form:IsVisible() then return end
    local transaction = form:GetTransaction()
    local schematic = transaction and transaction:GetRecipeSchematic()
    local slot = form.salvageSlot
    if not schematic or schematic.recipeType ~= Enum.TradeskillRecipeType.Salvage
        or not slot or not slot:IsShown() then
        autoGUID = nil
        currentRecipeID = nil
        SetToggle(form, false)
        return
    end
    currentRecipeID = schematic.recipeID
    SetToggle(form, true)
    if not RollAwayDB.salvageSlotActive then return end
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

function Schedule(fromInit)
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
            if panel then panel:Hide() end
        end)
        if ProfessionsFrame:IsShown() then ev:RegisterEvent("BAG_UPDATE_DELAYED") end
    end

    if ProfessionsFrame then
        HookProfessionsFrame()
    else
        RA.WaitForAddon("Blizzard_Professions", HookProfessionsFrame)
    end
end
