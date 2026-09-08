-- RollAway - QoL.lua
-- Quality of Life features.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local C_Timer_After    = RA.C_Timer_After
local C_Timer_NewTimer = RA.C_Timer_NewTimer

local VOIDCORE_CURRENCY_ID = RA.VOIDCORE_CURRENCY_ID

-- Shared "is the player max level" check, used by several QoL features
-- (vault currency display here, Omnium/Vault CharacterFrame buttons in
-- Modules/CharFrameButtons.lua) via RA.IsMaxLevel.
local function IsMaxLevel()
    return UnitLevel("player") >= GetMaxPlayerLevel()
end
RA.IsMaxLevel = IsMaxLevel

-- Equipment slots that can have durability
local DURA_SLOTS    = { 1, 3, 5, 6, 7, 8, 9, 10, 15, 16, 17 }
local DURA_THRESHOLD = 0.30  -- 30%

------------------------------------------------------------------------
-- Shared font helper
------------------------------------------------------------------------

local function GetQoLFont()
    local fontSize = (RollAwayDB and RollAwayDB.talentFontSize) or 20
    local fontPath = "Fonts\\FRIZQT__.TTF"
    if ElvUI then
        local E = unpack(ElvUI)
        fontPath = (E and E.media and E.media.normFont) or fontPath
    end
    return fontPath, fontSize
end

------------------------------------------------------------------------
-- Ready Check – "Check Talents" reminder
------------------------------------------------------------------------

-- Shared factory for QoL "toast" reminder frames (Ready Check, Durability):
-- centered, draggable, auto-hides after 6s via RA.CreateOneShotTimer. The
-- Join reminder frame is NOT built on this - its timer logic is more
-- involved (waits for full group / raid-vs-party), so keeping it separate
-- avoids coupling two very different lifecycles to one shared helper.
local function CreateQoLToastFrame(globalName, width, height, yOffset)
    local frame = CreateFrame("Frame", globalName, UIParent)
    frame:SetSize(width, height)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, yOffset)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    RA.MakeDraggable(frame)
    local timer = RA.CreateOneShotTimer(6, function() frame:Hide() end)
    frame:SetScript("OnHide", timer.Stop)
    frame:Hide()

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.text = text

    return frame, timer
end

local talentFrame
local talentTimer  -- RA.CreateOneShotTimer handle, set in CreateTalentFrame

local function CreateTalentFrame()
    if talentFrame then return end
    talentFrame, talentTimer = CreateQoLToastFrame("RollAwayTalentFrame", 280, 36, 180)
    talentFrame.text:SetText("|cffFFFFFF" .. RA_L["qol_check_talents"] .. "|r")
end

local function ShowTalentReminder()
    if not RollAwayDB or not RollAwayDB.readyCheckReminder then return end
    local itype = RA.cachedInstanceType
    if itype ~= "party" and itype ~= "raid" then return end

    DBG("[QoL] Ready check – showing talent reminder")
    CreateTalentFrame()

    local fontPath, fontSize = GetQoLFont()
    talentFrame.text:SetFont(fontPath, fontSize, "OUTLINE")
    talentFrame:Show()

    talentTimer.Start()
end

------------------------------------------------------------------------
-- Durability warning
------------------------------------------------------------------------

local durabilityFrame
local durabilityTimer  -- RA.CreateOneShotTimer handle, set in CreateDurabilityFrame

local function CreateDurabilityFrame()
    if durabilityFrame then return end
    durabilityFrame, durabilityTimer = CreateQoLToastFrame("RollAwayDurabilityFrame", 320, 36, 140)
