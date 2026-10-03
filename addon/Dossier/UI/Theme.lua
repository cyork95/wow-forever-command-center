local _, ns = ...

local C = ns.constants

local Theme = {}

local FLAT = "Interface\\Buttons\\WHITE8x8"
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

Theme.BACKDROP_TEMPLATE = BACKDROP_TEMPLATE

Theme.COLORS = {
    panel = { 0.06, 0.08, 0.10, 0.96 },
    header = { 0.08, 0.11, 0.13, 1 },
    card = { 0.09, 0.12, 0.14, 1 },
    cardHover = { 0.12, 0.16, 0.19, 1 },
    border = { 0.16, 0.34, 0.36, 1 },
    accent = { 0.25, 0.78, 0.82, 1 },
    accentDim = { 0.14, 0.40, 0.43, 1 },
    text = { 0.92, 0.94, 0.95, 1 },
    muted = { 0.58, 0.63, 0.67, 1 },
    disabled = { 0.36, 0.39, 0.42, 1 },
    warning = { 0.95, 0.74, 0.30, 1 },
    danger = { 0.95, 0.42, 0.36, 1 },
    dark = { 0.04, 0.05, 0.06, 1 },
}

Theme.HEADER_HEIGHT = 56

function Theme.LogoPath()
    return "Interface\\AddOns\\" .. (ns.name or "Dossier") .. "\\Media\\Logo"
end

local function Unpack(color)
    return color[1], color[2], color[3], color[4] or 1
end

function Theme.Color(name)
    return Unpack(Theme.COLORS[name] or Theme.COLORS.text)
end

function Theme.ColorCode(name)
    local r, g, b = Theme.Color(name)

    return string.format(
        "|cff%02x%02x%02x",
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5)
    )
end

function Theme.ApplyBackdrop(frame, background, border)
    if not frame then
        return
    end

    if type(frame.SetBackdrop) == "function" then
        frame:SetBackdrop({
            bgFile = FLAT,
            edgeFile = FLAT,
            edgeSize = 1,
        })
        frame:SetBackdropColor(Unpack(Theme.COLORS[background or "panel"]))
        frame:SetBackdropBorderColor(Unpack(Theme.COLORS[border or "border"]))
        return
    end

    if not frame.dossierBackground then
        local texture = frame:CreateTexture(nil, "BACKGROUND")
        texture:SetAllPoints()
        texture:SetTexture(FLAT)
        frame.dossierBackground = texture
    end

    frame.dossierBackground:SetVertexColor(
        Unpack(Theme.COLORS[background or "panel"])
    )
end

function Theme.SetBorderColor(frame, border)
    if frame and type(frame.SetBackdropBorderColor) == "function" then
        frame:SetBackdropBorderColor(Unpack(Theme.COLORS[border or "border"]))
    end
end

function Theme.SetBackgroundColor(frame, background)
    if not frame then
        return
    end

    if type(frame.SetBackdropColor) == "function" then
        frame:SetBackdropColor(Unpack(Theme.COLORS[background or "panel"]))
    elseif frame.dossierBackground then
        frame.dossierBackground:SetVertexColor(
            Unpack(Theme.COLORS[background or "panel"])
        )
    end
end

function Theme.SetBackdropAlpha(frame, background, border, alpha)
    if not frame then
        return
    end

    local r, g, b = Theme.Color(background or "panel")

    if type(frame.SetBackdropColor) == "function" then
        frame:SetBackdropColor(r, g, b, alpha)

        local br, bg, bb = Theme.Color(border or "border")
        frame:SetBackdropBorderColor(br, bg, bb, alpha)
    elseif frame.dossierBackground then
        frame.dossierBackground:SetVertexColor(r, g, b, alpha)
    end
end

function Theme.CreatePanel(parent, background, border, name)
    local frame = CreateFrame("Frame", name, parent, BACKDROP_TEMPLATE)
    Theme.ApplyBackdrop(frame, background, border)

    return frame
end

function Theme.CreateText(parent, template, color, layer)
    local text = parent:CreateFontString(
        nil,
        layer or "OVERLAY",
        template or "GameFontHighlight"
    )

    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetTextColor(Theme.Color(color or "text"))

    return text
end

