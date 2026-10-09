-- RollAway - Quests.lua
-- Quest automation at NPCs: picks quests from the gossip / greeting list, accepts them
-- (regular / daily / weekly separately) and turns in finished ones.
-- Safety: no turn-in for quests that ask for gold or currency, and only with at most
-- one reward to choose. A modifier key pauses the automation while held (default) or
-- is required to run it (questRequireModifier).
-- Settings: questAcceptRegular / questAcceptDaily / questAcceptWeekly / questAutoTurnIn /
-- questRequireModifier / questModifierKey. Events only while an option is on.

local RA  = _G["RollAway"]
local DBG = RA.DBG

local Frequency = Enum.QuestFrequency or { Default = 0, Daily = 1, Weekly = 2 }

local MODIFIER_DOWN = {
    SHIFT = IsShiftKeyDown,
    ALT   = IsAltKeyDown,
    CTRL  = IsControlKeyDown,
}

local questFrame

-- Rules

-- Allowed right now? Modifier not required: must NOT be held (pause); required: must be held.
local function AutomationActive()
    local db = RollAwayDB
    if not db then return false end
    local isDown = (MODIFIER_DOWN[db.questModifierKey] or IsShiftKeyDown)()
    return (isDown and true or false) == (db.questRequireModifier and true or false)
end

local function CanAcceptFrequency(frequency)
    local db = RollAwayDB
    if frequency == Frequency.Daily then return db.questAcceptDaily end
    if frequency == Frequency.Weekly then return db.questAcceptWeekly end
    return db.questAcceptRegular
end

-- Gold or currency the quest would take. Only valid in QUEST_PROGRESS (on the reward
-- page the same calls count the rewards).
local function TurnInCostsSomething()
    if (GetQuestMoneyToGet() or 0) > 0 then return true end
    return (GetNumQuestCurrencies and GetNumQuestCurrencies() or 0) > 0
end

-- NPC dialogs: pick the next quest from the list, one per event (the list reopens).

local function PickFromGossip()
    local db = RollAwayDB
    if db.questAutoTurnIn then
        for _, quest in ipairs(C_GossipInfo.GetActiveQuests()) do
            if quest.isComplete and quest.questID then
                C_GossipInfo.SelectActiveQuest(quest.questID)
                return
            end
        end
    end
    for _, quest in ipairs(C_GossipInfo.GetAvailableQuests()) do
        if quest.questID and CanAcceptFrequency(quest.frequency) then
            C_GossipInfo.SelectAvailableQuest(quest.questID)
            return
        end
    end
end

local function PickFromGreeting()
    if RollAwayDB.questAutoTurnIn then
        for i = 1, GetNumActiveQuests() do
            local _, isComplete = GetActiveTitle(i)
            if isComplete then
                SelectActiveQuest(i)
                return
            end
        end
    end
    for i = 1, GetNumAvailableQuests() do
        local _, frequency = GetAvailableQuestInfo(i)
        if CanAcceptFrequency(frequency) then
            SelectAvailableQuest(i)
            return
        end
    end
end

-- Quest dialog steps

local handlers = {
    GOSSIP_SHOW     = PickFromGossip,
    QUEST_GREETING  = PickFromGreeting,
}

function handlers.QUEST_DETAIL()
    -- Blizzard's UI code does not use QuestIsDaily/Weekly: without them it counts as regular.
    local frequency = Frequency.Default
    if QuestIsDaily and QuestIsDaily() then
        frequency = Frequency.Daily
    elseif QuestIsWeekly and QuestIsWeekly() then
        frequency = Frequency.Weekly
    end
    if not CanAcceptFrequency(frequency) then return end

    if QuestGetAutoAccept() then
        -- Already in the log, only the notice is open.
        CloseQuest()
    else
        AcceptQuest()
    end
end

-- Quests that ask for confirmation first (e.g. a shared escort)
function handlers.QUEST_ACCEPT_CONFIRM()
    if not RollAwayDB.questAcceptRegular then return end
    ConfirmAcceptQuest()
    StaticPopup_Hide("QUEST_ACCEPT")
end

function handlers.QUEST_PROGRESS()
    if not RollAwayDB.questAutoTurnIn then return end
    if not IsQuestCompletable() or TurnInCostsSomething() then return end
    CompleteQuest()
end

function handlers.QUEST_COMPLETE()
    if not RollAwayDB.questAutoTurnIn then return end
    local choices = GetNumQuestChoices()
    if choices <= 1 then
        GetQuestReward(choices)
        DBG("[Quests] Turned in quest")
    end
end

-- Event registration

local function SetRegistered(event, on)
    if on then
        questFrame:RegisterEvent(event)
    else
        questFrame:UnregisterEvent(event)
    end
end

-- Only the events the settings need; at load and on option change.
function RA.ApplyQuestAutomation()
    if not questFrame then return end
    local db = RollAwayDB
    local accept = db and (db.questAcceptRegular or db.questAcceptDaily or db.questAcceptWeekly)
    local turnIn = db and db.questAutoTurnIn

    SetRegistered("GOSSIP_SHOW",    accept or turnIn)
    SetRegistered("QUEST_GREETING", accept or turnIn)
    SetRegistered("QUEST_DETAIL",   accept)
    SetRegistered("QUEST_ACCEPT_CONFIRM", db and db.questAcceptRegular)
    SetRegistered("QUEST_PROGRESS", turnIn)
    SetRegistered("QUEST_COMPLETE", turnIn)
end

function RA.InitQuests()
    questFrame = CreateFrame("Frame")
    questFrame:SetScript("OnEvent", function(_, event)
        if not AutomationActive() then return end
        handlers[event]()
    end)
    RA.ApplyQuestAutomation()
end
