local _, ns = ...

local function Account()
    return ns.Account
end

local function Gold(copper)
    return Account().FormatGold(copper)
end

local function When(timestamp)
    return Account().FormatWhen(timestamp)
end

local PERIODS = {
    { id = "session", label = "This session" },
    { id = "today", label = "Today" },
    { id = "week", label = "Last 7 days" },
    { id = "all", label = "All" },
}

local SOURCES = {
    { id = "summary", label = "Summary" },
    { id = "auction", label = "Auction House" },
    { id = "vendor", label = "Vendors" },
    { id = "quest", label = "Questing" },
    { id = "loot", label = "Looting" },
    { id = "mail", label = "Mail" },
    { id = "trade", label = "Trades" },
    { id = "other", label = "Other" },
}

local function LedgerText(state)
    local ledger = ns.Data and ns.Data.Ledger

    if not ledger then
        return "Ledger is not ready yet."
    end

    local key = state.character
    local lines = {}

    if state.source == "summary" then
        local rows = ledger:Summary(key, state.period)

        if #rows == 0 then
            return "No entries for this character in this period."
        end

        table.insert(lines, "Source          In            Out           Net")

        for _, row in ipairs(rows) do
            table.insert(lines, string.format("%-16s %-13s %-13s %s", row.label, Gold(row.inn), Gold(row.out), Gold(row.net)))
        end

        return table.concat(lines, "\n")
    end

    if state.source == "auction" then
        for _, rate in ipairs(ledger:SaleRates(key)) do
            table.insert(lines, string.format("%s    sold %d    expired %d    %d%%", rate.item, rate.sold, rate.expired, rate.rate))
        end

        if #lines > 0 then
            table.insert(lines, "")
        end
    end

    local count = 0

    for _, row in ipairs(ledger:GoldRows(key, state.period)) do
        if row.source == state.source then
            count = count + 1
            local who = key == "all" and (row.character .. "  ") or ""
            local detail = row.detail and ("  " .. tostring(row.detail)) or ""
            table.insert(lines, string.format("%s%s  %s%s", who, When(row.time), Gold(row.delta), detail))
        end
    end

    if count == 0 then
        return "No entries for this character in this period."
    end

    return table.concat(lines, "\n")
end

local function Grouped(lines, groupKey, lineText)
    local current = nil
    local text = {}

    for _, row in ipairs(lines) do
        if row[groupKey] ~= current then
            current = row[groupKey]
            table.insert(text, current)
        end

        table.insert(text, "  " .. lineText(row))
    end

    if #text == 0 then
        return "No entries for this character in this period."
    end

    return table.concat(text, "\n")
end

local LedgerView = {}

function LedgerView:Build(page)
    self.state = ns.UI.HouseList.Build(page, {
        periods = PERIODS,
        sources = SOURCES,
        period = "all",
        source = "summary",
        keys = function()
            return ns.Data.Ledger:CharacterKeys()
        end,
        text = LedgerText,
    })
end

function LedgerView:Refresh()
    if self.state then
        self.state.refresh()
    end
end

local CurrenciesView = {}

function CurrenciesView:Build(page)
    self.state = ns.UI.HouseList.Build(page, {
        periods = PERIODS,
        keys = function()
            return ns.Data.Ledger:CharacterKeys()
        end,
        text = function(state)
            local rows = ns.Data.Ledger:CurrencyLines(state.character, state.period)

            return Grouped(rows, "name", function(row)
                local delta = row.delta ~= 0 and string.format(" %+d", row.delta) or ""
                return string.format("%s%s    now %d", row.character, delta, row.quantity)
            end)
        end,
    })
end

function CurrenciesView:Refresh()
    if self.state then
        self.state.refresh()
    end
end

local ReputationView = {}

function ReputationView:Build(page)
    self.state = ns.UI.HouseList.Build(page, {
        periods = PERIODS,
        keys = function()
            return ns.Data.Ledger:CharacterKeys()
        end,
        text = function(state)
            local rows = ns.Data.Ledger:ReputationLines(state.character, state.period)

            return Grouped(rows, "name", function(row)
                local delta = row.delta ~= 0 and string.format("%+d  ", row.delta) or ""
                return string.format("%s%s%s", row.character, delta ~= "" and ("  " .. delta) or "  ", row.standing)
            end)
        end,
    })
