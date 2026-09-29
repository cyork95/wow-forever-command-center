local _, ns = ...

local C = ns.constants

local MainFrame = {}

MainFrame.frame = nil
MainFrame.checkboxes = {}
MainFrame.minimapCheckbox = nil
MainFrame.verboseItemTypesCheckbox = nil
MainFrame.tabs = {}
MainFrame.pages = {}
MainFrame.companionRows = {}
MainFrame.companionsWarning = nil
MainFrame.guideBox = nil
MainFrame.activeTab = "export"

MainFrame.TAB_ORDER = { "export", "companions", "biography", "help" }

local FRAME_WIDTH = 720
local FRAME_HEIGHT = 540
local NAV_WIDTH = 140
local CONTENT_PADDING = 16
local CARD_GAP = 8
local CARD_COLUMNS = 3
local CARD_HEADER = 28
local CARD_ROW = 20
local COMPANION_ROW_HEIGHT = 42
local COMPANION_ROW_GAP = 4

local TAB_LABELS = {
    export = C.TEXT.TAB_EXPORT,
    companions = C.TEXT.TAB_COMPANIONS,
    biography = C.TEXT.TAB_BIOGRAPHY,
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
        checkbox:SetChecked(value == true)
    end

    SaveSelectionState()
end

local function UpdateSettingsCheckboxes()
    if MainFrame.minimapCheckbox then
        local visible = true

        if type(ns.IsMinimapIconVisible) == "function" then
            visible = ns:IsMinimapIconVisible()
        end

        MainFrame.minimapCheckbox:SetChecked(visible == true)
    end

    if MainFrame.verboseItemTypesCheckbox then
        local enabled = false

        if type(ns.IsVerboseItemTypesEnabled) == "function" then
            enabled = ns:IsVerboseItemTypesEnabled()
        end

        MainFrame.verboseItemTypesCheckbox:SetChecked(enabled == true)
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
    hint:SetText(C.TEXT.LABEL_BANK_HINT)

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

    MainFrame.createExportButton = createExport
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

        row.status:SetText(StatusText(status))
        row.status:SetTextColor(ns.Theme.Color(StatusColor(status)))
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

local function BuildHelpPage(page)
    local Theme = ns.Theme

    local guideBox = Theme.CreateScrollText(page, "AIExportGuideScrollFrame", "GameFontHighlightSmall")
    guideBox:SetPoint("TOPLEFT", 0, 0)
    guideBox:SetPoint("BOTTOMRIGHT", 0, 96)
    MainFrame.guideBox = guideBox

    local options = Theme.CreateCard(page, C.TEXT.LABEL_OPTIONS)
    options:SetPoint("BOTTOMLEFT", 0, 0)
    options:SetPoint("BOTTOMRIGHT", 0, 0)
    options:SetHeight(86)

    local minimapCheckbox = Theme.CreateCheckbox(options, C.TEXT.LABEL_SHOW_MINIMAP_ICON, function(self)
        local visible = self:GetChecked() == true
        local commands = GetCommands()

        if commands and type(commands.SetMinimapButtonVisible) == "function" then
            commands:SetMinimapButtonVisible(visible)
        elseif type(ns.SetMinimapIconVisible) == "function" then
            ns:SetMinimapIconVisible(visible)
        end
    end)
    minimapCheckbox:SetPoint("TOPLEFT", 10, -30)
    MainFrame.minimapCheckbox = minimapCheckbox

    local verboseCheckbox = Theme.CreateCheckbox(options, C.TEXT.LABEL_VERBOSE_ITEM_TYPES, function(self)
        if type(ns.SetVerboseItemTypesEnabled) == "function" then
            ns:SetVerboseItemTypesEnabled(self:GetChecked() == true)
        end
    end)
    verboseCheckbox:SetPoint("TOPLEFT", 10, -54)
    MainFrame.verboseItemTypesCheckbox = verboseCheckbox

    local copyGuide = Theme.CreateButton(options, C.TEXT.BUTTON_COPY_GUIDE, 110, 22, "default", function()
        local commands = GetCommands()

        if commands and type(commands.OpenGuide) == "function" then
            commands:OpenGuide()
        end
    end)
    copyGuide:SetPoint("TOPRIGHT", -10, -26)

    local reload = Theme.CreateButton(options, C.TEXT.BUTTON_RELOAD_UI, 110, 22, "default", function()
        if type(ReloadUI) == "function" then
            ReloadUI()
        end
    end)
    reload:SetPoint("TOPRIGHT", copyGuide, "BOTTOMRIGHT", 0, -6)

    page:SetScript("OnShow", function()
        local guide = ns.Guide

        if guide and type(guide.GetText) == "function" then
            guideBox:SetText(guide:GetText())
        end
    end)
end

local PAGE_BUILDERS = {
    export = BuildExportPage,
    companions = BuildCompanionsPage,
    biography = BuildBiographyPage,
    help = BuildHelpPage,
}

local function EnsureFrame()
    if MainFrame.frame then
        return MainFrame.frame
    end

    local Theme = ns.Theme
    local frame = Theme.CreateWindow("AIExportMainFrame", FRAME_WIDTH, FRAME_HEIGHT)

    Theme.CreateHeader(frame, C.TEXT.MAIN_WINDOW_TITLE, C.TEXT.LABEL_SUBTITLE)

    local nav = Theme.CreatePanel(frame, "header", "border")
    nav:SetPoint("TOPLEFT", 0, -(Theme.HEADER_HEIGHT - 1))
    nav:SetPoint("BOTTOMLEFT", 0, 0)
    nav:SetWidth(NAV_WIDTH)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", NAV_WIDTH + CONTENT_PADDING, -(Theme.HEADER_HEIGHT + 14))
    content:SetPoint("BOTTOMRIGHT", -CONTENT_PADDING, 14)

    for index, tabId in ipairs(MainFrame.TAB_ORDER) do
        local tab = Theme.CreateTab(nav, TAB_LABELS[tabId], function()
            MainFrame:SelectTab(tabId)
        end)
        tab:SetPoint("TOPLEFT", 1, -10 - ((index - 1) * 34))
        tab:SetPoint("TOPRIGHT", -1, -10 - ((index - 1) * 34))
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

    UpdateSettingsCheckboxes()

    return frame
end

function MainFrame:SelectTab(tabId)
    EnsureFrame()

    if not self.pages[tabId] then
        tabId = "export"
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

    if tabId == "companions" then
        RefreshCompanionRows()
    elseif tabId == "biography" then
        local view = ns.UI and ns.UI.BiographyView

        if view and type(view.ShowNewest) == "function" then
            view:ShowNewest()
        end
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

    UpdateSettingsCheckboxes()
    RefreshCompanionRows()
end

ns:RegisterModule("UI.MainFrame", MainFrame)

ns.UI = ns.UI or {}
ns.UI.MainFrame = MainFrame
