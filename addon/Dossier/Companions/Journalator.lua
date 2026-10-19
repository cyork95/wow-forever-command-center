local _, ns = ...

local WEEK = 7 * 24 * 60 * 60

local SECTIONS = {
    { key = "Questing", label = "Questing", incoming = true },
    { key = "LootContainers", label = "Looting", incoming = true },
    { key = "Invoices", label = "Auction sales", incoming = true },
    { key = "BasicMailReceived", label = "Mail in", incoming = true },
    { key = "Vendoring", label = "Vendors", incoming = false },
    { key = "VendorRepairs", label = "Repairs", incoming = false },
    { key = "Taxis", label = "Flight paths", incoming = false },
    { key = "TrainingCosts", label = "Trainers", incoming = false },
    { key = "BasicMailSent", label = "Mail out", incoming = false },
}

local function SameCharacter(source, player)
    if type(source) ~= "table" then
        return true
    end

    local character = source.character

    if type(character) ~= "string" or character == "" or player == "" then
        return true
    end

    character = string.lower(character)
    player = string.lower(player)

    return character == player
        or string.sub(character, 1, #player) == player
        or string.sub(player, 1, #character) == character
end

local function Amounts(entry, incoming)
    local gained = tonumber(entry.rewardMoney) or 0
    local spent = tonumber(entry.requiredMoney) or 0
    local money = tonumber(entry.money) or 0
    local price = tonumber(entry.unitPrice)
    local count = tonumber(entry.count) or 1
    local value = tonumber(entry.value) or 0
    local priced = (price and price > 0) and (price * count) or 0
    local kind = string.lower(tostring(entry.invoiceType or ""))

    if incoming then
        gained = gained + money
    else
        spent = spent + money + priced
    end

    if string.find(kind, "buy", 1, true) then
        spent = spent + value
    else
        gained = gained + value
    end

    return gained, spent
end

local function Entries(sectionKey, cutoff)
    if Journalator.Archiving and type(Journalator.Archiving.GetRange) == "function" then
        local ok, items = pcall(Journalator.Archiving.GetRange, cutoff, sectionKey)

        if ok and type(items) == "table" then
            return items
        end
    end

    local logs = Journalator.State and Journalator.State.Logs

    return type(logs) == "table" and logs[sectionKey] or nil
end

local function GoldLines(helpers)
    if type(Journalator) ~= "table" or type(Journalator.State) ~= "table" then
        return nil
    end

    local player = UnitName("player") or ""
    local now = time()
    local cutoff = now - WEEK
    local lines = {}

    for _, section in ipairs(SECTIONS) do
        local list = Entries(section.key, cutoff)
        local gained, spent, count = 0, 0, 0

        if type(list) == "table" then
            for _, entry in ipairs(list) do
                if type(entry) == "table" then
                    local when = tonumber(entry.time)

                    if (when == nil or when >= cutoff) and SameCharacter(entry.source, player) then
                        local inCopper, outCopper = Amounts(entry, section.incoming)

                        if inCopper > 0 or outCopper > 0 then
                            gained = gained + inCopper
                            spent = spent + outCopper
                            count = count + 1
                        end
                    end
                end
            end
        end

        if count > 0 then
            local parts = { section.label }

            if gained > 0 then
                table.insert(parts, "in " .. helpers.FormatMoney(gained))
            end

            if spent > 0 then
                table.insert(parts, "out " .. helpers.FormatMoney(spent))
            end

            table.insert(parts, "(" .. count .. ")")
            table.insert(lines, table.concat(parts, "  "))
        end
    end

    return lines
end

ns.Companions:Register({
    id = "journalator",
    title = "Journalator",
    addons = { "Journalator" },
    adds = "Gold in and out for the last 7 days.",

    ReadGold = function(_, helpers)
        return GoldLines(helpers)
    end,

    Collect = function(_, helpers)
        return GoldLines(helpers) or {}
    end,
})