function Theme.CreateWindow(name, width, height)
    local frame = Theme.CreatePanel(UIParent, "panel", "border", name)

    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)

    if type(frame.SetClampedToScreen) == "function" then
        frame:SetClampedToScreen(true)
    end

    if type(frame.SetToplevel) == "function" then
        frame:SetToplevel(true)
    end

    frame:Hide()

    if name and type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, name)
    end

    return frame
end

function Theme.CreateCloseButton(parent, onClick)
    local button = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
    button:SetSize(22, 22)
    Theme.ApplyBackdrop(button, "header", "header")

    local label = Theme.CreateText(button, "GameFontHighlight", "muted")
    label:SetPoint("CENTER", 0, 1)
    label:SetJustifyH("CENTER")
    label:SetText("x")

    button:SetScript("OnEnter", function(self)
        label:SetTextColor(Theme.Color("text"))
        Theme.SetBorderColor(self, "accent")
    end)

    button:SetScript("OnLeave", function(self)
        label:SetTextColor(Theme.Color("muted"))
        Theme.SetBorderColor(self, "header")
    end)

    button:SetScript("OnClick", onClick)

    return button
end

function Theme.CreateHeader(window, title, subtitle)
    local header = Theme.CreatePanel(window, "header", "border")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(Theme.HEADER_HEIGHT)
    header:EnableMouse(true)

    header:SetScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            window:StartMoving()
        end
    end)

    header:SetScript("OnMouseUp", function()
        window:StopMovingOrSizing()
    end)

    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(40, 40)
    logo:SetPoint("LEFT", 10, 0)
    logo:SetTexture(Theme.LogoPath())

    local titleText = Theme.CreateText(header, "GameFontNormalLarge", "text")
    titleText:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -3)
    titleText:SetText(title or C.ADDON_TITLE)

    local versionText = Theme.CreateText(header, "GameFontHighlightSmall", "accent")
    versionText:SetPoint("BOTTOMLEFT", titleText, "BOTTOMRIGHT", 8, 1)
    versionText:SetText("v" .. tostring(C.VERSION))

    local subtitleText = Theme.CreateText(header, "GameFontHighlightSmall", "muted")
    subtitleText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -4)
    subtitleText:SetText(subtitle or "")

    local close = Theme.CreateCloseButton(header, function()
        window:Hide()
    end)
    close:SetPoint("RIGHT", -10, 0)

    header.logo = logo
    header.title = titleText
    header.version = versionText
    header.subtitle = subtitleText
    header.close = close

    return header
end

local BUTTON_STYLES = {
    default = {
        background = "card",
        hover = "cardHover",
        border = "border",
        hoverBorder = "accent",
        text = "text",
    },
    primary = {
        background = "accent",
        hover = "accent",
        border = "accent",
        hoverBorder = "text",
        text = "dark",
    },
}

