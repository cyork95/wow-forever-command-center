local _, ns = ...

local C = ns.constants

local ExportFrame = {}

ExportFrame.frame = nil
ExportFrame.header = nil
ExportFrame.editBox = nil
ExportFrame.scrollFrame = nil
ExportFrame.updateLayout = nil
ExportFrame.sizeBar = nil
ExportFrame.lastTokens = nil
ExportFrame.reopenMainOnClose = false

local FRAME_WIDTH = 760
local FRAME_HEIGHT = 540
local MIN_TEXT_WIDTH = 100
local SIZE_BAR_HEIGHT = 40
local LARGEST_SECTION_COUNT = 3

local function CreateWindow()
    local Theme = ns.Theme
    local frame = Theme.CreateWindow("DossierExportFrame", FRAME_WIDTH, FRAME_HEIGHT)
    local header = Theme.CreateHeader(frame, C.TEXT.EXPORT_WINDOW_TITLE, C.TEXT.LABEL_EXPORT_HINT)

    return frame, header
end

local function CreateSizeBar(parent)
    local Theme = ns.Theme

    local bar = Theme.CreatePanel(parent, "card", "border")
    bar:SetPoint("TOPLEFT", 14, -(Theme.HEADER_HEIGHT + 10))
    bar:SetPoint("TOPRIGHT", -14, -(Theme.HEADER_HEIGHT + 10))
    bar:SetHeight(SIZE_BAR_HEIGHT)

    local estimate = Theme.CreateText(bar, "GameFontNormal", "accent")
    estimate:SetPoint("TOPLEFT", 10, -7)

    local note = Theme.CreateText(bar, "GameFontHighlightSmall", "muted")
    note:SetPoint("TOPLEFT", estimate, "BOTTOMLEFT", 0, -3)

    local largest = Theme.CreateText(bar, "GameFontHighlightSmall", "muted")
    largest:SetPoint("RIGHT", -10, 0)
    largest:SetJustifyH("RIGHT")

    bar.estimate = estimate
    bar.note = note
    bar.largest = largest

    return bar
end

local function FormatThousands(value)
    local text = tostring(math.floor(value or 0))
    local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (formatted:gsub("^,", ""))
end

local function UpdateSizeBar(bar, text)
    local Theme = ns.Theme
    local formatter = ns.Formatters and ns.Formatters.TextFormatter
    local characters = #(text or "")
    local tokens = math.ceil(characters / (C.CHARACTERS_PER_TOKEN or 4))

    if formatter and type(formatter.EstimateTokens) == "function" then
        tokens = formatter.EstimateTokens(characters)
    end

    local color, note = "accent", C.TEXT.LABEL_TOKEN_SMALL

    if tokens > C.TOKENS_MEDIUM then
        color, note = "danger", C.TEXT.LABEL_TOKEN_LARGE
    elseif tokens > C.TOKENS_SMALL then
        color, note = "warning", C.TEXT.LABEL_TOKEN_MEDIUM
    end

    bar.estimate:SetText(string.format(
        C.TEXT.LABEL_TOKEN_ESTIMATE,
        FormatThousands(tokens),
        FormatThousands(characters)
    ))
    bar.estimate:SetTextColor(Theme.Color(color))

    local stats = formatter and type(formatter.GetLastStats) == "function" and formatter:GetLastStats()
    local readiness = ns.Data and ns.Data.Readiness

    if readiness and type(stats) == "table" and type(stats.selections) == "table" then
        local ok, result = pcall(readiness.GetMissingData, readiness, stats.selections)
        local labels = ok and readiness:MissingLabels(result) or {}

        if #labels > 0 then
            note = note .. "  " .. string.format(C.TEXT.LABEL_MISSING, table.concat(labels, ", "))
        end
    end

    bar.note:SetText(note)
    local parts = {}

    for index, size in ipairs(stats and stats.sections or {}) do
        if index > LARGEST_SECTION_COUNT then
            break
        end

        table.insert(parts, string.format("%s %s", size.title, FormatThousands(size.tokens)))
    end

    bar.largest:SetText(#parts > 0 and string.format(C.TEXT.LABEL_TOKEN_LARGEST, table.concat(parts, ", ")) or "")

    ExportFrame.lastTokens = tokens

    return tokens
end

local function CreateScrollArea(parent)
    local Theme = ns.Theme

    local box = Theme.CreatePanel(parent, "dark", "border")
    box:SetPoint("TOPLEFT", 14, -(Theme.HEADER_HEIGHT + SIZE_BAR_HEIGHT + 18))
    box:SetPoint("BOTTOMRIGHT", -14, 14)

    local scrollFrame = CreateFrame(
        "ScrollFrame",
        "DossierExportScrollFrame",
        box,
        "UIPanelScrollFrameTemplate"
    )
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local editBox = CreateFrame("EditBox", "DossierExportEditBox", scrollFrame)
    local textMeasure = scrollFrame:CreateFontString(nil, "ARTWORK", "ChatFontNormal")

    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetJustifyH("LEFT")
    editBox:SetJustifyV("TOP")
    editBox:SetTextInsets(4, 4, 4, 4)
    editBox:SetTextColor(Theme.Color("text"))
    editBox:SetPoint("TOPLEFT")
    editBox:SetPoint("TOPRIGHT")
    editBox:SetWidth(680)
    editBox:SetHeight(1)

    textMeasure:SetJustifyH("LEFT")
    textMeasure:SetJustifyV("TOP")

    local function UpdateEditBoxLayout()
        local width = scrollFrame:GetWidth() - 8

        if width < MIN_TEXT_WIDTH then
            width = MIN_TEXT_WIDTH
        end

        editBox:SetWidth(width)
        textMeasure:SetWidth(math.max(width - 8, 1))
        textMeasure:SetText(editBox:GetText() or "")

        local textHeight = textMeasure:GetStringHeight() or 0
        local minimumHeight = scrollFrame:GetHeight()

        editBox:SetHeight(math.max(textHeight + 8, minimumHeight))

        if type(scrollFrame.UpdateScrollChildRect) == "function" then
            scrollFrame:UpdateScrollChildRect()
        end
    end

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        parent:Hide()
    end)

    editBox:SetScript("OnTextChanged", function()
        UpdateEditBoxLayout()
    end)

    scrollFrame:SetScript("OnSizeChanged", function()
        UpdateEditBoxLayout()
    end)

    scrollFrame:SetScrollChild(editBox)

    UpdateEditBoxLayout()

    return scrollFrame, editBox, UpdateEditBoxLayout
