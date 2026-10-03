local _, ns = ...

local Mail = {}

local CAP = 500

Mail.refusedEvents = {}

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

local function Richness(letter)
    local score = 0

    if letter.who and letter.who ~= "" then
        score = score + 2
    end

    if letter.subject and letter.subject ~= "" then
        score = score + 4
    end

    if letter.items and letter.items ~= "" then
        score = score + 3 + #letter.items
    end

    if letter.body and letter.body ~= "" then
        score = score + 2
    end

    if (tonumber(letter.gold) or 0) > 0 then
        score = score + 1
    end

    return score
end

local function FillLetter(keep, extra)
    if (not keep.subject or keep.subject == "") and extra.subject and extra.subject ~= "" then
        keep.subject = extra.subject
    end

    if extra.items and extra.items ~= "" and #extra.items > #(keep.items or "") then
        keep.items = extra.items
    end

    if (not keep.body or keep.body == "") and extra.body and extra.body ~= "" then
        keep.body = extra.body
    end

    if (tonumber(keep.gold) or 0) == 0 and (tonumber(extra.gold) or 0) > 0 then
        keep.gold = extra.gold
    end

    if extra.status == "waiting" then
        keep.status = "waiting"
    end

    local keptTime = tonumber(keep.time) or 0
    local extraTime = tonumber(extra.time) or 0

    if extraTime > 0 and (keptTime == 0 or extraTime < keptTime) then
        keep.time = extraTime
    end
end

function Mail:Cleanup()
    local bucket = Bucket()

    if not bucket then
        return
    end

    for _, record in pairs(bucket) do
        if type(record) == "table" and type(record.letters) == "table" then
            local kept = {}

            for _, letter in ipairs(record.letters) do
                if type(letter) == "table" and ((letter.who and letter.who ~= "") or (letter.subject and letter.subject ~= "")) then
                    local merged = false

                    for _, other in ipairs(kept) do
                        local sameWho = (other.who or "") == (letter.who or "")
                        local sameDirection = (other.direction or "") == (letter.direction or "")
                        local subjectA = other.subject or ""
                        local subjectB = letter.subject or ""
                        local sameSubject = subjectA == subjectB or subjectA == "" or subjectB == ""
                        local close = math.abs((tonumber(other.time) or 0) - (tonumber(letter.time) or 0)) <= 180
                        local goldA = tonumber(other.gold) or 0
                        local goldB = tonumber(letter.gold) or 0
                        local sameGold = goldA == goldB or goldA == 0 or goldB == 0

                        if sameWho and sameDirection and sameSubject and close and sameGold then
                            if Richness(letter) > Richness(other) then
                                local waiting = other.status == "waiting" or letter.status == "waiting"
                                other.who = letter.who or other.who
                                other.subject = (letter.subject and letter.subject ~= "") and letter.subject or other.subject
                                other.items = (letter.items and letter.items ~= "") and letter.items or other.items
                                other.body = (letter.body and letter.body ~= "") and letter.body or other.body
                                other.gold = goldB > 0 and letter.gold or other.gold
                                other.status = waiting and "waiting" or (letter.status or other.status)
                                FillLetter(other, letter)
                            else
                                FillLetter(other, letter)
                            end

                            merged = true
                            break
                        end
                    end

                    if not merged then
                        table.insert(kept, letter)
                    end
                end
            end

            record.letters = kept
        end
    end
end

function Mail:Letters(key, direction, query)
    self:Cleanup()

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

    if (not letter.who or letter.who == "") and (not letter.subject or letter.subject == "") then
        return
    end

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

local function FindWaiting(letters, claimed, sender, subject, money)
    local loose = nil

    for _, letter in ipairs(letters) do
        if not claimed[letter] and letter.direction == "received" and letter.status == "waiting" and (letter.who or "") == sender then
            local savedSubject = letter.subject or ""
            local sameSubject = savedSubject == (subject or "") or savedSubject == ""

            if sameSubject then
                if savedSubject == (subject or "") and (tonumber(letter.gold) or 0) == (tonumber(money) or 0) then
                    return letter
                end

                loose = loose or letter
            end
        end
    end

    return loose
end

local function ReadInbox()
    if type(GetInboxNumItems) ~= "function" or type(GetInboxHeaderInfo) ~= "function" then
        return
    end

    Mail:Cleanup()

    local ok, count, total = pcall(GetInboxNumItems)

    if not ok or type(count) ~= "number" then
        return
    end

    if type(total) == "number" and count < total then
        return
    end

    local headers = {}
    local complete = true

    for index = 1, count do
        local success, _, _, sender, subject, money, _, daysLeft = pcall(GetInboxHeaderInfo, index)

        if not success or type(sender) ~= "string" or sender == "" or subject == nil then
            complete = false
        else
            table.insert(headers, {
                sender = sender,
                subject = subject,
                money = tonumber(money) or 0,
                daysLeft = tonumber(daysLeft),
                items = ItemList(index),
            })
        end
    end

    if not complete then
        return
    end

    local row = Character()

    if not row then
        return
    end

    local claimed = {}
    local waiting = {}

    for _, header in ipairs(headers) do
        local existing = FindWaiting(row.letters, claimed, header.sender, header.subject, header.money)

        if existing then
            claimed[existing] = true
            existing.who = header.sender
            existing.subject = header.subject
            existing.daysLeft = header.daysLeft
            existing.gold = header.money

            if header.items ~= "" then
                existing.items = header.items
            end
        else
            Remember({
                direction = "received",
                time = Account().Now(),
                who = header.sender,
                subject = header.subject,
                gold = header.money,
                items = header.items,
                daysLeft = header.daysLeft,
                status = "waiting",
            })
            claimed[row.letters[1]] = true
        end

        waiting[header.sender .. "|" .. (header.subject or "")] = true
    end

    for _, letter in ipairs(row.letters) do
        if letter.direction == "received" and letter.status == "waiting" then
            local id = (letter.who or "") .. "|" .. (letter.subject or "")

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

    if type(who) ~= "string" or who == "" then
        return
    end

    local row = Character()
    local now = Account().Now()
    local itemText = table.concat(items, ", ")

    for _, letter in ipairs(row and row.letters or {}) do
        if letter.direction == "sent" and letter.who == who and (letter.subject or "") == (subject or "")
            and math.abs((tonumber(letter.time) or 0) - now) <= 10
        then
            letter.body = body or letter.body
            letter.gold = tonumber(money) or letter.gold
            letter.items = itemText ~= "" and itemText or letter.items
            return
        end
    end

    Remember({
        direction = "sent",
        time = now,
        who = who,
        subject = subject,
        body = body,
        gold = tonumber(money) or 0,
        items = itemText,
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
        Mail:Cleanup()
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
