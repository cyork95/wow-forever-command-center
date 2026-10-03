local _, ns = ...

local Ledger = {}

local GOLD_CAP = 400
local CHANGE_CAP = 200
local SALE_DAYS = 30 * 86400

Ledger.SOURCES = { "auction", "vendor", "quest", "loot", "mail", "trade", "other" }

Ledger.SOURCE_LABELS = {
    auction = "Auction House",
    vendor = "Vendors",
    quest = "Questing",
    loot = "Looting",
    mail = "Mail",
    trade = "Trades",
    other = "Other",
}

Ledger.refusedEvents = {}

local lastMoney = nil
local currencySeen = {}
local reputationSeen = {}
local hintKind = nil
local hintDetail = nil
local hintUntil = 0

local function Account()
    return ns.Account
end

local function Now()
    return Account().Now()
end

local function Clock()
    if type(GetTime) == "function" then
        local ok, value = pcall(GetTime)

        if ok and type(value) == "number" then
            return value
        end
    end

    return Now()
end

local function ReadMoney()
    if type(GetMoney) ~= "function" then
        return nil
    end

    local ok, money = pcall(GetMoney)

    if not ok or type(money) ~= "number" then
        return nil
    end

    if money == 0 and (lastMoney or 0) > 0 then
        return lastMoney
    end

    return money
end

local function Character()
    local bucket = Account().Bucket("ledger")
    local key = Account().CharacterKey()

    if not bucket or not key then
        return nil, nil
    end

    local row = bucket[key]

    if type(row) ~= "table" then
        row = {}
        bucket[key] = row
    end

    row.gold = type(row.gold) == "table" and row.gold or {}
    row.currencies = type(row.currencies) == "table" and row.currencies or {}
    row.reputations = type(row.reputations) == "table" and row.reputations or {}

    return row, key
end

function Ledger:CharacterKeys()
    local bucket = Account().Bucket("ledger")
    local keys = Account().Keys(bucket)
    local mine = Account().CharacterKey()
    local ordered = {}

    if mine then
        table.insert(ordered, mine)
    end

    for _, key in ipairs(keys) do
        if key ~= mine then
            table.insert(ordered, key)
        end
    end

    return ordered
end

function Ledger:Get(key)
    local bucket = Account().Bucket("ledger")

    if not bucket or not key or key == "all" then
        return nil
    end

    return bucket[key]
end

local function PeriodStart(period)
    local now = Now()

    if period == "today" then
        return now - (now % 86400)
    end

    if period == "week" then
        return now - (7 * 86400)
    end

    if period == "session" then
        local session = ns.Data and ns.Data.Session
        local summary = session and session.GetSummary and session:GetSummary() or nil

        return summary and tonumber(summary.startedAt) or now
    end

    return nil
end

local function InPeriod(timestamp, period)
    local start = PeriodStart(period)

    if not start then
        return true
    end

    return (tonumber(timestamp) or 0) >= start
end

local function Hint(kind, detail)
    hintKind = kind
    hintDetail = detail
    hintUntil = Clock() + 2
end

local function TakeHint()
    if Clock() > hintUntil then
        hintKind = nil
        hintDetail = nil
    end

    local kind, detail = hintKind, hintDetail
    hintKind = nil
    hintDetail = nil

    return kind, detail
end

local function Shown(name)
    return Account().Shown(name)
end

local function SourceFor(delta)
    local kind, detail = TakeHint()

    if Shown("AuctionFrame") or Shown("AuctionHouseFrame") then
        return "auction", detail or kind or (delta < 0 and "post" or "sale")
    end

    if Shown("TaxiFrame") then
        return "vendor", "flight"
    end

    if Shown("ClassTrainerFrame") or Shown("TrainerFrame") then
        return "vendor", "training"
    end

    if Shown("MerchantFrame") then
        if delta < 0 and type(GetRepairAllCost) == "function" then
            local ok, cost = pcall(GetRepairAllCost)

            if ok and type(cost) == "number" and cost > 0 and math.abs(delta) == cost then
                return "vendor", "repair"
            end
        end

        return "vendor", delta < 0 and "buy" or "sell"
    end

    if Shown("QuestFrame") or kind == "quest" then
        return "quest", detail
    end

    if Shown("LootFrame") or kind == "loot" then
        return "loot", detail
    end

    if Shown("InboxFrame") or Shown("SendMailFrame") or Shown("MailFrame") or kind == "mail" then
        return "mail", detail
    end

    if Shown("TradeFrame") or kind == "trade" then
        local who = type(UnitName) == "function" and UnitName("npc") or nil

        if type(who) ~= "string" or who == "" then
            who = type(UnitName) == "function" and UnitName("target") or nil
        end

        return "trade", detail or who
    end

    if Shown("GuildBankFrame") then
        return "other", "Guild bank"
    end

    if kind and Ledger.SOURCE_LABELS[kind] then
        return kind, detail
    end

    return "other", detail
