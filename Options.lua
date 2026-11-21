local _, addon = ...
local Options = {}
addon.Options = Options

function Options.Create()
    local panel = CreateFrame("Frame")
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -30, 8)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(560, 710)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width) content:SetWidth(math.max(280, width)) end)
    local controls = {}
    local function Text(text, y, font)
        local label = content:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
        label:SetPoint("TOPLEFT", 12, y)
        label:SetPoint("RIGHT", content, "RIGHT", -12, 0)
        label:SetJustifyH("LEFT")
        label:SetText(text)
        return label
    end
    local function Check(label, y, read, write)
        local check = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 10, y)
        check:SetSize(26, 26)
        local text = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", check, "RIGHT", 4, 0)
        text:SetText(label)
        check:SetScript("OnClick", function(self)
            if not addon.Config.blocked then write(self:GetChecked()) end
            Options.Refresh()
        end)
        controls[#controls + 1] = {frame = check, read = read}
    end
    local function Dropdown(label, y, value, items, change)
        Text(label, y, "GameFontNormal")
        local dropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
        dropdown:SetPoint("TOPLEFT", 14, y - 24)
        dropdown:SetWidth(300)
        dropdown:SetupMenu(function(_, root)
            for _, item in ipairs(items()) do
                root:CreateRadio(item.label, function() return value() == item.value end, function()
                    if not addon.Config.blocked then change(item.value) end
                    Options.Refresh()
                end)
            end
        end)
        return dropdown
    end
    Text(addon.title, -12, "GameFontNormalLarge")
    Text("Small additions to Blizzard plates. Enable nameplates in Blizzard settings first.", -42)
    Check("Use independent settings for this character", -78,
        function() return not addon.Config.blocked and ForeverPlatesCharacterDB.useCharacter end,
        addon.Config.SetCharacter)
    local scope = Text("", -112, "GameFontNormal")
    local features = {
        {"aggro", "Highlight group members with aggro"},
        {"interrupts", "Show interrupt availability beside enemy casts"},
        {"range", "Show when current target is out of spell range"},
        {"enemyRemoval", "Highlight enemy effects I can remove"},
        {"allyRemoval", "Highlight group effects I can dispel"},
        {"excludeTanks", "Exclude assigned tanks from aggro highlight"},
    }
    for index, feature in ipairs(features) do
        local key = feature[1]
        Check(feature[2], -144 - (index - 1) * 30,
            function() return addon.Config.Profile()[key] end,
            function(value) addon.Config.Set(key, value) end)
    end
    Dropdown("Ally aggro presentation", -340,
        function() return addon.Config.Profile().aggroStyle end,
        function() return {
            {value = "glow", label = "Blizzard-style glow (default)"},
            {value = "icon", label = "Small aggro icon"},
            {value = "color", label = "Temporary health-bar color"},
        } end, function(value) addon.Config.Set("aggroStyle", value) end)
    for index, kind in ipairs({"hostile", "friendly"}) do
        local side = kind
        Dropdown(side == "hostile" and "Hostile range reference (this talent setup)"
            or "Friendly range reference (this talent setup)", -410 - (index - 1) * 70,
            function()
                if addon.Config.blocked then return 0 end
                return addon.Config.Spells(addon.Client.Setup())[side] or 0
            end,
            function()
                local items = {{value = 0, label = "Automatic"}}
                for _, spell in ipairs(addon.Client.choices[side]) do
                    items[#items + 1] = {value = spell.id, label = spell.name .. " (" .. spell.id .. ")"}
                end
                return items
            end,
            function(id)
                addon.Config.Spells(addon.Client.Setup())[side] = id ~= 0 and id or nil
                addon.Config.Changed()
            end)
    end
    local status = Text("", -558)
    status:SetTextColor(1, 0.78, 0.35)
    Text("Unknown data never means ready or safe. Forbidden plates stay under Blizzard control.\nRemoval cues identify effects you can remove, not cooldown or range readiness.\nAll features are mouse transparent. /fplates status shows capability details.", -640)
    function Options.Refresh()
        for _, control in ipairs(controls) do
            control.frame:SetChecked(control.read())
            control.frame:SetEnabled(not addon.Config.blocked)
        end
        scope:SetText(addon.Config.blocked or (ForeverPlatesCharacterDB.useCharacter
            and "Editing: Character settings" or "Editing: Shared settings"))
        status:SetText(addon.Core.Status())
    end
    panel:SetScript("OnShow", Options.Refresh)
    Options.panel = panel
    Options.category = Settings.RegisterCanvasLayoutCategory(panel, addon.title)
    Settings.RegisterAddOnCategory(Options.category)
end

function Options.Open()
    if Options.category then Settings.OpenToCategory(Options.category:GetID()) end
end
