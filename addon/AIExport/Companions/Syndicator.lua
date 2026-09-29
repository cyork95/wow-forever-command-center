local _, ns = ...

local ITEM_LIMIT = 60

local function FindCharacter(H)
    local characters = H.Get(SYNDICATOR_DATA, "Characters")

    if type(characters) ~= "table" then
        error("SYNDICATOR_DATA.Characters missing")
    end

    local api = H.Get(Syndicator, "API")

    if api and type(api.GetCurrentCharacter) == "function" then
        local ok, key = pcall(api.GetCurrentCharacter)

        if ok and key and type(characters[key]) == "table" then
            return characters[key]
        end
    end

    local key = H.FindCharacterKey(characters)

    return key and characters[key]
end

local function AddItems(lines, H, label, container)
    local itemLines, distinct = H.ItemLines(container, ITEM_LIMIT)

    if distinct == 0 then
        table.insert(lines, label .. ": empty")
        return
    end

    table.insert(lines, string.format("%s (%s):", label, H.Plural(distinct, "different item")))

    for _, line in ipairs(itemLines) do
        table.insert(lines, line)
    end
end

ns.Companions:Register({
    id = "syndicator",
    title = "Syndicator",
    addons = { "Syndicator" },
    adds = "Your mail, and your bank contents even while the bank is closed.",
    Collect = function(_, H)
        local row = FindCharacter(H)

        if not row then
            return {}
        end

        local lines = {}

        if row.money then
            table.insert(lines, "Gold: " .. H.FormatMoney(row.money))
        end

        AddItems(lines, H, "Mail", row.mail)
        AddItems(lines, H, "Bank", row.bank)

        if H.Count(row.bankTabs) > 0 then
            AddItems(lines, H, "Bank tabs", row.bankTabs)
        end

        if H.Count(row.auctions) > 0 then
            AddItems(lines, H, "Auctions", row.auctions)
        end

        return lines
    end,
})