end

function ReputationView:Refresh()
    if self.state then
        self.state.refresh()
    end
end

local MailView = {}

function MailView:Build(page)
    local Theme = ns.Theme
    local direction = "all"
    local buttons = {}

    for index, choice in ipairs({
        { id = "all", label = "All" },
        { id = "received", label = "Received" },
        { id = "sent", label = "Sent" },
    }) do
        local button = Theme.CreateButton(page, choice.label, 80, 22, "default", function()
            direction = choice.id
            MailView.state.refresh()
        end)
        button:SetPoint("TOPLEFT", 196 + ((index - 1) * 84), 0)
        buttons[choice.id] = button
    end

    self.state = ns.UI.HouseList.Build(page, {
        search = true,
        keys = function()
            return ns.Data.Mail:CharacterKeys()
        end,
        text = function(state)
            local rows = ns.Data.Mail:Letters(state.character, direction, state.query or "")

            if #rows == 0 then
                return "No mail recorded yet."
            end

            local lines = {}

            for _, letter in ipairs(rows) do
                local way = letter.direction == "sent" and "to" or "from"
                local items = letter.items and letter.items ~= "" and ("  " .. letter.items) or ""
                table.insert(lines, string.format(
                    "%s  %s %s  %s%s  %s",
                    When(letter.time),
                    way,
                    letter.who or "someone",
                    Gold(letter.gold or 0),
                    items,
                    letter.status or ""
                ))

                if letter.subject and letter.subject ~= "" then
                    table.insert(lines, "  " .. letter.subject)
                end

                if letter.body and letter.body ~= "" then
                    table.insert(lines, "  " .. letter.body)
                end
            end

            return table.concat(lines, "\n")
        end,
    })
end

function MailView:Refresh()
    if self.state then
        self.state.refresh()
    end
end

local ProfessionsView = {}