function Theme.CreateButton(parent, label, width, height, style, onClick)
    local palette = BUTTON_STYLES[style or "default"] or BUTTON_STYLES.default
    local button = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)

    button:SetSize(width or 100, height or 22)
    Theme.ApplyBackdrop(button, palette.background, palette.border)

    local text = Theme.CreateText(
        button,
        style == "primary" and "GameFontNormal" or "GameFontHighlightSmall",
        palette.text
    )
    text:SetPoint("LEFT", 4, 0)
    text:SetPoint("RIGHT", -4, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    text:SetText(label or "")
    button.label = text

    if style == "primary" then
        -- The default drop shadow smears dark text on the bright fill.
        text:SetShadowOffset(0, 0)
        text:SetShadowColor(0, 0, 0, 0)
    end

    local function Paint(self, hovered)
        if self:IsEnabled() then
            Theme.SetBackgroundColor(self, hovered and palette.hover or palette.background)
            Theme.SetBorderColor(self, hovered and palette.hoverBorder or palette.border)
            text:SetTextColor(Theme.Color(palette.text))
        else
            Theme.SetBackgroundColor(self, "card")
            Theme.SetBorderColor(self, "card")
            text:SetTextColor(Theme.Color("disabled"))
        end
    end

    button:SetScript("OnEnter", function(self) Paint(self, true) end)
    button:SetScript("OnLeave", function(self) Paint(self, false) end)
    button:SetScript("OnEnable", function(self) Paint(self, false) end)
    button:SetScript("OnDisable", function(self) Paint(self, false) end)

    if onClick then
        button:SetScript("OnClick", onClick)
    end

    function button:SetLabel(value)
        text:SetText(value or "")
    end

    return button
end

function Theme.CreateCheckbox(parent, label, onClick)
    local checkbox = CreateFrame("CheckButton", nil, parent, BACKDROP_TEMPLATE)
    checkbox:SetSize(14, 14)
    Theme.ApplyBackdrop(checkbox, "dark", "border")

    local mark = checkbox:CreateTexture(nil, "ARTWORK")
    mark:SetTexture(FLAT)
    mark:SetPoint("TOPLEFT", 3, -3)
    mark:SetPoint("BOTTOMRIGHT", -3, 3)
    mark:SetVertexColor(Theme.Color("accent"))
    checkbox:SetCheckedTexture(mark)

    if type(checkbox.SetDisabledCheckedTexture) == "function" then
        local disabledMark = checkbox:CreateTexture(nil, "ARTWORK")
        disabledMark:SetTexture(FLAT)
        disabledMark:SetPoint("TOPLEFT", 3, -3)
        disabledMark:SetPoint("BOTTOMRIGHT", -3, 3)
        disabledMark:SetVertexColor(Theme.Color("disabled"))
        checkbox:SetDisabledCheckedTexture(disabledMark)
    end

    local text = Theme.CreateText(checkbox, "GameFontHighlightSmall", "text")
    text:SetPoint("LEFT", checkbox, "RIGHT", 7, 0)
    text:SetJustifyV("MIDDLE")
    text:SetText(label or "")
    checkbox.label = text

    local labelWidth = math.max(text:GetStringWidth() or 0, 60)
    checkbox:SetHitRectInsets(0, -(labelWidth + 10), -3, -3)

    checkbox:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            Theme.SetBorderColor(self, "accent")
        end
    end)

    checkbox:SetScript("OnLeave", function(self)
        Theme.SetBorderColor(self, "border")
    end)

    checkbox:SetScript("OnEnable", function()
        text:SetTextColor(Theme.Color("text"))
    end)

    checkbox:SetScript("OnDisable", function(self)
        text:SetTextColor(Theme.Color("disabled"))
        Theme.SetBorderColor(self, "card")
    end)

    if onClick then
        checkbox:SetScript("OnClick", onClick)
    end

    return checkbox
end

function Theme.CreateSlider(parent, width, minValue, maxValue, step, onChange)
    local slider = CreateFrame("Slider", nil, parent, BACKDROP_TEMPLATE)
    slider:SetSize(width or 120, 10)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step or 1)
    slider:EnableMouse(true)
    Theme.ApplyBackdrop(slider, "dark", "border")

    if type(slider.SetObeyStepOnDrag) == "function" then
        slider:SetObeyStepOnDrag(true)
    end

    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture(FLAT)
    thumb:SetSize(8, 14)
    thumb:SetVertexColor(Theme.Color("accent"))
    slider:SetThumbTexture(thumb)

    slider:SetScript("OnEnter", function(self) Theme.SetBorderColor(self, "accent") end)
    slider:SetScript("OnLeave", function(self) Theme.SetBorderColor(self, "border") end)

    if onChange then
        slider:SetScript("OnValueChanged", function(self, value)
            onChange(self, math.floor((tonumber(value) or 0) + 0.5))
        end)
    end

    return slider
end

