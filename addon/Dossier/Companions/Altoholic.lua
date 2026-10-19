local _, ns = ...

local FACTION_CAP = 40
local CHARACTER_CAP = 12

local function FactionName(factionID)
    if C_Reputation and type(C_Reputation.GetFactionDataByID) == "function" then
        local ok, info = pcall(C_Reputation.GetFactionDataByID, factionID)

        if ok and type(info) == "table" and type(info.name) == "string" then
            return info.name
        end
    end

    if type(GetFactionInfoByID) == "function" then
        local ok, name = pcall(GetFactionInfoByID, factionID)

        if ok and type(name) == "string" then
            return name
        end
    end

    return nil
end

local function StandingText(standing, earned, nextLevel)
    if type(standing) == "number" then
        standing = "Renown " .. standing
    end

    if type(standing) ~= "string" or standing == "" then
        return nil
    end

    local text = standing
    earned = tonumber(earned)
    nextLevel = tonumber(nextLevel)

    if earned and nextLevel and nextLevel > 0 then
        text = string.format("%s %d/%d", text, math.floor(earned), math.floor(nextLevel))
    end

    return text
end

local function CharacterLines(key)
    if type(DataStore.GetReputations) ~= "function" or type(DataStore.GetReputationInfo) ~= "function" then
        return nil
    end

    local factions = DataStore:GetReputations(key)

    if type(factions) ~= "table" then
        return nil
    end

    local names = {}

    for factionID in pairs(factions) do
        local name = FactionName(factionID)

        if name then
            table.insert(names, name)
        end
    end

    table.sort(names)

    local lines = {}

    for _, name in ipairs(names) do
        if #lines >= FACTION_CAP then
            table.insert(lines, "More factions saved.")
            break
        end

        local ok, standing, earned, nextLevel = pcall(DataStore.GetReputationInfo, DataStore, key, name)

        if ok then
            local text = StandingText(standing, earned, nextLevel)

            if text then
                table.insert(lines, name .. "  " .. text)
            end
        end
    end

    return lines
end

local function ReputationGroups()
    if type(DataStore) ~= "table" or type(DataStore.GetCharacters) ~= "function" then
        return nil
    end

    local realm = GetRealmName()
    local ok, characters = pcall(DataStore.GetCharacters, DataStore, realm)

    if not ok or type(characters) ~= "table" then
        return nil
    end

    local names = {}

    for name in pairs(characters) do
        table.insert(names, name)
    end

    table.sort(names)

    local groups = {}

    for _, name in ipairs(names) do
        if #groups >= CHARACTER_CAP then
            break
        end

        local lines = CharacterLines(characters[name])

        if type(lines) == "table" and #lines > 0 then
            table.insert(groups, { character = name, lines = lines })
        end
    end

    return groups
end

ns.Companions:Register({
    id = "altoholic",
    title = "Altoholic",
    addons = { "Altoholic", "DataStore", "DataStore_Reputations" },
    adds = "Reputation standings saved for each character.",

    ReadReputations = function()
        return ReputationGroups()
    end,

    Collect = function()
        local groups = ReputationGroups() or {}
        local lines = {}

        for _, group in ipairs(groups) do
            table.insert(lines, group.character)

            for _, line in ipairs(group.lines) do
                table.insert(lines, line)
            end
        end

        return lines
    end,
})
