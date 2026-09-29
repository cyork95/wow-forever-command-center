local _, ns = ...

local U = ns.utils

local TOP_MOBS = 15
local DROP_LIMIT = 60
local NAMES_PER_LINE = 6

local function AddNameRows(lines, names)
    for first = 1, #names, NAMES_PER_LINE do
        local row = {}

        for index = first, math.min(first + NAMES_PER_LINE - 1, #names) do
            table.insert(row, names[index])
        end

        table.insert(lines, "  " .. table.concat(row, ", "))
    end
end

ns.Companions:Register({
    id = "killdex",
    title = "KillDex",
    addons = { "KillDex" },
    adds = "Total kills, creature types, your top 15 creatures, and items seen dropping.",
    IsBuiltIn = function()
        local kills = ns.Data and ns.Data.Kills
        return kills ~= nil and kills:HasData()
    end,
    Collect = function(_, H)
        local mobs = H.Get(KillDexCharDB, "mobs")

        if type(mobs) ~= "table" then
            error("KillDexCharDB.mobs missing")
        end

        local rows = {}
        local byType = {}
        local drops = {}
        local totalKills = 0
        local totalGold = 0

        for _, mob in pairs(mobs) do
            if type(mob) == "table" then
                local kills = U.ToSafeNumber(mob.kills) or 0
                totalKills = totalKills + kills
                totalGold = totalGold + (U.ToSafeNumber(mob.gold) or 0)

                if mob.name then
                    table.insert(rows, { name = tostring(mob.name), kills = kills })
                end

                local creatureType = mob.creatureType

                if type(creatureType) ~= "string" or creatureType == "" or creatureType == "Not specified" then
                    creatureType = "Other"
                end

                byType[creatureType] = (byType[creatureType] or 0) + kills

                if type(mob.loot) == "table" then
                    for _, drop in pairs(mob.loot) do
                        local name = type(drop) == "table"
                            and (H.LinkName(drop.link) or drop.name)

                        if name then
                            drops[name] = true
                        end
                    end
                end
            end
        end

        if #rows == 0 then
            return {}
        end

        local lines = {
            string.format("Total kills: %d across %d creatures", totalKills, #rows),
            "Gold looted from kills: " .. H.FormatMoney(totalGold),
        }

        local types = {}

        for name, kills in pairs(byType) do
            table.insert(types, { name = name, kills = kills })
        end

        table.sort(types, function(a, b) return a.kills > b.kills end)

        local typeText = {}

        for _, entry in ipairs(types) do
            table.insert(typeText, string.format("%s %d", entry.name, entry.kills))
        end

        table.insert(lines, "By creature type: " .. table.concat(typeText, ", "))

        table.sort(rows, function(a, b)
            if a.kills == b.kills then
                return a.name < b.name
            end

            return a.kills > b.kills
        end)

        table.insert(lines, "Top creatures:")

        for index = 1, math.min(TOP_MOBS, #rows) do
            table.insert(lines, string.format("  %s x%d", rows[index].name, rows[index].kills))
        end

        local dropNames = {}

        for name in pairs(drops) do
            table.insert(dropNames, name)
        end

        table.sort(dropNames)

        if #dropNames > 0 then
            table.insert(lines, string.format("Items seen dropping (%d):", #dropNames))

            local shown = {}

            for index = 1, math.min(DROP_LIMIT, #dropNames) do
                shown[index] = dropNames[index]
            end

            AddNameRows(lines, shown)

            if #dropNames > DROP_LIMIT then
                table.insert(lines, string.format("  ...and %d more", #dropNames - DROP_LIMIT))
            end
        end

        return lines
    end,
})
