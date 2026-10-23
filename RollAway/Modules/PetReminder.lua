-- RollAway - PetReminder.lua
-- Hunter: text-only toast "Re-summon your pet." when entering a current dungeon or raid.
-- A pet that died has to be revived, dismissed and summoned again, or it is bugged; the bug
-- cannot be detected, so the toast shows on every entry (the pet's state is not checked).
--
-- Setting: RollAwayDB.hunterPetReminder (QoL page "Class", hunters only).
-- Once per loading screen: Core/Core.lua arms RA.petReminderArmed on every
-- PLAYER_ENTERING_WORLD (not on /reload) and calls this right away and again 1.5s later
-- (instance info can be stale); the first call that sees a current instance consumes it.
-- No saved "already shown" mark: entering the same dungeon again in the same group shows it again.

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local DBG  = RA.DBG

local petFrame, petTimer  -- QoL toast, created on first show

function RA.ShowPetReminder()
    local db = RollAwayDB
    if not RA.petReminderArmed or not db or not db.hunterPetReminder or not RA.IsHunter() then return end

    local itype, instanceID = RA.cachedInstanceType, RA.cachedInstanceID
    local current = (itype == "party" and RA.DUNGEON_MAP[instanceID])
        or (itype == "raid" and RA.REMINDER_RAID_MAP_IDS[instanceID])
    if not current then return end
    RA.petReminderArmed = false
    DBG("[PetReminder] instanceID:", instanceID)

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
