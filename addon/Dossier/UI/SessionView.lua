local _, ns = ...

local C = ns.constants

local SessionView = {}

SessionView.container = nil
SessionView.lineBoxes = {}
SessionView.categoryBoxes = {}

local COLUMN_WIDTH = 268
local RIGHT_X = 280
local ROW_HEIGHT = 22
local REFRESH_SECONDS = 1

local function GetSession()
    return ns.Data and ns.Data.Session
end

local function GetPanel()
    return ns.UI and ns.UI.KillPanel
end

function SessionView.SummaryText(summary)
    local session = GetSession()

    if not session then
        return ""
    end

    local count = session.FormatCount
    local lines = {}

    if ns:IsFeatureOn("kills") then
        table.insert(lines, string.format(C.TEXT.SESSION_LINE_KILLS, count(summary.kills), count(summary.killsPerHour)))
    end

    table.insert(lines, string.format(C.TEXT.SESSION_LINE_GATHERED, count(summary.gathered), count(summary.gatheredPerHour)))
    table.insert(lines, string.format(C.TEXT.SESSION_LINE_GOLD, session.FormatGold(summary.gold), session.FormatGold(summary.goldPerHour)))
    table.insert(lines, string.format(C.TEXT.SESSION_LINE_XP, count(summary.xp), count(summary.xpPerHour)))

    if summary.timeToLevel then
        table.insert(lines, string.format(C.TEXT.SESSION_TIME_TO_LEVEL, session.FormatDuration(summary.timeToLevel)))
    end

    if summary.levels > 0 then
        table.insert(lines, string.format(C.TEXT.SESSION_LEVELS, summary.levels))
    end

    return table.concat(lines, "\n")
end

function SessionView.ItemsText(summary)
    local session = GetSession()

    if not session or #summary.items == 0 then
        return C.TEXT.SESSION_TOOLTIP_EMPTY
    end

    local lines = {}

    for _, item in ipairs(summary.items) do
        table.insert(lines, string.format(
            "%s  %s  (%s/hr, %s)",
            item.name or "Unknown item",
            session.FormatCount(item.count),
            session.FormatCount(item.perHour),
            C.SESSION_CATEGORY_LABELS[item.type] or item.type or ""
        ))
    end

    return table.concat(lines, "\n")
end

