local _, ns = ...

local C = ns.constants

local MainFrame = {}

MainFrame.frame = nil
MainFrame.checkboxes = {}
MainFrame.options = nil
MainFrame.tabs = {}
MainFrame.pages = {}
MainFrame.companionRows = {}
MainFrame.companionsWarning = nil
MainFrame.guideBox = nil
MainFrame.readinessText = nil
MainFrame.readinessMarkers = {}
MainFrame.activeTab = "export"

MainFrame.TAB_ORDER = {
    "export", "biography", "kills", "session",
    "mail", "professions", "lockouts",
    "shopping", "tasks", "quests", "screenshots", "options", "help",
}

local FRAME_WIDTH = 720
local FRAME_HEIGHT = 680
local NAV_WIDTH = 140
local CONTENT_PADDING = 16
local TAB_SPACING = 28
local CARD_GAP = 8
local CARD_COLUMNS = 3
local CARD_HEADER = 28
local CARD_ROW = 20
local COMPANION_ROW_HEIGHT = 42
local COMPANION_ROW_GAP = 4
local READINESS_MAX_LINES = 4

local READINESS_SECTIONS = {
    C.SECTIONS.BANK,
    C.SECTIONS.PROFESSION_DETAILS,
}

local TAB_LABELS = {
    export = C.TEXT.TAB_EXPORT,
    companions = C.TEXT.TAB_COMPANIONS,
    biography = C.TEXT.TAB_BIOGRAPHY,
    kills = C.TEXT.TAB_KILLS,
    session = C.TEXT.TAB_SESSION,
    sessions = C.TEXT.TAB_SESSIONS,
    rares = C.TEXT.TAB_RARES,
    ledger = C.TEXT.TAB_LEDGER,
    currencies = C.TEXT.TAB_CURRENCIES,
    reputation = C.TEXT.TAB_REPUTATION,
    mail = C.TEXT.TAB_MAIL,
    professions = C.TEXT.TAB_PROFESSIONS,
    lockouts = C.TEXT.TAB_LOCKOUTS,
    shopping = C.TEXT.TAB_SHOPPING,
    tasks = C.TEXT.TAB_TASKS,
    quests = C.TEXT.TAB_QUESTS,
    screenshots = C.TEXT.TAB_SCREENSHOTS,
    options = C.TEXT.TAB_OPTIONS,
    help = C.TEXT.TAB_HELP,
}

local function GetCommands()
    return ns:GetModule("Commands")
end

local function GetCompanions()
    return ns.Companions
end

local function GetSelectionState()
    local selections = {}

    for sectionKey, checkbox in pairs(MainFrame.checkboxes) do
        selections[sectionKey] = checkbox:GetChecked() == true
    end

    return selections
end

local function SaveSelectionState()
    if type(ns.SetSelectedSections) == "function" then
        ns:SetSelectedSections(GetSelectionState())
    end

    MainFrame:RefreshReadiness()
end

local function ResolveInitialSelection(sectionKey)
    local saved = type(ns.GetSelectedSections) == "function"
        and ns:GetSelectedSections()
        or nil

    if type(saved) == "table" and saved[sectionKey] ~= nil then
        return saved[sectionKey] == true
    end

    return C.DEFAULT_SELECTIONS[sectionKey] == true
end

local function ApplySelectionState(value)
    for _, checkbox in pairs(MainFrame.checkboxes) do
        if checkbox:IsEnabled() then
            checkbox:SetChecked(value == true)
        end
    end

    SaveSelectionState()
end

-- A section whose feature is off keeps its saved tick but can't be changed
-- and is left out of the export.
local function RefreshSectionFeatures()
    for sectionKey, checkbox in pairs(MainFrame.checkboxes) do
        local label = C.SECTION_LABELS[sectionKey] or sectionKey

        if ns:IsSectionFeatureOn(sectionKey) then
            checkbox:Enable()
            checkbox.label:SetText(label)
        else
            checkbox:Disable()
            checkbox.label:SetText(label .. C.TEXT.SECTION_OFF_SUFFIX)
        end
    end
