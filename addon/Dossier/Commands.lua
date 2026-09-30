local _, ns = ...

local C = ns.constants
local U = ns.utils

local Commands = {}

Commands.minimapButton = nil
Commands.isInitialized = false
Commands.lastError = nil
Commands.lastErrors = {}

local EXPORT_DIAGNOSTICS_ENABLED = true

local MINIMAP_BUTTON_DEFAULT_ANGLE = 225
local MINIMAP_BUTTON_EDGE_PADDING = 6

local MINIMAP_SHAPE_QUADRANTS = {
    ROUND = {
        true,
        true,
        true,
        true,
    },

    SQUARE = {
        false,
        false,
        false,
        false,
    },

    ["CORNER-TOPLEFT"] = {
        false,
        true,
        true,
        true,
    },

    ["CORNER-TOPRIGHT"] = {
        true,
        false,
        true,
        true,
    },

    ["CORNER-BOTTOMLEFT"] = {
        true,
        true,
        false,
        true,
    },

    ["CORNER-BOTTOMRIGHT"] = {
        true,
        true,
        true,
        false,
    },

    ["SIDE-LEFT"] = {
        false,
        true,
        true,
        false,
    },

    ["SIDE-RIGHT"] = {
        true,
        false,
        false,
        true,
    },

    ["SIDE-TOP"] = {
        false,
        false,
        true,
        true,
    },

    ["SIDE-BOTTOM"] = {
        true,
        true,
        false,
        false,
    },

    ["TRICORNER-TOPLEFT"] = {
        true,
        false,
        false,
        false,
    },

    ["TRICORNER-TOPRIGHT"] = {
        false,
        true,
        false,
        false,
    },

    ["TRICORNER-BOTTOMLEFT"] = {
        false,
        false,
        true,
        false,
    },

    ["TRICORNER-BOTTOMRIGHT"] = {
        false,
        false,
        false,
        true,
    },
}

local function SafeErrorString(value)
    local success, text =
        pcall(
            tostring,
            value
        )

    if success
        and type(text) == "string"
        and text ~= ""
    then
        return text
    end

    return "<unprintable error>"
end

local function CaptureStack()
    if type(debugstack) ~= "function" then
        return nil
    end

    local success, stack =
        pcall(
            debugstack,
            3,
            30,
            30
        )

    if success
        and type(stack) == "string"
        and stack ~= ""
    then
        return stack
    end

    return nil
end

local function ErrorHandler(errorValue)
    local message =
        SafeErrorString(
            errorValue
        )

    local stack =
        CaptureStack()

    if stack then
        return
            message
            .. "\n"
            .. stack
    end

    return message
end

local function FirstLine(value)
    local text =
        SafeErrorString(
            value
        )

    local line =
        string.match(
            text,
            "([^\r\n]+)"
        )

    return line
        or text
end

local function EmitDiagnostic(
    message,
    force
)
    if not force
        and not EXPORT_DIAGNOSTICS_ENABLED
    then
        return
    end

    local text =
        "[Dossier] "
        .. SafeErrorString(
            message
        )

    if DEFAULT_CHAT_FRAME
        and type(
            DEFAULT_CHAT_FRAME.AddMessage
        ) == "function"
    then
        local success =
            pcall(
                DEFAULT_CHAT_FRAME.AddMessage,
                DEFAULT_CHAT_FRAME,
                text
            )

        if success then
            return
        end
    end

    if type(print) == "function" then
        pcall(
            print,
            text
        )
    end
end

local function GetSectionLabel(
    sectionKey
)
    if C.SECTION_LABELS
        and C.SECTION_LABELS[
            sectionKey
        ]
    then
        return
            C.SECTION_LABELS[
                sectionKey
            ]
    end

    return SafeErrorString(
        sectionKey
    )
end

local function RecordError(
    errors,
    stage,
    sectionKey,
    errorValue
)
    local entry = {
        stage =
            stage,

        sectionKey =
            sectionKey,

        sectionLabel =
            sectionKey
            and GetSectionLabel(
                sectionKey
            )
            or nil,

        message =
            SafeErrorString(
                errorValue
            ),
    }

    Commands.lastError =
        entry

    Commands.lastErrors =
        errors

    table.insert(
        errors,
        entry
    )

    return entry
end

