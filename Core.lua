local _, addon = ...
local Core, Client, Plates, Model = {}, addon.Client, addon.Plates, addon.Model
addon.Core = Core
local frame = CreateFrame("Frame")
Core.frame = frame

local baseline = {"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "ADDON_LOADED"}
local capabilityEvents = {
    "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
    "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "UNIT_PET", "PET_BAR_UPDATE",
    "PLAYER_SPECIALIZATION_CHANGED",
}
local castEvents = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "SPELL_RANGE_CHECK_UPDATE",
}

local function Register(event)
    -- Some events are edition-specific. Keep a diagnostic instead of failing login.
    local ok = pcall(frame.RegisterEvent, frame, event)
    if not ok then Client.issues[event] = "Event unavailable" end
end

function Core.Status()
    if addon.Config.blocked then return addon.Config.blocked end
    if Core.unsupported then return Core.unsupported end
    if Core.conflict then return Core.conflict end
    local count = 0
    for _ in pairs(Plates.units) do count = count + 1 end
    local caps = Client.capabilities
    return string.format("%s: %d interrupt(s), %d removal ability/abilities. %d accessible plate(s).\nLast skipped plate: %s. Live PvE/PvP validation pending.",
        Client.class or "Unknown class", #caps.interrupts, #caps.removals, count, Plates.lastSkip or "none")
end

function Core.PrintStatus()
    local version, build, _, interface = GetBuildInfo()
    print(addon.title .. " " .. addon.version .. " | " .. tostring(version) .. "." .. tostring(build)
        .. " | Interface " .. tostring(interface))
    print(Core.Status())
    if addon.Config.blocked then return end
    local profile = addon.Config.Profile()
    for _, feature in ipairs({"aggro", "interrupts", "range", "enemyRemoval", "allyRemoval"}) do
        print(feature .. ": " .. (profile[feature] and "enabled (accessible, readable units only)" or "off"))
    end
    for _, side in ipairs({"hostile", "friendly"}) do
        local spell = Client.Reference(side)
        print(side .. " range: " .. (spell and (spell.name .. " [" .. spell.id .. "]") or "unavailable"))
    end
    for _, entry in ipairs(Client.capabilities.interrupts) do
        print("Interrupt: " .. entry.name .. " [" .. entry.id .. "] (" .. entry.owner .. ")")
    end
    for reason in pairs(Client.issues) do print("Unavailable: " .. reason) end
end

function Core.WorkNeeded()
    local profile = addon.Config.Profile()
    if profile.range and Model.Value(Client.Call(UnitExists, "target")) == true then return true end
    return profile.interrupts and #Client.capabilities.interrupts > 0
end

local elapsed = 0
function Core.RefreshCombatCues()
    local profile = addon.Config.Profile()
    for _, state in pairs(Plates.units) do
        if state.active and not state.uf:IsForbidden() then
            if Model.Value(state.uf.unit) ~= state.unit then Plates.Remove(state.unit)
            else
                Plates.UpdateInterrupt(state, profile, Client.Side(state.unit))
                Plates.UpdateRange(state, profile)
            end
        end
    end
end

local function Tick(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.2 then return end
    elapsed = 0
    Core.RefreshCombatCues()
end

function Core.Schedule()
    local need = false
    if not Core.conflict and not Core.unsupported and not addon.Config.blocked and Core.WorkNeeded() then
        for _, state in pairs(Plates.units) do
            if state.active then
                local profile = addon.Config.Profile()
                local target = profile.range and Model.Value(Client.Call(UnitIsUnit, state.unit, "target")) == true
                local casting = profile.interrupts and #Client.capabilities.interrupts > 0
                    and Client.Side(state.unit) == "enemy" and state.cast:IsVisible()
                if target or casting then need = true; break end
            end
        end
    end
    frame:SetScript("OnUpdate", need and Tick or nil)
end

function Core.Configure()
    if not Core.initialized then return end
    frame:UnregisterAllEvents()
    for _, event in ipairs(baseline) do Register(event) end
    Core.conflict = Client.Conflict()
    local enabled = false
    local profile = addon.Config.Profile()
    for _, key in ipairs({"aggro", "interrupts", "range", "enemyRemoval", "allyRemoval"}) do
        if profile[key] then enabled = true end
    end
    if not enabled or Core.conflict or Core.unsupported or addon.Config.blocked then
        Plates.Stop()
        frame:SetScript("OnUpdate", nil)
        return
    end
    Register("NAME_PLATE_UNIT_ADDED")
    Register("NAME_PLATE_UNIT_REMOVED")
    Register("PLAYER_TARGET_CHANGED")
    Register("GROUP_ROSTER_UPDATE")
    Register("CVAR_UPDATE")
    for _, event in ipairs(capabilityEvents) do Register(event) end
    frame:RegisterUnitEvent("UNIT_HEALTH", "pet")
    frame:RegisterUnitEvent("UNIT_FLAGS", "pet")
    if profile.aggro then Register("UNIT_THREAT_SITUATION_UPDATE") end
    if profile.interrupts then
        for _, event in ipairs(castEvents) do Register(event) end
    end
    if profile.enemyRemoval or profile.allyRemoval then Register("UNIT_AURA") end
    Client.RefreshCapabilities()
    Plates.Hook()
    Plates.UpdateAll()
    Plates.Scan()
    Core.Schedule()
end
addon.SettingsChanged = Core.Configure

function Core.Initialize()
    local _, _, _, interface = GetBuildInfo()
    if interface ~= 16001 then Core.unsupported = "This preview requires WoW Forever interface 16001." end
    addon.Config.Initialize()
    Core.initialized = true
    if not Core.unsupported and not addon.Config.blocked then Client.RefreshCapabilities() end
    addon.Options.Create()
    SLASH_FOREVERPLATES1 = "/fplates"
    SlashCmdList.FOREVERPLATES = function(message)
        if message:match("^%s*status%s*$") then Core.PrintStatus() else addon.Options.Open() end
    end
    Core.Configure()
end

frame:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" and not Core.initialized then
        if unit == "ForeverPlates" then Core.Initialize() end
        return
    end
    if not Core.initialized then return end
    if event == "ADDON_LOADED" then
        if Client.Conflict() ~= Core.conflict then Core.Configure() end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then Core.Configure(); return end
    if event == "PLAYER_REGEN_ENABLED" then
        Plates.AfterCombat()
        Core.Configure()
        return
    end
    if Core.conflict or Core.unsupported or addon.Config.blocked then return end
    if event == "NAME_PLATE_UNIT_ADDED" then Plates.Attach(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then Plates.Remove(unit)
    elseif event == "UNIT_AURA" or event == "UNIT_THREAT_SITUATION_UPDATE" then
        if Model.Readable(unit) then
            local state = Plates.units[unit]
            if state then Plates.Update(state)
            else Plates.UpdateAll() end -- party/raid aliases can report for nameplate units
        end
    elseif event == "UNIT_HEALTH" or event == "UNIT_FLAGS" or event == "UNIT_PET" then
        if Model.Readable(unit) and (unit == "pet" or unit == "player") then
            Client.RefreshCapabilities()
            Plates.UpdateAll()
        end
    elseif event:match("^UNIT_SPELLCAST") then
        Core.RefreshCombatCues()
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_USABLE"
        or event == "SPELL_RANGE_CHECK_UPDATE" or event == "PLAYER_TARGET_CHANGED" then
        Core.RefreshCombatCues()
    elseif event == "CVAR_UPDATE" then
        for _, state in pairs(Plates.units) do Plates.Layout(state) end
        Plates.UpdateAll()
    else
        Client.RefreshCapabilities()
        Plates.UpdateAll()
    end
    Core.Schedule()
end)
Register("ADDON_LOADED")