end

function Ledger:RecordGold(delta, source, detail, balance)
    local row = Character()

    if not row or delta == 0 then
        return
    end

    Account().Push(row.gold, {
        time = Now(),
        delta = delta,
        balance = balance,
        source = source or "other",
        detail = detail,
    }, GOLD_CAP)
end

local function OnMoney()
    local money = ReadMoney()

    if not money then
        return
    end

    local previous = lastMoney or money
    local delta = money - previous

    if money == 0 and (lastMoney or 0) > 0 then
        return
    end

    lastMoney = money

    if delta == 0 or not ns:IsFeatureOn("ledger") then
        return
    end

    local source, detail = SourceFor(delta)
    Ledger:RecordGold(delta, source, detail, money)
    SyncCurrencies()
end

local function CurrencyList()
    local currencies = ns.Data and ns.Data.Currencies

    if not currencies or type(currencies.Collect) ~= "function" then
        return {}
    end

    local ok, data = pcall(currencies.Collect, currencies)

    if not ok or type(data) ~= "table" then
        return {}
    end

    return data.entries or {}
end

local function SyncCurrencies()
    local row = Character()

    if not row or not ns:IsFeatureOn("ledger") then
        return
    end

    for _, entry in ipairs(CurrencyList()) do
        local id = tonumber(entry.currencyID)
        local quantity = tonumber(entry.quantity)

        if id and quantity then
            local saved = row.currencies[id]

            if type(saved) ~= "table" then
                saved = { changes = {} }
                row.currencies[id] = saved
            end

            saved.changes = type(saved.changes) == "table" and saved.changes or {}
            saved.name = entry.name or saved.name or ("Currency " .. id)

            local previous = currencySeen[id]

            if previous == nil then
                previous = tonumber(saved.quantity)
            end

            if previous ~= nil and quantity ~= previous then
                Account().Push(saved.changes, {
                    time = Now(),
                    delta = quantity - previous,
                    quantity = quantity,
                }, CHANGE_CAP)
            end

            saved.quantity = quantity
            currencySeen[id] = quantity
        end
    end
end

local function ReputationList()
    local reputations = ns.Data and ns.Data.Reputations

    if not reputations or type(reputations.Collect) ~= "function" then
        return {}
    end

    local ok, data = pcall(reputations.Collect, reputations)

    if not ok or type(data) ~= "table" then
        return {}
    end

    return data.entries or {}
end

local function SyncReputations()
    local row = Character()

    if not row or not ns:IsFeatureOn("ledger") then
        return
    end

    for _, entry in ipairs(ReputationList()) do
        local id = tonumber(entry.factionID) or entry.name

        if id and not entry.isHeader then
            local saved = row.reputations[id]

            if type(saved) ~= "table" then
                saved = { changes = {} }
                row.reputations[id] = saved
            end

            saved.changes = type(saved.changes) == "table" and saved.changes or {}
            saved.name = entry.name or saved.name or tostring(id)

            local value = tonumber(entry.value)
            local previous = reputationSeen[id]

            if previous == nil then
                previous = tonumber(saved.value)
            end

            if previous ~= nil and value ~= nil and value ~= previous then
                Account().Push(saved.changes, {
                    time = Now(),
                    delta = value - previous,
                    standing = entry.standing,
                    value = value,
                }, CHANGE_CAP)
            end

            saved.standing = entry.standing or saved.standing
            saved.value = value or saved.value
            saved.progress = entry.progress
            saved.nextStanding = entry.nextStanding

            if value ~= nil then
                reputationSeen[id] = value
            end
        end
    end
end