local function RunProtected(
    label,
    callback
)
    EmitDiagnostic(
        "START: "
        .. label
    )

    local success,
        value1,
        value2,
        value3,
        value4 =
        xpcall(
            callback,
            ErrorHandler
        )

    if not success then
        EmitDiagnostic(
            "ERROR: "
            .. label
            .. " - "
            .. FirstLine(
                value1
            ),
            true
        )

        return
            false,
            value1
    end

    EmitDiagnostic(
        "OK: "
        .. label
    )

    return
        true,
        value1,
        value2,
        value3,
        value4
end

local function AppendErrorSummary(
    output,
    errors
)
    if type(errors) ~= "table"
        or #errors == 0
    then
        return output
    end

    local lines = {}

    table.insert(
        lines,
        ""
    )

    table.insert(
        lines,
        ""
    )

    table.insert(
        lines,
        "Dossier Errors:"
    )

    for _, entry
        in ipairs(errors)
    do
        local label =
            entry.sectionLabel
            or entry.stage
            or "Unknown"

        table.insert(
            lines,
            string.format(
                "- %s [%s]: %s",
                label,
                entry.stage
                    or "unknown",
                FirstLine(
                    entry.message
                )
            )
        )
    end

    return
        (
            type(output) == "string"
            and output
            or ""
        )
        .. table.concat(
            lines,
            "\n"
        )
end

local function NormalizeAngle(angle)
    local value =
        U.ToSafeNumber(
            angle
        )

    if value == nil then
        value =
            MINIMAP_BUTTON_DEFAULT_ANGLE
    end

    local normalized =
        value % 360

    if normalized < 0 then
        normalized =
            normalized + 360
    end

    return normalized
end

local function ResolveMinimapShape()
    local shape =
        "ROUND"

    if type(GetMinimapShape)
        == "function"
    then
        local success,
            value =
            pcall(
                GetMinimapShape
            )

        if success
            and type(value) == "string"
            and value ~= ""
        then
            shape =
                value
        end
    end

    return shape
end

local function SetMinimapButtonAngle(
    button,
    angle,
    shouldPersist
)
    if not button
        or not Minimap
    then
        return
    end

    local normalizedAngle =
        NormalizeAngle(
            angle
        )

    local radians =
        math.rad(
            normalizedAngle
        )

    local xUnit =
        math.cos(
            radians
        )

    local yUnit =
        math.sin(
            radians
        )

    local minimapWidth =
        Minimap:GetWidth()
        or 0

    local minimapHeight =
        Minimap:GetHeight()
        or 0

    local radius =
        (
            math.min(
                minimapWidth,
                minimapHeight
            )
            / 2
        )
        + MINIMAP_BUTTON_EDGE_PADDING

    if radius
        <= MINIMAP_BUTTON_EDGE_PADDING
    then
        radius =
            70
    end

    local shape =
        ResolveMinimapShape()

    local quadrants =
        MINIMAP_SHAPE_QUADRANTS[
            shape
        ]
        or MINIMAP_SHAPE_QUADRANTS.ROUND

    local isTop =
        yUnit >= 0

    local isRight =
        xUnit >= 0

    local quadrantIndex

    if isTop then
        quadrantIndex =
            isRight
            and 1
            or 2
    else
        quadrantIndex =
            isRight
            and 4
            or 3
    end

    local isRoundedQuadrant =
        quadrants[
            quadrantIndex
        ]

    local x
    local y

    if isRoundedQuadrant then
        x =
            xUnit
            * radius

        y =
            yUnit
            * radius
    else
        local scale =
            radius
            / math.max(
                math.abs(
                    xUnit
                ),
                math.abs(
                    yUnit
                ),
                0.0001
            )

        x =
            xUnit
            * scale

        y =
            yUnit
            * scale
    end

    button:ClearAllPoints()

    button:SetPoint(
        "CENTER",
        Minimap,
        "CENTER",
        x,
        y
    )

    if shouldPersist ~= false then
        if type(
            ns.SetMinimapButtonAngle
        ) == "function"
        then
            ns:SetMinimapButtonAngle(
                normalizedAngle
            )
        elseif ns.state then
            ns.state.minimapButtonAngle =
                normalizedAngle
        end
    end
end

local function CalculateFallbackAngle(
    y,
    x
)
    if x == 0 then
        if y >= 0 then
            return 90
        end

        return -90
    end

    local angle =
        math.deg(
            math.atan(
                y / x
            )
        )

    if x < 0 then
        angle =
            angle + 180
    end

    return angle
end

