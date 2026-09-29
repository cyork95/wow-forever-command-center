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

local function ContainerItems(H, container)
    local items = {}
    local byName = {}

    H.EachItem(container, function(item)
        local name = H.LinkName(item.itemLink)

        if name then
            local entry = byName[name]

            if not entry then
                entry = { name = name, link = item.itemLink, count = 0 }
                byName[name] = entry
                table.insert(items, entry)
            end

            entry.count = entry.count + (tonumber(item.itemCount) or 1)
        end
    end)

    return items
end

ns.Companions:Register({
    id = "syndicator",
    title = "Syndicator",
    addons = { "Syndicator" },
    adds = "Your mail, and your bank contents even while the bank is closed.",
    ReadBank = function(_, H)
        local row = FindCharacter(H)

        if not row then
            return nil
        end

        local sections = {}
        local bankItems = ContainerItems(H, row.bank)
        local tabItems = ContainerItems(H, row.bankTabs)

        if #bankItems > 0 then
            table.insert(sections, { name = "Bank", items = bankItems })
        end

        if #tabItems > 0 then
            table.insert(sections, { name = "Bank tabs", items = tabItems })
        end

        return { sections = sections }
    end,
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
