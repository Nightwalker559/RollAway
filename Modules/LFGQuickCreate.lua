-- RollAway - LFGQuickCreate.lua
-- Dungeon quick-select buttons in the Group Finder (Mythic+).
-- Dungeon data (cmID, lfgID) is read from RA.DUNGEONS[RA.ACTIVE_SEASON] (Data/Dungeons.lua).

local RA  = _G["RollAway"]
local RA_L = RA.RA_L
local DBG = RA.DBG

local ICON_SIZE = 32
local ICON_GAP  = 4

local initialized  = false
local buttons      = {}
local container    = nil
local updateTicker = nil

------------------------------------------------------------------------
-- Filters to dungeons active this season via GetMapTable(); falls back
-- to the full list if the active set is empty.
------------------------------------------------------------------------
local function ActiveDungeons()
    local source = RA.DUNGEONS[RA.ACTIVE_SEASON]
    if not C_ChallengeMode then return source end
    local cmIDs = C_ChallengeMode.GetMapTable()
    if not cmIDs or #cmIDs == 0 then return source end

    local active = {}
    for i = 1, #cmIDs do active[cmIDs[i]] = true end

    local out = {}
    for i = 1, #source do
        local d = source[i]
        if d.cmID and d.cmID > 0 and active[d.cmID] then
            out[#out + 1] = d
        end
    end
    return #out > 0 and out or source
end

------------------------------------------------------------------------
-- Returns the playstyle currently set in the EC frame, falling back to
-- the addon's saved default when the frame value is unset.
------------------------------------------------------------------------
local function CurrentPlaystyle()
    local ec = LFGListFrame and LFGListFrame.EntryCreation
    if ec and type(ec.generalPlaystyle) == "number" and ec.generalPlaystyle > 0 then
        return ec.generalPlaystyle
    end
    return (RollAwayDB and RollAwayDB.lfgDefaultPlaystyle) or 0
end

------------------------------------------------------------------------
-- Updates the keystone glow on each button to highlight the dungeon
-- matching the player's currently owned keystone.
------------------------------------------------------------------------
local function RefreshGlow()
    if not C_LFGList then return end
    local ownLfgID, _, ownLevel = C_LFGList.GetOwnedKeystoneActivityAndGroupAndLevel()
    for i = 1, #buttons do
        local btn = buttons[i]
        local match = ownLfgID and (btn._lfgID == ownLfgID)
        btn._glow:SetShown(match or false)
        btn._lvlText:SetShown(match or false)
        if match then
            btn._lvlText:SetText(ownLevel and ("+" .. ownLevel) or "")
        end
    end
end

------------------------------------------------------------------------
-- Saves original EC layout, then pushes labels down for the button row.
-- Offsets empirically measured for the Midnight 12.0.5 EC layout.
------------------------------------------------------------------------
local origLayout = {}

local function SaveLayout(ec)
    if origLayout.done then return end
    if ec.DescriptionLabel then
        local _, _, _, ox, oy = ec.DescriptionLabel:GetPoint()
        origLayout.dlX, origLayout.dlY = ox, oy
    end
    if ec.Description then
        origLayout.dH = ec.Description:GetHeight()
    end
    if ec.PlayStyleLabel then
        local _, _, _, ox, oy = ec.PlayStyleLabel:GetPoint()
        origLayout.plX, origLayout.plY = ox, oy
    end
    origLayout.done = true
end

local function PushLayout(ec)
    if ec.DescriptionLabel and ec.NameLabel then
        ec.DescriptionLabel:SetPoint("TOPLEFT", ec.NameLabel, "TOPLEFT", 0, -85)
    end
    if ec.Description then
        ec.Description:SetHeight(25)
    end
    if ec.PlayStyleLabel and ec.DescriptionLabel then
        ec.PlayStyleLabel:SetPoint("TOPLEFT", ec.DescriptionLabel, "TOPLEFT", 0, -55)
    end
end

local function PopLayout(ec)
    if not origLayout.done then return end
    if ec.DescriptionLabel and ec.NameLabel then
        ec.DescriptionLabel:SetPoint("TOPLEFT", ec.NameLabel, "TOPLEFT",
            origLayout.dlX or 0, origLayout.dlY or -55)
    end
    if ec.Description and origLayout.dH then
        ec.Description:SetHeight(origLayout.dH)
    end
    if ec.PlayStyleLabel and ec.DescriptionLabel and origLayout.plY then
        ec.PlayStyleLabel:SetPoint("TOPLEFT", ec.DescriptionLabel, "TOPLEFT",
            origLayout.plX or 0, origLayout.plY)
    end
end

------------------------------------------------------------------------
-- Shows the container when the Dungeons category (2) is active.
------------------------------------------------------------------------
local function SyncVisibility()
    if not container then return end
    if not (RollAwayDB and RollAwayDB.lfgQuickCreate) then
        container:Hide()
        return
    end
    local cs = LFGListFrame and LFGListFrame.CategorySelection
    container:SetShown(cs ~= nil and cs.selectedCategory == 2)
end

------------------------------------------------------------------------
-- Applies the saved default playstyle to the EC frame on every open.
-- The player can still change it manually in the EC form afterwards.
------------------------------------------------------------------------
local function ApplyDefaultPlaystyle(ec)
    if not RollAwayDB then return end
    local ps = RollAwayDB.lfgDefaultPlaystyle
    if not ps or ps == 0 then return end
    ec.generalPlaystyle = ps
    DBG("[LFGQuickCreate] Playstyle set:", ps)
    local dd = ec.PlayStyleDropdown
    if not dd then return end
    -- dd:SetSelectedValue() routes into protected SetEntryTitle(); called from
    -- a C_Timer (no hardware event), it taints and triggers ADDON_ACTION_BLOCKED
    -- (uncatchable by pcall). We don't need auto title fill, so no-op that
    -- one Blizzard function during our call, then restore it.
    local origSetTitle = LFGListEntryCreation_SetTitleFromActivityInfo
    LFGListEntryCreation_SetTitleFromActivityInfo = function() end
    if dd.SetSelectedValue then pcall(dd.SetSelectedValue, dd, ps) end
    if dd.GenerateMenu    then pcall(dd.GenerateMenu, dd)          end
    LFGListEntryCreation_SetTitleFromActivityInfo = origSetTitle
    -- Trigger Blizzard's button validation so "List Group" becomes clickable.
    if LFGListEntryCreation_UpdateValidState then
        pcall(LFGListEntryCreation_UpdateValidState, ec)
        DBG("[LFGQuickCreate] UpdateValidState triggered")
    end
end

------------------------------------------------------------------------
-- Creates a single dungeon icon button.
------------------------------------------------------------------------
local function MakeButton(parent, dungeon, index)
    local _, _, _, iconTex = C_ChallengeMode.GetMapUIInfo(dungeon.cmID)
    local actInfo = C_LFGList.GetActivityInfoTable(dungeon.lfgID)
    local label   = actInfo and actInfo.fullName ~= "" and actInfo.fullName or dungeon.key

    local btn = CreateFrame("Button", "RollAwayQC_" .. dungeon.key, parent)
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:SetPoint("TOPLEFT", (index - 1) * (ICON_SIZE + ICON_GAP), 0)

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if iconTex and iconTex ~= 0 then tex:SetTexture(iconTex) end

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.18)

    local glow = btn:CreateTexture(nil, "OVERLAY", nil, 1)
    glow:SetAllPoints()
    glow:SetColorTexture(1, 0.82, 0, 0.38)
    glow:Hide()

    local lvl = btn:CreateFontString(nil, "OVERLAY")
    lvl:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    lvl:SetPoint("CENTER")
    lvl:Hide()

    btn._lfgID   = dungeon.lfgID
    btn._glow    = glow
    btn._lvlText = lvl
    btn._label   = label

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:ClearLines()
        GameTooltip:SetText(self._label, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnClick", function(self, mb)
        if mb ~= "LeftButton" then return end
        local ec = LFGListFrame and LFGListFrame.EntryCreation
        if not ec then return end
        local nameBox = ec.Name or ec.NameBox
        local nm = nameBox and nameBox:GetText():match("^%s*(.-)%s*$") or ""
        if nm == "" then
            UIErrorsFrame:AddMessage(RA_L["qol_lfgqc_namefirst"], 1, 0.35, 0.35)
            if nameBox then nameBox:SetFocus() end
            return
        end
        DBG("[LFGQuickCreate] Click:", self._label, "lfgID:", self._lfgID)
        -- C_LFGList.CreateListing() must be called directly from the hardware
        -- event. Routing through LFGListEntryCreation_ListGroup() introduces
        -- taint and causes ADDON_ACTION_BLOCKED.
        C_LFGList.CreateListing({
            activityIDs           = { self._lfgID },
            questID               = nil,
            isAutoAccept          = false,
            isCrossFactionListing = true,
            isPrivateGroup        = false,
            newPlayerFriendly     = false,
            playstyle             = CurrentPlaystyle(),
            requiredDungeonScore  = 0,
            requiredItemLevel     = 0,
            requiredPvpRating     = 0,
        })
    end)

    return btn