local function GetCursorAngleFromMinimapCenter()
    if type(GetCursorPosition)
        ~= "function"
        or not Minimap
    then
        return
            MINIMAP_BUTTON_DEFAULT_ANGLE
    end

    local cursorX,
        cursorY =
        GetCursorPosition()

    cursorX =
        U.ToSafeNumber(
            cursorX
        )

    cursorY =
        U.ToSafeNumber(
            cursorY
        )

    local minimapScale =
        U.ToSafeNumber(
            Minimap:GetEffectiveScale()
        )

    local minimapX,
        minimapY =
        Minimap:GetCenter()

    minimapX =
        U.ToSafeNumber(
            minimapX
        )

    minimapY =
        U.ToSafeNumber(
            minimapY
        )

    if cursorX == nil
        or cursorY == nil
        or minimapScale == nil
        or minimapScale == 0
        or minimapX == nil
        or minimapY == nil
    then
        return
            MINIMAP_BUTTON_DEFAULT_ANGLE
    end

    local relativeX =
        (
            cursorX
            / minimapScale
        )
        - minimapX

    local relativeY =
        (
            cursorY
            / minimapScale
        )
        - minimapY

    if type(math.atan2)
        == "function"
    then
        return
            math.deg(
                math.atan2(
                    relativeY,
                    relativeX
                )
            )
    end

    return
        CalculateFallbackAngle(
            relativeY,
            relativeX
        )
end

local function GetCollector(
    sectionKey
)
    local data =
        ns.Data
        or {}

    local mapping = {
        [C.SECTIONS.ADDONS] =
            data.Addons,

        [C.SECTIONS.LOCATION] =
            data.Location,

        [C.SECTIONS.CHARACTER_STATS] =
            data.CharacterStats,

        [C.SECTIONS.CURRENCIES] =
            data.Currencies,

        [C.SECTIONS.COLLECTIONS] =
            data.Collections,

        [C.SECTIONS.BAGS] =
            data.Bags,

        [C.SECTIONS.BANK] =
            data.Bank,

        [C.SECTIONS.EQUIPMENT] =
            data.Equipment,

        [C.SECTIONS.LOCKOUTS] =
            data.Lockouts,

        [C.SECTIONS.PROGRESS] =
            data.Progress,

        [C.SECTIONS.ACHIEVEMENTS] =
            data.Achievements,

        [C.SECTIONS.COMPLETED_ACHIEVEMENTS] =
            data.CompletedAchievements,

        [C.SECTIONS.COLLECTED_APPEARANCES] =
            data.CollectedAppearances,

        [C.SECTIONS.APPEARANCES] =
            data.Appearances,

        [C.SECTIONS.REPUTATIONS] =
            data.Reputations,

        [C.SECTIONS.QUESTS] =
            data.Quests,

        [C.SECTIONS.COMPLETED_QUESTS] =
            data.CompletedQuests,

        [C.SECTIONS.SKILLS] =
            data.Skills,

        [C.SECTIONS.PROFESSION_DETAILS] =
            data.ProfessionDetails,

        [C.SECTIONS.TALENTS] =
            data.Talents,

        [C.SECTIONS.SPELLBOOK] =
            data.Spellbook,

        [C.SECTIONS.BIOGRAPHY] =
            data.Biography,

        [C.SECTIONS.KILLS] =
            data.Kills,

        [C.SECTIONS.SESSIONS] =
            data.Session,

        [C.SECTIONS.SHOPPING] =
            data.ShoppingList,

        [C.SECTIONS.STATISTICS] =
            data.Statistics,

        [C.SECTIONS.COMPANIONS] =
            ns.Companions,
    }

    return
        mapping[
            sectionKey
        ]
end

local function BuildExportData(
    selectedSections
)
    local exportData = {}
    local errors = {}

    Commands.lastError = nil
    Commands.lastErrors = errors

    for _, sectionKey
        in ipairs(
            C.SECTION_ORDER
        )
    do
        if U.IsSelected(
            selectedSections,
            sectionKey
        )
        then
            local collector =
                GetCollector(
                    sectionKey
                )

            local sectionLabel =
                GetSectionLabel(
                    sectionKey
                )

            if collector
                and type(
                    collector.Collect
                ) == "function"
            then
                local success,
                    result =
                    RunProtected(
                        "Collect "
                        .. sectionLabel,
                        function()
                            return
                                collector:Collect()
                        end
                    )

                if success then
                    exportData[
                        sectionKey
                    ] =
                        result
                else
                    RecordError(
                        errors,
                        "collector",
                        sectionKey,
                        result
                    )
                end
            else
                local message =
                    "Collector unavailable."

                EmitDiagnostic(
                    "ERROR: Collect "
                    .. sectionLabel
                    .. " - "
                    .. message,
                    true
                )

                RecordError(
                    errors,
                    "collector",
                    sectionKey,
                    message
                )
            end
        end
    end

    return
        exportData,
        errors
