local _, ns = ...

local Mail = {}

local CAP = 500

Mail.refusedEvents = {}

local seen = {}

local function Account()
    return ns.Account
end

local function Bucket()
    return Account().Bucket("mail")
end

local function Character()
    local bucket = Bucket()
    local key = Account().CharacterKey()

    if not bucket or not key then
        return nil, nil
    end

    local row = bucket[key]

    if type(row) ~= "table" then
        row = { letters = {} }
        bucket[key] = row
    end

    row.letters = type(row.letters) == "table" and row.letters or {}

    return row, key
end

function Mail:CharacterKeys()
    local keys = Account().Keys(Bucket())
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

function Mail:Letters(key, direction, query)
    local keys = key and key ~= "all" and { key } or self:CharacterKeys()
    local rows = {}
    local needle = type(query) == "string" and string.lower(query) or ""

    for _, character in ipairs(keys) do
        local record = Bucket() and Bucket()[character]

        for _, letter in ipairs(record and record.letters or {}) do
            local matchesDirection = not direction or direction == "all" or letter.direction == direction
            local blob = string.lower(table.concat({
                letter.who or "",
                letter.subject or "",
                letter.body or "",
                letter.items or "",
            }, " "))
            local matchesQuery = needle == "" or string.find(blob, needle, 1, true)

            if matchesDirection and matchesQuery then
                table.insert(rows, letter)
            end
        end
    end

    table.sort(rows, function(a, b)
        return (a.time or 0) > (b.time or 0)
    end)

    return rows
end

local function Remember(letter)
    local row = Character()

    if not row then
        return
    end

    local id = table.concat({
        letter.direction or "",
        tostring(letter.time or 0),
        letter.who or "",
        letter.subject or "",
        letter.items or "",
    }, "|")

    if seen[id] then
        return
    end

    seen[id] = true
    letter.character = Account().CharacterKey()
    Account().Push(row.letters, letter, CAP)
end

local function ItemList(index)
    local names = {}

    if type(GetInboxItem) ~= "function" then
        return ""
    end

    for slot = 1, 12 do
        local ok, name, _, count = pcall(GetInboxItem, index, slot)

        if ok and type(name) == "string" and name ~= "" then
            table.insert(names, string.format("[%s] x%s", name, tostring(count or 1)))
        end
    end

    return table.concat(names, ", ")
end

local function ReadInbox()
    if type(GetInboxNumItems) ~= "function" or type(GetInboxHeaderInfo) ~= "function" then
        return
    end

    local ok, count = pcall(GetInboxNumItems)

    if not ok or type(count) ~= "number" then
        return
    end

    local waiting = {}

    for index = 1, count do
        local success, _, _, sender, subject, money, _, daysLeft = pcall(GetInboxHeaderInfo, index)

        if success then
            local items = ItemList(index)
            local stamp = table.concat({ sender or "", subject or "", items }, "|")
            local row = Character()
            local existing = nil

            for _, letter in ipairs(row and row.letters or {}) do
                if letter.direction == "received" and letter.status == "waiting"
                    and letter.who == sender and letter.subject == subject and letter.items == items
                then
                    existing = letter
                    break
                end
            end

            if existing then
                existing.daysLeft = tonumber(daysLeft)
                existing.gold = tonumber(money) or existing.gold
            else
                Remember({
                    direction = "received",
                    time = Account().Now(),
                    who = sender,
                    subject = subject,
                    gold = tonumber(money) or 0,
                    items = items,
                    daysLeft = tonumber(daysLeft),
                    status = "waiting",
                })
            end

            waiting[stamp] = true
        end
    end

    local row = Character()

    for _, letter in ipairs(row and row.letters or {}) do
        if letter.direction == "received" and letter.status == "waiting" then
            local id = table.concat({ letter.who or "", letter.subject or "", letter.items or "" }, "|")

            if not waiting[id] then
                letter.status = "taken"
            end
        end
    end
