local _, ns = ...

local C = ns.constants

local KillsView = {}

KillsView.container = nil
KillsView.rows = {}
KillsView.sortKey = "kills"
KillsView.filter = ""
KillsView.offset = 0
KillsView.selected = nil

local ROW_COUNT = 12
local ROW_HEIGHT = 18
local LIST_TOP = -82

local COLUMNS = {
    { key = "name", x = 8, width = 200, justify = "LEFT" },
    { key = "kills", x = 212, width = 46, justify = "RIGHT" },
    { key = "level", x = 270, width = 34, justify = "RIGHT" },
    { key = "zone", x = 316, width = 132, justify = "LEFT" },
    { key = "last", x = 452, width = 80, justify = "LEFT" },
}

local COLUMN_TITLES = {
    name = "Creature",
    kills = "Kills",
    level = "Level",
    zone = "Zone",
    last = "Last kill",
}

local SORT_BUTTONS = {
    { key = "kills", label = C.TEXT.KILLS_SORT_KILLS },
    { key = "name", label = C.TEXT.KILLS_SORT_NAME },
    { key = "recent", label = C.TEXT.KILLS_SORT_RECENT },
}

local function GetKills()
    return ns.Data and ns.Data.Kills
end

local function FormatMoney(copper)
    local helpers = ns.Companions and ns.Companions.helpers
    return helpers and helpers.FormatMoney(copper or 0) or tostring(copper or 0)
end

local function FormatDate(timestamp)
    local helpers = ns.Companions and ns.Companions.helpers
    return helpers and helpers.FormatDate(timestamp) or tostring(timestamp)
end

