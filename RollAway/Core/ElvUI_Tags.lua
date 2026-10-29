-- RollAway - Core/ElvUI_Tags.lua
-- The [raw:ilvl] tags for ElvUI's unit frames (item level of group members, Modules/GroupIlvl.lua):
--   [raw:ilvl]           284     colored by the thresholds (switch in the QoL page "Group")
--   [raw:ilvl:plain]     284     never colored
-- Use them in any ElvUI text field, e.g. Unit Frames > Party > Name: [name] [raw:ilvl].
-- Silent no-op without ElvUI. The tags exist in ElvUI only while the feature is on
-- (RA.SetElvUITags, called by RA.ApplyGroupIlvl): switched off, they are gone from the
-- "Available Tags" list too. Text already typed into a field stays there and shows nothing.

if not ElvUI then return end
local E = unpack(ElvUI)
if not E or not E.AddTag then return end

local RA   = _G["RollAway"]
local RA_L = RA.RA_L
local oUF  = E.oUF
local Tags = oUF.Tags

-- The group in ElvUI's "Available Tags" list; the same in every language, all our tags go here.
-- ElvUI sorts the groups by name. The color code ("|") sorts after every letter, so the group
-- lands at the end of the list, next to other addons' groups, in the gold of our option tabs.
local TAG_CATEGORY = "|cffd9ba40RollAway|r"

-- Tag bodies run in oUF's environment, so they reach everything through upvalues.
-- GROUP_ROSTER_UPDATE is one of oUF's unitless events: it re-evaluates the tag when
-- the unit behind a frame changes. UNIT_NAME_UPDATE covers units that appear later.
local EVENTS = "UNIT_NAME_UPDATE GROUP_ROSTER_UPDATE"

local TAGS = {
    { "raw:ilvl",          nil,        "gilvl_tag_default" },
    { "raw:ilvl:plain",    "plain",    "gilvl_tag_plain" },
}

-- ElvUI_Options builds its "Available Tags" list once, from the tags that exist when it
-- loads. If it is already built, the entries are removed or added by hand.
local function TagListGroup(create)
    local options = E.Options and E.Options.args and E.Options.args.tagGroup
    if not options then return nil end
    local group = options.args[TAG_CATEGORY]
    if not group and create then
        group = { name = TAG_CATEGORY, type = "group", args = {} }
        options.args[TAG_CATEGORY] = group
    end
    return group, options
end

local function ShowInTagList(name, description)
    local group = TagListGroup(true)
    if not group then return end
    group.args[name] = { name = description, type = "input", width = "full", focusSelect = true,
        get = function() return "[" .. name .. "]" end }
end

local function HideFromTagList(name)
    local group, options = TagListGroup(false)
    if not group then return end
    group.args[name] = nil
    if next(group.args) == nil then options.args[TAG_CATEGORY] = nil end
end

local registered = false

-- Adds or removes the tags. Frames that already show one are refreshed by oUF (a missing
-- tag renders as an empty string).
function RA.SetElvUITags(enabled)
    enabled = enabled and true or false
    if enabled == registered then return end
    registered = enabled

    for _, tag in ipairs(TAGS) do
        local name, mode, descriptionKey = tag[1], tag[2], tag[3]
        if enabled then
            E:AddTag(name, EVENTS, function(unit)
                return RA.FormatGroupIlvl(unit, mode)
            end)
            E:AddTagInfo(name, TAG_CATEGORY, RA_L[descriptionKey])
            ShowInTagList(name, RA_L[descriptionKey])
        else
            Tags.Methods[name] = nil
            Tags.Events[name] = nil
            E.TagInfo[name] = nil
            HideFromTagList(name)
            Tags:RefreshEvents(name)
            Tags:RefreshMethods(name)
        end
    end
end

-- For /rawilvl status: whether ElvUI knows the tag and what it returns for the visible frames.
function RA.ElvUITagReport()
    local method = Tags.Methods["raw:ilvl:plain"]
    local parts = { method and "registered" or "NOT registered" }
    local seen = {}
    for _, frame in next, oUF.objects do
        local unit = frame.unit
        if method and type(unit) == "string" and not seen[unit] and frame:IsVisible() then
            seen[unit] = true
            local ok, text = pcall(method, unit)
            parts[#parts + 1] = unit .. "=" .. (ok and tostring(text) or "error")
        end
    end
    return table.concat(parts, ", ")
end

-- New levels arrive one at a time during an inspect sweep. Bursts are merged into a
-- single pass over ElvUI's frames on the next frame; only frames showing a changed
-- unit are re-evaluated, which is far cheaper than oUF.Tags:RefreshMethods.
local changed = {}
local scheduled = false

local function Flush()
    scheduled = false
    for _, frame in next, oUF.objects do
        local unit = frame.unit
        if unit and frame.UpdateTags and frame:IsVisible() then
            local guid = RA.SafeUnitGUID(unit)
            if guid and changed[guid] then frame:UpdateTags() end
        end
    end
    wipe(changed)
end

RA.OnGroupIlvlChanged(function(guid)
    changed[guid] = true
    if not scheduled then
        scheduled = true
        RunNextFrame(Flush)
    end
end)
