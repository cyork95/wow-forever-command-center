local _, ns = ...

local U = ns.utils

local COUNTS = {
    { key = "Quests", label = "Quests completed" },
    { key = "Exploration", label = "Areas explored" },
    { key = "FlightPaths", label = "Flight paths" },
    { key = "Achievements", label = "Achievements" },
    { key = "Mounts", label = "Mounts" },
    { key = "BattlePets", label = "Pets" },
    { key = "Toys", label = "Toys" },
    { key = "Titles", label = "Titles" },
}

local function FindCharacter(H)
    local characters = ATTCharacterData

    if type(characters) ~= "table" then
        error("ATTCharacterData missing")
    end

    local ok, guid = H.SafeCall(UnitGUID, "player")

    if ok and guid and type(characters[guid]) == "table" then
        return characters[guid]
    end

    local names = H.PlayerNames()

    for _, name in ipairs(names) do
        for _, row in pairs(characters) do
            if type(row) == "table" and row.name == name then
                return row
            end
        end
    end

    return nil
end

ns.Companions:Register({
    id = "allthethings",
    title = "AllTheThings",
    addons = { "AllTheThings" },
    adds = "Deaths, quests, areas explored, time played, and mount, pet, toy, and title counts.",
    Collect = function(_, H)
        local row = FindCharacter(H)

        if not row then
            return {}
        end

        local lines = {}

        if row.lvl then
            table.insert(lines, "Level: " .. tostring(row.lvl))
        end

        if U.ToSafeNumber(row.totalTimePlayed) then
            table.insert(lines, "Time played: " .. H.FormatDuration(row.totalTimePlayed))
        end

        if row.Deaths ~= nil then
            table.insert(lines, "Deaths: " .. tostring(row.Deaths))
        end

        for _, entry in ipairs(COUNTS) do
            if type(row[entry.key]) == "table" then
                table.insert(lines, string.format("%s: %d", entry.label, H.Count(row[entry.key])))
            end
        end

        if U.ToSafeNumber(row.lastPlayed) then
            table.insert(lines, "Last played: " .. H.FormatDate(row.lastPlayed))
        end

        return lines
    end,
})