function Ledger:GoldRows(key, period)
    local rows = {}
    local keys = key and key ~= "all" and { key } or self:CharacterKeys()

    for _, character in ipairs(keys) do
        local record = self:Get(character)

        for _, entry in ipairs(record and record.gold or {}) do
            if InPeriod(entry.time, period) then
                table.insert(rows, {
                    character = character,
                    time = entry.time,
                    delta = entry.delta,
                    balance = entry.balance,
                    source = entry.source,
                    detail = entry.detail,
                })
            end
        end
    end

    table.sort(rows, function(a, b)
        return (a.time or 0) > (b.time or 0)
    end)

    return rows
end

function Ledger:Summary(key, period)
    local totals = {}

    for _, source in ipairs(Ledger.SOURCES) do
        totals[source] = { source = source, label = Ledger.SOURCE_LABELS[source], inn = 0, out = 0, net = 0 }
    end

    for _, row in ipairs(self:GoldRows(key, period)) do
        local slot = totals[row.source] or totals.other
        local delta = tonumber(row.delta) or 0

        if delta > 0 then
            slot.inn = slot.inn + delta
        else
            slot.out = slot.out + delta
        end

        slot.net = slot.net + delta
    end

    local lines = {}

    for _, source in ipairs(Ledger.SOURCES) do
        local slot = totals[source]

        if slot.inn ~= 0 or slot.out ~= 0 then
            table.insert(lines, slot)
        end
    end

    return lines
end

function Ledger:SaleRates(key)
    local counts = {}
    local since = Now() - SALE_DAYS

    for _, row in ipairs(self:GoldRows(key, "all")) do
        if row.source == "auction" and (tonumber(row.time) or 0) >= since then
            local item = type(row.detail) == "string" and row.detail or "Auction"
            local slot = counts[item] or { item = item, sold = 0, expired = 0 }
            local detail = string.lower(item)

            if string.find(detail, "expire", 1, true) or string.find(detail, "cancel", 1, true) then
                slot.expired = slot.expired + 1
            elseif (tonumber(row.delta) or 0) > 0 then
                slot.sold = slot.sold + 1
            end

            counts[item] = slot
        end
    end

    local lines = {}

    for _, slot in pairs(counts) do
        local attempts = slot.sold + slot.expired

        if attempts > 0 then
            slot.rate = math.floor((slot.sold * 100 / attempts) + 0.5)
            table.insert(lines, slot)
        end
    end

    table.sort(lines, function(a, b)
        return a.item < b.item
    end)

    return lines
end

function Ledger:CurrencyLines(key, period)
    local lines = {}
    local keys = key and key ~= "all" and { key } or self:CharacterKeys()
    local latest = key == "all" or key == nil

    for _, character in ipairs(keys) do
        local record = self:Get(character)

        for id, entry in pairs(record and record.currencies or {}) do
            local delta = 0

            for _, change in ipairs(entry.changes or {}) do
                if InPeriod(change.time, latest and "all" or period) then
                    delta = delta + (tonumber(change.delta) or 0)
                end
            end

            if latest or delta ~= 0 then
                table.insert(lines, {
                    character = character,
                    id = id,
                    name = entry.name or ("Currency " .. tostring(id)),
                    quantity = tonumber(entry.quantity) or 0,
                    delta = delta,
                })
            end
        end
    end

    table.sort(lines, function(a, b)
        if a.name ~= b.name then
            return a.name < b.name
        end

        return a.character < b.character
    end)

    return lines
end

function Ledger:ReputationLines(key, period)
    local lines = {}
    local keys = key and key ~= "all" and { key } or self:CharacterKeys()
    local latest = key == "all" or key == nil

    for _, character in ipairs(keys) do
        local record = self:Get(character)

        for id, entry in pairs(record and record.reputations or {}) do
            local delta = 0
            local standing = entry.standing
            local value = entry.value

            for _, change in ipairs(entry.changes or {}) do
                if InPeriod(change.time, latest and "all" or period) then
                    delta = delta + (tonumber(change.delta) or 0)
                    standing = change.standing or standing
                    value = change.value or value
                end
            end

            if latest or delta ~= 0 then
                local bar = ""

                if entry.progress and entry.nextStanding then
                    bar = string.format(" %s/%s", tostring(entry.progress), tostring(entry.nextStanding))
                elseif value then
                    bar = " " .. tostring(value)
                end

                table.insert(lines, {
                    character = character,
                    id = id,
                    name = entry.name or tostring(id),
                    standing = (standing or "Unknown") .. bar,
                    delta = delta,
                })
            end
        end
    end

    table.sort(lines, function(a, b)
        if a.name ~= b.name then
            return a.name < b.name
        end

        return a.character < b.character
    end)

    return lines