end

local function BuildExportPage(page)
    local Theme = ns.Theme
    local contentWidth = FRAME_WIDTH - NAV_WIDTH - (CONTENT_PADDING * 2)
    local cardWidth = math.floor(
        (contentWidth - (CARD_GAP * (CARD_COLUMNS - 1))) / CARD_COLUMNS
    )

    local description = Theme.CreateText(page, "GameFontHighlightSmall", "muted")
    description:SetPoint("TOPLEFT", 0, 0)
    description:SetWidth(contentWidth)
    description:SetText(C.TEXT.LABEL_MAIN_DESCRIPTION)

    local groups = C.SECTION_GROUPS
    local y = -34
    local index = 1

    while index <= #groups do
        local rowHeight = 0

        for column = 0, CARD_COLUMNS - 1 do
            local group = groups[index + column]

            if group then
                rowHeight = math.max(
                    rowHeight,
                    CARD_HEADER + (#group.sections * CARD_ROW) + 6
                )
            end
        end

        for column = 0, CARD_COLUMNS - 1 do
            local group = groups[index + column]

            if group then
                local card = Theme.CreateCard(page, group.title)
                card:SetSize(cardWidth, rowHeight)
                card:SetPoint("TOPLEFT", column * (cardWidth + CARD_GAP), y)

                for row, sectionKey in ipairs(group.sections) do
                    local checkbox = Theme.CreateCheckbox(
                        card,
                        C.SECTION_LABELS[sectionKey] or sectionKey,
                        SaveSelectionState
                    )
                    checkbox:SetPoint("TOPLEFT", 10, -CARD_HEADER - ((row - 1) * CARD_ROW))
                    checkbox:SetChecked(ResolveInitialSelection(sectionKey))
                    MainFrame.checkboxes[sectionKey] = checkbox
                end
            end
        end

        y = y - rowHeight - CARD_GAP
        index = index + CARD_COLUMNS
    end

    local hint = Theme.CreateText(page, "GameFontHighlightSmall", "muted")
    hint:SetPoint("TOPLEFT", 0, y - 4)
    hint:SetWidth(contentWidth)
    hint:SetJustifyH("LEFT")
    hint:SetText(C.TEXT.LABEL_BANK_HINT)
    MainFrame.readinessText = hint

    for _, sectionKey in ipairs(READINESS_SECTIONS) do
        local checkbox = MainFrame.checkboxes[sectionKey]

        if checkbox and checkbox.label then
            local marker = Theme.CreateText(checkbox, "GameFontNormal", "warning")
            marker:SetPoint("LEFT", checkbox.label, "RIGHT", 4, 0)
            marker:SetText("!")
            marker:Hide()
            MainFrame.readinessMarkers[sectionKey] = marker
        end
    end

    page:SetScript("OnShow", function()
        MainFrame:RefreshReadiness()
    end)

    local selectAll = Theme.CreateButton(page, C.TEXT.BUTTON_SELECT_ALL, 90, 22, "default", function()
        ApplySelectionState(true)
    end)
    selectAll:SetPoint("BOTTOMLEFT", 0, 3)

    local clearAll = Theme.CreateButton(page, C.TEXT.BUTTON_CLEAR_ALL, 90, 22, "default", function()
        ApplySelectionState(false)
    end)
    clearAll:SetPoint("LEFT", selectAll, "RIGHT", 8, 0)

    local createExport = Theme.CreateButton(page, C.TEXT.BUTTON_EXPORT, 160, 28, "primary", function()
        SaveSelectionState()

        local commands = GetCommands()

        if commands and type(commands.RunExportFromSelection) == "function" then
            commands:RunExportFromSelection(GetSelectionState())
        end
    end)
    createExport:SetPoint("BOTTOMRIGHT", 0, 0)

    local lastExport = Theme.CreateText(page, "GameFontHighlightSmall", "muted")
    lastExport:SetPoint("RIGHT", createExport, "LEFT", -12, 0)
    lastExport:SetJustifyH("RIGHT")

    MainFrame.createExportButton = createExport
    MainFrame.lastExportText = lastExport
end

function MainFrame:SetLastExportTokens(tokens)
    if not self.lastExportText then
        return
    end

    local count = tonumber(tokens)

    if not count then
        self.lastExportText:SetText("")
        return
    end

    local text = tostring(math.floor(count)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    self.lastExportText:SetText(string.format(C.TEXT.LABEL_LAST_EXPORT, text))
end

local function GetReadiness()
    return ns.Data and ns.Data.Readiness
end

function MainFrame:GetReadinessResult()
    local readiness = GetReadiness()

    if not readiness then
        return nil
    end

    local selections = next(self.checkboxes) and GetSelectionState() or nil
    local ok, result = pcall(readiness.GetMissingData, readiness, selections)

    return ok and result or nil
end

function MainFrame:RefreshReadiness()
    if not self.readinessText then
        return
    end

    local readiness = GetReadiness()
    local result = self:GetReadinessResult()

    if not readiness or not result then
        self.readinessText:SetText(C.TEXT.LABEL_BANK_HINT)
        self.readinessText:SetTextColor(ns.Theme.Color("muted"))
        return
    end

    for sectionKey, marker in pairs(self.readinessMarkers) do
        marker:SetShown(readiness:IsSectionMissing(result, sectionKey))
    end

    if #result.missing > READINESS_MAX_LINES then
        local lines = {}

        for index = 1, READINESS_MAX_LINES - 1 do
            table.insert(lines, result.missing[index].text)
        end

        local rest = {}

        for index = READINESS_MAX_LINES, #result.missing do
            table.insert(rest, result.missing[index].label)
        end

        table.insert(lines, string.format(C.TEXT.LABEL_MISSING, table.concat(rest, ", ")))
        self.readinessText:SetText(table.concat(lines, "\n"))
        self.readinessText:SetTextColor(ns.Theme.Color("warning"))
        return
    end

    local text, warning = readiness:SummaryText(result)

    self.readinessText:SetText(text)
    self.readinessText:SetTextColor(ns.Theme.Color(warning and "warning" or "muted"))
end

local function StatusColor(status)
    if status == "loaded" then
        return "accent"
    elseif status == "installed" then
        return "warning"
    end

    return "disabled"
end

local function StatusText(status)
    if status == "loaded" then
        return C.TEXT.STATUS_LOADED
    elseif status == "installed" then
        return C.TEXT.STATUS_INSTALLED
    end

    return C.TEXT.STATUS_MISSING
end

local function RefreshCompanionRows()
    local companions = GetCompanions()

    if not companions then
        return
    end

    for _, row in ipairs(MainFrame.companionRows) do
        local status = companions:GetStatus(row.definition)
        local loaded = status == "loaded"

        if companions:IsBuiltIn(row.definition) then
            row.status:SetText(C.TEXT.KILLDEX_BUILT_IN)
            row.status:SetTextColor(ns.Theme.Color("accent"))
        else
            row.status:SetText(StatusText(status))
            row.status:SetTextColor(ns.Theme.Color(StatusColor(status)))
        end
        row.checkbox:SetChecked(companions:IsEnabled(row.definition.id))

        if loaded then
            row.checkbox:Enable()
        else
            row.checkbox:Disable()
        end
    end

    if MainFrame.companionsWarning then
        local sectionOn = ResolveInitialSelection(C.SECTIONS.COMPANIONS)

        if MainFrame.checkboxes[C.SECTIONS.COMPANIONS] then
            sectionOn = MainFrame.checkboxes[C.SECTIONS.COMPANIONS]:GetChecked() == true
        end

        if sectionOn then
            MainFrame.companionsWarning:Hide()
        else
            MainFrame.companionsWarning:Show()
        end
    end
end

local function BuildCompanionsPage(page)
    local Theme = ns.Theme
    local companions = GetCompanions()
    local contentWidth = FRAME_WIDTH - NAV_WIDTH - (CONTENT_PADDING * 2)

    local description = Theme.CreateText(page, "GameFontHighlightSmall", "muted")
    description:SetPoint("TOPLEFT", 0, 0)
    description:SetWidth(contentWidth)
    description:SetText(C.TEXT.LABEL_COMPANIONS_DESCRIPTION)

    local definitions = companions and companions:GetAll() or {}
    local y = -38

    for _, definition in ipairs(definitions) do
        local row = Theme.CreateCard(page)
        row:SetSize(contentWidth, COMPANION_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, y)

        local checkbox = Theme.CreateCheckbox(row, definition.title, function(self)
            companions:SetEnabled(definition.id, self:GetChecked() == true)
        end)
        checkbox:SetPoint("TOPLEFT", 10, -8)
        checkbox.label:SetFontObject("GameFontHighlight")

        local status = Theme.CreateText(row, "GameFontHighlightSmall", "muted")
        status:SetPoint("TOPRIGHT", -10, -9)
        status:SetJustifyH("RIGHT")

        local adds = Theme.CreateText(row, "GameFontHighlightSmall", "muted")
        adds:SetPoint("TOPLEFT", 31, -25)
        adds:SetWidth(contentWidth - 42)
        adds:SetText(definition.adds or "")

        table.insert(MainFrame.companionRows, {
            definition = definition,
            checkbox = checkbox,
            status = status,
        })

        y = y - COMPANION_ROW_HEIGHT - COMPANION_ROW_GAP
    end

    local warning = Theme.CreateText(page, "GameFontHighlightSmall", "warning")
    warning:SetPoint("BOTTOMLEFT", 0, 4)
    warning:SetWidth(contentWidth)
    warning:SetText(C.TEXT.LABEL_COMPANIONS_SECTION_OFF)
    warning:Hide()
    MainFrame.companionsWarning = warning
end

local function BuildBiographyPage(page)
    local view = ns.UI and ns.UI.BiographyView

    if view and type(view.Build) == "function" then
        view:Build(page)
    end
end

local function BuildKillsPage(page)
    local view = ns.UI and ns.UI.KillsView

    if view and type(view.Build) == "function" then
        view:Build(page)
    end
end

local function BuildSessionPage(page)
    local view = ns.UI and ns.UI.SessionView

    if view and type(view.Build) == "function" then
        view:Build(page)
    end
end

local function BuildShoppingPage(page)
    local view = ns.UI and ns.UI.ShoppingView

    if view and type(view.Build) == "function" then
        view:Build(page)
    end
end

local function BuildScreenshotsPage(page)
    local view = ns.UI and ns.UI.ScreenshotterView

    if view and type(view.Build) == "function" then
        view:Build(page)
    end
end

local function BuildOptionsPage(page)
    local view = ns.UI and ns.UI.OptionsView

    if view and type(view.New) == "function" then
        MainFrame.options = view.New(page, FRAME_WIDTH - NAV_WIDTH - (CONTENT_PADDING * 2))
    end
end

local function BuildHelpPage(page)
    local Theme = ns.Theme

    local guideBox = Theme.CreateScrollEdit(page, "DossierGuideScrollFrame", "GameFontHighlightSmall")
    guideBox:SetPoint("TOPLEFT", 0, 0)
    guideBox:SetPoint("BOTTOMRIGHT", 0, 30)
    MainFrame.guideBox = guideBox

    local copyGuide = Theme.CreateButton(page, C.TEXT.BUTTON_COPY_GUIDE, 110, 22, "default", function()
        local commands = GetCommands()

        if commands and type(commands.OpenGuide) == "function" then
            commands:OpenGuide()
        end
    end)
    copyGuide:SetPoint("BOTTOMRIGHT", 0, 0)
    MainFrame.copyGuideButton = copyGuide

    page:SetScript("OnShow", function()
        local guide = ns.Guide

        if guide and type(guide.GetDisplayText) == "function" then
            guideBox:SetText(guide:GetDisplayText())
        elseif guide and type(guide.GetText) == "function" then
            guideBox:SetText(guide:GetText())
        end
    end)
end

local function BuildHousePage(viewName)
    return function(page)
        local view = ns.UI and ns.UI[viewName]

        if view and type(view.Build) == "function" then
            view:Build(page)
        end
    end
end

local PAGE_BUILDERS = {
    export = BuildExportPage,
    biography = BuildBiographyPage,
    kills = BuildKillsPage,
    rares = BuildHousePage("RaresView"),
    session = BuildSessionPage,
    sessions = BuildHousePage("SessionsView"),
    ledger = BuildHousePage("LedgerView"),
    currencies = BuildHousePage("CurrenciesView"),
    reputation = BuildHousePage("ReputationView"),
    mail = BuildHousePage("MailView"),
    professions = BuildHousePage("ProfessionsView"),
    lockouts = BuildHousePage("LockoutsView"),
    shopping = BuildShoppingPage,
    tasks = BuildHousePage("TasksView"),
    quests = BuildHousePage("QuestHistoryView"),
    screenshots = BuildScreenshotsPage,
    options = BuildOptionsPage,
    help = BuildHelpPage,
}

-- Stacks the tabs of features that are on, with no gaps for the ones that are off.
function MainFrame:LayoutTabs()
    local index = 0

    for _, tabId in ipairs(self.TAB_ORDER) do
        local tab = self.tabs[tabId]

        if tab then
            if ns:IsTabFeatureOn(tabId) then
                tab:ClearAllPoints()
                tab:SetPoint("TOPLEFT", 1, -10 - (index * TAB_SPACING))
                tab:SetPoint("TOPRIGHT", -1, -10 - (index * TAB_SPACING))
                tab:Show()
                index = index + 1
            else
                tab:Hide()
            end
        end
    end
end

local function EnsureFrame()
    if MainFrame.frame then
        return MainFrame.frame
    end

    local Theme = ns.Theme
    local frame = Theme.CreateWindow("DossierMainFrame", FRAME_WIDTH, FRAME_HEIGHT)

    Theme.CreateHeader(frame, C.TEXT.MAIN_WINDOW_TITLE, C.TEXT.LABEL_SUBTITLE)

    local nav = Theme.CreatePanel(frame, "header", "border")
    nav:SetPoint("TOPLEFT", 0, -(Theme.HEADER_HEIGHT - 1))
    nav:SetPoint("BOTTOMLEFT", 0, 0)
    nav:SetWidth(NAV_WIDTH)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", NAV_WIDTH + CONTENT_PADDING, -(Theme.HEADER_HEIGHT + 14))
    content:SetPoint("BOTTOMRIGHT", -CONTENT_PADDING, 14)

    for _, tabId in ipairs(MainFrame.TAB_ORDER) do
        local tab = Theme.CreateTab(nav, TAB_LABELS[tabId], function()
            MainFrame:SelectTab(tabId)
        end)
        tab:SetHeight(26)
        MainFrame.tabs[tabId] = tab

        local page = CreateFrame("Frame", nil, content)
        page:SetAllPoints()
        page:Hide()
        MainFrame.pages[tabId] = page
    end

    local footer = Theme.CreateText(nav, "GameFontHighlightSmall", "disabled")
    footer:SetPoint("BOTTOMLEFT", 16, 14)
    footer:SetText(C.SLASH_COMMAND)

    MainFrame.frame = frame

    for _, tabId in ipairs(MainFrame.TAB_ORDER) do
        PAGE_BUILDERS[tabId](MainFrame.pages[tabId])
    end

    MainFrame:LayoutTabs()
    RefreshSectionFeatures()

    return frame
end

function MainFrame:SelectTab(tabId)
    EnsureFrame()

    if not self.pages[tabId] then
        tabId = "export"
    end

    if not ns:IsTabFeatureOn(tabId) then
        tabId = "options"
    end

    self.activeTab = tabId

    for id, page in pairs(self.pages) do
        if id == tabId then
            page:Show()
        else
            page:Hide()
        end

        self.tabs[id]:SetSelected(id == tabId)
    end

    if tabId == "biography" then
        local view = ns.UI and ns.UI.BiographyView

        if view and type(view.ShowNewest) == "function" then
            view:ShowNewest()
        end
    elseif tabId == "kills" then
        local view = ns.UI and ns.UI.KillsView

        if view and type(view.Refresh) == "function" then
            view:Refresh()
        end
    elseif tabId == "session" then
        local view = ns.UI and ns.UI.SessionView

        if view and type(view.Refresh) == "function" then
            view:Refresh()
        end
    elseif tabId == "shopping" then
        local view = ns.UI and ns.UI.ShoppingView

        if view and type(view.Refresh) == "function" then
            view:Refresh()
        end
    elseif tabId == "screenshots" then
        local view = ns.UI and ns.UI.ScreenshotterView

        if view and type(view.Refresh) == "function" then
            view:Refresh()
        end
    end

    local houseViews = {
        rares = "RaresView",
        sessions = "SessionsView",
        ledger = "LedgerView",
        currencies = "CurrenciesView",
        reputation = "ReputationView",
        mail = "MailView",
        professions = "ProfessionsView",
        lockouts = "LockoutsView",
        tasks = "TasksView",
        quests = "QuestHistoryView",
    }
    local house = houseViews[tabId] and ns.UI and ns.UI[houseViews[tabId]]

    if house and type(house.Refresh) == "function" then
        house:Refresh()
    end
end

function MainFrame:GetActiveTab()
    return self.activeTab
end

function MainFrame:Show(tabId)
    local frame = EnsureFrame()

    self:Refresh()
    frame:Show()
    self:SelectTab(tabId or self.activeTab or "export")
end

function MainFrame:ShowTab(tabId)
    self:Show(tabId)
end

function MainFrame:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function MainFrame:IsShown()
    return self.frame ~= nil and self.frame:IsShown()
end

function MainFrame:Toggle()
    local frame = EnsureFrame()

    if frame:IsShown() then
        frame:Hide()
    else
        self:Show()
    end
end

function MainFrame:GetSelections()
    return GetSelectionState()
end

function MainFrame:Refresh()
    if not self.frame then
        return
    end

    for sectionKey, checkbox in pairs(self.checkboxes) do
        checkbox:SetChecked(ResolveInitialSelection(sectionKey))
    end

    self:LayoutTabs()
    RefreshSectionFeatures()

    if self.options then
        self.options:Refresh()
    end

    RefreshCompanionRows()
    self:RefreshReadiness()
end

ns:OnFeatureChanged(function()
    if not MainFrame.frame then
        return
    end

    MainFrame:LayoutTabs()
    RefreshSectionFeatures()

    if not ns:IsTabFeatureOn(MainFrame.activeTab) then
        MainFrame:SelectTab("options")
    end
end)

if ns.Data and ns.Data.Readiness then
    ns.Data.Readiness:OnChanged(function()
        if MainFrame:IsShown() then
            MainFrame:RefreshReadiness()
        end
    end)
end

ns:RegisterModule("UI.MainFrame", MainFrame)

ns.UI = ns.UI or {}
ns.UI.MainFrame = MainFrame
