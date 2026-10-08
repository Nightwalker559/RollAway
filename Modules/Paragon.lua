-- RollAway - Paragon.lua
-- Midnight paragon bag notification.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local TIMER_DURATION = 60

------------------------------------------------------------------------
-- Midnight paragon quest table: questID -> locale key
------------------------------------------------------------------------
local PARAGON_QUESTS = {
    [94492] = "paragon_faction_slayers_duellum",
    [89032] = "paragon_faction_singularity",
    [93811] = "paragon_faction_silvermoon_court",
    [95391] = "paragon_faction_ritual_sites",
    [89035] = "paragon_faction_harati",
    [93566] = "paragon_faction_amani_tribe",
    [93798] = "paragon_faction_zuljarras_forces",
}

------------------------------------------------------------------------
-- Quests with a known turn-in NPC + zone (verified via Wowhead 12.0.7).
-- Text lives in locale files as paragon_npc_<questID> / paragon_zone_<questID>.
-- Static table since the live waypoint API only covers the tracked quest.
------------------------------------------------------------------------
local PARAGON_LOCATION_QUESTS = {
    [94492] = true,
    [89032] = true, -- Quest text says "Murik in Iskaara" (recycled DF text,
                     -- Blizzard bug since 11.0.5); actual turn-in is Void
                     -- Researcher Anomander at Howling Ridge in Voidstorm.
    [93811] = true,
    [95391] = true,
    [89035] = true,
    [93566] = true,
    -- [93798] Zul'jarra's Forces: turn-in NPC/zone not yet verified, omitted for now.
}

local function GetQuestLocation(questID)
    if not PARAGON_LOCATION_QUESTS[questID] then return nil end
    return {
        npc  = RA_L["paragon_npc_"  .. questID],
        zone = RA_L["paragon_zone_" .. questID],
    }
end

------------------------------------------------------------------------
-- Frame
------------------------------------------------------------------------

local paragonFrame

local function CreateParagonFrame()
    if paragonFrame then return end

    paragonFrame = RA.CreatePopupFrame({
        name     = "RollAwayParagonFrame",
        okayName = "RollAwayParagonOkay",
        width    = 300,
        height   = 130,
        yOffset  = -220,
        duration = TIMER_DURATION,
        fitHeight = function(self)
            local lastRow = self.rows[self.numActiveRows]
            local bottomY = lastRow and lastRow.content:GetBottom() or self.header:GetBottom()
            local topY = self:GetTop()
            local contentHeight = (topY and bottomY) and (topY - bottomY) or 80
            -- contentHeight (top edge -> last row bottom) + gap + btn(22) + bar(8) + pad(18)
            return contentHeight + 10 + 22 + 8 + 18
        end,
    })

    -- Header (count line)
    paragonFrame.header = RA.CreatePopupBodyText(paragonFrame)

    -- Row pool: bullet + content FontString, content anchored right after
    -- the bullet so wrapped lines stay aligned under the entry text.
    paragonFrame.rows = {}
end

-- Returns the row for index, creating and anchoring it below the previous row on first use.
local function EnsureRow(index)
    local row = paragonFrame.rows[index]
    if row then return row end

    local bullet = paragonFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bullet:SetWidth(14)
    bullet:SetJustifyH("LEFT")
    bullet:SetText("|cffFFD100-|r")

    local content = paragonFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    content:SetPoint("TOPLEFT", bullet, "TOPRIGHT", 2, 0)
    content:SetPoint("RIGHT", paragonFrame, "RIGHT", -10, 0)
    content:SetJustifyH("LEFT")
    content:SetNonSpaceWrap(true)

    if index == 1 then
        bullet:SetPoint("TOPLEFT", paragonFrame.header, "BOTTOMLEFT", 0, -6)
    else
        local prev = paragonFrame.rows[index - 1]
        -- X must match the previous bullet (not its content, which starts
        -- further right) — otherwise each row drifts further to the right.
        bullet:SetPoint("LEFT", prev.bullet, "LEFT", 0, 0)
        bullet:SetPoint("TOP",  prev.content, "BOTTOM", 0, -4)
    end

    row = { bullet = bullet, content = content }
    paragonFrame.rows[index] = row
    return row
end

------------------------------------------------------------------------
-- Logic
------------------------------------------------------------------------

