local _, ns = ...

local C = ns.constants

local MainFrame = {}

MainFrame.frame = nil
MainFrame.checkboxes = {}
MainFrame.minimapCheckbox = nil
MainFrame.verboseItemTypesCheckbox = nil
MainFrame.uiSectionOrder = nil

local FRAME_WIDTH = 560
local MIN_FRAME_HEIGHT = 500
local CHECKBOX_HEIGHT = 26
local SETTINGS_TO_BUTTON_GAP = 24
local BUTTON_ROW_HEIGHT = 22
local BUTTON_ROW_GAP = 6
local BOTTOM_PADDING = 18

local function SetCheckboxValue(
    checkbox,
    checked
)
    if checkbox
        and type(
            checkbox.SetChecked
        ) == "function"
    then
        checkbox:SetChecked(
            checked == true
        )
    end
end

local function GetSelectionState()
    local selections = {}

    for sectionKey, checkbox
        in pairs(
            MainFrame.checkboxes
        )
    do
        if checkbox
            and type(
                checkbox.GetChecked
            ) == "function"
        then
            selections[
                sectionKey
            ] =
                checkbox:GetChecked()
                == true
        end
    end

    return selections
end

local function SaveSelectionState()
    if type(
        ns.SetSelectedSections
    ) == "function"
    then
        ns:SetSelectedSections(
            GetSelectionState()
        )
    end
end

local function ResolveInitialSelection(
    sectionKey
)
    local savedSelections = nil

    if type(
        ns.GetSelectedSections
    ) == "function"
    then
        savedSelections =
            ns:GetSelectedSections()
    end

    if type(savedSelections)
        == "table"
        and savedSelections[
            sectionKey
        ] ~= nil
    then
        return
            savedSelections[
                sectionKey
            ] == true
    end

    return
        C.DEFAULT_SELECTIONS[
            sectionKey
        ] == true
end

local function ApplySelectionState(
    value
)
    for _, sectionKey
        in ipairs(
            MainFrame.uiSectionOrder
            or C.SECTION_ORDER
        )
    do
        SetCheckboxValue(
            MainFrame.checkboxes[
                sectionKey
            ],
            value
        )
    end

    SaveSelectionState()
end

local function BuildUISectionOrder()
    local sectionKeys = {}

    for _, sectionKey
        in ipairs(
            C.SECTION_ORDER
        )
    do
        table.insert(
            sectionKeys,
            sectionKey
        )
    end

    table.sort(
        sectionKeys,
        function(left, right)
            local leftLabel =
                C.SECTION_LABELS[
                    left
                ]
                or left

            local rightLabel =
                C.SECTION_LABELS[
                    right
                ]
                or right

            return
                leftLabel
                < rightLabel
        end
    )

    return sectionKeys
end

local function CreateTitle(
    parent,
    text
)
    local title =
        parent:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormalLarge"
        )

    title:SetPoint(
        "TOPLEFT",
        16,
        -36
    )

    title:SetText(
        text
    )

    return title
end

local function CreateHint(
    parent,
    text,
    topOffset
)
    local hint =
        parent:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlightSmall"
        )

    hint:SetPoint(
        "TOPLEFT",
        16,
        topOffset or -58
    )

    hint:SetWidth(
        348
    )

    hint:SetJustifyH(
        "LEFT"
    )

    hint:SetJustifyV(
        "TOP"
    )

    hint:SetText(
        text
    )

    return hint
end

local function CreateSectionLabel(
    parent,
    text,
    x,
    y
)
    local label =
        parent:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormal"
        )

    label:SetPoint(
        "TOPLEFT",
        x,
        y
    )

    label:SetTextColor(
        1.0,
        0.82,
        0.0
    )

    label:SetText(
        text
    )

    return label
end

local function ResolveCheckboxText(
    checkbox
)
    if not checkbox then
        return nil
    end

    if checkbox.text then
        return checkbox.text
    end

    if type(
        checkbox.GetName
    ) ~= "function"
    then
        return nil
    end

    local checkboxName =
        checkbox:GetName()

    if not checkboxName then
        return nil
    end

    return
        _G[
            checkboxName
            .. "Text"
        ]
end

local function CreateCheckbox(
    parent,
    label,
    x,
    y
)
    local checkbox =
        CreateFrame(
            "CheckButton",
            nil,
            parent,
            "UICheckButtonTemplate"
        )

    checkbox:SetPoint(
        "TOPLEFT",
        x,
        y
    )

    local fontString =
        ResolveCheckboxText(
            checkbox
        )

    if fontString
        and type(
            fontString.SetText
        ) == "function"
    then
        fontString:SetText(
            label
        )
    end

    return checkbox
end

local function CreateButton(
    parent,
    width,
    height,
    label,
    x,
    y,
    onClick
)
    local button =
        CreateFrame(
            "Button",
            nil,
            parent,
            "UIPanelButtonTemplate"
        )

    button:SetSize(
        width,
        height
    )

    button:SetPoint(
        "BOTTOMLEFT",
        x,
        y
    )

    button:SetText(
        label
    )

    button:SetScript(
        "OnClick",
        onClick
    )

    return button
