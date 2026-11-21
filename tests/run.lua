local total = 0
local function equal(actual, expected, message)
    if actual ~= expected then
        error((message or "Mismatch") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
    end
end
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error(name .. ": " .. tostring(err), 0) end
    total = total + 1
    print("ok " .. total .. " - " .. name)
end

local function World(class)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    local addon = {}
    local secrets = setmetatable({}, {__mode = "k"})
    env.issecretvalue = function(v) return secrets[v] == true end
    local function Secret()
        local value = newproxy(true)
        local mt = getmetatable(value)
        for _, key in ipairs({"__index", "__newindex", "__lt", "__le", "__add", "__sub", "__mul", "__div", "__tostring"}) do
            mt[key] = function() error("Inspected restricted value") end
        end
        secrets[value] = true
        return value
    end
    env.Secret = Secret
    env.book, env.units, env.frames = {}, {}, {}
    env.form, env.setup, env.combat, env.loaded = 0, 1, false, {}
    env.print = function() end
    local methods = {}
    local function Frame(parent, kind)
        local f = setmetatable({ parent = parent, shown = true, points = {}, scripts = {}, events = {}, kind = kind }, {__index = methods})
        env.frames[#env.frames + 1] = f
        return f
    end
    function methods:IsForbidden() return self.forbidden == true end
    function methods:IsProtected() return self.protected == true end
    function methods:SetSize(w, h) self.width, self.height = w, h end
    function methods:SetWidth(w) self.width = w end
    function methods:SetAllPoints(anchor) self.allPoints = anchor or self.parent end
    function methods:SetParent(parent) self.parent = parent end
    function methods:SetPoint(...) self.points[#self.points + 1] = {...} end
    function methods:ClearAllPoints() self.points = {} end
    function methods:EnableMouse(value) self.mouse = value end
    function methods:SetFrameLevel(value) self.level = value end
    function methods:GetFrameLevel() return self.level or 2 end
    function methods:Show() self.shown = true end
    function methods:Hide() self.shown = false end
    function methods:SetShown(value) self.shown = value == true end
    function methods:IsShown() return self.shown end
    function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function methods:SetAtlas(atlas)
        local allowed = {
            ["UI-HUD-ActionBar-IconFrame"] = true, ["UI-HUD-Nameplates-Aggro-Flare"] = true,
            ["UI-HUD-Nameplates-Aggro-Mask"] = true,
        }
        assert(allowed[atlas], "Unverified atlas: " .. atlas)
        self.atlas = atlas
    end
    function methods:SetTexture(texture) self.texture = texture end
    function methods:SetTexCoord(...) self.texCoord = {...} end
    function methods:SetAlpha(alpha) self.alpha = alpha end
    function methods:SetVertexColor(...) self.vertex = {...} end
    function methods:SetTextColor(...) self.textColor = {...} end
    function methods:SetStatusBarColor(...)
        assert(not self.forbidden, "Wrote forbidden health bar")
        assert(not (self.protected and env.combat), "Wrote protected health bar in combat")
        self.color = {...}
    end
    function methods:SetDesaturated(value) self.desaturated = value end
    function methods:SetBackdrop(value) self.backdrop = value end
    function methods:SetBackdropBorderColor(...) self.borderColor = {...} end
    function methods:AddMaskTexture(mask) self.mask = mask end
    function methods:CreateTexture() return Frame(self, "Texture") end
    function methods:CreateMaskTexture() return Frame(self, "Mask") end
    function methods:CreateFontString() return Frame(self, "Font") end
    function methods:SetText(text) self.text = text end
    function methods:SetJustifyH() end
    function methods:SetEnabled(value) self.enabled = value end
    function methods:SetChecked(value) self.checked = value end
    function methods:GetChecked() return self.checked end
    function methods:SetScrollChild(child) self.child = child end
    function methods:SetupMenu(fn) self.menu = fn end
    function methods:SetScript(event, fn) self.scripts[event] = fn end
    function methods:RegisterEvent(event) self.events[event] = true end
    function methods:RegisterUnitEvent(event, ...) self.events[event] = {...} end
    function methods:UnregisterAllEvents() self.events = {} end
    function methods:SetCooldownFromDurationObject(value) self.duration = value end
    function methods:Clear() self.duration = nil end
    env.CreateFrame = function(kind, _, parent) return Frame(parent, kind) end
    env.SlashCmdList = {}
    env.Settings = {
        RegisterCanvasLayoutCategory = function() return {GetID = function() return 1 end} end,
        RegisterAddOnCategory = function() end,
        OpenToCategory = function() env.opened = true end,
    }
    env.Enum = {SpellBookSpellBank = {Player = 0, Pet = 1}}
    env.GetBuildInfo = function() return "1.60.1", "71037", "", 16001 end
    env.UnitClass = function() return class, class end
    env.GetActiveTalentGroup = function() return env.setup end
    env.GetShapeshiftFormID = function() return env.form end
    env.InCombatLockdown = function() return env.combat end
    local function Unit(unit) return env.units[unit] or {} end
    env.UnitExists = function(unit)
        if unit == "target" then return env.target ~= nil end
        return env.units[unit] ~= nil
    end
    env.UnitIsDeadOrGhost = function(unit) return Unit(unit).dead == true end
    env.UnitIsUnit = function(a, b)
        if a == b then return true end
        return (a == "target" and b == env.target) or (b == "target" and a == env.target)
    end
    env.UnitIsPlayer = function(unit) return Unit(unit).player == true end
    env.UnitInParty = function(unit) return Unit(unit).group == true end
    env.UnitInRaid = function(unit) return Unit(unit).raid end
    env.UnitGroupRolesAssigned = function(unit) return Unit(unit).role or "NONE" end
    env.UnitThreatSituation = function(unit) return Unit(unit).threat end
    env.UnitCanAttack = function(_, unit) return Unit(unit).enemy == true end
    env.UnitCanAssist = function(_, unit) return Unit(unit).player == true end
    env.UnitCastingInfo = function(unit)
        local u = Unit(unit)
        if u.cast then return u.cast, nil, nil, nil, nil, nil, nil, u.shield end
    end
    env.UnitChannelInfo = function(unit)
        local u = Unit(unit)
        if u.channel then return u.channel, nil, nil, nil, nil, nil, u.shield end
    end
    local function Bank(bank)
        local spells = {}
        for _, entry in ipairs(env.book) do
            if (entry.owner == "pet" and 1 or 0) == bank then spells[#spells + 1] = entry end
        end
        return spells
    end
    local function Spell(slot, bank) return Bank(bank)[slot] or {} end
    env.C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function() return {itemIndexOffset = 0, numSpellBookItems = #Bank(0)} end,
        HasPetSpells = function() return #Bank(1) end,
        GetSpellBookItemInfo = function(slot, bank)
            local s = Spell(slot, bank)
            if s.id then return {spellID = s.id, actionID = s.base or s.id, name = s.name or ("Spell " .. s.id),
                iconID = 123, isOffSpec = s.offspec or false, isPassive = s.passive or false} end
        end,
        IsSpellKnown = function(id, bank)
            for _, s in ipairs(Bank(bank)) do if s.id == id then return not s.unknown end end
            return false
        end,
        IsSpellBookItemHarmful = function(slot, bank) return Spell(slot, bank).harmful == true end,
        IsSpellBookItemHelpful = function(slot, bank) return Spell(slot, bank).helpful == true end,
        IsSpellBookItemUsable = function(slot, bank)
            local s = Spell(slot, bank)
            if s.usable == nil then return true, false end
            return s.usable, s.power or false
        end,
        IsSpellBookItemInRange = function(slot, bank, unit)
            local s = Spell(slot, bank)
            if s.ranges then return s.ranges[unit] end
            return s.range
        end,
        GetSpellBookItemCooldown = function(slot, bank)
            local s = Spell(slot, bank)
            if s.noCooldownInfo then return nil end
            return {isEnabled = not s.disabled, isActive = s.cooldown or false, duration = s.timing, startTime = s.timing}
        end,
        GetSpellBookItemCooldownDuration = function(slot, bank) return Spell(slot, bank).duration end,
    }
    env.C_UnitAuras = { GetUnitAuras = function(unit, filter)
        env.lastFilter = filter
        return Unit(unit).auras or {}
    end }
    env.C_AddOns = {IsAddOnLoaded = function(name) return env.loaded[name] == true end}
    env.C_NamePlate = {
        GetNamePlateForUnit = function(unit)
            local plate = Unit(unit).plate
            if plate and not plate.forbidden then return plate end
        end,
        GetNamePlates = function()
            local plates = {}
            for _, unit in pairs(env.units) do if unit.plate then plates[#plates + 1] = unit.plate end end
            return plates
        end,
    }
    env.HIGH_THREAT_COLOR = {GetRGB = function() return 1, 0.2, 0.1 end}
    env.CompactUnitFrame_UpdateHealthColor = function(uf)
        uf.HealthBarsContainer.healthBar:SetStatusBarColor(0.2, env.nativeGreen or 0.8, 0.3)
        env.nativeCalls = (env.nativeCalls or 0) + 1
    end
    env.NamePlateAuraItemMixin = {SetAura = function(icon, aura) icon.spellID = aura.spellId end}
    env.NamePlateAurasMixin = {RefreshAuras = function() end}
    env.NamePlateUnitFrameMixin = {ApplyFrameOptions = function() end}
    env.hooksecurefunc = function(object, name, callback)
        if type(object) == "string" then callback, name, object = name, object, env end
        local original = object[name]
        object[name] = function(...)
            original(...)
            callback(...)
        end
    end
    local function Load(name)
        local chunk = assert(loadfile(name .. ".lua"))
        setfenv(chunk, env)("ForeverPlates", addon)
    end
    for _, name in ipairs({"Config", "Capabilities", "Model", "Client", "Plates", "Options", "Core"}) do Load(name) end
    local function AddPlate(unit, data)
        env.units[unit] = data or {}
        data = env.units[unit]
        local plate = Frame()
        plate.unitToken = unit
        local uf = Frame(plate)
        uf.unit = unit
        uf.HealthBarsContainer = {healthBar = Frame(uf)}
        uf.CastBarsContainer = {castBar = Frame(uf)}
        uf.CastBarsContainer.castBar:SetShown(data.cast ~= nil or data.channel ~= nil)
        uf.name = Frame(uf)
        uf.IsShowOnlyName = function() return data.nameOnly == true end
        uf.AurasFrame = Frame(uf)
        uf.AurasFrame.unitToken = unit
        uf.AurasFrame.icons = {}
        uf.AurasFrame.auraItemFramePool = { EnumerateActive = function()
            return next, uf.AurasFrame.icons, nil
        end }
        plate.UnitFrame, data.plate = uf, plate
        return plate, uf
    end
    local function Event(event, ...)
        local f = addon.Core.frame
        if f.events[event] then f.scripts.OnEvent(f, event, ...) end
    end
    local function Init() Event("ADDON_LOADED", "ForeverPlates") end
    return env, addon, AddPlate, Event, Init, Frame
end

test("shared defaults and character copy isolation", function()
    local e, a = World("SHAMAN")
    assert(a.Config.Initialize())
    equal(a.Config.Profile().aggroStyle, "glow")
    a.Config.SetCharacter(true)
    a.Config.Set("aggro", false)
    equal(e.ForeverPlatesDB.profile.aggro, true)
    a.Config.SetCharacter(false)
    equal(a.Config.Profile().aggro, true)
    a.Config.SetCharacter(true)
    equal(a.Config.Profile().aggro, false)
end)
test("future shared schema preserved", function()
    local e, a = World("MAGE")
    e.ForeverPlatesDB = {schema = 2, untouched = true}
    equal(a.Config.Initialize(), false)
    equal(e.ForeverPlatesDB.schema, 2)
    assert(e.ForeverPlatesDB.untouched)
    a.Config.Set("aggro", true)
    equal(e.ForeverPlatesDB.profile, nil)
end)
test("future character schema preserves both databases", function()
    local e, a = World("MAGE")
    e.ForeverPlatesDB, e.ForeverPlatesCharacterDB = {schema = 1}, {schema = 9}
    equal(a.Config.Initialize(), false)
    equal(e.ForeverPlatesDB.profile, nil)
end)
test("invalid settings normalize without losing valid values", function()
    local e, a = World("MAGE")
    e.ForeverPlatesDB = {profile = {aggro = false, aggroStyle = "invalid", range = "yes"}}
    a.Config.Initialize()
    equal(a.Config.Profile().aggro, false)
    equal(a.Config.Profile().aggroStyle, "glow")
    equal(a.Config.Profile().range, true)
end)
test("range spell choices isolated by talent setup", function()
    local _, a = World("SHAMAN")
    a.Config.Initialize()
    a.Config.Spells("1").hostile = 403
    equal(a.Config.Spells("2").hostile, nil)
    equal(a.Config.Spells("1").hostile, 403)
end)

local classCount = 0
for class in pairs(select(2, World("MAGE")).Capabilities.records) do
    classCount = classCount + 1
    test(class .. " only resolves learned active ranks", function()
        local e, a = World(class)
        a.Config.Initialize()
        local record = a.Capabilities.records[class]
        for _, category in ipairs({"interrupts", "hostile", "friendly", "removals"}) do
            for _, family in ipairs(record[category] or {}) do
                for _, id in ipairs(family.ids) do
                    local owner = family.owner or "player"
                    local book = {[owner .. ":" .. id] = {id = id, owner = owner}}
                    local form = family.forms and next(family.forms) or 0
                    local resolved = a.Capabilities.Resolve(class, book, form, true)
                    equal(#resolved[category], 1)
                    equal(resolved[category][1].id, id)
                    equal(#a.Capabilities.Resolve(class, {}, form, true)[category], 0)
                end
            end
        end
    end)
end
equal(classCount, 9)
test("hunter and paladin do not acquire invented interrupts", function()
    for _, class in ipairs({"HUNTER", "PALADIN", "PRIEST"}) do
        local _, a = World(class)
        equal(#a.Capabilities.Resolve(class, {}, 0, true).interrupts, 0)
    end
end)
test("druid interrupt restricted to bear forms", function()
    local _, a = World("DRUID")
    local book = {["player:16979"] = {id = 16979}}
    equal(#a.Capabilities.Resolve("DRUID", book, 0, true).interrupts, 0)
    equal(#a.Capabilities.Resolve("DRUID", book, 1, true).interrupts, 0)
    equal(#a.Capabilities.Resolve("DRUID", book, 5, true).interrupts, 1)
    equal(#a.Capabilities.Resolve("DRUID", book, 8, true).interrupts, 1)
end)
test("pet abilities disappear without live pet", function()
    local _, a = World("WARLOCK")
    local book = {["pet:19647"] = {id = 19647, owner = "pet"}}
    equal(#a.Capabilities.Resolve("WARLOCK", book, 0, false).interrupts, 0)
    equal(#a.Capabilities.Resolve("WARLOCK", book, 0, true).interrupts, 1)
end)
test("highest learned trainer rank wins within family", function()
    local _, a = World("SHAMAN")
    local book = {["player:8042"] = {id = 8042}, ["player:10414"] = {id = 10414}}
    equal(a.Capabilities.Resolve("SHAMAN", book, 0, false).interrupts[1].id, 10414)
end)
test("offspec passive and unknown spellbook entries excluded", function()
    local e, a = World("SHAMAN")
    e.book = {{id = 8042, offspec = true}, {id = 8044, passive = true}, {id = 8045, unknown = true}}
    a.Config.Initialize()
    a.Client.RefreshCapabilities()
    equal(#a.Client.capabilities.interrupts, 0)
end)
test("active override resolves through base ID", function()
    local e, a = World("SHAMAN")
    e.book = {{id = 1234567, base = 8042}}
    a.Config.Initialize()
    a.Client.RefreshCapabilities()
    equal(a.Client.capabilities.interrupts[1].id, 1234567)
end)
test("pet death and swapping refresh capabilities", function()
    local e, a = World("WARLOCK")
    e.book = {{id = 19647, owner = "pet"}}
    a.Config.Initialize()
    a.Client.RefreshCapabilities()
    equal(#a.Client.capabilities.interrupts, 0)
    e.units.pet = {}
    a.Client.RefreshCapabilities()
    equal(#a.Client.capabilities.interrupts, 1)
    e.units.pet.dead = true
    a.Client.RefreshCapabilities()
    equal(#a.Client.capabilities.interrupts, 0)
end)
test("invalid saved range choice returns to auto", function()
    local e, a = World("SHAMAN")
    e.book = {{id = 403, harmful = true}}
    a.Config.Initialize()
    a.Config.Spells("1").hostile = 999
    a.Client.RefreshCapabilities()
    equal(a.Client.Reference("hostile").id, 403)
    equal(a.Config.Spells("1").hostile, nil)
end)
test("manual spell choice independent from automatic records", function()
    local e, a = World("HUNTER")
    e.book = {{id = 3044, harmful = true}, {id = 999, harmful = true}}
    a.Config.Initialize()
    a.Client.RefreshCapabilities()
    a.Config.Spells("1").hostile = 999
    equal(a.Client.Reference("hostile").id, 999)
end)

test("aggro only tanking states and group players", function()
    local _, a = World("MAGE")
    a.Config.Initialize()
    local p = a.Config.Profile()
    for _, status in ipairs({0, 1, 2, 3}) do equal(a.Model.Aggro(p, true, status, "NONE"), status >= 2) end
    equal(a.Model.Aggro(p, false, 3, "NONE"), false)
    p.excludeTanks = true
    equal(a.Model.Aggro(p, true, 3, "TANK"), false)
    equal(a.Model.Aggro(p, true, 3, "NONE"), true)
end)
test("secret threat and role never become guessed aggro", function()
    local e, a = World("MAGE")
    a.Config.Initialize()
    equal(a.Model.Aggro(a.Config.Profile(), true, e.Secret(), "NONE"), false)
    a.Config.Profile().excludeTanks = true
    equal(a.Model.Aggro(a.Config.Profile(), true, 3, e.Secret()), true)
end)
test("secret aura fields omitted without comparisons or indexing", function()
    local e, a = World("MAGE")
    equal(a.Model.EligibleAura({dispelName = e.Secret()}, {Curse = true}), false)
    equal(a.Model.SelectAura({{dispelName = "Curse", auraInstanceID = e.Secret()}}, {Curse = true}), nil)
    e.units.n = {auras = e.Secret()}
    equal(#a.Client.Auras("n", "enemy"), 0)
    e.units.n.auras = {e.Secret()}
    equal(#a.Client.Auras("n", "enemy"), 0)
end)
test("group-wide removability cannot grant player capability", function()
    local _, a = World("MAGE")
    equal(a.Model.EligibleAura({dispelName = "Magic"}, {Curse = true}), false)
end)
test("enrage differs from magic removal", function()
    local _, a = World("HUNTER")
    equal(a.Model.EligibleAura({dispelName = ""}, {Enrage = true}), true)
    equal(a.Model.EligibleAura({dispelName = "Magic"}, {Enrage = true}), false)
end)
test("fallback retains same effect until removed", function()
    local _, a = World("MAGE")
    local x, y = {auraInstanceID = 1, dispelName = "Curse"}, {auraInstanceID = 2, dispelName = "Curse"}
    equal(a.Model.SelectAura({x, y}, {Curse = true}, 2), y)
    equal(a.Model.SelectAura({x}, {Curse = true}, 2), x)
end)
test("interrupt selection prefers ready player then pet", function()
    local _, a = World("WARLOCK")
    local pet = {owner = "pet", usable = true, cooldownReady = true, inRange = true}
    local player = {owner = "player", usable = true, cooldownReady = true, inRange = true}
    equal(a.Model.Interrupt({pet, player}, "interruptible"), player)
    player.cooldownReady = false
    equal(a.Model.Interrupt({player, pet}, "interruptible"), pet)
end)
test("unknown interruptibility never ready", function()
    local _, a = World("MAGE")
    local candidate = {owner = "player", usable = true, cooldownReady = true, inRange = true}
    local selected, ready = a.Model.Interrupt({candidate}, "unknown")
    equal(selected, candidate)
    equal(ready, false)
    equal(a.Model.Interrupt({candidate}, "blocked"), nil)
end)
test("restricted range usability and timing stay neutral", function()
    local e, a = World("SHAMAN")
    e.book = {{id = 8042, range = e.Secret(), usable = e.Secret(), timing = e.Secret(), duration = e.Secret()}}
    a.Config.Initialize()
    a.Client.RefreshCapabilities()
    local candidates = a.Client.Interrupts("n")
    equal(candidates[1].inRange, nil)
    equal(candidates[1].usable, nil)
    local _, ready = a.Model.Interrupt(candidates, "interruptible")
    equal(ready, false)
end)
test("active cooldown including GCD prevents ready", function()
    local e, a = World("SHAMAN")
    e.book = {{id = 8042, range = true, cooldown = true}}
    a.Config.Initialize()
    a.Client.RefreshCapabilities()
    local _, ready = a.Model.Interrupt(a.Client.Interrupts("n"), "interruptible")
    equal(ready, false)
    e.book[1].cooldown = false
    _, ready = a.Model.Interrupt(a.Client.Interrupts("n"), "interruptible")
    equal(ready, true)
end)
test("missing cooldown info never ready", function()
    local e, a = World("MAGE")
    e.book = {{id = 2139, range = true, noCooldownInfo = true}}
    a.Config.Initialize()
    a.Client.RefreshCapabilities()
    local _, ready = a.Model.Interrupt(a.Client.Interrupts("n"), "interruptible")
    equal(ready, false)
end)
test("casts channels and restricted casts handled separately", function()
    local e, a = World("MAGE")
    e.units.n = {channel = "Channel", shield = false}
    equal(a.Client.CastState("n"), "interruptible")
    e.units.n.shield = true
    equal(a.Client.CastState("n"), "blocked")
    e.units.n.shield = e.Secret()
    equal(a.Client.CastState("n"), "unknown")
    e.units.n = {cast = e.Secret()}
    equal(a.Client.CastState("n"), "unknown")
    e.units.n = {}
    equal(a.Client.CastState("n"), "none")
end)

test("glow preserves native color and remains mouse transparent", function()
    local e, a, plate, _, init = World("MAGE")
    local _, uf = plate("n", {player = true, group = true, threat = 3})
    init()
    local s = a.Plates.units.n
    equal(s.glow:IsShown(), true)
    equal(s.bar.color, nil)
    equal(s.root.mouse, false)
    equal(s.aggroIcon.mouse, false)
    equal(s.glow.mask, s.glowMask)
    equal(s.uf, uf)
end)
test("aggro transitions hide all cues", function()
    local e, a, plate, _, init = World("MAGE")
    plate("n", {player = true, group = true, threat = 3})
    init()
    e.units.n.threat = 1
    a.Plates.UpdateAll()
    equal(a.Plates.units.n.glow:IsShown(), false)
end)
test("icon mode does not recolor health", function()
    local _, a, plate, _, init = World("MAGE")
    plate("n", {player = true, group = true, threat = 3})
    init()
    a.Config.Set("aggroStyle", "icon")
    local s = a.Plates.units.n
    equal(s.aggroIcon:IsShown(), true)
    equal(s.glow:IsShown(), false)
    equal(s.bar.color, nil)
end)
test("bar color restores recalculated native state", function()
    local e, a, plate, _, init = World("MAGE")
    plate("n", {player = true, group = true, threat = 3})
    init()
    a.Config.Set("aggroStyle", "color")
    equal(a.Plates.units.n.bar.color[1], 1)
    e.nativeGreen = 0.4
    a.Config.Set("aggro", false)
    equal(a.Plates.units.n.bar.color[2], 0.4)
end)
test("native color refresh posthook preserves opted-in aggro color", function()
    local e, a, plate, _, init = World("MAGE")
    local _, uf = plate("n", {player = true, group = true, threat = 3})
    init()
    a.Config.Set("aggroStyle", "color")
    e.CompactUnitFrame_UpdateHealthColor(uf)
    equal(a.Plates.units.n.bar.color[1], 1)
end)
test("unrelated players pets and self excluded", function()
    local _, a, plate, _, init = World("MAGE")
    plate("n", {player = true, threat = 3})
    plate("pet", {group = true, threat = 3})
    plate("player", {player = true, group = true, threat = 3})
    init()
    for _, s in pairs(a.Plates.units) do equal(s.glow:IsShown(), false) end
end)
test("raid player and tank exclusion", function()
    local _, a, plate, _, init = World("MAGE")
    plate("n", {player = true, raid = 4, role = "TANK", threat = 3})
    init()
    equal(a.Plates.units.n.glow:IsShown(), true)
    a.Config.Set("excludeTanks", true)
    equal(a.Plates.units.n.glow:IsShown(), false)
end)
test("forbidden base plate never inspected", function()
    local e, a, plate, _, init = World("MAGE")
    local p = plate("n", {player = true, group = true, threat = 3})
    p.forbidden = true
    p.UnitFrame = nil
    setmetatable(p, {__index = function(_, key)
        if key == "IsForbidden" then return function() return true end end
        error("Inspected forbidden plate: " .. key)
    end})
    init()
    equal(a.Plates.units.n, nil)
end)
test("forbidden child frame skipped", function()
    local _, a, plate, _, init = World("MAGE")
    local _, uf = plate("n", {})
    uf.forbidden = true
    init()
    equal(a.Plates.units.n, nil)
end)
test("combat login defers protected attachment", function()
    local e, a, plate, event, init = World("MAGE")
    local p = plate("n", {})
    p.protected, e.combat = true, true
    init()
    equal(a.Plates.units.n, nil)
    equal(a.Plates.pending.n, true)
    e.combat = false
    event("PLAYER_REGEN_ENABLED")
    assert(a.Plates.units.n)
end)
test("unprotected new plate attaches during combat", function()
    local e, a, plate, event, init = World("MAGE")
    init()
    e.combat = true
    plate("n", {enemy = true})
    event("NAME_PLATE_UNIT_ADDED", "n")
    assert(a.Plates.units.n)
    assert(#a.Plates.units.n.interrupt.points > 0)
end)
test("protected health restoration delayed until combat ends", function()
    local e, a, plate, event, init = World("MAGE")
    plate("n", {player = true, group = true, threat = 3})
    init()
    a.Config.Set("aggroStyle", "color")
    local s = a.Plates.units.n
    s.bar.protected, e.combat = true, true
    e.units.n.threat = 0
    a.Plates.UpdateAll()
    equal(s.restorePending, true)
    e.combat = false
    event("PLAYER_REGEN_ENABLED")
    equal(s.bar.color[1], 0.2)
end)
test("plate removal and recycling clear owned visuals", function()
    local e, a, plate, event, init = World("MAGE")
    local p, uf = plate("n", {player = true, group = true, threat = 3})
    init()
    local s = a.Plates.units.n
    event("NAME_PLATE_UNIT_REMOVED", "n")
    equal(s.glow:IsShown(), false)
    equal(s.unit, nil)
    equal(a.Plates.units.n, nil)
    e.units.n = nil
    e.units.m = {plate = p, enemy = true}
    p.unitToken, uf.unit = "m", "m"
    event("NAME_PLATE_UNIT_ADDED", "m")
    equal(a.Plates.units.m, s)
    equal(s.glow:IsShown(), false)
end)
test("stale native unit cannot retain cue", function()
    local _, a, plate, _, init = World("MAGE")
    local _, uf = plate("n", {player = true, group = true, threat = 3})
    init()
    local s = a.Plates.units.n
    uf.unit = "different"
    a.Plates.UpdateAll()
    equal(s.active, false)
    equal(a.Plates.units.n, nil)
end)
test("current target only range cue never treats unknown as out", function()
    local e, a, plate, event, init = World("HUNTER")
    e.book = {{id = 3044, harmful = true, range = false}}
    plate("n", {enemy = true})
    plate("m", {enemy = true})
    e.target = "n"
    init()
    equal(a.Plates.units.n.range:IsShown(), true)
    equal(a.Plates.units.m.range:IsShown(), false)
    e.book[1].range = e.Secret()
    event("PLAYER_TARGET_CHANGED")
    equal(a.Plates.units.n.range:IsShown(), false)
end)
test("friendly target selects healing reference", function()
    local e, a, plate, _, init = World("SHAMAN")
    e.book = {{id = 331, helpful = true, range = false}, {id = 403, harmful = true, range = true}}
    plate("n", {player = true, group = true})
    e.target = "n"
    init()
    equal(a.Plates.units.n.range:IsShown(), true)
end)
test("interrupt icon covers multiple enemy casts", function()
    local e, a, plate, _, init = World("MAGE")
    e.book = {{id = 2139, range = true}}
    plate("n", {enemy = true, cast = "Spell", shield = false})
    plate("m", {enemy = true, channel = "Channel", shield = false})
    init()
    for _, s in pairs(a.Plates.units) do
        equal(s.interrupt:IsShown(), true)
        equal(s.interrupt.border.vertex[2], 1)
    end
end)
test("restricted cooldown passes to native widget unchanged", function()
    local e, a, plate, _, init = World("MAGE")
    local duration = e.Secret()
    e.book = {{id = 2139, range = nil, duration = duration}}
    plate("n", {enemy = true, cast = "Spell", shield = false})
    init()
    equal(a.Plates.units.n.interrupt.cooldown.duration, duration)
    equal(a.Plates.units.n.interrupt.border.vertex[2], 0.65)
end)
test("native uninterruptible cast remains unchanged", function()
    local e, a, plate, _, init = World("MAGE")
    e.book = {{id = 2139, range = true}}
    local _, uf = plate("n", {enemy = true, cast = "Spell", shield = true})
    init()
    equal(a.Plates.units.n.interrupt:IsShown(), false)
    equal(uf.CastBarsContainer.castBar:IsShown(), true)
end)
test("hidden native cast bar gets no added interrupt icon", function()
    local e, a, plate, _, init = World("MAGE")
    e.book = {{id = 2139, range = true}}
    local _, uf = plate("n", {enemy = true, cast = "Spell", shield = false})
    uf.CastBarsContainer.castBar:Hide()
    init()
    equal(a.Plates.units.n.interrupt:IsShown(), false)
end)
test("missing aura gets one stable fallback icon", function()
    local e, a, plate, _, init = World("SHAMAN")
    e.book = {{id = 370}}
    plate("n", {enemy = true, auras = {
        {auraInstanceID = 1, dispelName = "Magic", icon = 11},
        {auraInstanceID = 2, dispelName = "Magic", icon = 22},
    }})
    init()
    local s = a.Plates.units.n
    equal(s.removal.icon.texture, 11)
    equal(s.auraID, 1)
    e.units.n.auras = {e.units.n.auras[2], e.units.n.auras[1]}
    a.Plates.UpdateAll()
    equal(s.auraID, 1)
    e.units.n.auras = {e.units.n.auras[1]}
    a.Plates.UpdateAll()
    equal(s.auraID, 2)
end)
test("existing native aura highlighted without duplicate fallback", function()
    local e, a, plate, _, init, frame = World("SHAMAN")
    e.book = {{id = 370}}
    local aura = {auraInstanceID = 1, dispelName = "Magic", icon = 11}
    local _, uf = plate("n", {enemy = true, auras = {aura}})
    init()
    local icon = frame(uf.AurasFrame)
    uf.AurasFrame.icons[icon] = true
    e.NamePlateAuraItemMixin.SetAura(icon, aura)
    e.NamePlateAurasMixin.RefreshAuras(uf.AurasFrame)
    local s = a.Plates.units.n
    equal(s.removal:IsShown(), false)
    equal(s.auraGlows[icon]:IsShown(), true)
    e.units.n.auras = {}
    a.Plates.UpdateAll()
    equal(s.auraGlows[icon]:IsShown(), false)
end)
test("hidden native aura uses fallback without forcing visibility", function()
    local e, a, plate, _, init, frame = World("SHAMAN")
    e.book = {{id = 370}}
    local aura = {auraInstanceID = 1, dispelName = "Magic", icon = 11}
    local _, uf = plate("n", {enemy = true, auras = {aura}})
    init()
    local icon = frame(uf.AurasFrame)
    uf.AurasFrame.icons[icon] = true
    e.NamePlateAuraItemMixin.SetAura(icon, aura)
    uf.AurasFrame:Hide()
    a.Plates.UpdateAll()
    equal(a.Plates.units.n.removal:IsShown(), true)
    equal(uf.AurasFrame:IsShown(), false)
end)
test("ally dispel capability respects effect type and resources", function()
    local e, a, plate, _, init = World("MAGE")
    e.book = {{id = 475, usable = false, power = true}}
    plate("n", {player = true, group = true, auras = {{auraInstanceID = 1, dispelName = "Curse", icon = 1}}})
    init()
    equal(a.Plates.units.n.removal:IsShown(), true)
    e.units.n.auras[1].dispelName = "Poison"
    a.Plates.UpdateAll()
    equal(a.Plates.units.n.removal:IsShown(), false)
end)
test("disabled removal clears fallback and native outline", function()
    local e, a, plate, _, init = World("SHAMAN")
    e.book = {{id = 370}}
    plate("n", {enemy = true, auras = {{auraInstanceID = 1, dispelName = "Magic", icon = 1}}})
    init()
    a.Config.Set("enemyRemoval", false)
    equal(a.Plates.units.n.removal:IsShown(), false)
    equal(a.Plates.units.n.auraID, nil)
end)
test("all features off remove work and restore Blizzard state", function()
    local e, a, plate, _, init = World("MAGE")
    plate("n", {player = true, group = true, threat = 3})
    init()
    for _, key in ipairs({"aggro", "interrupts", "range", "enemyRemoval", "allyRemoval"}) do a.Config.Set(key, false) end
    equal(next(a.Plates.units), nil)
    equal(a.Core.frame.scripts.OnUpdate, nil)
    equal(a.Core.frame.events.UNIT_AURA, nil)
    equal(a.Core.frame.events.UNIT_THREAT_SITUATION_UPDATE, nil)
    equal(a.Core.frame.events.SPELL_UPDATE_COOLDOWN, nil)
end)
test("shared updater only runs for relevant target or cast", function()
    local e, a, plate, event, init = World("MAGE")
    e.book = {{id = 2139, range = true}}
    local _, uf = plate("n", {enemy = true})
    init()
    equal(a.Core.frame.scripts.OnUpdate, nil)
    e.units.n.cast, e.units.n.shield = "Spell", false
    uf.CastBarsContainer.castBar:Show()
    event("UNIT_SPELLCAST_START", "n")
    assert(a.Core.frame.scripts.OnUpdate)
    uf.CastBarsContainer.castBar:Hide()
    e.units.n.cast = nil
    event("UNIT_SPELLCAST_STOP", "n")
    equal(a.Core.frame.scripts.OnUpdate, nil)
end)
test("conflicting nameplate addon suspends without editing settings", function()
    local e, a, plate, _, init = World("MAGE")
    e.loaded.EllesmereUINameplates = true
    plate("n", {player = true, group = true, threat = 3})
    init()
    equal(next(a.Plates.units), nil)
    assert(a.Core.conflict:find("EllesmereUINameplates"))
    equal(e.loaded.EllesmereUINameplates, true)
end)
test("newly loaded replacement removes active addon visuals", function()
    local e, a, plate, event, init = World("MAGE")
    plate("n", {player = true, group = true, threat = 3})
    init()
    local s = a.Plates.units.n
    e.loaded.Plater = true
    event("ADDON_LOADED", "Plater")
    equal(s.glow:IsShown(), false)
    equal(next(a.Plates.units), nil)
end)
test("unsupported interface loads settings but attaches nothing", function()
    local e, a, plate, _, init = World("MAGE")
    e.GetBuildInfo = function() return "12.1", "x", "", 120100 end
    plate("n", {})
    init()
    assert(a.Core.unsupported)
    equal(next(a.Plates.units), nil)
end)
test("settings command and status are available", function()
    local e, a, _, _, init = World("SHAMAN")
    init()
    e.SlashCmdList.FOREVERPLATES("")
    equal(e.opened, true)
    e.SlashCmdList.FOREVERPLATES("status")
    assert(a.Core.Status():find("SHAMAN"))
end)
test("future schema still permits status and settings safely", function()
    local e, a, _, _, init = World("SHAMAN")
    e.ForeverPlatesCharacterDB = {schema = 9}
    init()
    e.SlashCmdList.FOREVERPLATES("status")
    a.Options.Refresh()
    equal(e.ForeverPlatesCharacterDB.schema, 9)
    equal(next(a.Plates.units), nil)
end)

test("pooled unit frame moves owned root to new base plate", function()
    local e, a, plate, event, init, frame = World("MAGE")
    local p, uf = plate("n", {player = true, group = true, threat = 3})
    init()
    local state = a.Plates.units.n
    event("NAME_PLATE_UNIT_REMOVED", "n")
    p:Hide()
    local other = frame()
    other.unitToken, other.UnitFrame = "m", uf
    uf:SetParent(other)
    uf.unit = "m"
    e.units.m = {plate = other, player = true, group = true, threat = 3}
    event("NAME_PLATE_UNIT_ADDED", "m")
    equal(a.Plates.units.m, state)
    equal(state.root.parent, other)
    equal(state.glow:IsVisible(), true)
end)
test("existing plates scanned using native unitToken property", function()
    local _, a, plate, _, init = World("MAGE")
    local p = plate("nameplate4", {})
    equal(p.namePlateUnitToken, nil)
    init()
    assert(a.Plates.units.nameplate4)
end)
test("lower interrupt rank selected when higher rank unusable", function()
    local e, a = World("SHAMAN")
    e.book = {{id = 8042, range = true}, {id = 10414, range = true, usable = false, power = true}}
    a.Config.Initialize()
    a.Client.RefreshCapabilities()
    local entry, ready = a.Model.Interrupt(a.Client.Interrupts("n"), "interruptible")
    equal(entry.id, 8042)
    equal(ready, true)
end)
test("druid removal and healing capabilities follow forms", function()
    local e, a = World("DRUID")
    e.book = {{id = 2782}, {id = 8946}, {id = 5185}}
    a.Config.Initialize()
    a.Client.RefreshCapabilities()
    equal(#a.Client.capabilities.removals, 2)
    e.form = 1
    a.Client.RefreshCapabilities()
    equal(#a.Client.capabilities.removals, 0)
    equal(#a.Client.capabilities.friendly, 0)
    e.form = 31
    a.Client.RefreshCapabilities()
    equal(#a.Client.capabilities.removals, 1)
end)
test("native aura highlight can be created during unprotected combat", function()
    local e, a, plate, _, init, frame = World("SHAMAN")
    e.book = {{id = 370}}
    local aura = {auraInstanceID = 1, dispelName = "Magic", icon = 11}
    local _, uf = plate("n", {enemy = true, auras = {aura}})
    init()
    e.combat = true
    local icon = frame(uf.AurasFrame)
    uf.AurasFrame.icons[icon] = true
    e.NamePlateAuraItemMixin.SetAura(icon, aura)
    a.Plates.UpdateAll()
    equal(a.Plates.units.n.removal:IsShown(), false)
    equal(a.Plates.units.n.auraGlows[icon]:IsShown(), true)
end)
test("range movement refreshes through bounded shared updater", function()
    local e, a, plate, _, init = World("HUNTER")
    e.book = {{id = 3044, harmful = true, range = true}}
    plate("n", {enemy = true})
    e.target = "n"
    init()
    local f = a.Core.frame
    assert(f.scripts.OnUpdate)
    e.book[1].range = false
    f.scripts.OnUpdate(f, 0.1)
    equal(a.Plates.units.n.range:IsShown(), false)
    f.scripts.OnUpdate(f, 0.1)
    equal(a.Plates.units.n.range:IsShown(), true)
end)
test("name-only layout anchors cue to existing name", function()
    local _, a, plate, _, init = World("MAGE")
    local _, uf = plate("n", {player = true, group = true, threat = 3, nameOnly = true})
    init()
    equal(a.Plates.units.n.glow.points[1][2], uf.name)
end)
test("disabling one feature leaves other events active", function()
    local _, a, _, _, init = World("MAGE")
    init()
    a.Config.Set("interrupts", false)
    equal(a.Core.frame.events.UNIT_SPELLCAST_START, nil)
    equal(a.Core.frame.events.UNIT_THREAT_SITUATION_UPDATE, true)
    equal(a.Core.frame.events.UNIT_AURA, true)
end)
test("native menu changes actual aggro presentation", function()
    local e, a, _, _, init = World("MAGE")
    init()
    local choices = {}
    local root = {CreateRadio = function(_, label, selected, click)
        choices[label] = {selected = selected, click = click}
    end}
    for _, f in ipairs(e.frames) do if f.kind == "DropdownButton" then f.menu(f, root) end end
    choices["Small aggro icon"].click()
    equal(a.Config.Profile().aggroStyle, "icon")
    equal(choices["Small aggro icon"].selected(), true)
end)
test("unrelated addon loads do not rescan spellbook", function()
    local e, _, _, event, init = World("MAGE")
    init()
    local scans = 0
    e.C_SpellBook.GetNumSpellBookSkillLines = function() scans = scans + 1; return 0 end
    event("ADDON_LOADED", "UnrelatedAddon")
    equal(scans, 0)
end)
test("roster alias threat event updates nameplate", function()
    local e, a, plate, event, init = World("MAGE")
    plate("n", {player = true, group = true, threat = 0})
    init()
    e.units.n.threat = 3
    event("UNIT_THREAT_SITUATION_UPDATE", "party1")
    equal(a.Plates.units.n.glow:IsShown(), true)
end)
test("pet health events filtered to pet unit", function()
    local _, a, _, _, init = World("MAGE")
    init()
    equal(a.Core.frame.events.UNIT_HEALTH[1], "pet")
end)

test("native specialization namespace selects correct talent group", function()
    local e, a = World("SHAMAN")
    e.C_SpecializationInfo = {GetActiveSpecGroup = function() return 2 end}
    e.GetActiveTalentGroup = nil
    equal(a.Client.Setup(), "2")
end)
test("native icons populated before hooks do not duplicate", function()
    local e, a, plate, _, init, frame = World("SHAMAN")
    e.book = {{id = 370}}
    local aura = {auraInstanceID = 1, spellId = 42, dispelName = "Magic", icon = 11}
    local _, uf = plate("n", {enemy = true, auras = {aura}})
    local icon = frame(uf.AurasFrame)
    icon.spellID = 42
    uf.AurasFrame.icons[icon] = true
    init()
    equal(a.Plates.units.n.removal:IsShown(), false)
    equal(a.Plates.units.n.auraGlows[icon]:IsShown(), true)
end)
test("cooldown events do not rescan native auras", function()
    local e, _, plate, event, init = World("SHAMAN")
    e.book = {{id = 370}, {id = 8042, range = true}}
    plate("n", {enemy = true, cast = "Spell", shield = false})
    init()
    local scans = 0
    e.C_UnitAuras.GetUnitAuras = function() scans = scans + 1; return {} end
    event("SPELL_UPDATE_COOLDOWN")
    equal(scans, 0)
end)
test("combat cue tick clears stale native unit state", function()
    local e, a, plate, _, init = World("MAGE")
    e.book = {{id = 2139, range = true}}
    local _, uf = plate("n", {enemy = true, cast = "Spell", shield = false})
    init()
    local state = a.Plates.units.n
    uf.unit = e.Secret()
    a.Core.RefreshCombatCues()
    equal(state.interrupt:IsShown(), false)
    equal(a.Plates.units.n, nil)
end)
test("PvP restricted state produces no readiness claim", function()
    local e, a, plate, _, init = World("SHAMAN")
    e.book = {{id = 8042, range = e.Secret()}, {id = 370}}
    plate("n", {enemy = true, player = true, cast = e.Secret(), shield = e.Secret(), auras = {e.Secret()}})
    init()
    local state = a.Plates.units.n
    equal(state.interrupt.border.vertex[2], 0.65)
    equal(state.removal:IsShown(), false)
    equal(state.glow:IsShown(), false)
end)

print("Passed " .. total .. " checks.")
