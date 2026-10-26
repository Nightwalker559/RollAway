-- RollAway - PetReminder.lua
-- Hunter: text-only toast "Re-summon your pet." in a current dungeon or raid, 1) when entering
-- it and 2) when the dead pet was revived there. A pet that died has to be revived, dismissed
-- and summoned again, or it is bugged; the bug cannot be detected, so the toast shows
-- every time (the pet's state is not checked).
--
-- Setting: RollAwayDB.hunterPetReminder (QoL page "Class", hunters only).
-- Entering: once per loading screen. Core/Core.lua arms RA.petReminderArmed on every
-- PLAYER_ENTERING_WORLD (not on /reload) and calls this right away and again 1.5s later
-- (instance info can be stale); the first call that sees a current instance consumes it.
-- No saved "already shown" mark: entering the same dungeon again in the same group shows it again.
-- Reviving: the player's own successful Revive Pet cast, no mark either.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local REVIVE_PET_SPELL_ID = 982

local petFrame, petTimer  -- QoL toast, created on first show

-- In a current dungeon or raid (the instance info comes from Core/Core.lua).
local function InCurrentInstance()
    local itype, instanceID = RA.cachedInstanceType, RA.cachedInstanceID
    return (itype == "party" and RA.DUNGEON_MAP[instanceID])
        or (itype == "raid" and RA.REMINDER_RAID_MAP_IDS[instanceID])
end

local function ShowToast()
    if not petFrame then
        petFrame, petTimer = RA.CreateToastFrame("RollAwayPetReminderFrame", 280, 36, 220)
        RA.SetupInstanceReminderLifecycle(petFrame)
    end
    local fontPath, fontSize = RA.GetQoLFont()
    petFrame.text:SetFont(fontPath, fontSize, "OUTLINE")
    petFrame.text:SetText("|cffFFFFFF" .. RA_L["qol_pet_reminder_text"] .. "|r")
    petFrame:Show()
    petTimer.Start()
end

function RA.ShowPetReminder()
    local db = RollAwayDB
    if not RA.petReminderArmed or not db or not db.hunterPetReminder or not RA.IsHunter() then return end

    if not InCurrentInstance() then return end
    RA.petReminderArmed = false
    DBG("[PetReminder] instanceID:", RA.cachedInstanceID)
    ShowToast()
end

-- Revive Pet cast by the player. The spell ID can be a secret value in restricted situations:
-- ignored then.
local function OnSpellSucceeded(_, _, _, _, spellID)
    if not RA.IsAccessible(spellID) or spellID ~= REVIVE_PET_SPELL_ID then return end
    local db = RollAwayDB
    if not db or not db.hunterPetReminder or not InCurrentInstance() then return end
    DBG("[PetReminder] pet revived in instance", RA.cachedInstanceID)
    ShowToast()
end

if RA.IsHunter() then
    local watcher = CreateFrame("Frame")
    watcher:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    watcher:SetScript("OnEvent", OnSpellSucceeded)
end