end

local function UpdateSettingsCheckboxes()
    if MainFrame.minimapCheckbox then
        local visible = true

        if type(
            ns.IsMinimapIconVisible
        ) == "function"
        then
            visible =
                ns:IsMinimapIconVisible()
        end

        MainFrame.minimapCheckbox:SetChecked(
            visible == true
        )
    end

    if MainFrame.verboseItemTypesCheckbox then
        local enabled = false

        if type(
            ns.IsVerboseItemTypesEnabled
        ) == "function"
        then
            enabled =
                ns:IsVerboseItemTypesEnabled()
        end

        MainFrame.verboseItemTypesCheckbox:SetChecked(
            enabled == true
        )
    end
end

local function EnsureFrame()
    if MainFrame.frame then
        return MainFrame.frame
    end

    local frame =
        CreateFrame(
            "Frame",
            "AIExportMainFrame",
            UIParent,
            "BasicFrameTemplateWithInset"
        )

    frame:SetSize(
        FRAME_WIDTH,
        MIN_FRAME_HEIGHT
    )

    frame:SetPoint(
        "CENTER"
    )

    frame:SetFrameStrata(
        "MEDIUM"
    )

    if type(
        frame.SetToplevel
    ) == "function"
    then
        frame:SetToplevel(
            false
        )
    end

    frame:SetMovable(
        true
    )

    frame:EnableMouse(
        true
    )

    frame:RegisterForDrag(
        "LeftButton"
    )

    frame:SetScript(
        "OnDragStart",
        function(self)
            if type(
                self.StartMoving
            ) == "function"
            then
                self:StartMoving()
            end
        end
    )

    frame:SetScript(
        "OnDragStop",
        function(self)
            if type(
                self.StopMovingOrSizing
            ) == "function"
            then
                self:StopMovingOrSizing()
            end
        end
    )

    frame:Hide()

    if frame.TitleText
        and type(
            frame.TitleText.SetText
        ) == "function"
    then
        frame.TitleText:SetText(
            C.TEXT.MAIN_WINDOW_TITLE
        )
    end

    MainFrame.uiSectionOrder =
        BuildUISectionOrder()

    CreateTitle(
        frame,
        C.TEXT.MAIN_WINDOW_TITLE
    )

    CreateHint(
        frame,
        C.TEXT.LABEL_MAIN_DESCRIPTION,
        -58
    )

    CreateHint(
        frame,
        C.TEXT.LABEL_BANK_HINT,
        -92
    )

    local exportLabelY =
        -128

    local startY =
        exportLabelY
        - 24

    local rowStep =
        -24

    local columnCount =
        3

    local columnRows =
        math.ceil(
            #MainFrame.uiSectionOrder
            / columnCount
        )

    local columnStartX =
        20

    local columnGap =
        10

    local columnWidth =
        math.floor(
            (
                FRAME_WIDTH
                - (
                    columnStartX
                    * 2
                )
                - (
                    (
                        columnCount
                        - 1
                    )
                    * columnGap
                )
            )
            / columnCount
        )

    CreateSectionLabel(
        frame,
        C.TEXT.LABEL_EXPORT_DATA,
        20,
        exportLabelY
    )

    for index, sectionKey
        in ipairs(
            MainFrame.uiSectionOrder
        )
    do
        local column =
            math.floor(
                (
                    index
                    - 1
                )
                / columnRows
            )

        local row =
            (
                index
                - 1
            )
            % columnRows

        local x =
            columnStartX
            + (
                column
                * (
                    columnWidth
                    + columnGap
                )
            )

        local y =
            startY
            + (
                row
                * rowStep
            )

        local checkbox =
            CreateCheckbox(
                frame,
                C.SECTION_LABELS[
                    sectionKey
                ]
                or sectionKey,
                x,
                y
            )

        SetCheckboxValue(
            checkbox,
            ResolveInitialSelection(
                sectionKey
            )
        )

        checkbox:SetScript(
            "OnClick",
            SaveSelectionState
        )

        MainFrame.checkboxes[
            sectionKey
        ] =
            checkbox
    end

    local addonSettingsLabelY =
        startY
        + (
            columnRows
            * rowStep
        )
        - 12

    local minimapY =
        addonSettingsLabelY
        - 24

    CreateSectionLabel(
        frame,
        C.TEXT.LABEL_ADDON_SETTINGS,
        20,
        addonSettingsLabelY
    )

    local minimapCheckbox =
        CreateCheckbox(
            frame,
            C.TEXT.LABEL_SHOW_MINIMAP_ICON,
            20,
            minimapY
        )

    minimapCheckbox:SetScript(
        "OnClick",
        function(self)
            local commands =
                ns:GetModule(
                    "Commands"
                )

            if commands
                and type(
                    commands.SetMinimapButtonVisible
                ) == "function"
            then
                commands:SetMinimapButtonVisible(
                    self:GetChecked()
                    == true
                )
            elseif type(
                ns.SetMinimapIconVisible
            ) == "function"
            then
                ns:SetMinimapIconVisible(
                    self:GetChecked()
                    == true
                )
            end
        end
    )

    MainFrame.minimapCheckbox =
        minimapCheckbox

    local verboseY =
        minimapY
        + rowStep

    local buttonRowBottom =
        BOTTOM_PADDING

    local helpRowBottom =
        buttonRowBottom
        + BUTTON_ROW_HEIGHT
        + BUTTON_ROW_GAP

    local requiredFrameHeight =
        math.abs(
            verboseY
        )
        + CHECKBOX_HEIGHT
        + SETTINGS_TO_BUTTON_GAP
        + BUTTON_ROW_HEIGHT
        + BUTTON_ROW_GAP
        + BUTTON_ROW_HEIGHT
        + BOTTOM_PADDING

    if requiredFrameHeight
        > MIN_FRAME_HEIGHT
    then
        frame:SetSize(
            FRAME_WIDTH,
            requiredFrameHeight
        )
    end

    local verboseCheckbox =
        CreateCheckbox(
            frame,
            C.TEXT.LABEL_VERBOSE_ITEM_TYPES,
            20,
            verboseY
        )

    verboseCheckbox:SetScript(
        "OnClick",
        function(self)
            if type(
                ns.SetVerboseItemTypesEnabled
            ) == "function"
            then
                ns:SetVerboseItemTypesEnabled(
                    self:GetChecked()
                    == true
                )
            end
        end
    )

    MainFrame.verboseItemTypesCheckbox =
        verboseCheckbox

    UpdateSettingsCheckboxes()

    CreateButton(
        frame,
        100,
        BUTTON_ROW_HEIGHT,
        C.TEXT.BUTTON_HOW_TO_USE,
        20,
        helpRowBottom,
        function()
            local commands =
                ns:GetModule(
                    "Commands"
                )

            if commands
                and type(
                    commands.OpenGuide
                ) == "function"
            then
                commands:OpenGuide()
            end
        end
    )

    CreateButton(
        frame,
        100,
        BUTTON_ROW_HEIGHT,
        C.TEXT.BUTTON_BIOGRAPHY,
        128,
        helpRowBottom,
        function()
            local commands =
                ns:GetModule(
                    "Commands"
                )

            if commands
                and type(
                    commands.OpenBiography
                ) == "function"
            then
                commands:OpenBiography()
            end
        end
    )

    CreateButton(
        frame,
        100,
        BUTTON_ROW_HEIGHT,
        C.TEXT.BUTTON_SELECT_ALL,
        20,
        buttonRowBottom,
        function()
            ApplySelectionState(
                true
            )
        end
    )

    CreateButton(
        frame,
        100,
        BUTTON_ROW_HEIGHT,
        C.TEXT.BUTTON_CLEAR_ALL,
        128,
        buttonRowBottom,
        function()
            ApplySelectionState(
                false
            )
        end
    )

    CreateButton(
        frame,
        120,
        BUTTON_ROW_HEIGHT,
        C.TEXT.BUTTON_EXPORT,
        236,
        buttonRowBottom,
        function()
            SaveSelectionState()

            local commands =
                ns:GetModule(
                    "Commands"
                )

            if commands
                and type(
                    commands.RunExportFromSelection
                ) == "function"
            then
                commands:RunExportFromSelection(
                    GetSelectionState()
                )
            end
        end
    )

    CreateButton(
        frame,
        100,
        BUTTON_ROW_HEIGHT,
        C.TEXT.BUTTON_RELOAD_UI,
        364,
        buttonRowBottom,
        function()
            if type(
                ReloadUI
            ) == "function"
            then
                ReloadUI()
            end
        end
    )

    MainFrame.frame =
        frame

    return frame
