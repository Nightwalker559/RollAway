-- RollAway - Misc.lua
-- Catch-all module for standalone features shown under the "Misc" settings
-- tab (Options\OptionsQoL.lua) - anything too small or too unrelated to the
-- other categories (Filter/LFG/Logs/Reminder) to warrant its own file.
--
-- Auto-accept invites from guild/friends: accepts group invites from guild
-- members, friends, and Battle.net friends. Default UI only - ElvUI already
-- ships this exact behavior under its own General options, so this stays
-- inactive when ElvUI is loaded (avoids fighting ElvUI's own
-- PARTY_INVITE_REQUEST handler / double-accepting the same invite).
-- Setting: RollAwayDB.autoAcceptInvite
--
-- Auto Repair: repairs at any merchant, using player or guild funds. Same
-- Default-UI-only reasoning as above - ElvUI has its own Auto Repair option.
-- Setting: RollAwayDB.autoRepairMode ("none" | "player" | "guild")

local RA   = _G["RollAway"]
local DBG  = RA.DBG
local RA_L = RA.RA_L

if ElvUI then return end

local function IsKnownInviter(inviterGUID)
    if not inviterGUID then return false end
    return C_BattleNet.GetGameAccountInfoByGUID(inviterGUID) ~= nil
        or C_FriendList.IsFriend(inviterGUID)
        or IsGuildMember(inviterGUID)
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
            print("|cff33ff99RollAway:|r " .. string.format(RA_L["qol_autorepair_msg_guild"], GetCoinTextureString(cost)))
            DBG("[Misc] Auto-repaired via guild funds:", cost)
            return
        end
        -- Guild funds insufficient - fall through to player funds below.
    end

    if GetMoney() >= cost then
        RepairAllItems()
        print("|cff33ff99RollAway:|r " .. string.format(RA_L["qol_autorepair_msg_player"], GetCoinTextureString(cost)))
        DBG("[Misc] Auto-repaired via player funds:", cost)
    else
        DBG("[Misc] Auto-repair skipped - not enough gold:", cost)
    end
end

local autoRepairFrame = CreateFrame("Frame")
autoRepairFrame:RegisterEvent("MERCHANT_SHOW")
autoRepairFrame:SetScript("OnEvent", TryAutoRepair)