function Theme.CreateTab(parent, label, onClick)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetHeight(32)

    local background = tab:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetTexture(FLAT)
    background:SetVertexColor(Theme.Color("card"))
    background:Hide()

    local bar = tab:CreateTexture(nil, "ARTWORK")
    bar:SetTexture(FLAT)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("BOTTOMLEFT")
    bar:SetWidth(3)
    bar:SetVertexColor(Theme.Color("accent"))
    bar:Hide()

    local text = Theme.CreateText(tab, "GameFontHighlight", "muted")
    text:SetPoint("LEFT", 14, 0)
    text:SetPoint("RIGHT", -10, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    text:SetText(label or "")

    tab.selected = false

    function tab:SetSelected(selected)
        self.selected = selected == true

        if self.selected then
            background:Show()
            bar:Show()
            text:SetTextColor(Theme.Color("text"))
        else
            background:Hide()
            bar:Hide()
            text:SetTextColor(Theme.Color("muted"))
        end
    end

    tab:SetScript("OnEnter", function(self)
        if not self.selected then
            text:SetTextColor(Theme.Color("text"))
        end
    end)

    tab:SetScript("OnLeave", function(self)
        if not self.selected then
            text:SetTextColor(Theme.Color("muted"))
        end
    end)

    tab:SetScript("OnClick", onClick)
    tab.label = text

    return tab
end

function Theme.CreateCard(parent, title)
    local card = Theme.CreatePanel(parent, "card", "border")

    if title then
        local titleText = Theme.CreateText(card, "GameFontNormalSmall", "accent")
        titleText:SetPoint("TOPLEFT", 10, -8)
        titleText:SetText(string.upper(title))
        card.title = titleText
    end

    return card
end

function Theme.CreateScrollText(parent, name, template)
    local box = Theme.CreatePanel(parent, "dark", "border")

    local scrollFrame = CreateFrame(
        "ScrollFrame",
        name,
        box,
        "UIPanelScrollFrameTemplate"
    )
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    local text = Theme.CreateText(content, template or "GameFontHighlight", "text", "ARTWORK")
    text:SetPoint("TOPLEFT", 4, -4)

    function box:SetText(value)
        local width = scrollFrame:GetWidth() or 0

        if width < 50 then
            width = 50
        end

        content:SetWidth(width)
        text:SetWidth(width - 8)
        text:SetText(value or "")
        content:SetHeight(
            math.max(
                (text:GetStringHeight() or 0) + 12,
                scrollFrame:GetHeight() or 1
            )
        )

        if type(scrollFrame.UpdateScrollChildRect) == "function" then
            scrollFrame:UpdateScrollChildRect()
        end

        scrollFrame:SetVerticalScroll(0)
    end

    box.scrollFrame = scrollFrame
    box.content = content
    box.text = text

    return box
end

-- FontStrings on classic-like clients stop around 4KB. An EditBox can hold the guide.
function Theme.CreateScrollEdit(parent, name, template)
    local box = Theme.CreatePanel(parent, "dark", "border")

    local scrollFrame = CreateFrame("ScrollFrame", name, box, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(template or "GameFontHighlightSmall")
    editBox:SetJustifyH("LEFT")
    editBox:SetJustifyV("TOP")
    editBox:SetTextInsets(4, 4, 4, 4)
    editBox:SetTextColor(Theme.Color("text"))
    editBox:SetPoint("TOPLEFT")
    editBox:EnableMouse(true)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(self.dossierText or "")
        end
    end)

    scrollFrame:SetScrollChild(editBox)

    local layingOut = false

    function box:SetText(value)
        if layingOut then
            return
        end

        layingOut = true

        local width = scrollFrame:GetWidth() or 0

        if width < 50 then
            width = 50
        end

        editBox.dossierText = value or ""
        editBox:SetWidth(math.max(width - 8, 1))
        editBox:SetText(editBox.dossierText)
        editBox:SetTextColor(Theme.Color("text"))

        local fontHeight = select(2, editBox:GetFont()) or 12
        local charsPerLine = math.max(math.floor((width - 16) / math.max(fontHeight * 0.5, 1)), 20)
        local lines = 0

        for line in string.gmatch(editBox.dossierText .. "\n", "(.-)\n") do
            lines = lines + math.max(math.ceil(math.max(#line, 1) / charsPerLine), 1)
        end

        if lines < 1 then
            lines = 1
        end

        editBox:SetHeight(math.max(lines * (fontHeight + 3) + 12, scrollFrame:GetHeight() or 1))

        if type(scrollFrame.UpdateScrollChildRect) == "function" then
            scrollFrame:UpdateScrollChildRect()
        end

        scrollFrame:SetVerticalScroll(0)
        layingOut = false
    end

    scrollFrame:SetScript("OnSizeChanged", function()
        if editBox.dossierText then
            box:SetText(editBox.dossierText)
        end
    end)

    box.scrollFrame = scrollFrame
    box.editBox = editBox

    return box
end

ns:RegisterModule("UI.Theme", Theme)

ns.UI = ns.UI or {}
ns.UI.Theme = Theme
ns.Theme = Theme