end

local function BuildFormattedOutput(
    formatter,
    sections,
    exportData,
    errors
)
    local success,
        result =
        RunProtected(
            "Format export",
            function()
                return
                    formatter:Build(
                        sections,
                        exportData
                    )
            end
        )

    if success
        and type(result) == "string"
    then
        return
            AppendErrorSummary(
                result,
                errors
            )
    end

    local errorMessage =
        success
        and "Formatter returned no text."
        or result

    RecordError(
        errors,
        "formatter",
        nil,
        errorMessage
    )

    local fallback =
        "Dossier\n"
        .. "\n"
        .. "[Export formatting failed.]"

    return
        AppendErrorSummary(
            fallback,
            errors
        )
end

local function GetMinimapIconTexturePath()
    return
        "Interface\\AddOns\\"
        .. (
            ns.name
            or "Dossier"
        )
        .. "\\Media\\MinimapIcon.tga"
end

local function EnsureMinimapButton()
    if Commands.minimapButton then
        return
            Commands.minimapButton
    end

    if not Minimap
        or type(CreateFrame)
            ~= "function"
    then
        return nil
    end

    local button =
        CreateFrame(
            "Button",
            "DossierMinimapButton",
            Minimap
        )

    button:SetSize(
        32,
        32
    )

    button:SetFrameStrata(
        "MEDIUM"
    )

    button:SetFrameLevel(
        8
    )

    button:SetMovable(
        true
    )

    button:RegisterForDrag(
        "LeftButton"
    )

    button.isDragging =
        false

    local icon =
        button:CreateTexture(
            nil,
            "ARTWORK"
        )

    icon:SetSize(
        20,
        20
    )

    icon:SetPoint(
        "CENTER"
    )

    icon:SetTexture(
        GetMinimapIconTexturePath()
    )

    local overlay =
        button:CreateTexture(
            nil,
            "OVERLAY"
        )

    overlay:SetSize(
        53,
        53
    )

    overlay:SetPoint(
        "TOPLEFT"
    )

    overlay:SetTexture(
        "Interface\\Minimap\\MiniMap-TrackingBorder"
    )

    button:RegisterForClicks(
        "LeftButtonUp",
        "RightButtonUp"
    )

    button:SetScript(
        "OnClick",
        function(self, mouseButton)
            if self.isDragging then
                self.isDragging =
                    false

                return
            end

            if mouseButton == "RightButton" then
                Commands:ToggleKillPanel()
                return
            end

            Commands:OpenMainUI()
        end
    )

    button:SetScript(
        "OnDragStart",
        function(self)
            self.isDragging =
                true

            self:SetScript(
                "OnUpdate",
                function()
                    SetMinimapButtonAngle(
                        self,
                        GetCursorAngleFromMinimapCenter(),
                        false
                    )
                end
            )
        end
    )

    button:SetScript(
        "OnDragStop",
        function(self)
            self:SetScript(
                "OnUpdate",
                nil
            )

            local angle =
                GetCursorAngleFromMinimapCenter()

            SetMinimapButtonAngle(
                self,
                angle,
                true
            )
        end
    )

    button:SetScript(
        "OnEnter",
        function(self)
            if not GameTooltip then
                return
            end

            GameTooltip:SetOwner(
                self,
                "ANCHOR_LEFT"
            )

            GameTooltip:SetText(
                C.ADDON_TITLE
                or "Dossier"
            )

            GameTooltip:AddLine(
                C.TEXT.MINIMAP_LEFT_CLICK,
                1,
                1,
                1
            )

            GameTooltip:AddLine(
                C.TEXT.MINIMAP_RIGHT_CLICK,
                1,
                1,
                1
            )

            GameTooltip:Show()
        end
    )

    button:SetScript(
        "OnLeave",
        function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end
    )

    local savedAngle = nil

    if ns.state
        and ns.state.db
    then
        savedAngle =
            ns.state.db.minimapButtonAngle
    end

    if savedAngle == nil
        and type(
            ns.GetMinimapButtonAngle
        ) == "function"
    then
        savedAngle =
            ns:GetMinimapButtonAngle()
    end

    if savedAngle == nil
        and ns.state
    then
        savedAngle =
            ns.state.minimapButtonAngle
    end

    SetMinimapButtonAngle(
        button,
        savedAngle
            or MINIMAP_BUTTON_DEFAULT_ANGLE,
        false
    )

    local isVisible =
        true

    if type(
        ns.IsMinimapIconVisible
    ) == "function"
    then
        isVisible =
            ns:IsMinimapIconVisible()
    end

    if isVisible then
        button:Show()
    else
        button:Hide()
    end

    Commands.minimapButton =
        button

    return button