end

local function ReadSent()
    local who = type(SendMailNameEditBox) == "table" and SendMailNameEditBox.GetText and SendMailNameEditBox:GetText() or nil
    local subject = type(SendMailSubjectEditBox) == "table" and SendMailSubjectEditBox.GetText and SendMailSubjectEditBox:GetText() or nil
    local body = type(SendMailBodyEditBox) == "table" and SendMailBodyEditBox.GetText and SendMailBodyEditBox:GetText() or nil
    local money = type(GetSendMailMoney) == "function" and GetSendMailMoney() or 0
    local items = {}

    if type(GetSendMailItem) == "function" then
        for slot = 1, 12 do
            local ok, name, _, count = pcall(GetSendMailItem, slot)

            if ok and type(name) == "string" and name ~= "" then
                table.insert(items, string.format("[%s] x%s", name, tostring(count or 1)))
            end
        end
    end

    Remember({
        direction = "sent",
        time = Account().Now(),
        who = who,
        subject = subject,
        body = body,
        gold = tonumber(money) or 0,
        items = table.concat(items, ", "),
        status = "sent",
    })
end

function Mail:Expiring()
    local names = {}

    for _, key in ipairs(self:CharacterKeys()) do
        local record = Bucket() and Bucket()[key]

        for _, letter in ipairs(record and record.letters or {}) do
            if letter.status == "waiting" and tonumber(letter.daysLeft) and letter.daysLeft <= 1 then
                names[key] = true
            end
        end
    end

    local list = {}

    for name in pairs(names) do
        table.insert(list, name)
    end

    table.sort(list)

    return list
end

function Mail:TryImportParcel()
    local row = Character()

    if not row or row.importedFrom or #row.letters > 0 or type(ParcelDB) ~= "table" then
        return
    end

    local source = ParcelDB.history or ParcelDB.mail or ParcelDB.mails

    if type(source) ~= "table" then
        return
    end

    local copied = 0

    for _, entry in pairs(source) do
        if type(entry) == "table" and (entry.sender or entry.recipient or entry.subject) then
            Remember({
                direction = entry.sent and "sent" or "received",
                time = tonumber(entry.time or entry.timestamp) or Account().Now(),
                who = entry.sender or entry.recipient or entry.who,
                subject = entry.subject,
                body = entry.body,
                gold = tonumber(entry.money or entry.gold) or 0,
                items = type(entry.item) == "string" and entry.item or nil,
                status = "taken",
            })
            copied = copied + 1
        end
    end

    if copied > 0 then
        row.importedFrom = "Parcel"
    end
end

local eventFrame = CreateFrame("Frame")
local registered = {}

local function Register(event)
    local ok, result = pcall(eventFrame.RegisterEvent, eventFrame, event)

    if ok and result ~= false then
        table.insert(registered, event)
    else
        table.insert(Mail.refusedEvents, event)
    end
end

function Mail:SetFeatureActive(on)
    ns.Features.SetEvents(eventFrame, registered, on)
end

eventFrame:SetScript("OnEvent", function(_, event)
    if not ns:IsFeatureOn("mail") then
        return
    end

    if event == "MAIL_SHOW" or event == "MAIL_INBOX_UPDATE" then
        ReadInbox()
    elseif event == "MAIL_SEND_SUCCESS" then
        ReadSent()
    elseif event == "PLAYER_LOGIN" then
        Mail:TryImportParcel()

        local expiring = Mail:Expiring()

        if #expiring > 0 and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("Dossier: mail expires soon for " .. table.concat(expiring, ", "))
        end
    end
end)

Register("PLAYER_LOGIN")
Register("MAIL_SHOW")
Register("MAIL_INBOX_UPDATE")
Register("MAIL_SEND_SUCCESS")

ns.Data = ns.Data or {}
ns.Data.Mail = Mail
ns:RegisterModule("Data.Mail", Mail)
