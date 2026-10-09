-- RollAway - Misc.lua
-- Small standalone features of the "Misc" settings tab:
-- Auto-accept invites from guild members, friends and Battle.net friends (autoAcceptInvite).
-- Auto repair at any merchant with player or guild funds (autoRepairMode: none/player/guild).

local RA   = _G["RollAway"]
local DBG  = RA.DBG
local RA_L = RA.RA_L

-- IsGuildMember takes a unit token, not a GUID: match against the roster instead
-- (C_GuildInfo.GuildRoster() requests a fresh one, async).
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

-- Finds the invite popup by its StaticPopupDialogs key (no numbered dialogs since 11.2).
local function HidePartyInvitePopup()
    for _, which in ipairs({ "PARTY_INVITE", "PARTY_INVITE_XREALM" }) do
        local popupName, popup = StaticPopup_Visible(which)
        if popupName then
            popup.inviteAccepted = 1
            StaticPopup_Hide(which)
        end
    end
end

local autoAcceptFrame = CreateFrame("Frame")
autoAcceptFrame:RegisterEvent("PARTY_INVITE_REQUEST")
autoAcceptFrame:SetScript("OnEvent", function(_, _, _, _, _, _, _, _, inviterGUID)
    if not RollAwayDB or not RollAwayDB.autoAcceptInvite then return end
    -- Not while grouped or queued (would disturb an LFG/premade group).
    if IsInGroup() or (QueueStatusMinimapButton and QueueStatusMinimapButton:IsShown()) then return end
    if not IsKnownInviter(inviterGUID) then return end

    AcceptGroup()
    HidePartyInvitePopup()
    DBG("[Misc] Auto-accepted invite from guild/friend")
end)

-- Auto repair

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
            RA.Print(string.format(RA_L["qol_autorepair_msg_guild"], C_CurrencyInfo.GetCoinTextureString(cost)))
            DBG("[Misc] Auto-repaired via guild funds:", cost)
            return
        end
        -- Guild funds not enough: player funds below.
    end

    if GetMoney() >= cost then
        RepairAllItems()
        RA.Print(string.format(RA_L["qol_autorepair_msg_player"], C_CurrencyInfo.GetCoinTextureString(cost)))
        DBG("[Misc] Auto-repaired via player funds:", cost)
    else
        DBG("[Misc] Auto-repair skipped - not enough gold:", cost)
    end
end

local autoRepairFrame = CreateFrame("Frame")
autoRepairFrame:RegisterEvent("MERCHANT_SHOW")
autoRepairFrame:SetScript("OnEvent", TryAutoRepair)
