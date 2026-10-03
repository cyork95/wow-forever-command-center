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

local function RunDuration(seconds)
    local session = ns.Data and ns.Data.Session

    if session and type(session.FormatDuration) == "function" then
        return session.FormatDuration(seconds)
    end

    seconds = tonumber(seconds) or 0

    if seconds < 0 then
        seconds = 0
    end

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)

    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    end

    return string.format("%dm", minutes)
end

function LockoutsView:Build(page)
    self.state = ns.UI.HouseList.Build(page, {
        keys = function()
            return ns.Data.Runs:CharacterKeys()
        end,
        blocks = function(state)
            local blocks = { { kind = "heading", text = "Saved now" } }
            local groups = {}
            local order = {}

            for _, entry in ipairs(ns.Data.Runs:SavedLines()) do
                if state.character == "all" or state.character == entry.character then
                    if not groups[entry.character] then
                        groups[entry.character] = {}
                        table.insert(order, entry.character)
                    end

                    table.insert(groups[entry.character], entry)
                end
            end

            if #order == 0 then
                table.insert(blocks, { kind = "line", text = "|cff8d9aa3No saved instances.|r" })
            end

            for _, character in ipairs(order) do
                if state.character == "all" then
                    table.insert(blocks, { kind = "line", text = "|cffd4b15a" .. character .. "|r" })
                end

                for _, entry in ipairs(groups[character]) do
                    local progress = tonumber(entry.progress) or 0
                    local encounters = tonumber(entry.encounters) or 0
                    local done = encounters > 0 and progress >= encounters
                    local notes = {}

                    if entry.difficulty and entry.difficulty ~= "" then
                        table.insert(notes, entry.difficulty)
                    end

                    if entry.resetText and entry.resetText ~= "" then
                        table.insert(notes, entry.resetText)
                    end

                    table.insert(blocks, {
                        kind = "bar",
                        label = entry.name or "Instance",
                        note = table.concat(notes, "   "),
                        right = encounters > 0 and string.format("%d/%d", progress, encounters) or "",
                        value = progress,
                        max = encounters > 0 and encounters or 1,
                        color = done and { 0.45, 0.78, 0.42 } or { 0.86, 0.64, 0.28 },
                    })
                end
            end

            table.insert(blocks, { kind = "heading", text = "Recent runs" })

            local runs = ns.Data.Runs:RunLines(state.character)

            if #runs == 0 then
                table.insert(blocks, { kind = "line", text = "|cff8d9aa3No instance runs yet.|r" })
            end

            for _, run in ipairs(runs) do
                local details = { "|cffd4b15a" .. When(run.entered) .. "|r" }

                if run.levelFrom and run.levelTo and run.levelTo ~= run.levelFrom then
                    table.insert(details, string.format("|cff9ec5ff%s to %s|r", tostring(run.levelFrom), tostring(run.levelTo)))
                end

                if tonumber(run.gold) and tonumber(run.gold) ~= 0 then
                    table.insert(details, Gold(run.gold))
                end

                if tonumber(run.mobs) and tonumber(run.mobs) > 0 then
                    table.insert(details, string.format("|cffff8a7a%s kills|r", tostring(run.mobs)))
                end

                if state.character == "all" and run.character and run.character ~= "" then
                    table.insert(details, "|cff8d9aa3" .. run.character .. "|r")
                end

                table.insert(blocks, {
                    kind = "line",
                    text = string.format("|cff7ee0e6%s|r    |cffffd36b%s|r", run.name or "Instance", RunDuration(run.seconds)),
                })
                table.insert(blocks, { kind = "line", text = table.concat(details, "    ") })
            end

            return blocks
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
    local repeatKind = "daily"
    local editing = nil
    local character = ns.Account.CharacterKey()
    local cards = {}

    local characterButton = Theme.CreateButton(page, character or "This character", 200, 22, "default", function()
        local keys = ns.Data.Tasks and ns.Data.Tasks:CharacterKeys() or {}
        local nextIndex = 1

        for index, key in ipairs(keys) do
            if key == character then
                nextIndex = index + 1
            end
        end

        character = keys[nextIndex] or keys[1] or character
        editing = nil
        TasksView:Refresh()
    end)
    characterButton:SetPoint("TOPLEFT", 0, 0)

    local C = ns.constants
    local panelCard = Theme.CreateCard(page, C.TEXT.TASK_PANEL_CARD)
    panelCard:SetPoint("TOPLEFT", 0, -28)
    panelCard:SetPoint("RIGHT", 0, 0)
    panelCard:SetHeight(96)

    local showBox = Theme.CreateCheckbox(panelCard, C.TEXT.TASK_SHOW_PANEL, function(self)
        local panel = ns.UI and ns.UI.TrackerWindow

        if panel then
            panel:SetShown(self:GetChecked() == true)
        end
    end)
    showBox:SetPoint("TOPLEFT", 10, -26)

    local zoneBox = Theme.CreateCheckbox(panelCard, C.TEXT.TASK_OPEN_ZONE, function(self)
        local panel = ns.UI and ns.UI.TrackerWindow

        if panel then
            panel:SetAutoOpen(self:GetChecked() == true)
        end
    end)
    zoneBox:SetPoint("TOPLEFT", 220, -26)

    local lineBoxes = {}

    for index, key in ipairs(C.TASK_PANEL_LINES) do
        local lineKey = key
        local box = Theme.CreateCheckbox(panelCard, C.TASK_PANEL_LINE_LABELS[key], function(self)
            local panel = ns.UI and ns.UI.TrackerWindow

            if panel then
                panel:SetLine(lineKey, self:GetChecked() == true)
            end
        end)
        box:SetPoint("TOPLEFT", 10 + (index - 1) * 128, -48)
        lineBoxes[key] = box
    end

    local opacityLabel = Theme.CreateText(panelCard, "GameFontHighlightSmall", "text")
    opacityLabel:SetPoint("BOTTOMLEFT", 10, 10)
    opacityLabel:SetText(C.TEXT.KILLS_PANEL_OPACITY)

    local opacityValue = Theme.CreateText(panelCard, "GameFontHighlightSmall", "muted")
    local opacitySlider = Theme.CreateSlider(panelCard, 90, 0, 100, 5, function(_, value)
        opacityValue:SetText(string.format(C.TEXT.KILLS_PANEL_OPACITY_VALUE, value))
        local panel = ns.UI and ns.UI.TrackerWindow

        if panel and panel:GetOpacity() ~= value then
            panel:SetOpacity(value)
        end
    end)
    opacitySlider:SetPoint("BOTTOMLEFT", 130, 12)
    opacityValue:SetPoint("LEFT", opacitySlider, "RIGHT", 8, 0)

    local nameBox = CreateFrame("EditBox", nil, page, Theme.BACKDROP_TEMPLATE)
    nameBox:SetSize(280, 36)
    nameBox:SetPoint("TOPLEFT", 0, -132)
    nameBox:SetAutoFocus(false)
    nameBox:SetMultiLine(true)
    nameBox:SetFontObject(ChatFontNormal)
    nameBox:SetTextInsets(8, 8, 6, 6)
    nameBox:SetMaxLetters(400)
    Theme.ApplyBackdrop(nameBox, "dark", "border")

    local placeholder = Theme.CreateText(nameBox, "GameFontHighlightSmall", "disabled")
    placeholder:SetPoint("TOPLEFT", 8, -8)
    placeholder:SetText("What do you need to do?")

    local kindButton = Theme.CreateButton(page, "Each day", 110, 22, "default", function(self)
        if repeatKind == "daily" then
            repeatKind = "weekly"
        elseif repeatKind == "weekly" then
            repeatKind = "monthly"
        elseif repeatKind == "monthly" then
            repeatKind = "yearly"
        elseif repeatKind == "yearly" then
            repeatKind = "once"
        else
            repeatKind = "daily"
        end

        local labels = {
            weekly = "Each week",
            monthly = "Each month",
            yearly = "Each year",
            once = "Just once",
        }

        self:SetLabel(labels[repeatKind] or "Each day")
    end)
    kindButton:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)

    local add = Theme.CreateButton(page, "Add task", 84, 22, "primary", function()
        TasksView:Commit()
    end)
    add:SetPoint("LEFT", kindButton, "RIGHT", 8, 0)

    local box = Theme.CreatePanel(page, "dark", "border")
    box:SetPoint("TOPLEFT", 0, -176)
    box:SetPoint("BOTTOMRIGHT", 0, 0)

    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    local empty = Theme.CreateText(content, "GameFontHighlightSmall", "muted")
    empty:SetPoint("TOPLEFT", 8, -8)
    empty:SetJustifyH("LEFT")

    local function Trim(value)
        return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    end

    local function CadenceLabel(kind)
        if kind == "weekly" then
            return "Each week"
        end

        if kind == "monthly" then
            return "Each month"
        end

        if kind == "yearly" then
            return "Each year"
        end

        if kind == "once" then
            return "Just once"
        end

        return "Each day"
    end

    local function LayoutComposer()
        characterButton:SetLabel(character or "This character")
        kindButton:SetLabel(CadenceLabel(repeatKind))
        placeholder:SetText(editing and "Change this task" or "What do you need to do?")
        add:SetLabel(editing and "Save" or "Add task")
        placeholder:SetShown(Trim(nameBox:GetText()) == "")
    end

    local function TakeCard(index)
        local card = cards[index]

        if card then
            card:Show()
            return card
        end

        card = CreateFrame("Frame", nil, content, Theme.BACKDROP_TEMPLATE)
        Theme.ApplyBackdrop(card, "card", "border")
        card.title = Theme.CreateText(card, "GameFontHighlight", "text")
        card.title:SetJustifyH("LEFT")
        card.title:SetJustifyV("TOP")
        card.detail = Theme.CreateText(card, "GameFontHighlightSmall", "muted")
        card.detail:SetJustifyH("LEFT")
        card.done = Theme.CreateButton(card, "Done today", 132, 20, "primary", function() end)
        card.edit = Theme.CreateButton(card, "Edit", 46, 20, "default", function() end)
        card.delete = Theme.CreateButton(card, "Delete", 56, 20, "default", function() end)
        cards[index] = card

        return card
    end

    function TasksView:Commit()
        local tasks = ns.Data and ns.Data.Tasks
        local text = Trim(nameBox:GetText())

        if text == "" or not tasks or not character then
            return
        end

        if editing then
            tasks:Update(editing, character, text, repeatKind)
        else
            local zone = character == ns.Account.CharacterKey() and ns.Account.Zone() or nil
            tasks:Add(text, repeatKind, zone, "task", character)
        end

        editing = nil
        nameBox:SetText("")
        nameBox:ClearFocus()
        TasksView:Refresh()
    end

    nameBox:SetScript("OnTextChanged", function()
        placeholder:SetShown(Trim(nameBox:GetText()) == "")
    end)
    nameBox:SetScript("OnEnterPressed", function()
        TasksView:Commit()
    end)
    nameBox:SetScript("OnEscapePressed", function(self)
        editing = nil
        self:SetText("")
        self:ClearFocus()
        LayoutComposer()
    end)

    function TasksView:Refresh()
        local tasks = ns.Data and ns.Data.Tasks

        if not character then
            character = ns.Account.CharacterKey()
        end

        LayoutComposer()

        local width = (scroll:GetWidth() or 0) - 12

        if width < 240 then
            width = 420
        end

        local y = 4
        local count = 0

        if not tasks or not character then
            empty:SetText("Log in on a character to write tasks.")
            empty:Show()
        else
            local rows = tasks:All(character)

            if #rows == 0 then
                empty:SetText("Nothing waiting. Add a task above.")
                empty:Show()
            else
                empty:Hide()
            end

            for _, task in ipairs(rows) do
                count = count + 1
                local card = TakeCard(count)
                local taskIndex = task.index
                local taskName = task.name
                local taskKind = task.repeatKind
                local open = task.open ~= false
                card.done:Show()
                card.edit:Show()
                card.delete:Show()
                card.detail:Show()
                card.title:SetWordWrap(false)
                card.title:SetText((open and "|cff7ee0e6" or "|cff8d9aa3") .. (taskName or "") .. "|r")
                local place = task.zone and task.zone ~= "" and ("  |cff8d9aa3" .. task.zone .. "|r") or ""
                card.detail:SetText((open and "|cffffd36b" or "|cff8d9aa3") .. tasks:Status(task) .. "|r  |cff8d9aa3" .. tasks:Cadence(task) .. "|r" .. place)
                card.done:SetLabel(tasks:DoneLabel(task))
                card.title:ClearAllPoints()
                card.title:SetPoint("TOPLEFT", 10, -8)
                card.title:SetPoint("RIGHT", card.delete, "LEFT", -8, 0)
                card.detail:ClearAllPoints()
                card.detail:SetPoint("BOTTOMLEFT", 10, 8)
                card.detail:SetPoint("RIGHT", card.delete, "LEFT", -8, 0)
                card.done:ClearAllPoints()
                card.done:SetPoint("TOPRIGHT", -8, -8)
                card.edit:ClearAllPoints()
                card.edit:SetPoint("RIGHT", card.done, "LEFT", -4, 0)
                card.delete:ClearAllPoints()
                card.delete:SetPoint("RIGHT", card.edit, "LEFT", -4, 0)
                card.done:SetScript("OnClick", function()
                    tasks:SetDone(taskIndex, character, open)
                    TasksView:Refresh()
                end)
                card.edit:SetScript("OnClick", function()
                    editing = taskIndex
                    repeatKind = taskKind or "daily"
                    nameBox:SetText(taskName or "")
                    nameBox:SetFocus()
                    LayoutComposer()
                end)
                card.delete:SetScript("OnClick", function()
                    tasks:Remove(taskIndex, character)
                    if editing == taskIndex then
                        editing = nil
                        nameBox:SetText("")
                    end
                    TasksView:Refresh()
                end)
                card:SetWidth(width)
                card:SetHeight(52)
                card:ClearAllPoints()
                card:SetPoint("TOPLEFT", 4, -y)
                y = y + 60
            end
        end

        for index = count + 1, #cards do
            cards[index]:Hide()
        end

        content:SetWidth(width)
        content:SetHeight(math.max(y + 8, scroll:GetHeight() or 1))

        if type(scroll.UpdateScrollChildRect) == "function" then
            scroll:UpdateScrollChildRect()
        end

        local panel = ns.UI and ns.UI.TrackerWindow

        if panel then
            showBox:SetChecked(panel:IsEnabled())
            zoneBox:SetChecked(panel:IsAutoOpen())

            for key, lineBox in pairs(lineBoxes) do
                lineBox:SetChecked(panel:IsLineOn(key))
            end

            local opacity = panel:GetOpacity()
            opacitySlider:SetValue(opacity)
            opacityValue:SetText(string.format(C.TEXT.KILLS_PANEL_OPACITY_VALUE, opacity))
        end
    end

    self.state = { refresh = function()
        TasksView:Refresh()
    end }

    page:SetScript("OnShow", function()
        TasksView:Refresh()
    end)

    TasksView:Refresh()
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

local NotesView = {}

function NotesView:Build(page)
    local Theme = ns.Theme
    local editing = nil
    local character = ns.Account.CharacterKey()
    local cards = {}

    local characterButton = Theme.CreateButton(page, character or "This character", 200, 22, "default", function()
        local keys = ns.Data.Tasks and ns.Data.Tasks:CharacterKeys() or {}
        local nextIndex = 1

        for index, key in ipairs(keys) do
            if key == character then
                nextIndex = index + 1
            end
        end

        character = keys[nextIndex] or keys[1] or character
        editing = nil
        NotesView:Refresh()
    end)
    characterButton:SetPoint("TOPLEFT", 0, 0)

    local titleBox = CreateFrame("EditBox", nil, page, Theme.BACKDROP_TEMPLATE)
    titleBox:SetSize(280, 22)
    titleBox:SetPoint("TOPLEFT", 0, -30)
    titleBox:SetAutoFocus(false)
    titleBox:SetFontObject(ChatFontNormal)
    titleBox:SetTextInsets(8, 8, 0, 0)
    titleBox:SetMaxLetters(80)
    Theme.ApplyBackdrop(titleBox, "card", "accent")

    local titlePlaceholder = Theme.CreateText(titleBox, "GameFontHighlightSmall", "disabled")
    titlePlaceholder:SetPoint("LEFT", 8, 0)
    titlePlaceholder:SetText("Title")

    local add = Theme.CreateButton(page, "Add note", 84, 22, "primary", function()
        NotesView:Commit()
    end)
    add:SetPoint("LEFT", titleBox, "RIGHT", 8, 0)

    local noteBox = CreateFrame("EditBox", nil, page, Theme.BACKDROP_TEMPLATE)
    noteBox:SetHeight(72)
    noteBox:SetPoint("TOPLEFT", 0, -58)
    noteBox:SetPoint("RIGHT", 0, 0)
    noteBox:SetAutoFocus(false)
    noteBox:SetMultiLine(true)
    noteBox:SetFontObject(ChatFontNormal)
    noteBox:SetTextInsets(8, 8, 8, 8)
    noteBox:SetMaxLetters(4000)
    Theme.ApplyBackdrop(noteBox, "card", "accent")

    local placeholder = Theme.CreateText(noteBox, "GameFontHighlightSmall", "disabled")
    placeholder:SetPoint("TOPLEFT", 8, -8)
    placeholder:SetText("Write the note")

    local box = Theme.CreatePanel(page, "dark", "border")
    box:SetPoint("TOPLEFT", 0, -138)
    box:SetPoint("BOTTOMRIGHT", 0, 0)

    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    local empty = Theme.CreateText(content, "GameFontHighlightSmall", "muted")
    empty:SetPoint("TOPLEFT", 8, -8)
    empty:SetJustifyH("LEFT")

    local function Trim(value)
        return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    end

    local function LayoutComposer()
        characterButton:SetLabel(character or "This character")
        titlePlaceholder:SetText(editing and "Change the title" or "Title")
        placeholder:SetText(editing and "Change the note" or "Write the note")
        add:SetLabel(editing and "Save" or "Add note")
        titlePlaceholder:SetShown(Trim(titleBox:GetText()) == "")
        placeholder:SetShown(Trim(noteBox:GetText()) == "")
    end

    local function TakeCard(index)
        local card = cards[index]

        if card then
            card:Show()
            return card
        end

        card = CreateFrame("Frame", nil, content, Theme.BACKDROP_TEMPLATE)
        Theme.ApplyBackdrop(card, "card", "border")
        card.title = Theme.CreateText(card, "GameFontHighlight", "text")
        card.title:SetJustifyH("LEFT")
        card.title:SetJustifyV("TOP")
        card.title:SetWordWrap(true)
        card.body = Theme.CreateText(card, "GameFontHighlightSmall", "text")
        card.body:SetJustifyH("LEFT")
        card.body:SetJustifyV("TOP")
        card.body:SetWordWrap(true)
        card.edit = Theme.CreateButton(card, "Edit", 46, 20, "default", function() end)
        card.delete = Theme.CreateButton(card, "Delete", 56, 20, "default", function() end)
        cards[index] = card

        return card
    end

    function NotesView:Commit()
        local tasks = ns.Data and ns.Data.Tasks
        local title = Trim(titleBox:GetText())
        local text = Trim(noteBox:GetText())

        if title == "" or not tasks or not character then
            return
        end

        if editing then
            tasks:UpdateNote(editing, title, text, character)
        else
            tasks:AddNote(title, text, character)
        end

        editing = nil
        titleBox:SetText("")
        noteBox:SetText("")
        noteBox:ClearFocus()
        NotesView:Refresh()
    end

    titleBox:SetScript("OnTextChanged", function()
        titlePlaceholder:SetShown(Trim(titleBox:GetText()) == "")
    end)
    titleBox:SetScript("OnEnterPressed", function()
        noteBox:SetFocus()
    end)
    titleBox:SetScript("OnEscapePressed", function(self)
        editing = nil
        self:SetText("")
        noteBox:SetText("")
        self:ClearFocus()
        LayoutComposer()
    end)
    noteBox:SetScript("OnTextChanged", function()
        placeholder:SetShown(Trim(noteBox:GetText()) == "")
    end)
    noteBox:SetScript("OnEscapePressed", function(self)
        editing = nil
        titleBox:SetText("")
        self:SetText("")
        self:ClearFocus()
        LayoutComposer()
    end)

    function NotesView:Refresh()
        local tasks = ns.Data and ns.Data.Tasks

        if not character then
            character = ns.Account.CharacterKey()
        end

        LayoutComposer()

        local width = (scroll:GetWidth() or 0) - 12

        if width < 240 then
            width = 420
        end

        local columnWidth = math.floor((width - 12) / 2)
        local y = 4
        local count = 0
        local rowHeight = 0
        local notes = tasks and character and tasks:Notes(character) or {}

        if not tasks or not character then
            empty:SetText("Log in on a character to write notes.")
            empty:Show()
        elseif #notes == 0 then
            empty:SetText("No notes yet. Add a title and a note above.")
            empty:Show()
        else
            empty:Hide()
        end

        for _, note in ipairs(notes) do
            count = count + 1
            local card = TakeCard(count)
            local noteIndex = note.index
            local noteTitle = note.title ~= "" and note.title or "Note"
            local noteText = note.text or ""
            local column = (count - 1) % 2
            local textWidth = columnWidth - 20
            card:SetWidth(columnWidth)
            card.title:SetWidth(textWidth - 110)
            card.title:SetText("|cffffd36b" .. noteTitle .. "|r")
            card.body:SetWidth(textWidth)
            card.body:SetText(noteText ~= "" and ("|cffe7d7b1" .. noteText .. "|r") or "")
            card.body:SetShown(noteText ~= "")
            card.title:ClearAllPoints()
            card.title:SetPoint("TOPLEFT", 10, -8)
            card.body:ClearAllPoints()
            card.body:SetPoint("TOPLEFT", 10, -((card.title:GetStringHeight() or 16) + 14))
            card.body:SetPoint("RIGHT", -10, 0)
            card.edit:ClearAllPoints()
            card.edit:SetPoint("TOPRIGHT", -8, -6)
            card.delete:ClearAllPoints()
            card.delete:SetPoint("RIGHT", card.edit, "LEFT", -4, 0)
            card.edit:SetScript("OnClick", function()
                editing = noteIndex
                titleBox:SetText(note.title or "")
                noteBox:SetText(noteText)
                titleBox:SetFocus()
                LayoutComposer()
            end)
            card.delete:SetScript("OnClick", function()
                tasks:RemoveNote(noteIndex, character)
                if editing == noteIndex then
                    editing = nil
                    titleBox:SetText("")
                    noteBox:SetText("")
                end
                NotesView:Refresh()
            end)
            local function BlockHeight(fontString, plain, lineHeight)
                local measured = fontString:GetStringHeight() or 0

                if measured > 4 then
                    return measured
                end

                if plain == "" then
                    return 0
                end

                local perLine = math.max(8, math.floor(fontString:GetWidth() / 7))
                local lines = 0

                for paragraph in (plain .. "\n"):gmatch("([^\n]*)\n") do
                    lines = lines + math.max(1, math.ceil(math.max(#paragraph, 1) / perLine))
                end

                return lines * lineHeight
            end

            local bodyHeight = noteText ~= "" and BlockHeight(card.body, noteText, 14) or 0
            local height = 16 + BlockHeight(card.title, noteTitle, 16) + bodyHeight + 16
            card:SetHeight(math.max(44, height))
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", 4 + column * (columnWidth + 8), -y)

            if column == 0 then
                rowHeight = card:GetHeight()
            else
                y = y + math.max(rowHeight, card:GetHeight()) + 8
                rowHeight = 0
            end
        end

        if count % 2 == 1 then
            y = y + rowHeight + 8
        end

        for index = count + 1, #cards do
            cards[index]:Hide()
        end

        content:SetHeight(math.max(y + 8, 40))
        content:SetWidth(width)
    end
end

function NotesView:Refresh()
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
ns.UI.NotesView = NotesView
ns.UI.QuestHistoryView = QuestHistoryView
