local _, ns = ...

local C = ns.constants

local ExportFrame = {}

ExportFrame.frame = nil
ExportFrame.editBox = nil
ExportFrame.scrollFrame = nil
ExportFrame.updateLayout = nil
ExportFrame.reopenMainOnClose = false

local FRAME_WIDTH = 760
local FRAME_HEIGHT = 520
local MIN_TEXT_WIDTH = 100

local function CreateBackdropFrame()
    local frame =
        CreateFrame(
            "Frame",
            "AIExportExportFrame",
            UIParent,
            "BasicFrameTemplateWithInset"
        )

    frame:SetSize(
        FRAME_WIDTH,
        FRAME_HEIGHT
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
            C.TEXT.EXPORT_WINDOW_TITLE
        )
    end

    return frame
end

local function CreateScrollArea(parent)
    local scrollFrame =
        CreateFrame(
            "ScrollFrame",
            "AIExportExportScrollFrame",
            parent,
            "UIPanelScrollFrameTemplate"
        )

    scrollFrame:SetPoint(
        "TOPLEFT",
        16,
        -32
    )

    scrollFrame:SetPoint(
        "BOTTOMRIGHT",
        -30,
        16
    )

    local editBox =
        CreateFrame(
            "EditBox",
            "AIExportExportEditBox",
            scrollFrame
        )

    local textMeasure =
        scrollFrame:CreateFontString(
            nil,
            "ARTWORK",
            "ChatFontNormal"
        )

    editBox:SetMultiLine(
        true
    )

    editBox:SetAutoFocus(
        false
    )

    editBox:SetFontObject(
        ChatFontNormal
    )

    editBox:SetJustifyH(
        "LEFT"
    )

    editBox:SetJustifyV(
        "TOP"
    )

    editBox:SetTextInsets(
        4,
        4,
        4,
        4
    )

    editBox:SetPoint(
        "TOPLEFT"
    )

    editBox:SetPoint(
        "TOPRIGHT"
    )

    editBox:SetWidth(
        680
    )

    editBox:SetHeight(
        1
    )

    textMeasure:SetJustifyH(
        "LEFT"
    )

    textMeasure:SetJustifyV(
        "TOP"
    )

    local function UpdateEditBoxLayout()
        local width =
            scrollFrame:GetWidth()
            - 24

        if width < MIN_TEXT_WIDTH then
            width =
                MIN_TEXT_WIDTH
        end

        editBox:SetWidth(
            width
        )

        textMeasure:SetWidth(
            math.max(
                width - 8,
                1
            )
        )

        textMeasure:SetText(
            editBox:GetText()
            or ""
        )

        local textHeight =
            textMeasure:GetStringHeight()
            or 0

        local minimumHeight =
            scrollFrame:GetHeight()

        editBox:SetHeight(
            math.max(
                textHeight + 8,
                minimumHeight
            )
        )

        if type(
            scrollFrame.UpdateScrollChildRect
        ) == "function"
        then
            scrollFrame:UpdateScrollChildRect()
        end
    end

    editBox:SetScript(
        "OnEscapePressed",
        function(self)
            self:ClearFocus()
            parent:Hide()
        end
    )

    editBox:SetScript(
        "OnTextChanged",
        function()
            UpdateEditBoxLayout()
        end
    )

    scrollFrame:SetScript(
        "OnSizeChanged",
        function()
            UpdateEditBoxLayout()
        end
    )

    scrollFrame:SetScrollChild(
        editBox
    )

    UpdateEditBoxLayout()

    return
        scrollFrame,
        editBox,
        UpdateEditBoxLayout
end

local function ReopenMainFrameIfNeeded()
    if not ExportFrame.reopenMainOnClose then
        return
    end

    ExportFrame.reopenMainOnClose =
        false

    local mainFrame =
        ns.UI
        and ns.UI.MainFrame

    if mainFrame
        and type(
            mainFrame.Show
        ) == "function"
    then
        mainFrame:Show()
    end
end

local function EnsureFrame()
    if ExportFrame.frame
        and ExportFrame.editBox
    then
        return
            ExportFrame.frame,
            ExportFrame.editBox
    end

    local frame =
        CreateBackdropFrame()

    local scrollFrame,
        editBox,
        updateLayout =
        CreateScrollArea(
            frame
        )

    frame:SetScript(
        "OnHide",
        function()
            if editBox
                and type(
                    editBox.ClearFocus
                ) == "function"
            then
                editBox:ClearFocus()
            end

            ReopenMainFrameIfNeeded()
        end
    )

    ExportFrame.frame =
        frame

    ExportFrame.scrollFrame =
        scrollFrame

    ExportFrame.editBox =
        editBox

    ExportFrame.updateLayout =
        updateLayout

    return
        frame,
        editBox
end

function ExportFrame:SetReopenMainOnClose(
    enabled
)
    self.reopenMainOnClose =
        enabled == true
end

function ExportFrame:ShowText(
    text,
    title
)
    local frame,
        editBox =
        EnsureFrame()

    if frame.TitleText
        and type(
            frame.TitleText.SetText
        ) == "function"
    then
        frame.TitleText:SetText(
            title
            or C.TEXT.EXPORT_WINDOW_TITLE
        )
    end

    frame:Show()

    editBox:SetText(
        text
        or ""
    )

    if type(
        self.updateLayout
    ) == "function"
    then
        self.updateLayout()
    end

    editBox:HighlightText()
    editBox:SetFocus()

    if self.scrollFrame
        and type(
            self.scrollFrame.SetVerticalScroll
        ) == "function"
    then
        self.scrollFrame:SetVerticalScroll(
            0
        )
    end

    if C_Timer
        and type(
            C_Timer.After
        ) == "function"
    then
        C_Timer.After(
            0,
            function()
                if not self.frame
                    or not self.frame:IsShown()
                then
                    return
                end

                if type(
                    self.updateLayout
                ) == "function"
                then
                    self.updateLayout()
                end

                if self.scrollFrame
                    and type(
                        self.scrollFrame.SetVerticalScroll
                    ) == "function"
                then
                    self.scrollFrame:SetVerticalScroll(
                        0
                    )
                end
            end
        )
    end
end

function ExportFrame:Hide()
    if not self.frame then
        return
    end

    if self.editBox
        and type(
            self.editBox.ClearFocus
        ) == "function"
    then
        self.editBox:ClearFocus()
    end

    self.frame:Hide()
end

function ExportFrame:IsShown()
    return
        self.frame ~= nil
        and type(
            self.frame.IsShown
        ) == "function"
        and self.frame:IsShown()
end

function ExportFrame:GetText()
    if not self.editBox
        or type(
            self.editBox.GetText
        ) ~= "function"
    then
        return nil
    end

    return
        self.editBox:GetText()
end

ns:RegisterModule(
    "UI.ExportFrame",
    ExportFrame
)

ns.UI =
    ns.UI
    or {}

ns.UI.ExportFrame =
    ExportFrame