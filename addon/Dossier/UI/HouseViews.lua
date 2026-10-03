local _, ns = ...

local function Account()
    return ns.Account
end

local function Gold(copper)
    return Account().Coins(copper)
end

local function CurrencyIcon(id)
    local texture = nil

    if C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, tonumber(id))

        if ok and type(info) == "table" then
            texture = info.iconFileID
        end
    end

    if not texture and type(GetCurrencyInfo) == "function" then
        local ok, _, _, icon = pcall(GetCurrencyInfo, tonumber(id))

        if ok then
            texture = icon
        end
    end

    if not texture or texture == "" then
        return ""
    end

    return string.format("|T%s:14:14:0:0|t ", texture)
end

local function DeltaColor(delta)
    delta = tonumber(delta) or 0

    if delta > 0 then
        return "|cff7dffb3+" .. tostring(delta) .. "|r"
    end

    if delta < 0 then
        return "|cffff6b61" .. tostring(delta) .. "|r"
    end

    return "|cff8d9aa30|r"
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
            return nil
        end

        local blocks = { { kind = "heading", text = "Where the gold went" } }

        for _, row in ipairs(rows) do
            table.insert(blocks, {
                kind = "line",
                text = string.format("%s|cffffd36b%s|r    in %s    out %s    net %s", ns.Theme.ColorCode("accent"), row.label, Gold(row.inn), Gold(row.out), Gold(row.net)),
            })
        end

        return blocks
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

    if count == 0 and #lines == 0 then
        return nil
    end

    return table.concat(lines, "\n")
end