end

local function RestoreMinimapButtonAngleDeferred(
    angle
)
    local restoreAngle =
        U.ToSafeNumber(
            angle
        )

    if restoreAngle == nil
        and type(
            ns.GetMinimapButtonAngle
        ) == "function"
    then
        restoreAngle =
            U.ToSafeNumber(
                ns:GetMinimapButtonAngle()
            )
    end

    if restoreAngle == nil
        and ns.state
    then
        restoreAngle =
            U.ToSafeNumber(
                ns.state.minimapButtonAngle
            )
    end

    restoreAngle =
        restoreAngle
        or MINIMAP_BUTTON_DEFAULT_ANGLE

    local button =
        EnsureMinimapButton()

    if not button then
        return
    end

    if C_Timer
        and type(
            C_Timer.After
        ) == "function"
    then
        C_Timer.After(
            0,
            function()
                if Commands.minimapButton then
                    SetMinimapButtonAngle(
                        Commands.minimapButton,
                        restoreAngle,
                        false
                    )
                end
            end
        )

        C_Timer.After(
            0.2,
            function()
                if Commands.minimapButton then
                    SetMinimapButtonAngle(
                        Commands.minimapButton,
                        restoreAngle,
                        false
                    )
                end
            end
        )

        return
    end

    SetMinimapButtonAngle(
        button,
        restoreAngle,
        false
    )
end