-- Pending paragon rewards: the listed quests (any faction) plus every Major
-- Faction of the current expansion that reports a pending paragon reward, so
-- a faction missing from the table above still gets announced (by the name
-- the game gives it).
local function GetAvailableParagonQuests()
    local found, seen = {}, {}
    for questID, locKey in pairs(PARAGON_QUESTS) do
        if C_QuestLog.IsOnQuest(questID) then
            seen[questID] = true
            found[#found + 1] = { name = RA_L[locKey], questID = questID }
        end
    end
    if C_MajorFactions and C_MajorFactions.GetMajorFactionIDs then
        for _, factionID in ipairs(C_MajorFactions.GetMajorFactionIDs(LE_EXPANSION_LEVEL_CURRENT) or {}) do
            local _, _, questID, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID)
            if hasRewardPending and questID and not seen[questID] then
                seen[questID] = true
                local data = C_MajorFactions.GetMajorFactionData(factionID)
                found[#found + 1] = { name = data and data.name or tostring(factionID), questID = questID }
            end
        end
    end
    return RA.SortByLabel(found, function(e) return e.name end)
end

function RA.ShowParagonFrame(quests)
    CreateParagonFrame()

    -- Stacked in the shared popup order (Core/Helpers.lua), so the
    -- notifications never overlap.
    RA.StackPopupFrame(paragonFrame)

    local countKey = (#quests == 1) and "paragon_count_one" or "paragon_count_many"
    paragonFrame.header:SetText(string.format(RA_L[countKey], #quests))

    for i, q in ipairs(quests) do
        local row = EnsureRow(i)
        local text = q.name
        local loc = GetQuestLocation(q.questID)
        if loc then
            text = text .. string.format(RA_L["paragon_location"], loc.npc, loc.zone)
        end
        row.content:SetText(text)
        row.bullet:Show()
        row.content:Show()
    end

    -- Hide any leftover rows from a previous, longer list.
    for i = #quests + 1, #paragonFrame.rows do
        paragonFrame.rows[i].bullet:Hide()
        paragonFrame.rows[i].content:Hide()
    end
    paragonFrame.numActiveRows = #quests

    paragonFrame:Show()
    DBG("[Paragon] Showing frame, count:", #quests)
end

local function CheckAndShow()
    if not RollAwayDB or not RollAwayDB.paragonAlert then return end
    local quests = GetAvailableParagonQuests()
    if #quests == 0 then return end
    RA.ShowParagonFrame(quests)
end

-- Manual check: always runs regardless of the paragonAlert setting.
local function ManualCheck()
    local quests = GetAvailableParagonQuests()
    if #quests == 0 then
        RA.Print(RA_L["paragon_none"])
        return
    end
    RA.ShowParagonFrame(quests)
end

-- Dev-only test (/rawreminder): shows the frame with fake names but real
-- questIDs, ignoring the paragonAlert setting.
local function TestShow()
    RA.ShowParagonFrame({
        { name = RA_L["paragon_faction_silvermoon_court"], questID = 93811 },
        { name = RA_L["paragon_faction_amani_tribe"],      questID = 93566 },
    })
end
RA.ParagonTestShow = TestShow

------------------------------------------------------------------------
-- Initialization
------------------------------------------------------------------------

function RA.InitParagon()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("QUEST_ACCEPTED")

    f:SetScript("OnEvent", function(_, event, arg1)
        if event == "PLAYER_ENTERING_WORLD" then
            -- arg1 = isInitialLogin. Only fire on actual login, never on
            -- /reload or zoning.
            if not arg1 then return end

            -- Delay so the quest log is fully populated before scanning.
            C_Timer.After(3, CheckAndShow)

        elseif event == "QUEST_ACCEPTED" then
            -- arg1 is the questID in modern WoW (Shadowlands+).
            if not (RollAwayDB and RollAwayDB.paragonAlert) then return end
            -- Short delay so IsOnQuest() / hasRewardPending are reliable. Any
            -- accepted quest may be a paragon reward of a faction that is not in
            -- the table, so check for it there too (a few API calls).
            C_Timer.After(0.5, function()
                local quests = GetAvailableParagonQuests()
                for _, q in ipairs(quests) do
                    if q.questID == arg1 then
                        DBG("[Paragon] Paragon quest accepted:", arg1)
                        RA.ShowParagonFrame(quests)
                        return
                    end
                end
            end)
        end
    end)

    -- /rawparagon – manual check, available to all users
    SLASH_RAWPARAGON1 = "/rawparagon"
    SlashCmdList["RAWPARAGON"] = ManualCheck

    DBG("[Paragon] Initialized")
end