end

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
    CreateDurabilityFrame()

    local fontPath, fontSize = GetQoLFont()
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
        if C_Timer_After then
            C_Timer_After(0.2, SetAHExpansionFilter)
        end
        -- Hook SetDisplayMode once when AH opens (catches tab switches e.g. Auctionator → Blizzard)
        if AuctionHouseFrame and not AuctionHouseFrame.RA_displayModeHooked then
            hooksecurefunc(AuctionHouseFrame, "SetDisplayMode", function()
                if C_Timer_After then
                    C_Timer_After(0.1, SetAHExpansionFilter)
                end
            end)
            AuctionHouseFrame.RA_displayModeHooked = true
            DBG("[QoL] AH SetDisplayMode hook set")
        end
    end)

    local function HookCraftingFrame()
        local co = ProfessionsCustomerOrdersFrame
        if not co then return false end
        local bo = co.BrowseOrders
        if not bo then return false end
        hooksecurefunc(bo, "Show", function()
            if C_Timer_After then
                C_Timer_After(0.2, SetCraftingOrderExpansionFilter)
            end
        end)
        DBG("[QoL] BrowseOrders:Show hook set")
        return true
    end

    -- PLAYER_INTERACTION_MANAGER_FRAME_SHOW catches NPC crafting board opens
    local coEventFrame = CreateFrame("Frame")
    coEventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    coEventFrame:SetScript("OnEvent", function()
        if C_Timer_After then
            C_Timer_After(0.5, SetCraftingOrderExpansionFilter)
        end
    end)

    if not HookCraftingFrame() then
        local hookFrame = CreateFrame("Frame")
        hookFrame:RegisterEvent("ADDON_LOADED")
        hookFrame:SetScript("OnEvent", function(self, _, loadedAddon)
            if loadedAddon == "Blizzard_ProfessionsUI" then
                HookCraftingFrame()
                self:UnregisterAllEvents()
            end
        end)
    end

    DBG("[QoL] AH/Crafting Orders expansion filter hook ready")
end

------------------------------------------------------------------------
-- Weekly Rewards (Great Vault) – Voidcore currency display
------------------------------------------------------------------------

local vaultCurrencyFrame

