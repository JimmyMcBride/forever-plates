local _, addon = ...
local Plates, Client, Model = {}, addon.Client, addon.Model
addon.Plates = Plates
Plates.units = {}
Plates.frames = setmetatable({}, {__mode = "k"})
Plates.auraIDs = setmetatable({}, {__mode = "k"})
Plates.pending = {}
Plates.skipped = 0

local function Texture(parent, atlas, layer)
    local texture = parent:CreateTexture(nil, layer or "OVERLAY")
    texture:SetAtlas(atlas)
    return texture
end

local function Icon(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(16, 16)
    frame:EnableMouse(false)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints()
    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints()
    frame.cooldown:EnableMouse(false)
    frame.border = Texture(frame, "UI-HUD-ActionBar-IconFrame")
    frame.border:SetAllPoints()
    frame:Hide()
    return frame
end

local function Outline(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:EnableMouse(false)
    -- Nameplate-relative dimensions can be secret. BackdropTemplate's size
    -- callback divides those dimensions in Lua, so let native anchors draw
    -- four solid edges instead; no dimension reads or tiled coordinates.
    frame.edges = {}
    local anchors = {
        {"TOPLEFT", "TOPRIGHT", "height"},
        {"BOTTOMLEFT", "BOTTOMRIGHT", "height"},
        {"TOPLEFT", "BOTTOMLEFT", "width"},
        {"TOPRIGHT", "BOTTOMRIGHT", "width"},
    }
    for _, points in ipairs(anchors) do
        local edge = frame:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(1, 0.82, 0.15, 0.8)
        edge:SetPoint(points[1], frame, points[1])
        edge:SetPoint(points[2], frame, points[2])
        if points[3] == "height" then edge:SetHeight(1) else edge:SetWidth(1) end
        frame.edges[#frame.edges + 1] = edge
    end
    frame:Hide()
    return frame
end

function Plates.Color()
    if HIGH_THREAT_COLOR then return HIGH_THREAT_COLOR:GetRGB() end
    return 1, 0.12, 0.12
end

function Plates.RestoreColor(state)
    if not state.colored then return end
    if state.uf:IsForbidden() then state.colored = false; return end
    if InCombatLockdown() and state.bar:IsProtected() then
        state.restorePending = true
        return
    end
    state.colored, state.restorePending = false, nil
    if CompactUnitFrame_UpdateHealthColor and Model.Value(state.uf.unit) ~= nil then
        CompactUnitFrame_UpdateHealthColor(state.uf)
    end
end

function Plates.Paint(state)
    if not state.active or not state.aggro or addon.Config.Profile().aggroStyle ~= "color" then return end
    if state.uf:IsForbidden() then return end
    if InCombatLockdown() and state.bar:IsProtected() then return end
    local r, g, b = Plates.Color()
    state.bar:SetStatusBarColor(r, g, b)
    state.colored = true
end

function Plates.Layout(state)
    if state.uf:IsForbidden() then return end
    if InCombatLockdown() and state.root:IsProtected() then state.layoutPending = true; return end
    local anchor = state.bar
    if state.uf.IsShowOnlyName and state.uf:IsShowOnlyName() then anchor = state.uf.name or anchor end
    state.glow:ClearAllPoints()
    state.glow:SetPoint("TOPLEFT", anchor, "TOPLEFT", -5, 5)
    state.glow:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 5, -5)
    state.glowMask:ClearAllPoints()
    state.glowMask:SetAllPoints(state.glow)
    state.aggroIcon:ClearAllPoints()
    state.aggroIcon:SetPoint("LEFT", anchor, "RIGHT", 3, 0)
    state.range:ClearAllPoints()
    state.range:SetPoint("RIGHT", anchor, "LEFT", -3, 0)
    state.interrupt:ClearAllPoints()
    state.interrupt:SetPoint("LEFT", state.cast, "RIGHT", 3, 0)
    state.removal:ClearAllPoints()
    state.removal:SetPoint("BOTTOMLEFT", anchor, "TOPRIGHT", 3, 3)
    state.layoutPending = nil
end

function Plates.Clear(state)
    state.active, state.aggro, state.auraID = false, false, nil
    state.glow:Hide()
    state.aggroIcon:Hide()
    state.interrupt:Hide()
    state.range:Hide()
    state.removal:Hide()
    for _, glow in pairs(state.auraGlows) do glow:Hide() end
    Plates.RestoreColor(state)
end

function Plates.Remove(unit)
    Plates.pending[unit] = nil
    local state = Plates.units[unit]
    if state then
        Plates.Clear(state)
        Plates.units[unit] = nil
        state.unit = nil
    end
end

function Plates.Attach(unit)
    if not Model.Readable(unit) or type(unit) ~= "string" then return end
    local plate, reason = Client.Access(unit)
    if not plate then
        Plates.skipped = Plates.skipped + 1
        Plates.lastSkip = reason
        return
    end
    local uf = plate.UnitFrame
    if InCombatLockdown() and (plate:IsProtected() or uf:IsProtected()) then
        Plates.pending[unit] = true
        return
    end
    local state = Plates.frames[uf]
    if not state then
        state = { uf = uf, bar = uf.HealthBarsContainer.healthBar,
            cast = uf.CastBarsContainer.castBar, auraGlows = {} }
        state.root = CreateFrame("Frame", nil, plate)
        state.root:SetAllPoints(uf)
        state.root:EnableMouse(false)
        state.root:SetFrameLevel(uf:GetFrameLevel() + 10)
        state.glow = Texture(state.root, "UI-HUD-Nameplates-Aggro-Flare")
        state.glowMask = state.root:CreateMaskTexture()
        state.glowMask:SetAtlas("UI-HUD-Nameplates-Aggro-Mask")
        state.glow:AddMaskTexture(state.glowMask)
        state.glow:SetAlpha(0.55)
        state.glow:Hide()
        state.aggroIcon = Icon(state.root)
        state.aggroIcon.icon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
        state.aggroIcon.icon:SetTexCoord(0.5, 1, 0, 0.5)
        state.interrupt, state.range, state.removal = Icon(state.root), Icon(state.root), Icon(state.root)
        state.range.icon:SetTexture("Interface\\Cursor\\UnableCast")
        Plates.frames[uf] = state
    end
    if state.unit then Plates.Remove(state.unit) end
    if Plates.units[unit] then Plates.Remove(unit) end
    -- Native unit frames are pooled independently of their base nameplates.
    state.root:SetParent(plate)
    state.unit, state.active = unit, true
    Plates.units[unit] = state
    Plates.pending[unit] = nil
    Plates.Layout(state)
    Plates.Update(state)
end

function Plates.UpdateAggro(state, profile)
    state.aggro = Client.AllyAggro(state.unit, profile)
    state.glow:SetShown(state.aggro and profile.aggroStyle == "glow")
    state.aggroIcon:SetShown(state.aggro and profile.aggroStyle == "icon")
    if state.aggro then state.glow:SetVertexColor(Plates.Color()) end
    if state.aggro and profile.aggroStyle == "color" then Plates.Paint(state)
    else Plates.RestoreColor(state) end
end

function Plates.UpdateInterrupt(state, profile, side)
    local selected, ready
    if profile.interrupts and side == "enemy" and state.cast:IsVisible() then
        selected, ready = Model.Interrupt(Client.Interrupts(state.unit), Client.CastState(state.unit))
    end
    state.interrupt:SetShown(selected ~= nil)
    if not selected then return end
    state.interrupt.icon:SetTexture(selected.icon)
    state.interrupt.icon:SetDesaturated(selected.usable == false)
    state.interrupt.border:SetVertexColor(ready and 0.35 or 0.65, ready and 1 or 0.65, ready and 0.35 or 0.65)
    local cooldown = state.interrupt.cooldown
    if Model.Readable(selected.duration) and selected.duration == nil then
        cooldown:Clear()
    elseif cooldown.SetCooldownFromDurationObject then
        cooldown:SetCooldownFromDurationObject(selected.duration)
    else
        cooldown:Clear()
    end
end

function Plates.UpdateRange(state, profile)
    local out = false
    if profile.range and Model.Value(Client.Call(UnitIsUnit, state.unit, "target")) == true then
        local side
        if Model.Value(Client.Call(UnitCanAttack, "player", state.unit)) == true then side = "hostile"
        elseif Model.Value(Client.Call(UnitCanAssist, "player", state.unit)) == true then side = "friendly" end
        if side then out = Client.Range(Client.Reference(side), "target") == false end
    end
    state.range:SetShown(out)
end

function Plates.UpdateRemovals(state, profile, side)
    for _, glow in pairs(state.auraGlows) do glow:Hide() end
    state.removal:Hide()
    if not side or (side == "enemy" and not profile.enemyRemoval)
        or (side == "ally" and not profile.allyRemoval) then state.auraID = nil; return end
    local types = Client.Removals(side)
    if next(types) == nil then state.auraID = nil; return end
    local visible, visibleSpells = {}, {}
    local aurasFrame = state.uf.AurasFrame
    if not aurasFrame or aurasFrame:IsForbidden() then return end
    local pool = aurasFrame.auraItemFramePool
    if pool and pool.EnumerateActive then
        for icon in pool:EnumerateActive() do
            if not icon:IsForbidden() and icon:IsVisible() then
                local id = Plates.auraIDs[icon]
                if id then visible[id] = icon end
                local spell = Model.Value(icon.spellID)
                if type(spell) == "number" then visibleSpells[spell] = icon end
            end
        end
    end
    local missing = {}
    for _, aura in ipairs(Client.Auras(state.unit, side)) do
        if Model.EligibleAura(aura, types) and Model.Readable(aura.auraInstanceID)
            and type(aura.auraInstanceID) == "number" then
            local icon = visible[aura.auraInstanceID]
            -- Icons populated before our hook have no instance mapping yet.
            local spell = Model.Value(aura.spellId)
            if not icon and type(spell) == "number" then icon = visibleSpells[spell] end
            if icon then
                local glow = state.auraGlows[icon]
                if not glow and (not InCombatLockdown() or not state.root:IsProtected()) then
                    glow = Outline(state.root)
                    glow:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
                    glow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
                    state.auraGlows[icon] = glow
                end
                if glow then glow:Show() end
            else missing[#missing + 1] = aura end
        end
    end
    local aura = Model.SelectAura(missing, types, state.auraID)
    state.auraID = aura and aura.auraInstanceID or nil
    if aura then
        state.removal.icon:SetTexture(aura.icon)
        state.removal.border:SetVertexColor(1, 0.82, 0.15)
        state.removal:Show()
    end
end

function Plates.Update(state)
    if not state.active or state.uf:IsForbidden() then return end
    local ufUnit = Model.Value(state.uf.unit)
    if ufUnit ~= state.unit then Plates.Remove(state.unit); return end
    local profile = addon.Config.Profile()
    local side = Client.Side(state.unit)
    Plates.UpdateAggro(state, profile)
    Plates.UpdateInterrupt(state, profile, side)
    Plates.UpdateRange(state, profile)
    Plates.UpdateRemovals(state, profile, side)
end

function Plates.UpdateAll()
    for _, state in pairs(Plates.units) do Plates.Update(state) end
end

function Plates.Scan()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    local plates = Client.Call(C_NamePlate.GetNamePlates)
    if not Model.Readable(plates) or type(plates) ~= "table" then return end
    for _, plate in ipairs(plates) do
        if not plate:IsForbidden() then
            local unit = Model.Value(plate.unitToken)
            if unit then Plates.Attach(unit) end
        end
    end
end

function Plates.AfterCombat()
    for _, state in pairs(Plates.frames) do
        Plates.RestoreColor(state)
        if state.active and state.layoutPending then Plates.Layout(state) end
    end
    local pending = Plates.pending
    Plates.pending = {}
    for unit in pairs(pending) do
        if Model.Value(Client.Call(UnitExists, unit)) == true then Plates.Attach(unit) end
    end
end

function Plates.Stop()
    for unit in pairs(Plates.units) do Plates.Remove(unit) end
    Plates.pending = {}
end

function Plates.Hook()
    if Plates.hooked then return end
    Plates.hooked = true
    if CompactUnitFrame_UpdateHealthColor then
        hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(uf)
            if uf:IsForbidden() then return end
            local state = Plates.frames[uf]
            if state then Plates.Paint(state) end
        end)
    end
    if NamePlateAuraItemMixin then
        hooksecurefunc(NamePlateAuraItemMixin, "SetAura", function(icon, aura)
            if icon:IsForbidden() then return end
            Plates.auraIDs[icon] = nil
            if Model.Readable(aura) and type(aura) == "table" then
                local id = Model.Value(aura.auraInstanceID)
                if type(id) == "number" then Plates.auraIDs[icon] = id end
            end
        end)
    end
    if NamePlateAurasMixin then
        hooksecurefunc(NamePlateAurasMixin, "RefreshAuras", function(frame)
            if frame:IsForbidden() then return end
            local unit = Model.Value(frame.unitToken)
            local state = unit and Plates.units[unit]
            if state then Plates.UpdateRemovals(state, addon.Config.Profile(), Client.Side(unit)) end
        end)
    end
    if NamePlateUnitFrameMixin then
        hooksecurefunc(NamePlateUnitFrameMixin, "ApplyFrameOptions", function(uf)
            if uf:IsForbidden() then return end
            local state = Plates.frames[uf]
            if state and state.active then Plates.Layout(state) end
        end)
    end
end