local function LedgerBlocks(state)
    if state.source == "summary" then
        local summary = LedgerText(state)

        if type(summary) == "table" then
            return summary
        end

        return {
            { kind = "heading", text = "|cff8d9aa3Example for Flann, until a real gold change is saved|r" },
            { kind = "line", text = string.format("|cff3ec7d1Questing|r    in %s    out %s    net %s", Gold(125000), Gold(0), Gold(125000)) },
            { kind = "line", text = string.format("|cff3ec7d1Vendors|r    in %s    out %s    net %s", Gold(48000), Gold(32000), Gold(16000)) },
            { kind = "line", text = string.format("|cff3ec7d1Auction House|r    in %s    out %s    net %s", Gold(250000), Gold(40000), Gold(210000)) },
            { kind = "line", text = string.format("|cff3ec7d1Looting|r    in %s    out %s    net %s", Gold(8600), Gold(0), Gold(8600)) },
        }
    end

    local text = LedgerText(state)

    if not text or text == "" then
        return { { kind = "line", text = "|cff8d9aa3No entries for this character in this period.|r" } }
    end

    return { { kind = "line", text = text } }
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
        blocks = LedgerBlocks,
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
        blocks = function(state)
            local rows = ns.Data.Ledger:CurrencyLines(state.character, state.period)
            local blocks = {}
            local current = nil

            if #rows == 0 then
                return { { kind = "line", text = "|cff8d9aa3No currencies saved for this period.|r" } }
            end

            for _, row in ipairs(rows) do
                if row.name ~= current then
                    current = row.name
                    table.insert(blocks, { kind = "heading", text = CurrencyIcon(row.id) .. row.name })
                end

                table.insert(blocks, {
                    kind = "line",
                    text = string.format("%s    %s    |cffffd36b%d|r", row.character, DeltaColor(row.delta), row.quantity),
                })
            end

            return blocks
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
        blocks = function(state)
            local rows = ns.Data.Ledger:ReputationLines(state.character, state.period)
            local blocks = {}
            local current = nil

            if #rows == 0 then
                return { { kind = "line", text = "|cff8d9aa3No reputation saved for this period.|r" } }
            end

            for _, row in ipairs(rows) do
                if row.name ~= current then
                    current = row.name
                    table.insert(blocks, { kind = "heading", text = row.name })
                end

                local standing = row.standingName or row.standing or "Unknown"
                local right = standing

                if row.progress and row.maximum then
                    right = string.format("%s  %d/%d", standing, row.progress, row.maximum)
                end

                if row.delta ~= 0 then
                    right = DeltaColor(row.delta) .. "   " .. right
                end

                table.insert(blocks, {
                    kind = "bar",
                    label = row.character,
                    value = row.progress or 0,
                    max = row.maximum or 1,
                    color = standing,
                    right = right,
                })
            end

            return blocks
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
        blocks = function(state)
            local rows = ns.Data.Mail:Letters(state.character, direction, state.query or "")
            local blocks = {}

            for _, letter in ipairs(rows) do
                local way = letter.direction == "sent" and "To" or "From"
                local status = letter.status or ""
                local statusColor = status == "waiting" and "|cff7dffb3" or "|cff8d9aa3"

                table.insert(blocks, {
                    kind = "heading",
                    text = string.format("|cffffd36b%s %s|r    %s%s|r", way, letter.who or "someone", statusColor, status),
                })

                local bits = { "|cff8d9aa3" .. When(letter.time) .. "|r" }

                if (tonumber(letter.gold) or 0) ~= 0 then
                    table.insert(bits, Gold(letter.gold))
                end

                if letter.items and letter.items ~= "" then
                    table.insert(bits, "|cff7ee0e6" .. letter.items .. "|r")
                end

                table.insert(blocks, { kind = "line", text = table.concat(bits, "    ") })

                if letter.subject and letter.subject ~= "" then
                    table.insert(blocks, { kind = "line", text = letter.subject })
                end
            end

            if #blocks == 0 then
                return { { kind = "line", text = "|cff8d9aa3No mail recorded yet.|r" } }
            end

            return blocks
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
        blocks = function(state)
            local blocks = {}

            for _, row in ipairs(ns.Data.ProfessionBoard:Rows()) do
                if state.character == "all" or state.character == row.character then
                    table.insert(blocks, { kind = "heading", text = "|cffffd36b" .. row.character .. "|r" })

                    if #(row.skills or {}) == 0 then
                        table.insert(blocks, { kind = "line", text = "|cff8d9aa3No skills saved yet.|r" })
                    end

                    for _, skill in ipairs(row.skills or {}) do
                        local max = tonumber(skill.max) or 0
                        table.insert(blocks, {
                            kind = "bar",
                            label = skill.name,
                            right = max > 0 and (skill.current .. " / " .. max) or tostring(skill.current),
                            value = skill.current,
                            max = max > 0 and max or 1,
                            color = "Honored",
                        })
                    end
                end
            end

            if #blocks == 0 then
                return { { kind = "line", text = "|cff8d9aa3No profession skills saved yet. Open the character skills window once, then check again.|r" } }
            end

            return blocks
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
        blocks = function()
            local bucket = ns.Account.Bucket("rares") or {}
            local rows = {}

            for _, rare in pairs(bucket) do
                if type(rare) == "table" then
                    table.insert(rows, rare)
                end
            end

            table.sort(rows, function(a, b)
                return (a.kills or 0) > (b.kills or 0)
            end)

            local blocks = {}

            for _, rare in ipairs(rows) do
                local place = rare.zone or "Unknown zone"

                if rare.x and rare.y then
                    place = string.format("%s  %.1f, %.1f", place, rare.x, rare.y)
                end

                local kills = tonumber(rare.kills) or 0
                local times = kills == 1 and "1 kill" or (kills .. " kills")

                table.insert(blocks, {
                    kind = "heading",
                    text = string.format("|cffffd36b%s|r    |cffffcc66%s|r", rare.name or "Rare", times),
                })
                table.insert(blocks, {
                    kind = "line",
                    text = string.format("|cff7ee0e6%s|r    |cff8d9aa3%s|r", place, rare.character or ""),
                })

                local drops = {}

                for _, item in ipairs(rare.loot or {}) do
                    if type(item) == "string" and item ~= "" then
                        table.insert(drops, item)
                    end
                end

                table.insert(blocks, {
                    kind = "line",
                    text = #drops == 0 and "|cff8d9aa3No drops recorded yet.|r" or "|cffb7e3a1" .. table.concat(drops, ", ") .. "|r",
                })
            end

            if #blocks == 0 then
                return { { kind = "line", text = "|cff8d9aa3No rares recorded yet. A rare kill is added here, with its kill count.|r" } }
            end

            return blocks
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
        blocks = function(state)
            local bucket = ns.Account.Bucket("sessions") or {}
            local keys = state.character == "all" and ns.Account.Keys(bucket) or { state.character }
            local blocks = {}

            for _, key in ipairs(keys) do
                local history = bucket[key] or {}
                local show = state.character == "all" and { history[1] } or history

                if history[1] then
                    table.insert(blocks, { kind = "heading", text = key })
                end

                for _, entry in ipairs(show) do
                    if type(entry) == "table" then
                        local duration = ns.Data.Session and ns.Data.Session.FormatDuration and ns.Data.Session.FormatDuration(entry.seconds) or ""
                        table.insert(blocks, {
                            kind = "line",
                            text = string.format(
                                "|cffd4b15a%s|r   |cff7ee0e6%s|r   |cffffd36b%s|r   %s   |cff9ec5ff%s XP|r",
                                When(entry.start),
                                entry.zone or "",
                                duration,
                                Gold(entry.gold or 0),
                                tostring(entry.xp or 0)
                            ),
                        })
                    end
                end
            end

            if #blocks == 0 then
                return { { kind = "line", text = "|cff8d9aa3No finished sessions yet.|r" } }
            end

            return blocks
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
    local nameBox = CreateFrame("EditBox", nil, page, Theme.BACKDROP_TEMPLATE)
    nameBox:SetSize(180, 22)
    nameBox:SetPoint("TOPLEFT", 190, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetFontObject(ChatFontNormal)
    nameBox:SetTextInsets(6, 6, 0, 0)
    Theme.ApplyBackdrop(nameBox, "dark", "border")

    local placeholder = Theme.CreateText(nameBox, "GameFontHighlightSmall", "disabled")
    placeholder:SetPoint("LEFT", 7, 0)
    placeholder:SetText("Task name")

    local repeatKind = "daily"
    local kindButton = Theme.CreateButton(page, "Daily", 70, 22, "default", function(self)
        if repeatKind == "daily" then
            repeatKind = "weekly"
        elseif repeatKind == "weekly" then
            repeatKind = "once"
        else
            repeatKind = "daily"
        end

        self:SetLabel(repeatKind:gsub("^%l", string.upper))
    end)
    kindButton:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)

    local function AddTask()
        local name = (nameBox:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")

        if name == "" or not ns.Data.Tasks then
            return
        end

        ns.Data.Tasks:Add(name, repeatKind, ns.Account.Zone(), "task")
        nameBox:SetText("")
        nameBox:ClearFocus()
        TasksView.state.refresh()
    end

    nameBox:SetScript("OnTextChanged", function(self)
        placeholder:SetShown((self:GetText() or "") == "")
    end)
    nameBox:SetScript("OnEnterPressed", AddTask)
    nameBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local add = Theme.CreateButton(page, "Add", 50, 22, "primary", AddTask)
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
local questCache = { at = 0, data = nil }
local questTitlesHooked = false

local function CompletedQuestData()
    local now = type(GetTime) == "function" and GetTime() or 0

    if questCache.data and (now - questCache.at) < 3 then
        return questCache.data
    end

    local completed = ns.Data and ns.Data.CompletedQuests

    if not completed or type(completed.Collect) ~= "function" then
        return nil
    end

    local ok, data = pcall(completed.Collect, completed)

    if not ok or type(data) ~= "table" then
        return nil
    end

    questCache.at = now
    questCache.data = data

    if not questTitlesHooked and type(completed.OnTitlesReady) == "function" then
        questTitlesHooked = true
        completed:OnTitlesReady(function()
            questCache.at = 0

            if QuestHistoryView.state then
                QuestHistoryView.state.refresh()
            end
        end)
    end

    return data
end

function QuestHistoryView:Build(page)
    self.state = ns.UI.HouseList.Build(page, {
        search = true,
        keys = function()
            return {}
        end,
        blocks = function(state)
            local data = CompletedQuestData()
            local blocks = {}
            local needle = string.lower(state.query or "")
            local seen = {}
            local titles = {}

            for _, quest in ipairs(data and data.resolvedQuests or {}) do
                local title = type(quest) == "table" and quest.title or nil

                if type(title) == "string" and title ~= "" and not quest.tracking then
                    local key = string.lower(title)

                    if not seen[key] and (needle == "" or string.find(key, needle, 1, true)) then
                        seen[key] = true
                        table.insert(titles, title)
                    end
                end
            end

            table.sort(titles)

            local count = data and tonumber(data.count) or #titles
            local who = ns.Account.CharacterKey() or "This character"
            table.insert(blocks, {
                kind = "heading",
                text = string.format("|cffffd36b%s|r    |cff8d9aa3%d finished|r", who, count or 0),
            })

            for _, title in ipairs(titles) do
                table.insert(blocks, { kind = "line", text = title })
            end

            local unnamed = data and tonumber(data.unresolvedCount) or 0

            if unnamed and unnamed > 0 then
                table.insert(blocks, {
                    kind = "line",
                    text = string.format("|cff8d9aa3%d finished quests are still waiting for a name.|r", unnamed),
                })
            end

            if #titles == 0 and (not unnamed or unnamed == 0) then
                return { { kind = "line", text = "|cff8d9aa3No completed quests in the export list yet.|r" } }
            end

            return blocks
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
