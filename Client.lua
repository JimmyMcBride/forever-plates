local _, addon = ...
local Client, Model = {}, addon.Model
addon.Client = Client
Client.capabilities = { interrupts = {}, hostile = {}, friendly = {}, removals = {} }
Client.choices = { hostile = {}, friendly = {} }
Client.issues = {}

function Client.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h end
    Client.issues.api = "Some requested data is unavailable in this context."
end

local function Value(fn, ...)
    return Model.Value(Client.Call(fn, ...))
end

function Client.Setup()
    local group = C_SpecializationInfo and Value(C_SpecializationInfo.GetActiveSpecGroup)
    if type(group) ~= "number" then group = Value(GetActiveTalentGroup) end
    if type(group) ~= "number" then group = 1 end
    return tostring(group)
end

function Client.Book()
    local book, list = {}, {}
    if not C_SpellBook then return book, list end
    local banks = Enum and Enum.SpellBookSpellBank or { Player = 0, Pet = 1 }
    local function Scan(first, count, bank, owner)
        if type(first) ~= "number" or type(count) ~= "number" then return end
        for slot = first, first + count - 1 do
            local info = Client.Call(C_SpellBook.GetSpellBookItemInfo, slot, bank)
            if Model.Readable(info) and type(info) == "table" and Model.Readable(info.spellID)
                and type(info.spellID) == "number" and Model.Value(info.isOffSpec) == false
                and Model.Value(info.isPassive) == false then
                local known = Value(C_SpellBook.IsSpellKnown, info.spellID, bank)
                if known == true then
                    local id = info.spellID
                    local name = Model.Value(info.name)
                    local entry = {
                        id = id, name = type(name) == "string" and name or tostring(id),
                        icon = Model.Value(info.iconID), slot = slot, bank = bank, owner = owner,
                    }
                    book[owner .. ":" .. id] = entry
                    -- Family IDs can refer to a base spell that is overridden in this setup.
                    local base = Model.Value(info.actionID)
                    if type(base) == "number" then book[owner .. ":" .. base] = entry end
                    list[#list + 1] = entry
                end
            end
        end
    end
    local lines = Value(C_SpellBook.GetNumSpellBookSkillLines) or 0
    for line = 1, lines do
        local info = Client.Call(C_SpellBook.GetSpellBookSkillLineInfo, line)
        if Model.Readable(info) and type(info) == "table" then
            local offset, count = Model.Value(info.itemIndexOffset), Model.Value(info.numSpellBookItems)
            if type(offset) == "number" then Scan(offset + 1, count, banks.Player, "player") end
        end
    end
    Scan(1, Value(C_SpellBook.HasPetSpells) or 0, banks.Pet, "pet")
    return book, list
end

function Client.RefreshCapabilities()
    local _, class = UnitClass("player")
    class = Model.Value(class)
    Client.class = type(class) == "string" and class or "UNKNOWN"
    local exists = Value(UnitExists, "pet") == true
    local dead = Value(UnitIsDeadOrGhost, "pet")
    local book, list = Client.Book()
    Client.capabilities = addon.Capabilities.Resolve(Client.class, book,
        Value(GetShapeshiftFormID) or 0, exists and dead == false)
    Client.choices = { hostile = {}, friendly = {} }
    for _, entry in ipairs(list) do
        if entry.owner == "player" then
            if Value(C_SpellBook.IsSpellBookItemHarmful, entry.slot, entry.bank) == true then
                Client.choices.hostile[#Client.choices.hostile + 1] = entry
            end
            if Value(C_SpellBook.IsSpellBookItemHelpful, entry.slot, entry.bank) == true then
                Client.choices.friendly[#Client.choices.friendly + 1] = entry
            end
        end
    end
    for _, choices in pairs(Client.choices) do
        table.sort(choices, function(a, b)
            if a.name == b.name then return a.id > b.id end
            return a.name < b.name
        end)
    end
end

function Client.Range(entry, unit)
    if not entry or not C_SpellBook then return nil end
    local range = Client.Call(C_SpellBook.IsSpellBookItemInRange, entry.slot, entry.bank, unit)
    if not Model.Readable(range) then Client.issues.range = "Range data restricted"; return nil end
    return range
end

function Client.Reference(side)
    local chosen = addon.Config.Spells(Client.Setup())
    local id = chosen[side]
    if type(id) == "number" then
        for _, entry in ipairs(Client.choices[side]) do
            if entry.id == id then return entry end
        end
        chosen[side] = nil
    end
    for _, entry in ipairs(Client.capabilities[side]) do
        if Value(C_SpellBook.IsSpellBookItemUsable, entry.slot, entry.bank) == true then return entry end
    end
    return Client.capabilities[side][1]
end

function Client.Interrupts(unit)
    local result = {}
    for _, ability in ipairs(Client.capabilities.interrupts) do
        local entry = {}
        for key, value in pairs(ability) do entry[key] = value end
        entry.usable = Value(C_SpellBook.IsSpellBookItemUsable, entry.slot, entry.bank)
        entry.inRange = Client.Range(entry, unit)
        local info = Client.Call(C_SpellBook.GetSpellBookItemCooldown, entry.slot, entry.bank)
        if Model.Readable(info) and type(info) == "table" then
            local enabled, active = Model.Value(info.isEnabled), Model.Value(info.isActive)
            if enabled == true and active ~= nil then entry.cooldownReady = active == false end
        end
        -- Native duration widgets may consume restricted timing without Lua inspecting it.
        entry.duration = Client.Call(C_SpellBook.GetSpellBookItemCooldownDuration, entry.slot, entry.bank, false)
        result[#result + 1] = entry
    end
    return result
end

function Client.CastState(unit)
    local name, _, _, _, _, _, _, shield = Client.Call(UnitCastingInfo, unit)
    if not Model.Readable(name) then Client.issues.cast = "Cast data restricted"; return "unknown" end
    if name == nil then
        name, _, _, _, _, _, shield = Client.Call(UnitChannelInfo, unit)
        if not Model.Readable(name) then Client.issues.cast = "Cast data restricted"; return "unknown" end
    end
    if name == nil then return "none" end
    shield = Model.Value(shield)
    if shield == true then return "blocked" end
    return shield == false and "interruptible" or "unknown"
end

function Client.GroupPlayer(unit)
    if Value(UnitIsPlayer, unit) ~= true or Value(UnitIsUnit, unit, "player") ~= false then return false end
    if Value(UnitInParty, unit) == true then return true end
    local index = Value(UnitInRaid, unit)
    return type(index) == "number"
end

function Client.AllyAggro(unit, profile)
    if not profile.aggro or not Client.GroupPlayer(unit) then return false end
    local status = Client.Call(UnitThreatSituation, unit)
    if not Model.Readable(status) then Client.issues.threat = "Threat state restricted"; return false end
    return Model.Aggro(profile, true,
        status, Client.Call(UnitGroupRolesAssigned, unit))
end

function Client.Side(unit)
    if Value(UnitCanAttack, "player", unit) == true then return "enemy" end
    if Client.GroupPlayer(unit) then return "ally" end
end

function Client.Auras(unit, side)
    if not C_UnitAuras then return {} end
    local filter = side == "enemy" and "HELPFUL|DISPELLABLE|INCLUDE_NAME_PLATE_ONLY"
        or "HARMFUL|RAID|INCLUDE_NAME_PLATE_ONLY"
    local auras = Client.Call(C_UnitAuras.GetUnitAuras, unit, filter)
    if not Model.Readable(auras) then Client.issues.auras = "Aura data restricted"; return {} end
    if type(auras) ~= "table" then return {} end
    local result = {}
    -- GetUnitAuras can contain secret AuraData; never index those records in Lua.
    for _, aura in ipairs(auras) do
        if Model.Readable(aura) and type(aura) == "table" then result[#result + 1] = aura
        else Client.issues.auras = "Some aura records restricted" end
    end
    return result
end

function Client.Removals(side)
    -- This cue describes learned capability, not current cooldown/resources.
    -- Form and pet requirements are applied while resolving capabilities.
    return Model.RemovalTypes(Client.capabilities.removals, side)
end

function Client.Access(unit)
    if not C_NamePlate then return nil, "Nameplate API unavailable" end
    local plate = Client.Call(C_NamePlate.GetNamePlateForUnit, unit)
    if not Model.Readable(plate) or plate == nil then return nil, "Plate absent or forbidden" end
    if plate:IsForbidden() then return nil, "Forbidden plate" end
    local frame = plate.UnitFrame
    if not frame or frame:IsForbidden() then return nil, "Forbidden or missing unit frame" end
    if not frame.HealthBarsContainer or not frame.CastBarsContainer or not frame.AurasFrame then
        return nil, "Native plate replaced or unsupported"
    end
    return plate
end

function Client.Conflict()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
    for _, name in ipairs({"EllesmereUINameplates", "Plater", "ThreatPlates", "TidyPlates_ThreatPlates", "Platynator", "ElvUI"}) do
        if Value(loaded, name) == true then return name .. " is loaded; native plate attachment paused." end
    end
end