local function UpdateVaultCurrency()
    if not RollAwayDB or not RollAwayDB.vaultCurrencyDisplay then
        if vaultCurrencyFrame then vaultCurrencyFrame:Hide() end
        return
    end
    if not RA.BONUS_ROLLS_ENABLED then
        if vaultCurrencyFrame then vaultCurrencyFrame:Hide() end
        return
    end
    if not (RA.IsMaxLevel and RA.IsMaxLevel()) then
        if vaultCurrencyFrame then vaultCurrencyFrame:Hide() end
        return
    end

    local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(VOIDCORE_CURRENCY_ID)
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
        local fontPath, _ = GetQoLFont()
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
    local function HookVaultFrame()
        if not WeeklyRewardsFrame then return false end
        hooksecurefunc(WeeklyRewardsFrame, "Show", function()
            if C_Timer_After then
                C_Timer_After(0.1, UpdateVaultCurrency)
            end
        end)
        hooksecurefunc(WeeklyRewardsFrame, "SetShown", function(_, shown)
            if shown and C_Timer_After then
                C_Timer_After(0.1, UpdateVaultCurrency)
            end
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
        local f = CreateFrame("Frame")
        f:RegisterEvent("ADDON_LOADED")
        f:SetScript("OnEvent", function(self, _, loadedAddon)
            if loadedAddon == "Blizzard_WeeklyRewards" then
                HookVaultFrame()
                self:UnregisterAllEvents()
            end
        end)
    end
end

------------------------------------------------------------------------
-- Keystone companion addon – BigWigs Keystones or Details! Keystones.
-- Mutually exclusive via RollAwayDB.joinReminderKeyAddon.
-- Calls SlashCmdList directly (not typed text) to avoid triggering other addons.
------------------------------------------------------------------------

-- Availability checks, exposed via RA so Options.lua can grey out the
-- corresponding checkbox when the addon isn't installed/loaded.
local function IsBigWigsKeyAvailable()
    return _G["BigWigsLoader"] ~= nil and SlashCmdList["key"] ~= nil
end
RA.IsBigWigsKeyAvailable = IsBigWigsKeyAvailable

local function IsDetailsKeyAvailable()
    return _G["Details"] ~= nil and SlashCmdList["KEYSTONE"] ~= nil
end
RA.IsDetailsKeyAvailable = IsDetailsKeyAvailable

-- Returns "bigwigs" / "details" if the selected companion addon is loaded
-- and its toggle command is available, otherwise nil. Checks
-- joinReminderKeyAddon by default; pass "premade" to check premadeKeyAddon
-- instead (separate choice for manually formed groups, see below).
local function GetActiveKeyAddon(context)
    local choice = RollAwayDB and (context == "premade" and RollAwayDB.premadeKeyAddon or RollAwayDB.joinReminderKeyAddon)
    if choice == "bigwigs" and IsBigWigsKeyAvailable() then return "bigwigs" end
    if choice == "details" and IsDetailsKeyAvailable() then return "details" end
    return nil
end

-- Toggles the selected companion addon's keystone frame. Returns true if
-- toggled (caller schedules the matching close-toggle).
-- BigWigs' "key" toggles natively; Details!' "/keys" doesn't, so we
-- check its shown state and Hide() it directly when already open.
local function ToggleKeyAddon(context)
    local which = GetActiveKeyAddon(context)
    if which == "bigwigs" then
        DBG("[QoL] Toggling BigWigs Keystones via SlashCmdList[key]")
        SlashCmdList["key"]("")
        return true
    elseif which == "details" then
        local f = _G["DetailsKeystoneSmallFrame"]
        if f and f:IsShown() then
            DBG("[QoL] Closing Details! Keystones (direct Hide)")
            f:Hide()
        else
            DBG("[QoL] Opening Details! Keystones via SlashCmdList[KEYSTONE]")
            SlashCmdList["KEYSTONE"]("")
        end
        return true
    end
    return false
end

------------------------------------------------------------------------
-- Instance Join reminder – shows instance name when joining a group
------------------------------------------------------------------------

local joinFrame
local joinTimer
local keyAddonOpenedByCreation      = false -- shared: own listing active (M+ or raid)
local keyAddonOpenedByCreationMplus = false -- true only when own M+ listing opened the companion addon

local function StopJoinTimer()
    if joinTimer then
        RA.SafeCancelTimer(joinTimer)
        joinTimer = nil
    end
end

local function CreateJoinFrame()
    if joinFrame then return end

    joinFrame = CreateFrame("Frame", "RollAwayJoinFrame", UIParent)
    joinFrame:SetSize(400, 36)
    joinFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
    joinFrame:SetFrameStrata("HIGH")
    joinFrame:SetClampedToScreen(true)
    RA.MakeDraggable(joinFrame)
    joinFrame:SetScript("OnHide", StopJoinTimer)
    joinFrame:Hide()

    local text = joinFrame:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    text:SetPoint("CENTER", joinFrame, "CENTER", 0, 0)
    joinFrame.text = text
end

local function ShowJoinReminder(instanceName, forceTimer)
    if not RollAwayDB or not RollAwayDB.instanceJoinReminder then return end
    if not instanceName or instanceName == "" then return end
    -- Don't show reminder if we are the group leader (own listing creation)
    if keyAddonOpenedByCreation then
        DBG("[QoL] Join reminder skipped – own listing active")
        return
    end

    DBG("[QoL] Join reminder:", instanceName)
    CreateJoinFrame()
    StopJoinTimer()

    local fontPath, fontSize = GetQoLFont()
    joinFrame.text:SetFont(fontPath, fontSize, "OUTLINE")
    joinFrame.text:SetText("|cffFFFFFF" .. instanceName .. "|r")
    joinFrame:Show()

    -- Auto-open companion addon for party only (no keystone teleports in raid);
    -- skip if already opened by listing creation.
    local keyAddonOpened = false
    if not IsInRaid() and not keyAddonOpenedByCreation and GetActiveKeyAddon() and C_Timer_After then
        keyAddonOpened = true
        C_Timer_After(0.3, ToggleKeyAddon)
    end

    -- Helper: start the 6s hide timer and close the companion addon after
    local function StartHideTimer()
        StopJoinTimer()
        if C_Timer_NewTimer then
            joinTimer = C_Timer_NewTimer(6, function()
                joinTimer = nil
                if joinFrame then joinFrame:Hide() end
                if keyAddonOpened then
                    DBG("[QoL] Closing keystone companion addon after reminder timeout")
                    ToggleKeyAddon()
                    keyAddonOpened = false
                end
            end)
        elseif C_Timer_After then
            C_Timer_After(6, function()
                if joinFrame and joinFrame:IsShown() then joinFrame:Hide() end
                if keyAddonOpened then
                    DBG("[QoL] Closing keystone companion addon after reminder timeout")
                    ToggleKeyAddon()
                    keyAddonOpened = false
                end
            end)
        end
    end

    -- Raids: start immediately. Party: wait for full group (5). forceTimer
    -- (test mode) skips the group check. Fallback: start after 30s anyway.
    if forceTimer or IsInRaid() or GetNumGroupMembers() >= 5 then
        DBG("[QoL] Timer starting immediately (force:", tostring(forceTimer), "/ raid:", tostring(IsInRaid()), "/ full:", tostring(GetNumGroupMembers() >= 5), ")")
        StartHideTimer()
    else
        DBG("[QoL] Waiting for full group before starting hide timer")
        local waitFrame = CreateFrame("Frame", nil, UIParent)
        local fallbackTimer = nil
        local done = false

        local function Finish()
            if done then return end
            done = true
            waitFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
            if fallbackTimer then
                RA.SafeCancelTimer(fallbackTimer)
                fallbackTimer = nil
            end
            StartHideTimer()
        end

        waitFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        waitFrame:SetScript("OnEvent", function()
            -- Small delay so WoW has time to update the roster count
            if C_Timer_After then
                C_Timer_After(0.3, function()
                    if GetNumGroupMembers() >= 5 then Finish() end
                end)
            else
                if GetNumGroupMembers() >= 5 then Finish() end
            end
        end)

        -- Fallback: start hide timer after 30s if group never fills up
        if C_Timer_NewTimer then
            fallbackTimer = C_Timer_NewTimer(30, function()
                DBG("[QoL] Fallback – starting hide timer after 30s")
                Finish()
            end)
        elseif C_Timer_After then
            C_Timer_After(30, function()
                DBG("[QoL] Fallback – starting hide timer after 30s")
                Finish()
            end)
        end
    end
end

-- Finds the current-season dungeon entry (Data\Dungeons.lua) matching an
-- LFG activity ID. activityID == dungeon.lfgID (see LFGQuickCreate.lua).
local function GetDungeonEntryByLfgID(activityID)
    local dungeons = RA.DUNGEONS[RA.ACTIVE_SEASON] or {}
    for _, d in ipairs(dungeons) do
        if d.lfgID == activityID then return d end
    end
    return nil
end

-- Resolve instance name from an LFG activity ID.
-- Returns nil if the activity is not a Mythic+ dungeon or current raid.
-- Second return value: true if the activity is Mythic+ (vs. raid).
-- Third return value: the matched dungeon entry (M+ only, if found in the
-- current season's pool) - used by the teleport reminder to show only the
-- relevant portal.
-- For M+ dungeons the name comes from our own locale table (RA_L), not the
-- Blizzard client string, so it always matches the addon's own language
-- setting instead of the game client's.
local function GetNameFromActivityID(activityID)
    if not (activityID and C_LFGList) then return nil end
    local act = C_LFGList.GetActivityInfoTable(activityID)
    if not act then return nil end
    -- Only show reminder for Mythic+ dungeons or current season raids
    if not (act.isMythicPlusActivity or act.isCurrentRaidActivity) then
        DBG("[QoL] Join reminder filtered out – not M+ or current raid (activityID:", activityID, ")")
        return nil
    end

    if act.isMythicPlusActivity then
        local dungeon = GetDungeonEntryByLfgID(activityID)
        if dungeon then
            return RA_L["dungeon_"..dungeon.key], true, dungeon
        end
        -- Fallback for a M+ activity outside the tracked season pool
        -- (shouldn't normally happen) - use the Blizzard string as-is.
        local name = act.fullName ~= "" and act.fullName or nil
        return name, true, nil
    end

    local name = act.fullName ~= "" and act.fullName or nil
    return name, false, nil
end

-- Routes to the teleport reminder for Mythic+ when selected, otherwise the
-- default instance-name join reminder. Raids always use the default one -
-- BigWigs/Details/teleport portals don't apply to raid teleports.
local function DispatchJoinReminder(name, isMythicPlus, dungeon, forceTimer)
    if isMythicPlus and RollAwayDB and RollAwayDB.joinReminderKeyAddon == "teleport" then
        RA.ShowTeleportReminder(name, dungeon)
    else
        ShowJoinReminder(name, forceTimer)
    end
end

local function InitJoinReminder()
    local f = CreateFrame("Frame")

    -- LFG_LIST_APPLICATION_STATUS_UPDATED: fires when the local player's
    -- own application is accepted via the LFG browser
    f:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")

    -- GROUP_ROSTER_UPDATE: fires when joining a group via direct invite.
    -- We check if the group has an active LFG listing and show its name.
    f:RegisterEvent("GROUP_ROSTER_UPDATE")

    -- LFG_LIST_ACTIVE_ENTRY_UPDATE: fires when the player creates or removes
    -- their own LFG listing — used to open/close BigWigs Keystones.
    f:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")

    -- Track whether we already showed the reminder for the current group listing
    local lastShownEntryID = nil
    -- Spam protection: only one pending check at a time
    local rosterCheckPending = false
    -- Timer for delayed BigWigs close after own listing group fills up
    local creationCloseTimer = nil
    -- Persists until the group is left; prevents GROUP_ROSTER_UPDATE spam
    -- (ready checks, buffs, etc.) from re-opening the addon after the
    -- 6s auto-close timer runs.
    local premadeHandledThisGroup = false
    -- Persists until the group is left. True once we've ever had our own
    -- LFG listing for this group (even after Blizzard auto-removes it when
    -- the group fills up). Prevents the premade-group fallback from firing
    -- during that removal, which raced with the creation-close timer and
    -- caused the companion addon to toggle open/close/open.
    local hadOwnListingThisGroup = false

    -- Fallback: group formed manually (direct invites/premade), not via LFG
    -- Group Finder. There's no LFG activity to resolve an instance name from,
    -- so just open the companion addon (or the teleport reminder) once the
    -- party is full.
    local function TryOpenForPremadeGroup()
        if not RollAwayDB or not RollAwayDB.instanceJoinReminder then return end
        if not IsInGroup() or IsInRaid() then return end
        if keyAddonOpenedByCreation or premadeHandledThisGroup or hadOwnListingThisGroup then return end
        if GetNumGroupMembers() < 5 then return end

        if not GetActiveKeyAddon("premade") then return end

        DBG("[QoL] Premade group full – opening keystone companion addon")
        premadeHandledThisGroup = true
        ToggleKeyAddon("premade")

        if C_Timer_NewTimer then
            C_Timer_NewTimer(6, function()
                DBG("[QoL] Closing keystone companion addon after premade timeout")
                ToggleKeyAddon("premade")
            end)
        end
    end

    local function TryShowFromActiveEntry()
        rosterCheckPending = false
        if not RollAwayDB or not RollAwayDB.instanceJoinReminder then return end
        if not C_LFGList then return end
        if not IsInGroup() then
            lastShownEntryID = nil
            premadeHandledThisGroup = false
            hadOwnListingThisGroup = false
            return
        end
        local entryInfo = C_LFGList.GetActiveEntryInfo()
        if not (entryInfo and entryInfo.activityIDs and entryInfo.activityIDs[1]) then
            TryOpenForPremadeGroup()
            return
        end
        local entryID = entryInfo.activityIDs[1]
        if entryID == lastShownEntryID then return end  -- already shown for this listing
        local name, isMythicPlus, dungeon = GetNameFromActivityID(entryID)
        DBG("[QoL] Join reminder (active entry): resolved name=", name or "nil")
        if name then
            lastShownEntryID = entryID
            DispatchJoinReminder(name, isMythicPlus, dungeon)
        end
    end

    f:SetScript("OnEvent", function(_, event, searchResultID, newStatus)
        if event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
            DBG("[QoL] LFG_LIST_APPLICATION_STATUS_UPDATED: searchResultID=", searchResultID, "status=", newStatus)
            if newStatus ~= "inviteaccepted" then return end
            local resultInfo = C_LFGList.GetSearchResultInfo(searchResultID)
            if not (resultInfo and resultInfo.activityIDs) then
                DBG("[QoL] Join reminder: no activityIDs in resultInfo")
                return
            end
            local name, isMythicPlus, dungeon = GetNameFromActivityID(resultInfo.activityIDs[1])
            DBG("[QoL] Join reminder: resolved name=", name or "nil")
            if name then
                lastShownEntryID = resultInfo.activityIDs[1]
                DispatchJoinReminder(name, isMythicPlus, dungeon)
            end

        elseif event == "GROUP_ROSTER_UPDATE" then
            -- Spam protection: if a check is already queued, skip this event.
            -- GROUP_ROSTER_UPDATE fires for every roster change (joins, leaves, role changes).
            if rosterCheckPending then return end
            rosterCheckPending = true
            if C_Timer_After then
                C_Timer_After(0.5, TryShowFromActiveEntry)
            else
                TryShowFromActiveEntry()
            end

        elseif event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
            if not C_LFGList then return end
            local entryInfo = C_LFGList.GetActiveEntryInfo()

            if entryInfo and entryInfo.activityIDs and entryInfo.activityIDs[1] then
                -- Own listing created or updated (M+ or raid)
                local activityID = entryInfo.activityIDs[1]
                local act = C_LFGList.GetActivityInfoTable(activityID)
                if not (act and (act.isMythicPlusActivity or act.isCurrentRaidActivity)) then return end
                hadOwnListingThisGroup = true
                if keyAddonOpenedByCreation then return end  -- already open
                keyAddonOpenedByCreation = true

                -- Teleport reminder takes priority for M+ when selected -
                -- doesn't use the companion-addon open/close bookkeeping
                -- below since it has no auto-close timer.
                if act.isMythicPlusActivity and RollAwayDB and RollAwayDB.joinReminderKeyAddon == "teleport" then
                    local dungeon = GetDungeonEntryByLfgID(activityID)
                    local name = dungeon and RA_L["dungeon_"..dungeon.key] or (act.fullName ~= "" and act.fullName or nil)
                    DBG("[QoL] Own M+ listing created – showing teleport reminder:", name or "nil")
                    RA.ShowTeleportReminder(name, dungeon)
                    return
                end

                -- Only open the companion addon for M+ (raids have no keystone teleports)
                if act.isMythicPlusActivity and GetActiveKeyAddon() then
                    DBG("[QoL] Own M+ listing created – opening keystone companion addon")
                    keyAddonOpenedByCreationMplus = true
                    ToggleKeyAddon()
                end
            else
                -- Listing removed (cancelled or group full)
                if not keyAddonOpenedByCreation then return end
                keyAddonOpenedByCreation = false
                if creationCloseTimer then
                    RA.SafeCancelTimer(creationCloseTimer)
                    creationCloseTimer = nil
                end
                -- Only toggle the companion addon if it was opened by M+ creation
                if keyAddonOpenedByCreationMplus then
                    keyAddonOpenedByCreationMplus = false
                    if GetNumGroupMembers() >= 5 then
                        DBG("[QoL] Group full – closing keystone companion addon in 6s")
                        if C_Timer_NewTimer then
                            creationCloseTimer = C_Timer_NewTimer(6, function()
                                creationCloseTimer = nil
                                DBG("[QoL] Closing keystone companion addon after creation timer")
                                ToggleKeyAddon()
                            end)
                        end
                    else
                        DBG("[QoL] Listing cancelled – closing keystone companion addon immediately")
                        ToggleKeyAddon()
                    end
                end
            end
        end
    end)

    RA.ShowJoinReminder = ShowJoinReminder
    DBG("[QoL] Instance join reminder initialized")
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
local function FadeOutButton(child)
    child:SetAlpha(0)
    if child.EnableMouse then child:EnableMouse(false) end
end

local function FadeInButton(child)
    child:SetAlpha(1)
    if child.EnableMouse then child:EnableMouse(true) end
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
                        FadeOutButton(self)
                    end
                end)
            end
            if child:IsShown() and child:GetAlpha() > 0 then
                FadeOutButton(child)
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
        FadeInButton(btn)
    end
    wipe(hiddenMapActivityButtons)
end

function RA.ApplyMapActivityTrackerFeature()
    if InCombatLockdown and InCombatLockdown() then
        if C_Timer_After then C_Timer_After(1, RA.ApplyMapActivityTrackerFeature) end
        return
    end
    if not WorldMapFrame then return end

    if not (RollAwayDB and RollAwayDB.hideMapActivityTracker) then
        RestoreMapActivityTracker()
        return
    end

    if not mapActivityHooked then
        mapActivityHooked = true
        local function DeferredHide()
            if C_Timer_After then C_Timer_After(0, HideMapActivityTracker)
            else HideMapActivityTracker() end
        end
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

local craftingOutputLogHooked       = false
local craftingOutputLogHookedOrders = false

local function HookCraftingOutputLog(log)
    hooksecurefunc(log, "FinalizeResultData", function(self)
        if RollAwayDB and RollAwayDB.hideCraftingOutputLog then
            self:Hide()
        end
    end)
end

function RA.ApplyCraftingOutputLogFeature()
    local log = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.CraftingOutputLog
    if log then
        if not craftingOutputLogHooked then
            craftingOutputLogHooked = true
            HookCraftingOutputLog(log)
            DBG("[QoL] CraftingOutputLog hide hook set (CraftingPage)")
        end
        if RollAwayDB and RollAwayDB.hideCraftingOutputLog and log:IsShown() then
            log:Hide()
        end
    end

    -- Crafting orders (Handwerksaufträge) use a separate frame instance.
    local orderLog = ProfessionsFrame and ProfessionsFrame.OrdersPage
        and ProfessionsFrame.OrdersPage.OrderView
        and ProfessionsFrame.OrdersPage.OrderView.CraftingOutputLog
    if orderLog then
        if not craftingOutputLogHookedOrders then
            craftingOutputLogHookedOrders = true
            HookCraftingOutputLog(orderLog)
            DBG("[QoL] CraftingOutputLog hide hook set (OrdersPage)")
        end
        if RollAwayDB and RollAwayDB.hideCraftingOutputLog and orderLog:IsShown() then
            orderLog:Hide()
        end
    end
end

local function InitCraftingOutputLogHide()
    if ProfessionsFrame then
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
        return
    end

    local hookFrame = CreateFrame("Frame")
    hookFrame:RegisterEvent("ADDON_LOADED")
    hookFrame:SetScript("OnEvent", function(self, _, loadedAddon)
        if loadedAddon == "Blizzard_Professions" then
            self:UnregisterAllEvents()
            RA.ApplyCraftingOutputLogFeature()
            ProfessionsFrame:HookScript("OnShow", RA.ApplyCraftingOutputLogFeature)
            if ProfessionsFrame.OrdersPage then
                ProfessionsFrame.OrdersPage:HookScript("OnShow", RA.ApplyCraftingOutputLogFeature)
                if ProfessionsFrame.OrdersPage.OrderView then
                    ProfessionsFrame.OrdersPage.OrderView:HookScript("OnShow", RA.ApplyCraftingOutputLogFeature)
                end
            end
        end
    end)
end

------------------------------------------------------------------------
-- Initialization – called from Core.lua ADDON_LOADED
------------------------------------------------------------------------

function RA.InitQoL()
    -- Ready Check
    local f = CreateFrame("Frame")
    f:RegisterEvent("READY_CHECK")
    f:SetScript("OnEvent", function() ShowTalentReminder() end)

    -- Durability
    local d = CreateFrame("Frame")
    d:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    d:RegisterEvent("PLAYER_ENTERING_WORLD")
    d:SetScript("OnEvent", function() CheckDurability() end)

    -- AH Current Expansion Only filter
    InitAHFilter()

    -- Great Vault currency display
    InitVaultCurrency()

    -- Instance join reminder
    InitJoinReminder()

    -- Omniumfoliant minimap → CharacterFrame button
    RA.InitOmniumfoliant()

    -- Great Vault → CharacterFrame button
    RA.ApplyVaultButtonFeature()

    -- Re-apply both CharacterFrame buttons once Blizzard_CharacterFrame (PaperDollFrame)
    -- actually loads, since it's load-on-demand and usually isn't ready yet here.
    RA.InitCharacterFrameButtons()

    -- World Map: hide tracked-faction activity button
    RA.ApplyMapActivityTrackerFeature()

    -- Professions: hide "Crafting Output Log" popup
    InitCraftingOutputLogHide()

    -- Re-check max-level gating once the player dings (UnitLevel can be
    -- stale in the same frame as PLAYER_LEVEL_UP, so defer one tick).
    local levelGateFrame = CreateFrame("Frame")
    levelGateFrame:RegisterEvent("PLAYER_LEVEL_UP")
    levelGateFrame:SetScript("OnEvent", function()
        C_Timer_After(0, function()
            RA.ApplyOmniumfoliantFeature()
            RA.ApplyVaultButtonFeature()
        end)
    end)

    -- Re-apply buttons after every loading screen: Blizzard's frame reset
    -- can hide them without our hooks firing. Cheap/idempotent to re-run.
    local reapplyFrame = CreateFrame("Frame")
    reapplyFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    reapplyFrame:SetScript("OnEvent", function()
        C_Timer_After(0.5, function()
            RA.ApplyOmniumfoliantFeature()
            RA.ApplyVaultButtonFeature()
        end)
    end)

    DBG("QoL initialized")
end