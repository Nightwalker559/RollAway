-- RollAway - Core/DB.lua
-- Saved-variable database with profiles, no library. It keeps AceDB's SavedVariables layout
-- (profileKeys / profiles / global), so existing data loads unchanged. Missing defaults
-- are filled in at load and on every profile change, and stripped again at logout.

local RA = _G["RollAway"]

-- Fills in what `data` lacks (in place); tables are filled recursively.
local function FillDefaults(data, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(data[key]) ~= "table" then data[key] = {} end
            FillDefaults(data[key], value)
        elseif data[key] == nil then
            data[key] = value
        end
    end
end

-- Removes everything that equals the defaults (in place); emptied tables go too.
function RA.StripDefaults(data, defaults)
    for key, value in pairs(data) do
        local default = defaults[key]
        if type(value) == "table" and type(default) == "table" then
            RA.StripDefaults(value, default)
            if not next(value) then data[key] = nil end
        elseif value == default then
            data[key] = nil
        end
    end
end

local function IsValidName(name)
    return type(name) == "string" and name ~= "" and strlenutf8(name) <= 50 and not name:find("^ +$")
end

local DB = {}
DB.__index = DB

-- Makes `name` the active profile (created on first use).
local function Activate(self, name)
    local sv = self.sv
    sv.profileKeys[self.charKey] = name
    sv.profiles[name] = sv.profiles[name] or {}
    self.profileName = name
    self.profile = sv.profiles[name]
    FillDefaults(self.profile, self.defaults.profile or {})
end

local function Changed(self)
    if self.onProfileChange then self.onProfileChange(self) end
end

function DB:GetCurrentProfile() return self.profileName end

-- Names of all profiles, unsorted.
function DB:GetProfiles()
    local names = {}
    for name in pairs(self.sv.profiles) do names[#names + 1] = name end
    return names
end

-- Unknown names start as a new profile with the defaults.
function DB:SetProfile(name)
    if not IsValidName(name) then error("RollAway DB: invalid profile name", 2) end
    if name == self.profileName then return end
    Activate(self, name)
    Changed(self)
end

local function Reset(self)
    wipe(self.profile)
    FillDefaults(self.profile, self.defaults.profile or {})
end

function DB:ResetProfile()
    Reset(self)
    Changed(self)
end

-- Copies a named profile into the active one, replacing its settings.
function DB:CopyProfile(name)
    if name == self.profileName or not self.sv.profiles[name] then
        error("RollAway DB: cannot copy profile " .. tostring(name), 2)
    end
    Reset(self)
    for key, value in pairs(RA.DeepCopy(self.sv.profiles[name])) do self.profile[key] = value end
    FillDefaults(self.profile, self.defaults.profile or {})
    Changed(self)
end

-- The active profile cannot be deleted; characters that used the deleted one fall back
-- to their own default profile at next login. `silent`: no error for an unknown name.
function DB:DeleteProfile(name, silent)
    if name == self.profileName then error("RollAway DB: cannot delete the active profile", 2) end
    if not self.sv.profiles[name] and not silent then
        error("RollAway DB: unknown profile " .. tostring(name), 2)
    end
    self.sv.profiles[name] = nil
    for char, profile in pairs(self.sv.profileKeys) do
        if profile == name then self.sv.profileKeys[char] = nil end
    end
end

-- svName: name of the SavedVariables table; defaults: { profile = {...}, global = {...} }.
-- Every character starts on its own profile ("Name - Realm"). Set db.onProfileChange(db)
-- to react to profile switch / copy / reset.
function RA.NewDB(svName, defaults)
    local sv = _G[svName]
    if type(sv) ~= "table" then
        sv = {}
        _G[svName] = sv
    end
    if type(sv.profileKeys) ~= "table" then sv.profileKeys = {} end
    if type(sv.profiles) ~= "table" then sv.profiles = {} end
    if type(sv.global) ~= "table" then sv.global = {} end

    local db = setmetatable({
        sv = sv, defaults = defaults, profiles = sv.profiles, global = sv.global,
        charKey = UnitName("player") .. " - " .. GetRealmName(),
    }, DB)
    FillDefaults(db.global, defaults.global or {})

    local name = sv.profileKeys[db.charKey]
    if not IsValidName(name) then name = db.charKey end
    Activate(db, name)

    -- Keep the file small: only what differs from the defaults is saved.
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGOUT")
    frame:SetScript("OnEvent", function()
        RA.StripDefaults(db.global, defaults.global or {})
        for _, profile in pairs(sv.profiles) do
            RA.StripDefaults(profile, defaults.profile or {})
        end
    end)
    return db
end