function Commands:RunExportFromSelection(
    selectedSections
)
    local formatter =
        ns.Formatters
        and ns.Formatters.TextFormatter

    local exportFrame =
        ns.UI
        and ns.UI.ExportFrame

    local mainFrame =
        ns.UI
        and ns.UI.MainFrame

    if not formatter
        or type(
            formatter.Build
        ) ~= "function"
        or not exportFrame
        or type(
            exportFrame.ShowText
        ) ~= "function"
    then
        EmitDiagnostic(
            "ERROR: Export infrastructure unavailable.",
            true
        )

        return
    end

    local sections =
        type(selectedSections)
            == "table"
        and selectedSections
        or {}

    if type(
        ns.SetSelectedSections
    ) == "function"
    then
        local success,
            errorMessage =
            xpcall(
                function()
                    ns:SetSelectedSections(
                        sections
                    )
                end,
                ErrorHandler
            )

        if not success then
            EmitDiagnostic(
                "ERROR: Save selected sections - "
                .. FirstLine(
                    errorMessage
                ),
                true
            )
        end
    end

    EmitDiagnostic(
        "Export started."
    )

    if type(ns.FilterSelectionsByFeature) == "function" then
        sections =
            ns:FilterSelectionsByFeature(
                sections
            )
    end

    local exportData,
        errors =
        BuildExportData(
            sections
        )

    local output

    local refreshScheduled =
        false

    local function ScheduleExportRefresh()
        if refreshScheduled then
            return
        end

        refreshScheduled =
            true

        local function Refresh()
            refreshScheduled =
                false

            output =
                BuildFormattedOutput(
                    formatter,
                    sections,
                    exportData,
                    errors
                )

            local showSuccess,
                showError =
                xpcall(
                    function()
                        exportFrame:ShowText(
                            output
                        )
                    end,
                    ErrorHandler
                )

            if not showSuccess then
                RecordError(
                    errors,
                    "export-ui",
                    nil,
                    showError
                )

                EmitDiagnostic(
                    "ERROR: Show refreshed export - "
                    .. FirstLine(
                        showError
                    ),
                    true
                )
            end
        end

        if C_Timer
            and type(
                C_Timer.After
            ) == "function"
        then
            C_Timer.After(
                0,
                function()
                    local success,
                        errorMessage =
                        xpcall(
                            Refresh,
                            ErrorHandler
                        )

                    if not success then
                        refreshScheduled =
                            false

                        RecordError(
                            errors,
                            "async-refresh",
                            nil,
                            errorMessage
                        )

                        EmitDiagnostic(
                            "ERROR: Async export refresh - "
                            .. FirstLine(
                                errorMessage
                            ),
                            true
                        )
                    end
                end
            )
        else
            local success,
                errorMessage =
                xpcall(
                    Refresh,
                    ErrorHandler
                )

            if not success then
                refreshScheduled =
                    false

                RecordError(
                    errors,
                    "refresh",
                    nil,
                    errorMessage
                )

                EmitDiagnostic(
                    "ERROR: Export refresh - "
                    .. FirstLine(
                        errorMessage
                    ),
                    true
                )
            end
        end
    end

    local function RefreshExportAfterItemLoad()
        ScheduleExportRefresh()
    end

    if type(
        U.ResolveMissingItemLevels
    ) == "function"
    then
        local success,
            errorMessage =
            RunProtected(
                "Resolve missing item levels",
                function()
                    U.ResolveMissingItemLevels(
                        exportData,
                        RefreshExportAfterItemLoad
                    )
                end
            )

        if not success then
            RecordError(
                errors,
                "item-level-resolver",
                nil,
                errorMessage
            )
        end
    end

    local completedQuestsCollector =
        GetCollector(
            C.SECTIONS.COMPLETED_QUESTS
        )

    if U.IsSelected(
        sections,
        C.SECTIONS.COMPLETED_QUESTS
    )
        and completedQuestsCollector
        and type(
            completedQuestsCollector.HasPendingTitleLoads
        ) == "function"
        and type(
            completedQuestsCollector.OnTitlesReady
        ) == "function"
    then
        local pendingSuccess,
            hasPending =
            RunProtected(
                "Check completed quest title loads",
                function()
                    return
                        completedQuestsCollector:
                            HasPendingTitleLoads()
                end
            )

        if pendingSuccess
            and hasPending == true
        then
            EmitDiagnostic(
                "Waiting for completed quest titles."
            )

            local callbackSuccess,
                callbackError =
                RunProtected(
                    "Register completed quest title refresh",
                    function()
                        completedQuestsCollector:
                            OnTitlesReady(
                                function()
                                    local collectSuccess,
                                        result =
                                        RunProtected(
                                            "Refresh completed quest titles",
                                            function()
                                                return
                                                    completedQuestsCollector:
                                                        Collect()
                                            end
                                        )

                                    if collectSuccess then
                                        exportData[
                                            C.SECTIONS.COMPLETED_QUESTS
                                        ] =
                                            result

                                        EmitDiagnostic(
                                            "Completed quest titles refreshed."
                                        )

                                        ScheduleExportRefresh()
                                    else
                                        RecordError(
                                            errors,
                                            "completed-quest-refresh",
                                            C.SECTIONS.COMPLETED_QUESTS,
                                            result
                                        )
                                    end
                                end
                            )
                    end
                )

            if not callbackSuccess then
                RecordError(
                    errors,
                    "completed-quest-refresh",
                    C.SECTIONS.COMPLETED_QUESTS,
                    callbackError
                )
            end
        end
    end

    output =
        BuildFormattedOutput(
            formatter,
            sections,
            exportData,
            errors
        )

    if type(
        exportFrame.SetReopenMainOnClose
    ) == "function"
    then
        local success,
            errorMessage =
            xpcall(
                function()
                    exportFrame:SetReopenMainOnClose(
                        true
                    )
                end,
                ErrorHandler
            )

        if not success then
            RecordError(
                errors,
                "export-ui",
                nil,
                errorMessage
            )

            EmitDiagnostic(
                "ERROR: Configure export window - "
                .. FirstLine(
                    errorMessage
                ),
                true
            )
        end
    end

    if mainFrame
        and type(
            mainFrame.Hide
        ) == "function"
    then
        local success,
            errorMessage =
            xpcall(
                function()
                    mainFrame:Hide()
                end,
                ErrorHandler
            )

        if not success then
            RecordError(
                errors,
                "main-ui",
                nil,
                errorMessage
            )

            EmitDiagnostic(
                "ERROR: Hide main window - "
                .. FirstLine(
                    errorMessage
                ),
                true
            )
        end
    end

    local showSuccess,
        showError =
        xpcall(
            function()
                exportFrame:ShowText(
                    output
                )
            end,
            ErrorHandler
        )

    if not showSuccess then
        RecordError(
            errors,
            "export-ui",
            nil,
            showError
        )

        EmitDiagnostic(
            "ERROR: Show export - "
            .. FirstLine(
                showError
            ),
            true
        )

        return
    end

    EmitDiagnostic(
        string.format(
            "Export finished with %d error(s).",
            #errors
        )
    )
