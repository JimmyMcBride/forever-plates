local _, addon = ...
local Capabilities = {}
addon.Capabilities = Capabilities

-- Forever's nine classes. Families list trainer ranks, not Retail replacements.
-- Every entry must also be present in the active player/pet spellbook.
local function Ability(ids, extra)
    local result = extra or {}
    result.ids = ids
    return result
end
Capabilities.records = {
    WARRIOR = {
        interrupts = { Ability({6552, 6554}), Ability({72, 1671, 1672}) },
        hostile = { Ability({1715, 7372, 7373}), Ability({78, 284, 285, 1608, 11564, 11565, 11566, 11567, 25286}) },
    },
    PALADIN = {
        hostile = { Ability({20271}) },
        friendly = { Ability({635, 639, 647, 1026, 1042, 3472, 10328, 10329, 25292}) },
        removals = {
            Ability({4987}, { ally = {Magic = true, Poison = true, Disease = true} }),
            Ability({1152}, { ally = {Poison = true, Disease = true} }),
        },
    },
    HUNTER = {
        hostile = { Ability({3044, 14281, 14282, 14283, 14284, 14285, 14286, 14287}) },
        removals = { Ability({19801}, { enemy = {Enrage = true} }) },
    },
    ROGUE = {
        interrupts = { Ability({1766, 1767, 1768, 1769}) },
        hostile = { Ability({1752, 1757, 1758, 1759, 1760, 8621, 11293, 11294}) },
    },
    PRIEST = {
        hostile = { Ability({585, 591, 598, 984, 1004, 6060, 10933, 10934}) },
        friendly = { Ability({2050, 2052, 2053}), Ability({2054, 2055, 6063, 6064}), Ability({2060, 10963, 10964, 10965, 25314}) },
        removals = {
            Ability({527, 988}, { ally = {Magic = true}, enemy = {Magic = true} }),
            Ability({528, 552}, { ally = {Disease = true} }),
        },
    },
    SHAMAN = {
        interrupts = { Ability({8042, 8044, 8045, 8046, 10412, 10413, 10414}) },
        hostile = { Ability({403, 529, 548, 915, 943, 6041, 10391, 10392, 15207, 15208}) },
        friendly = { Ability({331, 332, 547, 913, 939, 959, 8005, 10395, 10396, 25357}) },
        removals = {
            Ability({370, 8012}, { enemy = {Magic = true} }),
            Ability({526}, { ally = {Poison = true} }),
            Ability({2870}, { ally = {Disease = true} }),
        },
    },
    MAGE = {
        interrupts = { Ability({2139}) },
        hostile = { Ability({116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304}) },
        removals = { Ability({475}, { ally = {Curse = true} }) },
    },
    WARLOCK = {
        interrupts = { Ability({19244, 19647}, { owner = "pet" }) },
        hostile = { Ability({686, 695, 705, 1088, 1106, 7641, 11659, 11660, 11661, 25307}) },
        removals = { Ability({19505, 19731, 19734, 19736}, { owner = "pet", ally = {Magic = true}, enemy = {Magic = true} }) },
    },
    DRUID = {
        interrupts = { Ability({16979}, { forms = {[5] = true, [8] = true} }) },
        hostile = {
            Ability({1082, 3029, 5201, 9849, 9850}, { forms = {[1] = true} }),
            Ability({6807, 6808, 6809, 8972, 9745, 9880, 9881}, { forms = {[5] = true, [8] = true} }),
            Ability({5176, 5177, 5178, 5179, 5180, 6780, 8905, 9912}),
        },
        friendly = { Ability({5185, 5186, 5187, 5188, 5189, 6778, 8903, 9758, 9888, 9889, 25297}, { forms = {[0] = true} }) },
        removals = {
            Ability({2782}, { ally = {Curse = true}, forms = {[0] = true, [31] = true} }),
            Ability({8946, 2893}, { ally = {Poison = true}, forms = {[0] = true} }),
        },
    },
}

function Capabilities.Resolve(class, book, form, petAlive)
    local resolved = { interrupts = {}, hostile = {}, friendly = {}, removals = {} }
    local records = Capabilities.records[class] or {}
    for _, category in ipairs({"interrupts", "hostile", "friendly", "removals"}) do
        local seen = {}
        for _, family in ipairs(records[category] or {}) do
            if (not family.forms or family.forms[form]) and (family.owner ~= "pet" or petAlive) then
                for index = #family.ids, 1, -1 do
                    local known = book[(family.owner or "player") .. ":" .. family.ids[index]]
                    if known then
                        local identity = (known.owner or "player") .. ":" .. known.id
                        if not seen[identity] then
                            local entry = {}
                            for key, value in pairs(known) do entry[key] = value end
                            entry.ally, entry.enemy = family.ally, family.enemy
                            resolved[category][#resolved[category] + 1] = entry
                            seen[identity] = true
                        end
                        if category ~= "interrupts" then break end
                    end
                end
            end
        end
    end
    return resolved
end
