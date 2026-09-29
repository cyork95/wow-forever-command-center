local _, ns = ...

local U = ns.utils

local PROFESSION_NAMES = {
    [129] = "First Aid",
    [164] = "Blacksmithing",
    [165] = "Leatherworking",
    [171] = "Alchemy",
    [182] = "Herbalism",
    [185] = "Cooking",
    [186] = "Mining",
    [197] = "Tailoring",
    [202] = "Engineering",
    [333] = "Enchanting",
    [356] = "Fishing",
    [393] = "Skinning",
    [755] = "Jewelcrafting",
    [773] = "Inscription",
}

-- Profession Master stores item-only entries as 9000000 + itemID.
local ITEM_SKILL_OFFSET = 9000000
local NAMES_PER_LINE = 5

local function RecipeName(H, entry)
    local skillId = U.ToSafeNumber(entry.skillId)

    if not skillId then
        return nil
    end

    local known = H.Get(PM_Skills, skillId, "name")

    if type(known) == "string" and known ~= "" then
        return known
    end

    if skillId < ITEM_SKILL_OFFSET then
        local ok, name = H.SafeCall(GetSpellInfo, skillId)

        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end

    local itemId = U.ToSafeNumber(entry.itemId)

    if itemId then
        local ok, name = H.SafeCall(GetItemInfo, itemId)

        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end

    return nil
end

local function FindOwn(H)
    if type(PM_Data) ~= "table" then
        error("PM_Data missing")
    end

    for _, realm in pairs(PM_Data) do
        local own = type(realm) == "table" and realm.own
        local key = H.FindCharacterKey(own)

        if key then
            return own[key], H.Get(realm, "ownLevels", key)
        end
    end

    return nil
end

ns.Companions:Register({
    id = "professionmaster",
    title = "Profession Master",
    addons = { "ProfessionMaster" },
    adds = "Every recipe you know, grouped by profession.",
    Collect = function(_, H)
        local professions, levels = FindOwn(H)

        if type(professions) ~= "table" then
            return {}
        end

        local sorted = {}

        for professionId, entries in pairs(professions) do
            local id = U.ToSafeNumber(professionId)
            local names = {}
            local seen = {}

            if type(entries) == "table" then
                for _, entry in pairs(entries) do
                    local name = type(entry) == "table" and RecipeName(H, entry)

                    if name and not seen[name] then
                        seen[name] = true
                        table.insert(names, name)
                    end
                end
            end

            table.sort(names)

            table.insert(sorted, {
                name = PROFESSION_NAMES[id] or ("Profession " .. tostring(professionId)),
                level = type(levels) == "table" and (levels[professionId] or levels[id]) or nil,
                recipes = names,
            })
        end

        table.sort(sorted, function(a, b) return a.name < b.name end)

        local lines = {}

        for _, profession in ipairs(sorted) do
            local header = profession.name

            if profession.level then
                header = header .. " (skill " .. tostring(profession.level) .. ")"
            end

            table.insert(lines, string.format("%s: %s", header, H.Plural(#profession.recipes, "recipe")))

            for first = 1, #profession.recipes, NAMES_PER_LINE do
                local row = {}

                for index = first, math.min(first + NAMES_PER_LINE - 1, #profession.recipes) do
                    table.insert(row, profession.recipes[index])
                end

                table.insert(lines, "  " .. table.concat(row, ", "))
            end
        end

        return lines
    end,
})
