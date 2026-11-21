local _, addon = ...
local Model = {}
addon.Model = Model

-- Check secrecy before type checks, equality, indexing, or truthiness of values.
function Model.Readable(value)
    return not (issecretvalue and issecretvalue(value))
end

function Model.Value(value)
    if Model.Readable(value) then return value end
end

function Model.Aggro(profile, grouped, status, role)
    if not profile.aggro or grouped ~= true or not Model.Readable(status) then return false end
    if profile.excludeTanks and Model.Readable(role) and role == "TANK" then return false end
    return status == 2 or status == 3
end

function Model.Interrupt(candidates, state)
    if state ~= "interruptible" and state ~= "unknown" then return nil end
    local fallback, player, pet
    for _, entry in ipairs(candidates) do
        if not fallback then fallback = entry end
        local ready = state == "interruptible" and entry.cooldownReady == true
            and entry.usable == true and entry.inRange == true
        if ready then
            if entry.owner == "pet" then pet = pet or entry else player = player or entry end
        end
    end
    local selected = player or pet or fallback
    return selected, (player ~= nil or pet ~= nil)
end

function Model.RemovalTypes(removals, side)
    local types = {}
    for _, entry in ipairs(removals) do
        for kind in pairs(entry[side] or {}) do types[kind] = true end
    end
    return types
end

function Model.EligibleAura(aura, types)
    if not aura or not Model.Readable(aura.dispelName) then return false end
    local kind = aura.dispelName
    if kind == "" then kind = "Enrage" end
    return kind ~= nil and types[kind] == true
end

function Model.SelectAura(auras, types, previous)
    local first
    for _, aura in ipairs(auras) do
        if Model.EligibleAura(aura, types) and Model.Readable(aura.auraInstanceID)
            and type(aura.auraInstanceID) == "number" then
            first = first or aura
            if previous and aura.auraInstanceID == previous then return aura end
        end
    end
    return first
end