-- Sep 29, 18:00  1h 23m, Westfall
--   45 kills, 120 gathered, gold +1g 20s 0c, 12,345 XP
function SessionView.HistoryText(history)
    local session = GetSession()

    if not session or #history == 0 then
        return C.TEXT.SESSION_HISTORY_EMPTY
    end

    local accent = ns.Theme.ColorCode("accent")
    local lines = {}

    for _, entry in ipairs(history) do
        local when = type(date) == "function" and date("%b %d, %H:%M", tonumber(entry.start) or 0) or tostring(entry.start)
        local header = when .. "  " .. session.FormatDuration(entry.seconds)

        if entry.zone then
            header = header .. ", " .. entry.zone
        end

        local counts = {}

        if (entry.kills or 0) > 0 then
            table.insert(counts, session.FormatCount(entry.kills) .. " kills")
        end

        if (entry.gathered or 0) > 0 then
            table.insert(counts, session.FormatCount(entry.gathered) .. " gathered")
        end

        if (entry.gold or 0) ~= 0 then
            table.insert(counts, "gold " .. session.FormatGold(entry.gold))
        end

        if (entry.xp or 0) > 0 then
            table.insert(counts, session.FormatCount(entry.xp) .. " XP")
        end

        if (entry.levels or 0) > 0 then
            table.insert(counts, entry.levels == 1 and "1 level" or (entry.levels .. " levels"))
        end

        table.insert(lines, accent .. header .. "|r")
        table.insert(lines, "  " .. (#counts > 0 and table.concat(counts, ", ") or C.TEXT.SESSION_HISTORY_NOTHING))
    end

    return table.concat(lines, "\n")
end

-- Setting a scroll box's text scrolls it back to the top, so skip the once-a-second
-- refresh when nothing changed.
local function SetBoxText(box, text)
    if box.shownText ~= text then
        box.shownText = text
        box:SetText(text)
    end
end

local function AddCheckboxGrid(card, keys, labels, columns, width, top, boxes, onClick)
    for index, key in ipairs(keys) do
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        local box = ns.Theme.CreateCheckbox(card, labels[key], function(self)
            onClick(key, self:GetChecked() == true)
        end)
        box:SetPoint("TOPLEFT", 10 + column * width, top - row * ROW_HEIGHT)
        boxes[key] = box
    end
end

function SessionView:Build(parent)
    if self.container then
        return self.container
    end

    local Theme = ns.Theme
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints()

    local clock = Theme.CreateText(container, "GameFontNormalLarge", "accent")
    clock:SetPoint("TOPLEFT", 0, -2)

    local status = Theme.CreateText(container, "GameFontHighlightSmall", "muted")
    status:SetPoint("LEFT", clock, "RIGHT", 10, 0)

    local reset = Theme.CreateButton(container, C.TEXT.SESSION_RESET, 80, 22, "default", function()
        local panel = GetPanel()

        if panel then
            panel:ConfirmReset()
        end
    end)
    reset:SetPoint("TOPRIGHT", 0, 0)

    local toggle = Theme.CreateButton(container, C.TEXT.SESSION_PAUSE, 100, 22, "primary", function()
        local session = GetSession()

        if session then
            session:Toggle()
            SessionView:Refresh()
        end
    end)
    toggle:SetPoint("RIGHT", reset, "LEFT", -6, 0)

    local summaryCard = Theme.CreateCard(container, C.TEXT.SESSION_THIS_SESSION)
    summaryCard:SetPoint("TOPLEFT", 0, -34)
    summaryCard:SetSize(COLUMN_WIDTH, 132)

    local summaryText = Theme.CreateText(summaryCard, "GameFontHighlightSmall", "text")
    summaryText:SetPoint("TOPLEFT", 10, -28)
    summaryText:SetWidth(COLUMN_WIDTH - 20)
    summaryText:SetSpacing(3)

    local itemsTitle = Theme.CreateText(container, "GameFontNormalSmall", "accent")
    itemsTitle:SetPoint("TOPLEFT", summaryCard, "BOTTOMLEFT", 0, -12)
    itemsTitle:SetText(string.upper(C.TEXT.SESSION_TOOLTIP_TITLE))

    local items = Theme.CreateScrollText(container, "DossierSessionItemsScrollFrame", "GameFontHighlightSmall")
    items:SetPoint("TOPLEFT", itemsTitle, "BOTTOMLEFT", 0, -6)
    items:SetSize(COLUMN_WIDTH, 100)

    local historyTitle = Theme.CreateText(container, "GameFontNormalSmall", "accent")
    historyTitle:SetPoint("TOPLEFT", items, "BOTTOMLEFT", 0, -10)
    historyTitle:SetText(string.upper(C.TEXT.SESSION_HISTORY_TITLE))

    local history = Theme.CreateScrollText(container, "DossierSessionHistoryScrollFrame", "GameFontHighlightSmall")
    history:SetPoint("TOPLEFT", historyTitle, "BOTTOMLEFT", 0, -6)
    history:SetPoint("BOTTOMLEFT", 0, 0)
    history:SetWidth(COLUMN_WIDTH)

    local panelCard = Theme.CreateCard(container, C.TEXT.SESSION_PANEL_CARD)
    panelCard:SetPoint("TOPLEFT", RIGHT_X, -34)
    panelCard:SetSize(COLUMN_WIDTH, 30 + 4 * ROW_HEIGHT + 34)

    local panelToggle = Theme.CreateCheckbox(panelCard, C.TEXT.KILLS_SHOW_PANEL, function(self)
        local panel = GetPanel()

        if panel then
            panel:SetShown(self:GetChecked() == true)
        end
    end)
    panelToggle:SetPoint("TOPLEFT", 10, -28)

    AddCheckboxGrid(panelCard, C.SESSION_PANEL_LINES, C.SESSION_PANEL_LINE_LABELS, 2, 124, -28 - ROW_HEIGHT, self.lineBoxes, function(key, checked)
        local panel = GetPanel()

        if panel then
            panel:SetLine(key, checked)
        end
    end)

    local opacityLabel = Theme.CreateText(panelCard, "GameFontHighlightSmall", "text")
    opacityLabel:SetPoint("BOTTOMLEFT", 10, 12)
    opacityLabel:SetText(C.TEXT.KILLS_PANEL_OPACITY)

    local opacityValue = Theme.CreateText(panelCard, "GameFontHighlightSmall", "muted")

    local opacitySlider = Theme.CreateSlider(panelCard, 90, 0, 100, 5, function(_, value)
        opacityValue:SetText(string.format(C.TEXT.KILLS_PANEL_OPACITY_VALUE, value))

        local panel = GetPanel()

        if panel and panel:GetOpacity() ~= value then
            panel:SetOpacity(value)
        end
    end)
    opacitySlider:SetPoint("BOTTOMLEFT", 120, 14)
    opacityValue:SetPoint("LEFT", opacitySlider, "RIGHT", 8, 0)

    local session = GetSession()
    local categoryKeys = {}

    for _, category in ipairs(session and session.CATEGORIES or {}) do
        table.insert(categoryKeys, category.key)
    end

    local rows = math.ceil(#categoryKeys / 2)
    local categoryCard = Theme.CreateCard(container, C.TEXT.SESSION_CATEGORIES)
    categoryCard:SetPoint("TOPLEFT", panelCard, "BOTTOMLEFT", 0, -12)
    categoryCard:SetSize(COLUMN_WIDTH, 30 + rows * ROW_HEIGHT + 4)

    AddCheckboxGrid(categoryCard, categoryKeys, C.SESSION_CATEGORY_LABELS, 2, 124, -28, self.categoryBoxes, function(key, checked)
        local current = GetSession()

        if current then
            current:SetCategory(key, checked)
        end
    end)

    local elapsed = 0

    container:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + (delta or 0)

        if elapsed >= REFRESH_SECONDS then
            elapsed = 0
            SessionView:Refresh()
        end
    end)

    container:SetScript("OnShow", function()
        SessionView:Refresh()
    end)

    self.container = container
    self.clockText = clock
    self.statusText = status
    self.toggleButton = toggle
    self.resetButton = reset
    self.summaryText = summaryText
    self.itemsBox = items
    self.historyBox = history
    self.panelToggle = panelToggle
    self.opacitySlider = opacitySlider
    self.opacityValue = opacityValue

    if session then
        session:OnChanged(function()
            if container:IsVisible() then
                SessionView:Refresh()
            end
        end)
    end

    return container
end

function SessionView:Refresh()
    if not self.container then
        return
    end

    local session = GetSession()

    if not session then
        return
    end

    local summary = session:GetSummary()

    self.clockText:SetText(session.FormatClock(summary.seconds))

    if summary.status == "paused" then
        self.statusText:SetText(C.TEXT.SESSION_PAUSED)
    elseif summary.status == "idle" then
        self.statusText:SetText("")
    else
        self.statusText:SetText(summary.zone or "")
    end

    self.toggleButton:SetLabel(summary.status == "running" and C.TEXT.SESSION_PAUSE or C.TEXT.SESSION_RESUME)
    self.summaryText:SetText(SessionView.SummaryText(summary))
    SetBoxText(self.itemsBox, SessionView.ItemsText(summary))
    SetBoxText(self.historyBox, SessionView.HistoryText(session:GetHistory()))

    local panel = GetPanel()

    if panel then
        self.panelToggle:SetChecked(panel:IsEnabled())

        for key, box in pairs(self.lineBoxes) do
            box:SetChecked(panel:IsLineOn(key))
        end

        local opacity = panel:GetOpacity()
        self.opacitySlider:SetValue(opacity)
        self.opacityValue:SetText(string.format(C.TEXT.KILLS_PANEL_OPACITY_VALUE, opacity))
    end

    for key, box in pairs(self.categoryBoxes) do
        box:SetChecked(session:IsCategoryOn(key))
    end
end

ns:RegisterModule("UI.SessionView", SessionView)

ns.UI = ns.UI or {}
ns.UI.SessionView = SessionView