end

------------------------------------------------------------------------
-- One-time initialization, deferred until Blizzard_LFGList is ready.
------------------------------------------------------------------------
local function Init()
    if initialized then return end

    local ec = LFGListFrame and LFGListFrame.EntryCreation
    if not ec then return end

    -- GetCurrentSeason() returns -1 until RequestMapInfo resolves.
    if not C_MythicPlus then return end
    C_MythicPlus.RequestMapInfo()
    if C_MythicPlus.GetCurrentSeason() == -1 then
        C_Timer.After(0.5, Init)
        return
    end

    initialized = true
    DBG("[LFGQuickCreate] Init")

    SaveLayout(ec)

    local list    = ActiveDungeons()
    local totalW  = #list * ICON_SIZE + math.max(0, #list - 1) * ICON_GAP
    local nameBox = ec.Name or ec.NameBox

    container = CreateFrame("Frame", "RollAwayQCContainer", ec)
    container:SetSize(totalW, ICON_SIZE)
    container:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", -5, -2)
    container:Hide()

    for i, d in ipairs(list) do
        buttons[#buttons + 1] = MakeButton(container, d, i)
    end

    local function HookDD(dd)
        if not dd then return end
        dd:HookScript("OnHide", function()
            C_Timer.After(0.05, SyncVisibility)
        end)
    end
    HookDD(ec.GroupDropdown)
    HookDD(ec.ActivityDropdown)
    if ec.CategoryDropdown and ec.CategoryDropdown ~= ec.GroupDropdown then
        HookDD(ec.CategoryDropdown)
    end

    ec:HookScript("OnShow", function()
        if RollAwayDB and RollAwayDB.lfgQuickCreate then
            PushLayout(ec)
            SyncVisibility()
            RefreshGlow()
            if not updateTicker then
                updateTicker = C_Timer.NewTicker(2, RefreshGlow)
            end
        else
            PopLayout(ec)
            container:Hide()
        end
        -- Apply default playstyle independently of the dungeon buttons.
        if RollAwayDB and RollAwayDB.lfgAutoPlaystyle then
            C_Timer.After(0.05, function()
                if ec:IsShown() then ApplyDefaultPlaystyle(ec) end
            end)
        end
    end)

    ec:HookScript("OnHide", function()
        if updateTicker then updateTicker:Cancel(); updateTicker = nil end
    end)

    if ec:IsShown() then
        if RollAwayDB and RollAwayDB.lfgQuickCreate then
            PushLayout(ec)
            SyncVisibility()
            RefreshGlow()
        end
        if RollAwayDB and RollAwayDB.lfgAutoPlaystyle then
            C_Timer.After(0.05, function()
                if ec:IsShown() then ApplyDefaultPlaystyle(ec) end
            end)
        end
    end
end

------------------------------------------------------------------------
-- Public init – called from Core.lua on ADDON_LOADED.
------------------------------------------------------------------------
function RA.InitLFGQuickCreate()
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")

    f:SetScript("OnEvent", function(self, event, arg1)
        if event == "ADDON_LOADED" and arg1 == "Blizzard_LFGList" then
            C_Timer.After(0.1, Init)
        elseif event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(0.5, Init)
            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        end
    end)

    if RA.DEV_CHARS and RA.DEV_CHARS[UnitName("player")] then
        SLASH_RAWQCDBG1 = "/rawqcdbg"
        SlashCmdList["RAWQCDBG"] = function()
            if not (RollAwayDB and RollAwayDB.debug) then return end
            local ec = LFGListFrame and LFGListFrame.EntryCreation
            if not ec then print("|cffff4444[QC]|r EntryCreation not open"); return end
            print("|cff33ff99[QC]|r EntryCreation children:")
            for _, c in next, { ec:GetChildren() } do
                print("  " .. c:GetObjectType() .. "  " .. tostring(c.GetName and c:GetName() or "(no name)"))
            end
        end
    end

    DBG("[LFGQuickCreate] Ready")
end