end

local function ReopenMainFrameIfNeeded()
    if not ExportFrame.reopenMainOnClose then
        return
    end

    ExportFrame.reopenMainOnClose = false

    local mainFrame = ns.UI and ns.UI.MainFrame

    if mainFrame and type(mainFrame.Show) == "function" then
        mainFrame:Show()
    end
end

local function EnsureFrame()
    if ExportFrame.frame and ExportFrame.editBox then
        return ExportFrame.frame, ExportFrame.editBox
    end

    local frame, header = CreateWindow()
    local sizeBar = CreateSizeBar(frame)
    local scrollFrame, editBox, updateLayout = CreateScrollArea(frame)

    ExportFrame.sizeBar = sizeBar

    frame:SetScript("OnHide", function()
        editBox:ClearFocus()
        ReopenMainFrameIfNeeded()
    end)

    ExportFrame.frame = frame
    ExportFrame.header = header
    ExportFrame.scrollFrame = scrollFrame
    ExportFrame.editBox = editBox
    ExportFrame.updateLayout = updateLayout

    return frame, editBox
end

function ExportFrame:SetReopenMainOnClose(enabled)
    self.reopenMainOnClose = enabled == true
end

function ExportFrame:ShowText(text, title, recordSize)
    local frame, editBox = EnsureFrame()

    self.header.title:SetText(title or C.TEXT.EXPORT_WINDOW_TITLE)

    frame:Show()
    editBox:SetText(text or "")

    -- The guide reuses this window. Its length must not replace the last export's size.
    if recordSize ~= false then
        if self.sizeBar then
            self.sizeBar:Show()
        end

        UpdateSizeBar(self.sizeBar, text)

        local mainFrame = ns.UI and ns.UI.MainFrame

        if mainFrame and type(mainFrame.SetLastExportTokens) == "function" then
            mainFrame:SetLastExportTokens(self.lastTokens)
        end
    elseif self.sizeBar then
        self.sizeBar:Hide()
    end

    if type(self.updateLayout) == "function" then
        self.updateLayout()
    end

    editBox:HighlightText()
    editBox:SetFocus()
    self.scrollFrame:SetVerticalScroll(0)

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, function()
            if not self.frame or not self.frame:IsShown() then
                return
            end

            if type(self.updateLayout) == "function" then
                self.updateLayout()
            end

            self.scrollFrame:SetVerticalScroll(0)
        end)
    end
end

function ExportFrame:Hide()
    if not self.frame then
        return
    end

    if self.editBox then
        self.editBox:ClearFocus()
    end

    self.frame:Hide()
end

function ExportFrame:IsShown()
    return self.frame ~= nil and self.frame:IsShown()
end

function ExportFrame:GetText()
    if not self.editBox then
        return nil
    end

    return self.editBox:GetText()
end

ns:RegisterModule("UI.ExportFrame", ExportFrame)

ns.UI = ns.UI or {}
ns.UI.ExportFrame = ExportFrame
