-- RollAway - Misc.lua
-- Catch-all module for standalone features shown under the "Misc" settings
-- tab (Options\OptionsQoL.lua) - anything too small or too unrelated to the
-- other categories (Character/Filter/Hide/LFG/Logs/Quests/Reminder) to warrant its own file.
--
-- Auto-accept invites from guild/friends: accepts group invites from guild
-- members, friends, and Battle.net friends.
-- Setting: RollAwayDB.autoAcceptInvite
--
-- Auto Repair: repairs at any merchant, using player or guild funds.
-- Setting: RollAwayDB.autoRepairMode ("none" | "player" | "guild")

local RA   = _G["RollAway"]
local DBG  = RA.DBG
local RA_L = RA.RA_L

-- IsGuildMember(unit) takes a unit token ("target", "party1", ...), not a
-- GUID - there is no direct GUID-based guild check, so match against the
-- roster instead. C_GuildInfo.GuildRoster() requests a fresh roster (async,
-- GUILD_ROSTER_UPDATE); harmless to call even if one is already in flight.
local function IsGuildMemberGUID(guid)
    if not IsInGuild() then return false end
    if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
    for i = 1, GetNumGuildMembers() do
        if select(17, GetGuildRosterInfo(i)) == guid then return true end
    end
    return false
end

local function IsKnownInviter(inviterGUID)
    if not inviterGUID or not RA.IsAccessible(inviterGUID) then return false end
    return C_BattleNet.GetGameAccountInfoByGUID(inviterGUID) ~= nil
        or C_FriendList.IsFriend(inviterGUID)
        or IsGuildMemberGUID(inviterGUID)
end

-- STATICPOPUP_NUMDIALOGS was removed in patch 11.2 (no numbered-loop
-- iteration anymore). StaticPopup_Visible(which) + StaticPopup_Hide(which)
-- doesn't need it - finds the dialog by its StaticPopupDialogs key directly.
local function HidePartyInvitePopup()
    for _, which in ipairs({ "PARTY_INVITE", "PARTY_INVITE_XREALM" }) do
        local popupName = StaticPopup_Visible(which)
        if popupName then
            local popup = _G[popupName]
            if popup then popup.inviteAccepted = 1 end
            StaticPopup_Hide(which)
        end
    end
end

local autoAcceptFrame = CreateFrame("Frame")
autoAcceptFrame:RegisterEvent("PARTY_INVITE_REQUEST")
autoAcceptFrame:SetScript("OnEvent", function(_, _, _, _, _, _, _, _, inviterGUID)
    if not RollAwayDB or not RollAwayDB.autoAcceptInvite then return end
    -- Don't auto-accept while already grouped or queued - avoid
    -- interfering with an active LFG/premade group flow.
    if IsInGroup() or (QueueStatusMinimapButton and QueueStatusMinimapButton:IsShown()) then return end
    if not IsKnownInviter(inviterGUID) then return end

    AcceptGroup()
    HidePartyInvitePopup()
    DBG("[Misc] Auto-accepted invite from guild/friend")
end)

------------------------------------------------------------------------
-- Auto Repair
------------------------------------------------------------------------

local function TryAutoRepair()
    local mode = RollAwayDB and RollAwayDB.autoRepairMode
    if not mode or mode == "none" then return end
    if not CanMerchantRepair() then return end

    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end

    if mode == "guild" and IsInGuild() and CanGuildBankRepair() then
        local withdrawLimit = GetGuildBankWithdrawMoney()
        local guildMoney    = GetGuildBankMoney()
        local available = (withdrawLimit == -1) and guildMoney or math.min(withdrawLimit, guildMoney)
        if available >= cost then
            RepairAllItems(1)
            RA.Print(string.format(RA_L["qol_autorepair_msg_guild"], GetCoinTextureString(cost)))
            DBG("[Misc] Auto-repaired via guild funds:", cost)
            return
        end
        -- Guild funds insufficient - fall through to player funds below.
    end

    if GetMoney() >= cost then
        RepairAllItems()
        RA.Print(string.format(RA_L["qol_autorepair_msg_player"], GetCoinTextureString(cost)))
        DBG("[Misc] Auto-repaired via player funds:", cost)
    else
        DBG("[Misc] Auto-repair skipped - not enough gold:", cost)
    end
end

local autoRepairFrame = CreateFrame("Frame")
autoRepairFrame:RegisterEvent("MERCHANT_SHOW")
autoRepairFrame:SetScript("OnEvent", TryAutoRepair)