end

function Commands:OpenMainUI()
    local mainFrame =
        ns.UI
        and ns.UI.MainFrame

    if mainFrame
        and type(
            mainFrame.Toggle
        ) == "function"
    then
        local success,
            errorMessage =
            xpcall(
                function()
                    mainFrame:Toggle()
                end,
                ErrorHandler
            )

        if not success then
            Commands.lastError = {
                stage =
                    "main-ui",

                message =
                    SafeErrorString(
                        errorMessage
                    ),
            }

            EmitDiagnostic(
                "ERROR: Open main UI - "
                .. FirstLine(
                    errorMessage
                ),
                true
            )
        end
    end
end

function Commands:Initialize()
    if self.isInitialized then
        return
    end

    if not ns.state
        or not ns.state.db
    then
        return
    end

    self.isInitialized =
        true

    local success,
        errorMessage =
        xpcall(
            EnsureMinimapButton,
            ErrorHandler
        )

    if not success then
        self.lastError = {
            stage =
                "minimap",

            message =
                SafeErrorString(
                    errorMessage
                ),
        }

        EmitDiagnostic(
            "ERROR: Initialize minimap button - "
            .. FirstLine(
                errorMessage
            ),
            true
        )
    end
end

function Commands:ApplyMinimapButtonAngle(
    angle
)
    local button =
        EnsureMinimapButton()

    if not button then
        return
    end

    SetMinimapButtonAngle(
        button,
        angle
            or MINIMAP_BUTTON_DEFAULT_ANGLE,
        false
    )
end

function Commands:RestoreMinimapButtonAngleDeferred(
    angle
)
    RestoreMinimapButtonAngleDeferred(
        angle
    )
end

function Commands:SetMinimapButtonVisible(
    isVisible
)
    local button =
        EnsureMinimapButton()

    local visible =
        isVisible ~= false

    if type(
        ns.SetMinimapIconVisible
    ) == "function"
    then
        ns:SetMinimapIconVisible(
            visible
        )
    end

    if not button then
        return
    end

    if visible then
        button:Show()
    else
        button:Hide()
    end
end

function Commands:IsMinimapButtonVisible()
    if type(
        ns.IsMinimapIconVisible
    ) == "function"
    then
        return
            ns:IsMinimapIconVisible()
    end

    return true
end

function Commands:OpenGuide()
    local exportFrame =
        ns.UI
        and ns.UI.ExportFrame

    local mainFrame =
        ns.UI
        and ns.UI.MainFrame

    local guide =
        ns.Guide

    if not exportFrame
        or type(
            exportFrame.ShowText
        ) ~= "function"
        or not guide
        or type(
            guide.GetText
        ) ~= "function"
    then
        EmitDiagnostic(
            "ERROR: Guide unavailable.",
            true
        )

        return
    end

    local success,
        errorMessage =
        xpcall(
            function()
                if mainFrame
                    and type(
                        mainFrame.IsShown
                    ) == "function"
                    and mainFrame:IsShown()
                then
                    exportFrame:SetReopenMainOnClose(
                        true
                    )

                    mainFrame:Hide()
                end

                exportFrame:ShowText(
                    guide:GetText(),
                    C.TEXT.GUIDE_WINDOW_TITLE
                )
            end,
            ErrorHandler
        )

    if not success then
        EmitDiagnostic(
            "ERROR: Open guide - "
            .. FirstLine(
                errorMessage
            ),
            true
        )
    end
end

function Commands:OpenTab(
    tabId
)
    local mainFrame =
        ns.UI
        and ns.UI.MainFrame

    if not mainFrame
        or type(
            mainFrame.ShowTab
        ) ~= "function"
    then
        EmitDiagnostic(
            "ERROR: Main window unavailable.",
            true
        )

        return
    end

    local success,
        errorMessage =
        xpcall(
            function()
                mainFrame:ShowTab(
                    tabId
                )
            end,
            ErrorHandler
        )

    if not success then
        EmitDiagnostic(
            "ERROR: Open "
            .. SafeErrorString(
                tabId
            )
            .. " tab - "
            .. FirstLine(
                errorMessage
            ),
            true
        )
    end
end

