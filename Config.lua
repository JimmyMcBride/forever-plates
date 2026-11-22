local _, addon = ...
addon.title = "Forever Plates"
addon.version = "0.1.1"

local Config = {}
addon.Config = Config
Config.defaults = {
    aggro = true, interrupts = true, range = true,
    enemyRemoval = true, allyRemoval = true,
    aggroStyle = "glow", excludeTanks = false,
}

local function Copy(source)
    local copy = {}
    for key, value in pairs(source) do copy[key] = value end
    return copy
end

local function Normalize(profile)
    profile = type(profile) == "table" and profile or {}
    for key, default in pairs(Config.defaults) do
        if type(profile[key]) ~= type(default) then profile[key] = default end
    end
    if profile.aggroStyle ~= "glow" and profile.aggroStyle ~= "icon" and profile.aggroStyle ~= "color" then
        profile.aggroStyle = "glow"
    end
    return profile
end

function Config.Initialize()
    for _, db in ipairs({ ForeverPlatesDB or {}, ForeverPlatesCharacterDB or {} }) do
        if type(db) == "table" and type(db.schema) == "number" and db.schema > 1 then
            Config.blocked = "Settings belong to a newer Forever Plates version."
            return false
        end
    end
    ForeverPlatesDB = type(ForeverPlatesDB) == "table" and ForeverPlatesDB or {}
    ForeverPlatesDB.schema = 1
    ForeverPlatesDB.profile = Normalize(ForeverPlatesDB.profile)
    local character = type(ForeverPlatesCharacterDB) == "table" and ForeverPlatesCharacterDB or {}
    character.schema = 1
    character.useCharacter = character.useCharacter == true
    character.spells = type(character.spells) == "table" and character.spells or {}
    if character.profile then character.profile = Normalize(character.profile) end
    if character.useCharacter and not character.profile then
        character.profile = Copy(ForeverPlatesDB.profile)
    end
    ForeverPlatesCharacterDB = character
    Config.blocked = nil
    return true
end

function Config.Profile()
    if Config.blocked then return {} end
    local character = ForeverPlatesCharacterDB
    return character.useCharacter and character.profile or ForeverPlatesDB.profile
end

function Config.Changed()
    if addon.SettingsChanged then addon.SettingsChanged() end
end

function Config.Set(key, value)
    if Config.blocked or Config.defaults[key] == nil then return end
    Config.Profile()[key] = value
    Normalize(Config.Profile())
    Config.Changed()
end

function Config.SetCharacter(enabled)
    if Config.blocked then return end
    local character = ForeverPlatesCharacterDB
    if enabled and not character.profile then character.profile = Copy(ForeverPlatesDB.profile) end
    character.useCharacter = enabled == true
    Config.Changed()
end

function Config.Spells(setup)
    local choices = ForeverPlatesCharacterDB.spells
    choices[setup] = type(choices[setup]) == "table" and choices[setup] or {}
    return choices[setup]
end