end

function MainFrame:Show()
    local frame =
        EnsureFrame()

    for _, sectionKey
        in ipairs(
            MainFrame.uiSectionOrder
            or C.SECTION_ORDER
        )
    do
        SetCheckboxValue(
            MainFrame.checkboxes[
                sectionKey
            ],
            ResolveInitialSelection(
                sectionKey
            )
        )
    end

    UpdateSettingsCheckboxes()

    frame:Show()
end

function MainFrame:Hide()
    if self.frame
        and type(
            self.frame.Hide
        ) == "function"
    then
        self.frame:Hide()
    end
end

function MainFrame:Toggle()
    local frame =
        EnsureFrame()

    if frame:IsShown() then
        frame:Hide()
    else
        self:Show()
    end
end

function MainFrame:GetSelections()
    return
        GetSelectionState()
end

function MainFrame:Refresh()
    if not self.frame then
        return
    end

    for _, sectionKey
        in ipairs(
            MainFrame.uiSectionOrder
            or C.SECTION_ORDER
        )
    do
        SetCheckboxValue(
            MainFrame.checkboxes[
                sectionKey
            ],
            ResolveInitialSelection(
                sectionKey
            )
        )
    end

    UpdateSettingsCheckboxes()
end

ns:RegisterModule(
    "UI.MainFrame",
    MainFrame
)

ns.UI =
    ns.UI
    or {}

ns.UI.MainFrame =
    MainFrame