end

function Ledger:SessionLine()
    local summary = self:Summary(Account().CharacterKey(), "session")
    local parts = {}

    for _, slot in ipairs(summary) do
        if slot.net ~= 0 then
            table.insert(parts, slot.label .. " " .. Account().FormatGold(slot.net))
        end
    end

    local currencies = self:CurrencyLines(Account().CharacterKey(), "session")

    for index, line in ipairs(currencies) do
        if index > 3 then
            break
        end

        if line.delta ~= 0 then
            table.insert(parts, string.format("%s %+d", line.name, line.delta))
        end
    end

    if #parts == 0 then
        return nil
    end

    return "Ledger: " .. table.concat(parts, ", ")
end

function Ledger:ExportLines()
    local lines = { currencies = {}, reputations = {}, gold = {} }
    local key = Account().CharacterKey()

    for _, line in ipairs(self:CurrencyLines(key, "session")) do
        if line.delta ~= 0 then
            table.insert(lines.currencies, string.format("Session currency: %s %+d (now %d)", line.name, line.delta, line.quantity))
        end
    end

    for _, line in ipairs(self:ReputationLines(key, "session")) do
        if line.delta ~= 0 then
            table.insert(lines.reputations, string.format("Session reputation: %s %+d (%s)", line.name, line.delta, line.standing))
        end
    end

    local count = 0

    for _, row in ipairs(self:GoldRows(key, "session")) do
        count = count + 1

        if count > 10 then
            break
        end

        local detail = row.detail and (" " .. tostring(row.detail)) or ""
        table.insert(lines.gold, "Gold change: " .. Account().FormatGold(row.delta) .. " " .. (Ledger.SOURCE_LABELS[row.source] or row.source) .. detail)
    end

    return lines
end

local eventFrame = CreateFrame("Frame")
local registered = {}

local function Register(event)
    local ok, result = pcall(eventFrame.RegisterEvent, eventFrame, event)

    if ok and result ~= false then
        table.insert(registered, event)
    else
        table.insert(Ledger.refusedEvents, event)
    end
end

local function NoteChat(text)
    if type(text) ~= "string" then
        return
    end

    local lower = string.lower(text)

    if string.find(lower, "auction", 1, true) then
        Hint("auction", text)
    elseif string.find(lower, "you loot", 1, true) or string.find(lower, "you receive loot", 1, true) then
        Hint("loot", text)
    elseif string.find(lower, "quest", 1, true) then
        Hint("quest", text)
    end
end

function Ledger:SetFeatureActive(on)
    ns.Features.SetEvents(eventFrame, registered, on)

    if on then
        lastMoney = ReadMoney()
        SyncCurrencies()
        SyncReputations()
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if not ns:IsFeatureOn("ledger") then
        return
    end

    if event == "PLAYER_MONEY" then
        OnMoney()
    elseif event == "PLAYER_LOGIN" then
        lastMoney = ReadMoney()
        SyncCurrencies()
        SyncReputations()
    elseif event == "CURRENCY_DISPLAY_UPDATE" or event == "PLAYER_MONEY" then
        SyncCurrencies()
    elseif event == "UPDATE_FACTION" or event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        SyncReputations()
    elseif event == "CHAT_MSG_MONEY" or event == "CHAT_MSG_SYSTEM" or event == "CHAT_MSG_LOOT" then
        NoteChat(...)
    elseif event == "QUEST_TURNED_IN" then
        Hint("quest", nil)
    end
end)

Register("PLAYER_LOGIN")
Register("PLAYER_MONEY")
Register("CURRENCY_DISPLAY_UPDATE")
Register("UPDATE_FACTION")
Register("CHAT_MSG_COMBAT_FACTION_CHANGE")
Register("CHAT_MSG_MONEY")
Register("CHAT_MSG_SYSTEM")
Register("CHAT_MSG_LOOT")
Register("QUEST_TURNED_IN")

ns.Data = ns.Data or {}
ns.Data.Ledger = Ledger
ns:RegisterModule("Data.Ledger", Ledger)