local function FormatCount(value)
    local text = tostring(math.floor(tonumber(value) or 0))
    return (text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

function KillsView.FormatAgo(timestamp)
    local seconds = math.max(0, (time() or 0) - (tonumber(timestamp) or 0))

    if not tonumber(timestamp) then
        return ""
    elseif seconds < 3600 then
        return string.format("%dm ago", math.max(1, math.floor(seconds / 60)))
    elseif seconds < 86400 then
        return string.format("%dh ago", math.floor(seconds / 3600))
    end

    return string.format("%dd ago", math.floor(seconds / 86400))
end

function KillsView.HeaderText()
    local kills = GetKills()

    if not kills then
        return ""
    end

    local totals = kills:GetTotals()
    local session = kills:GetSession()

    return string.format(
        C.TEXT.KILLS_HEADER,
        FormatCount(totals.kills),
        FormatCount(totals.creatures),
        FormatCount(session.kills),
        FormatCount(session.killsPerHour),
        FormatMoney(totals.gold)
    )
end

function KillsView.DetailText(id, mob)
    if type(mob) ~= "table" then
        return C.TEXT.KILLS_DETAIL_EMPTY
    end

    local facts = {}

    if (tonumber(mob.level) or 0) > 0 then
        table.insert(facts, "level " .. mob.level)
    end

    if mob.classification then
        table.insert(facts, mob.classification)
    end

    if mob.creatureType then
        table.insert(facts, mob.creatureType)
    end

    if mob.zone then
        table.insert(facts, mob.zone)
    end

    local lines = {
        (mob.name or "Unknown") .. (#facts > 0 and (" (" .. table.concat(facts, ", ") .. ")") or ""),
        string.format("Killed %s times. First %s, last %s.", FormatCount(mob.kills), FormatDate(mob.firstKill), FormatDate(mob.lastKill)),
    }

    if (mob.gold or 0) > 0 then
        table.insert(lines, "Gold looted: " .. FormatMoney(mob.gold))
    end

    local drops = {}

    for _, entry in pairs(mob.loot or {}) do
        table.insert(drops, entry)
    end

    table.sort(drops, function(a, b)
        if (a.quantity or 0) ~= (b.quantity or 0) then
            return (a.quantity or 0) > (b.quantity or 0)
        end

        return (a.name or "") < (b.name or "")
    end)

    if #drops == 0 then
        table.insert(lines, C.TEXT.KILLS_NO_DROPS)
    else
        local parts = {}

        for _, entry in ipairs(drops) do
            table.insert(parts, string.format("%s x%s", entry.name or "Unknown item", FormatCount(entry.quantity)))
        end

        table.insert(lines, "Drops: " .. table.concat(parts, ", "))
    end

    return table.concat(lines, "\n")
end

local function CreateRow(parent, index)
    local Theme = ns.Theme
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 4, -4 - ((index - 1) * ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", -4, -4 - ((index - 1) * ROW_HEIGHT))

    local highlight = row:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints()
    highlight:SetColorTexture(Theme.Color("cardHover"))
    highlight:Hide()
    row.highlight = highlight

    row.cells = {}

    for _, column in ipairs(COLUMNS) do
        local cell = Theme.CreateText(row, "GameFontHighlightSmall", column.key == "name" and "text" or "muted")
        cell:SetPoint("LEFT", column.x, 0)
        cell:SetWidth(column.width)
        cell:SetJustifyH(column.justify)
        cell:SetJustifyV("MIDDLE")
        cell:SetWordWrap(false)
        row.cells[column.key] = cell
    end

    row:SetScript("OnEnter", function(self) self.highlight:Show() end)
    row:SetScript("OnLeave", function(self)
        if KillsView.selected ~= self.mobID then
            self.highlight:Hide()
        end
    end)
    row:SetScript("OnClick", function(self)
        KillsView.selected = self.mobID
        KillsView:Refresh()
    end)

    row:Hide()

    return row
end

function KillsView:Build(parent)
    if self.container then
        return self.container
    end

    local Theme = ns.Theme
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints()

    local header = Theme.CreateText(container, "GameFontHighlightSmall", "accent")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)

    local imported = Theme.CreateText(container, "GameFontHighlightSmall", "muted")
    imported:SetPoint("TOPLEFT", 0, -16)
    imported:SetPoint("TOPRIGHT", 0, -16)

    local search = CreateFrame("EditBox", nil, container, Theme.BACKDROP_TEMPLATE)
    search:SetSize(180, 22)
    search:SetPoint("TOPLEFT", 0, -38)
    search:SetAutoFocus(false)
    search:SetFontObject(ChatFontNormal)
    search:SetTextInsets(6, 6, 0, 0)
    Theme.ApplyBackdrop(search, "dark", "border")

    local placeholder = Theme.CreateText(search, "GameFontHighlightSmall", "disabled")
    placeholder:SetPoint("LEFT", 7, 0)
    placeholder:SetText(C.TEXT.KILLS_SEARCH)

    search:SetScript("OnTextChanged", function(self)
        KillsView.filter = self:GetText() or ""
        KillsView.offset = 0
        placeholder:SetShown(KillsView.filter == "")
        KillsView:Refresh()
    end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    self.sortButtons = {}
    local previous = nil

    for index = #SORT_BUTTONS, 1, -1 do
        local option = SORT_BUTTONS[index]
        local button = Theme.CreateButton(container, option.label, 84, 22, "default", function()
            KillsView.sortKey = option.key
            KillsView.offset = 0
            KillsView:Refresh()
        end)

        if previous then
            button:SetPoint("RIGHT", previous, "LEFT", -6, 0)
        else
            button:SetPoint("TOPRIGHT", 0, -38)
        end

        button:HookScript("OnLeave", function()
            KillsView:PaintSortButtons()
        end)

        previous = button
        self.sortButtons[option.key] = button
    end

    for _, column in ipairs(COLUMNS) do
        local title = Theme.CreateText(container, "GameFontNormalSmall", "accent")
        title:SetPoint("TOPLEFT", column.x + 4, -66)
        title:SetWidth(column.width)
        title:SetJustifyH(column.justify)
        title:SetText(COLUMN_TITLES[column.key])
    end

    local list = Theme.CreatePanel(container, "dark", "border")
    list:SetPoint("TOPLEFT", 0, LIST_TOP)
    list:SetPoint("TOPRIGHT", 0, LIST_TOP)
    list:SetHeight(ROW_COUNT * ROW_HEIGHT + 8)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        KillsView.offset = math.max(0, KillsView.offset - delta * 3)
        KillsView:Refresh()
    end)

    for index = 1, ROW_COUNT do
        self.rows[index] = CreateRow(list, index)
    end

    local empty = Theme.CreateText(list, "GameFontHighlightSmall", "muted")
    empty:SetPoint("TOPLEFT", 10, -10)
    empty:SetPoint("TOPRIGHT", -10, -10)

    local position = Theme.CreateText(container, "GameFontHighlightSmall", "muted")
    position:SetPoint("TOPRIGHT", list, "BOTTOMRIGHT", 0, -4)
    position:SetJustifyH("RIGHT")

    local detail = Theme.CreateScrollText(container, "AIExportKillsDetailScrollFrame", "GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -20)
    detail:SetPoint("BOTTOMRIGHT", 0, 26)

    local panelToggle = Theme.CreateCheckbox(container, C.TEXT.KILLS_SHOW_PANEL, function(self)
        local panel = ns.UI and ns.UI.KillPanel

        if panel then
            panel:SetShown(self:GetChecked() == true)
        end
    end)
    panelToggle:SetPoint("BOTTOMLEFT", 0, 4)

    local tooltipToggle = Theme.CreateCheckbox(container, C.TEXT.KILLS_SHOW_TOOLTIP, function(self)
        local kills = GetKills()

        if kills then
            kills:SetTooltipEnabled(self:GetChecked() == true)
        end
    end)
    tooltipToggle:SetPoint("BOTTOMLEFT", 220, 4)

    container:SetScript("OnShow", function()
        KillsView:Refresh()
    end)

    self.container = container
    self.header = header
    self.importedText = imported
    self.search = search
    self.list = list
    self.emptyText = empty
    self.positionText = position
    self.detail = detail
    self.panelToggle = panelToggle
    self.tooltipToggle = tooltipToggle

    local kills = GetKills()

    if kills then
        kills:OnChanged(function()
            if container:IsVisible() then
                KillsView:Refresh()
            end
        end)
    end

    return container
end

function KillsView:PaintSortButtons()
    for key, button in pairs(self.sortButtons or {}) do
        button.label:SetTextColor(ns.Theme.Color(key == self.sortKey and "accent" or "text"))
    end
end

function KillsView:Refresh()
    if not self.container then
        return
    end

    local kills = GetKills()

    if not kills then
        return
    end

    self.header:SetText(KillsView.HeaderText())

    local imported = kills:GetImportInfo()
    self.importedText:SetText(imported and string.format(C.TEXT.KILLS_IMPORTED, FormatCount(imported.kills)) or "")

    self:PaintSortButtons()

    local list = kills:GetSortedMobs(self.sortKey, self.filter)
    local maxOffset = math.max(0, #list - ROW_COUNT)

    self.offset = math.min(self.offset, maxOffset)
    self.visible = {}

    for index, row in ipairs(self.rows) do
        local entry = list[self.offset + index]

        if entry then
            local mob = entry.mob

            row.mobID = entry.id
            row.cells.name:SetText(mob.name or "Unknown")
            row.cells.kills:SetText(FormatCount(mob.kills))
            row.cells.level:SetText((tonumber(mob.level) or 0) > 0 and tostring(mob.level) or "")
            row.cells.zone:SetText(mob.zone or "")
            row.cells.last:SetText(KillsView.FormatAgo(mob.lastKill))
            row.highlight:SetShown(self.selected == entry.id)
            row:Show()
            table.insert(self.visible, entry)
        else
            row.mobID = nil
            row:Hide()
        end
    end

    if #list == 0 then
        self.emptyText:SetText(kills:HasData() and C.TEXT.KILLS_NO_MATCH or C.TEXT.KILLS_EMPTY)
        self.emptyText:Show()
        self.positionText:SetText("")
    else
        self.emptyText:Hide()
        self.positionText:SetText(string.format(
            "%d-%d of %d",
            self.offset + 1,
            math.min(self.offset + ROW_COUNT, #list),
            #list
        ))
    end

    local selected = self.selected and kills:GetMob(self.selected)
    self.detail:SetText(KillsView.DetailText(self.selected, selected))

    local panel = ns.UI and ns.UI.KillPanel
    self.panelToggle:SetChecked(panel ~= nil and panel:IsEnabled())
    self.tooltipToggle:SetChecked(kills:IsTooltipEnabled())
end

ns:RegisterModule("UI.KillsView", KillsView)

ns.UI = ns.UI or {}
ns.UI.KillsView = KillsView