local function PrintLine(text)
    if DEFAULT_CHAT_FRAME
        and type(DEFAULT_CHAT_FRAME.AddMessage) == "function"
    then
        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, text)
    end
end

-- Runs `action` when the feature is on, otherwise says how to turn it on.
local function IfFeatureOn(id, action)
    if ns:IsFeatureOn(id) then
        action()
    else
        ns.Features.PrintOff(id)
    end
end

function Commands:OpenOptions()
    self:OpenTab("options")
end

function Commands:OpenSettings()
    local page = ns.UI and ns.UI.SettingsPanel

    if not page or not page:Open() then
        self:OpenOptions()
    end
end

function Commands:SetFeature(name, on)
    local feature = ns.Features.Find(name)

    if not feature then
        PrintLine(string.format(C.TEXT.FEATURE_UNKNOWN, SafeErrorString(name)))
        return false
    end

    ns:SetFeatureOn(feature.id, on)
    PrintLine(string.format(on and C.TEXT.FEATURE_TURNED_ON or C.TEXT.FEATURE_TURNED_OFF, feature.label))

    return true
end

function Commands:OpenBiography()
    self:OpenTab(
        "biography"
    )
end

function Commands:OpenHelp()
    self:OpenTab(
        "help"
    )
end

function Commands:OpenCompanions()
    self:OpenTab(
        "companions"
    )
end

function Commands:OpenKills()
    self:OpenTab("kills")
end

function Commands:OpenSession()
    self:OpenTab("session")
end

function Commands:OpenScreenshotter()
    self:OpenTab("screenshots")
end

function Commands:OpenShopping()
    self:OpenTab("shopping")
end

function Commands:TakeScreenshot()
    local shots = ns.Data and ns.Data.Screenshotter

    if not shots then
        EmitDiagnostic("ERROR: Screenshotter unavailable.", true)
        return
    end

    local success, errorMessage = xpcall(function()
        shots:TakeNow(C.TEXT.SHOTS_REASON_MANUAL)
    end, ErrorHandler)

    if not success then
        EmitDiagnostic("ERROR: Screenshotter - " .. FirstLine(errorMessage), true)
    end
end

function Commands:ToggleKillPanel()
    local panel = ns.UI and ns.UI.KillPanel

    if not panel then
        EmitDiagnostic("ERROR: Session panel unavailable.", true)
        return
    end

    local success, errorMessage = xpcall(function()
        panel:Toggle()
    end, ErrorHandler)

    if not success then
        EmitDiagnostic("ERROR: Session panel - " .. FirstLine(errorMessage), true)
    end
end

SLASH_DOSSIER1 =
    C.SLASH_COMMAND

SLASH_DOSSIER2 =
    C.SLASH_ALIAS

SlashCmdList[
    "DOSSIER"
] =
    function(message)
        local argument =
            string.lower(
                U.Trim(
                    U.SafeString(
                        message,
                        ""
                    )
                )
            )

        local verb, featureName =
            string.match(argument, "^(%S+)%s+(%S+)$")

        if verb == "on" or verb == "off" then
            Commands:SetFeature(featureName, verb == "on")
        elseif argument == "options"
            or argument == "features"
            or argument == "on"
            or argument == "off"
        then
            Commands:OpenOptions()
        elseif argument == "settings"
            or argument == "config"
        then
            Commands:OpenSettings()
        elseif argument == "help"
            or argument == "guide"
        then
            Commands:OpenHelp()
        elseif argument == "bio"
            or argument == "biography"
        then
            IfFeatureOn("biography", function() Commands:OpenBiography() end)
        elseif argument == "companions"
        then
            IfFeatureOn("companions", function() Commands:OpenCompanions() end)
        elseif argument == "kills"
        then
            IfFeatureOn("kills", function() Commands:OpenKills() end)
        elseif argument == "session"
            or argument == "sessions"
        then
            IfFeatureOn("session", function() Commands:OpenSession() end)
        elseif argument == "panel"
        then
            Commands:ToggleKillPanel()
        elseif argument == "shop"
            or argument == "shopping"
        then
            IfFeatureOn("shopping", function() Commands:OpenShopping() end)
        elseif argument == "shots"
            or argument == "screenshotter"
        then
            IfFeatureOn("screenshots", function() Commands:OpenScreenshotter() end)
        elseif argument == "shot"
        then
            IfFeatureOn("screenshots", function() Commands:TakeScreenshot() end)
        else
            Commands:OpenMainUI()
        end
    end

ns:RegisterModule(
    "Commands",
    Commands
)