function ProfessionsView:Build(page)
    self.state = ns.UI.HouseList.Build(page, {
        keys = function()
            local rows = ns.Data.ProfessionBoard:Rows()
            local keys = {}

            for _, row in ipairs(rows) do
                table.insert(keys, row.character)
            end

            return keys
        end,
        text = function(state)
            local lines = {}

            for _, row in ipairs(ns.Data.ProfessionBoard:Rows()) do
                if state.character == "all" or state.character == row.character then
                    local bits = {}

                    for _, skill in ipairs(row.skills) do
                        local max = skill.max and skill.max > 0 and ("/" .. skill.max) or ""
                        table.insert(bits, skill.name .. " " .. skill.current .. max)
                    end

                    table.insert(lines, row.character)
                    table.insert(lines, "  " .. (#bits > 0 and table.concat(bits, "   ") or "No skills saved yet."))
                end
            end

            if #lines == 0 then
                return "No profession skills saved yet. Log in on a character to record them."
            end

            return table.concat(lines, "\n")
        end,
    })
end

function ProfessionsView:Refresh()
    if self.state then
        self.state.refresh()
    end
end

local RaresView = {}

function RaresView:Build(page)
    self.state = ns.UI.HouseList.Build(page, {
        keys = function()
            return {}
        end,
        footer = true,
        text = function()
            local bucket = ns.Account.Bucket("rares") or {}
            local lines = {}
            local rows = {}

            for _, rare in pairs(bucket) do
                if type(rare) == "table" then
                    table.insert(rows, rare)
                end
            end

            table.sort(rows, function(a, b)
                return (a.time or 0) > (b.time or 0)
            end)

            for _, rare in ipairs(rows) do
                local place = rare.zone or "Unknown zone"

                if rare.x and rare.y then
                    place = string.format("%s %.1f, %.1f", place, rare.x, rare.y)
                end

                table.insert(lines, string.format("%s    %d    %s    %s", rare.name or "Rare", rare.kills or 0, place, rare.character or ""))

                local drops = {}

                for _, item in ipairs(rare.loot or {}) do
                    if type(item) == "string" and item ~= "" then
                        table.insert(drops, item)
                    end
                end

                if #drops == 0 then
                    table.insert(lines, "  No drops recorded yet.")
                else
                    table.insert(lines, "  " .. table.concat(drops, ", "))
                end

                for index, pin in ipairs(rare.pins or {}) do
                    if index > 1 then
                        local pinPlace = pin.zone or ""

                        if pin.x and pin.y then
                            pinPlace = string.format("%s %.1f, %.1f", pinPlace, pin.x, pin.y)
                        end

                        table.insert(lines, "  earlier  " .. When(pin.time) .. "  " .. pinPlace .. "  " .. (pin.character or ""))
                    end
                end
            end

            if #lines == 0 then
                return "No rares recorded yet."
            end

            return table.concat(lines, "\n")
        end,
    })

    local button = ns.Theme.CreateButton(page, "Track latest", 110, 22, "default", function()
        local bucket = ns.Account.Bucket("rares") or {}
        local tasks = ns.Data and ns.Data.Tasks
        local newest = nil

        if not tasks then
            return
        end

        for _, rare in pairs(bucket) do
            if type(rare) == "table" and rare.name and (not newest or (rare.time or 0) > (newest.time or 0)) then
                newest = rare
            end
        end

        if newest then
            tasks:Add(newest.name, "once", newest.zone, "rare")
            local view = ns.UI and ns.UI.TasksView

            if view and view.Refresh then
                view:Refresh()
            end
        end
    end)
    button:SetPoint("BOTTOMLEFT", 0, 0)
end

function RaresView:Refresh()
    if self.state then
        self.state.refresh()
    end
end

local LockoutsView = {}

function LockoutsView:Build(page)
    self.state = ns.UI.HouseList.Build(page, {
        keys = function()
            return ns.Data.Runs:CharacterKeys()
        end,
        text = function(state)
            local lines = { "Saved now" }
            local saved = ns.Data.Runs:SavedLines()

            if #saved == 0 then
                table.insert(lines, "  No saved instances.")
            end

            for _, entry in ipairs(saved) do
                if state.character == "all" or state.character == entry.character then
                    table.insert(lines, string.format(
                        "  %s    %s    %s/%s    %s",
                        entry.character,
                        entry.difficulty or "",
                        tostring(entry.progress or 0),
                        tostring(entry.encounters or 0),
                        entry.resetText or ""
                    ))
                    table.insert(lines, "  " .. entry.name)
                end
            end

            table.insert(lines, "")
            table.insert(lines, "Recent runs")

            local runs = ns.Data.Runs:RunLines(state.character)

            if #runs == 0 then
                table.insert(lines, "  No instance runs yet.")
            end

            for _, run in ipairs(runs) do
                local levels = ""

                if run.levelFrom and run.levelTo and run.levelTo ~= run.levelFrom then
                    levels = string.format("  level %s to %s", tostring(run.levelFrom), tostring(run.levelTo))
                end

                table.insert(lines, string.format(
                    "%s  %s  %s%s  %s",
                    When(run.entered),
                    run.name or "Instance",
                        ns.Data.Session and ns.Data.Session.FormatDuration and ns.Data.Session.FormatDuration(run.seconds) or "",
                    levels,
                    run.gold and Gold(run.gold) or ""
                ))
            end

            return table.concat(lines, "\n")
        end,
    })
end

function LockoutsView:Refresh()
    if self.state then
        self.state.refresh()
    end
end

local SessionsView = {}

function SessionsView:Build(page)
    self.state = ns.UI.HouseList.Build(page, {
        keys = function()
            return ns.Account.Keys(ns.Account.Bucket("sessions"))
        end,
        text = function(state)
            local bucket = ns.Account.Bucket("sessions") or {}
            local lines = {}
            local keys = state.character == "all" and ns.Data.Runs and ns.Account.Keys(bucket) or { state.character }

            if state.character ~= "all" then
                keys = { state.character }
            end

            for _, key in ipairs(keys) do
                local history = bucket[key] or {}
                local show = state.character == "all" and { history[1] } or history

                if history[1] then
                    table.insert(lines, key)
                end

                for _, entry in ipairs(show) do
                    if type(entry) == "table" then
                        table.insert(lines, string.format(
                            "  %s  %s  %s  %s  %s XP",
                            When(entry.start),
                            entry.zone or "",
                            ns.Data.Session and ns.Data.Session.FormatDuration and ns.Data.Session.FormatDuration(entry.seconds) or "",
                            Gold(entry.gold or 0),
                            tostring(entry.xp or 0)
                        ))
                    end
                end
            end

            if #lines == 0 then
                return "No finished sessions yet."
            end

            return table.concat(lines, "\n")
        end,
    })
end

function SessionsView:Refresh()
    if self.state then
        self.state.refresh()
    end
end

local TasksView = {}

function TasksView:Build(page)
    local Theme = ns.Theme
    local nameBox = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    nameBox:SetSize(160, 20)
    nameBox:SetPoint("TOPLEFT", 190, -2)
    nameBox:SetAutoFocus(false)

    local repeatKind = "daily"
    local kindButton = Theme.CreateButton(page, "Daily", 70, 22, "default", function(self)
        if repeatKind == "daily" then
            repeatKind = "weekly"
        elseif repeatKind == "weekly" then
            repeatKind = "once"
        else
            repeatKind = "daily"
        end

        self:SetText(repeatKind:gsub("^%l", string.upper))
    end)
    kindButton:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)

    local add = Theme.CreateButton(page, "Add", 50, 22, "default", function()
        ns.Data.Tasks:Add(nameBox:GetText(), repeatKind, ns.Account.Zone(), "task")
        nameBox:SetText("")
        TasksView.state.refresh()
    end)
    add:SetPoint("LEFT", kindButton, "RIGHT", 8, 0)

    self.state = ns.UI.HouseList.Build(page, {
        keys = function()
            return ns.Data.Tasks:CharacterKeys()
        end,
        text = function(state)
            local rows = state.character == "all" and ns.Data.Tasks:Open("all") or ns.Data.Tasks:All(state.character)
            local lines = {}
            local character = nil

            for _, task in ipairs(rows) do
                if task.character and task.character ~= character then
                    character = task.character
                    table.insert(lines, character)
                end

                table.insert(lines, string.format("  %s  %s  %s  %s", task.name, task.repeatKind or "once", task.zone or "", task.open == false and "done" or "open"))
            end

            if #lines == 0 then
                return "No tasks yet."
            end

            return table.concat(lines, "\n")
        end,
    })
end

function TasksView:Refresh()
    if self.state then
        self.state.refresh()
    end
end

local QuestHistoryView = {}

function QuestHistoryView:Build(page)
    local Theme = ns.Theme
    local areaOnly = false
    local areaButton = Theme.CreateButton(page, "All zones", 100, 22, "default", function(self)
        areaOnly = not areaOnly
        self:SetText(areaOnly and "This area" or "All zones")
        QuestHistoryView.state.refresh()
    end)
    areaButton:SetPoint("TOPLEFT", 190, 0)

    self.state = ns.UI.HouseList.Build(page, {
        keys = function()
            return ns.Data.QuestHistory:CharacterKeys()
        end,
        text = function(state)
            local zone = areaOnly and ns.Account.Zone() or nil
            local rows = ns.Data.QuestHistory:List(state.character, zone, "")

            if #rows == 0 then
                return areaOnly and "No quests turned in here yet." or "No completed quests yet."
            end

            return Grouped(rows, "zone", function(row)
                local when = row.time and ("  " .. When(row.time)) or ""
                local who = state.character == "all" and ("  " .. row.character) or ""
                return row.title .. when .. who
            end)
        end,
    })
end

function QuestHistoryView:Refresh()
    if self.state then
        self.state.refresh()
    end
end

ns.UI = ns.UI or {}
ns.UI.LedgerView = LedgerView
ns.UI.CurrenciesView = CurrenciesView
ns.UI.ReputationView = ReputationView
ns.UI.MailView = MailView
ns.UI.ProfessionsView = ProfessionsView
ns.UI.RaresView = RaresView
ns.UI.LockoutsView = LockoutsView
ns.UI.SessionsView = SessionsView
ns.UI.TasksView = TasksView
ns.UI.QuestHistoryView = QuestHistoryView
