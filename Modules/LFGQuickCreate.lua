-- RollAway - LFGQuickCreate.lua
-- Dungeon quick-select buttons in the Group Finder (Mythic+); dungeon data (cmID,
-- lfgID) from RA.DUNGEONS[RA.ACTIVE_SEASON].

local RA  = _G["RollAway"]
local RA_L = RA.RA_L
local DBG = RA.DBG

local ICON_SIZE = 32
local ICON_GAP  = 4

local initialized  = false
local buttons      = {}
local container    = nil
local updateTicker = nil

-- Display name of a dungeon: tooltip text and sort key.
local function DungeonSortLabel(d)
    local actInfo = C_LFGList and C_LFGList.GetActivityInfoTable(d.lfgID)
    local full = actInfo and actInfo.fullName
    return (full and full ~= "") and full or d.key
end

-- The season's dungeons via GetMapTable() (full list if that is empty), sorted by name.
local function ActiveDungeons()
    local source = RA.DUNGEONS[RA.ACTIVE_SEASON]
    if not C_ChallengeMode then return RA.SortByLabel(source, DungeonSortLabel) end
    local cmIDs = C_ChallengeMode.GetMapTable()
    if not cmIDs or #cmIDs == 0 then return RA.SortByLabel(source, DungeonSortLabel) end

    local active = {}
    for i = 1, #cmIDs do active[cmIDs[i]] = true end

    local out = {}
    for i = 1, #source do
        local d = source[i]
        if d.cmID and d.cmID > 0 and active[d.cmID] then
            out[#out + 1] = d
        end
    end
    return RA.SortByLabel(#out > 0 and out or source, DungeonSortLabel)
end

-- Playstyle set in the EC frame, else the saved default.
local function CurrentPlaystyle()
    local ec = LFGListFrame and LFGListFrame.EntryCreation
    if ec and type(ec.generalPlaystyle) == "number" and ec.generalPlaystyle > 0 then
        return ec.generalPlaystyle
    end
    return (RollAwayDB and RollAwayDB.lfgDefaultPlaystyle) or 0
end

-- Keystone glow on the button of the dungeon the player's keystone belongs to.
local function RefreshGlow()
    local ownLfgID, ownLevel = RA.GetOwnedKeystone()
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

-- Saves the original EC layout and pushes the labels down for the button row
-- (offsets measured for the Midnight 12.0.5 layout).
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

-- Shows the container while the Dungeons category (2) is active.
local function SyncVisibility()
    if not container then return end
    if not (RollAwayDB and RollAwayDB.lfgQuickCreate) then
        container:Hide()
        return
    end
    local cs = LFGListFrame and LFGListFrame.CategorySelection
    container:SetShown(cs ~= nil and cs.selectedCategory == 2)
end

-- Saved default playstyle on every open; the player can still change it.
local function ApplyDefaultPlaystyle(ec)
    if not RollAwayDB then return end
    local ps = RollAwayDB.lfgDefaultPlaystyle
    if not ps or ps == 0 then return end
    -- Plain data field only. dd:SetSelectedValue()/GenerateMenu() would reach the
    -- protected SetEntryTitle() from insecure code and taint the EntryCreation frame
    -- until /reload (ADDON_ACTION_BLOCKED, e.g. on "Edit"). The label does not show the
    -- default; CreateListing() and "List Group" read ec.generalPlaystyle anyway.
    ec.generalPlaystyle = ps
    DBG("[LFGQuickCreate] Playstyle set:", ps)
    if LFGListEntryCreation_UpdateValidState then
        pcall(LFGListEntryCreation_UpdateValidState, ec)
        DBG("[LFGQuickCreate] UpdateValidState triggered")
    end
end

-- Selects Mythic+ (Blizzard defaults to Mythic) for the selected dungeon: when the form
-- opens and after another dungeon was picked, never after a manual difficulty pick.
local function ApplyMythicPlus(ec)
    if not (RollAwayDB and RollAwayDB.lfgAutoMythicPlus) then return end
    if ec.selectedCategory ~= 2 or not ec.selectedActivity then return end

    local current = C_LFGList.GetActivityInfoTable(ec.selectedActivity)
    if not current or current.isMythicPlusActivity then return end

    for _, activityID in ipairs(C_LFGList.GetAvailableActivities(ec.selectedCategory, ec.selectedGroup, ec.selectedFilters) or {}) do
        local info = C_LFGList.GetActivityInfoTable(activityID)
        if info and info.isMythicPlusActivity then
            -- Plain data field only (taint, see playstyle above); the label may keep
            -- showing "Mythic", "List Group" reads ec.selectedActivity.
            ec.selectedActivity = activityID
            DBG("[LFGQuickCreate] Difficulty set to Mythic+, activityID:", activityID)
            if LFGListEntryCreation_UpdateValidState then
                pcall(LFGListEntryCreation_UpdateValidState, ec)
            end
            return
        end
    end
end

-- One dungeon icon button.
local function MakeButton(parent, dungeon, index)
    local _, _, _, iconTex = C_ChallengeMode.GetMapUIInfo(dungeon.cmID)
    local label = DungeonSortLabel(dungeon)

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
        -- CreateListing() directly from the click: via LFGListEntryCreation_ListGroup()
        -- it taints (ADDON_ACTION_BLOCKED).
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

-- One-time initialization, once Blizzard_GroupFinder is ready.
local seasonWait  -- frame that waits for the season data (created when needed)

local function Init()
    if initialized then return end

    local ec = LFGListFrame and LFGListFrame.EntryCreation
    if not ec then return end

    -- GetCurrentSeason() is -1 until RequestMapInfo is answered.
    if not C_MythicPlus then return end
    C_MythicPlus.RequestMapInfo()
    if C_MythicPlus.GetCurrentSeason() == -1 then
        -- CHALLENGE_MODE_MAPS_UPDATE answers RequestMapInfo; the timer covers no answer.
        if not seasonWait then
            seasonWait = CreateFrame("Frame")
            seasonWait:SetScript("OnEvent", function(self)
                self:UnregisterAllEvents()
                Init()
            end)
        end
        seasonWait:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
        C_Timer.After(3, Init)
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

    -- After a dropdown closes: re-sync the row; after a dungeon/category pick, Mythic+ again.
    local function HookDD(dd, isDifficultyDropdown)
        if not dd then return end
        dd:HookScript("OnHide", function()
            C_Timer.After(0.05, function()
                SyncVisibility()
                if not isDifficultyDropdown and ec:IsShown() then ApplyMythicPlus(ec) end
            end)
        end)
    end
    HookDD(ec.GroupDropdown)
    HookDD(ec.ActivityDropdown, true)
    if ec.CategoryDropdown and ec.CategoryDropdown ~= ec.GroupDropdown then
        HookDD(ec.CategoryDropdown)
    end

    -- Applies the options to the entry-creation frame on every open (and now if open).
    local function OnEntryCreationShown()
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
        -- Playstyle / Mythic+ independent of the dungeon buttons.
        C_Timer.After(0.05, function()
            if not ec:IsShown() then return end
            if RollAwayDB and RollAwayDB.lfgAutoPlaystyle then ApplyDefaultPlaystyle(ec) end
            ApplyMythicPlus(ec)
        end)
    end

    ec:HookScript("OnShow", OnEntryCreationShown)
    ec:HookScript("OnHide", function()
        if updateTicker then updateTicker:Cancel(); updateTicker = nil end
    end)

    if ec:IsShown() then OnEntryCreationShown() end
end

-- Public init, called from Core.lua on ADDON_LOADED.
function RA.InitLFGQuickCreate()
    -- Blizzard_GroupFinder loads at startup: the first loading screen is enough;
    -- Init waits for the season data itself.
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")

    f:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        C_Timer.After(0.5, Init)
    end)

    DBG("[LFGQuickCreate] Ready")
end
