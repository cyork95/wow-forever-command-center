local _, ns = ...

local C = ns.constants

local ScreenshotterView = {}

ScreenshotterView.container = nil
ScreenshotterView.triggerBoxes = {}
ScreenshotterView.optionBoxes = {}

local ROW_HEIGHT = 24
local COLUMN_X = { 10, 280 }

-- Interval gets its own row with the slider.
local TRIGGER_COLUMNS = {
    { "levelUp", "death", "achievement", "boss" },
    { "pvp", "duel", "collection", "login" },
}

local OPTION_COLUMNS = {
    { "hideUI", "stamp" },
    { "sound", "chat" },
}

local function GetScreenshotter()
    return ns.Data and ns.Data.Screenshotter
end

function ScreenshotterView.StatusText()
    local shots = GetScreenshotter()

    if not shots then
        return C.TEXT.SHOTS_STATUS_OFF, "muted"
    elseif shots:IsPaused() then
        return C.TEXT.SHOTS_STATUS_PAUSED, "warning"
    elseif shots:IsEnabled() then
        return C.TEXT.SHOTS_STATUS_ON, "accent"
    end

    return C.TEXT.SHOTS_STATUS_OFF, "muted"
end

local function AddCheckboxColumns(card, columns, labels, boxes, onClick)
    for columnIndex, keys in ipairs(columns) do
        for rowIndex, key in ipairs(keys) do
            local box = ns.Theme.CreateCheckbox(card, labels[key], function(self)
                onClick(key, self:GetChecked() == true)
            end)
            box:SetPoint("TOPLEFT", COLUMN_X[columnIndex], -30 - ((rowIndex - 1) * ROW_HEIGHT))
            boxes[key] = box
        end
    end
end

function ScreenshotterView:Build(parent)
    if self.container then
        return self.container
    end

    local Theme = ns.Theme
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints()

    local description = Theme.CreateText(container, "GameFontHighlightSmall", "muted")
    description:SetPoint("TOPLEFT", 0, 0)
    description:SetPoint("TOPRIGHT", 0, 0)
    description:SetText(C.TEXT.SHOTS_DESCRIPTION)

    local master = Theme.CreateCheckbox(container, C.TEXT.SHOTS_ENABLED, function(self)
        local shots = GetScreenshotter()

        if shots then
            shots:SetEnabled(self:GetChecked() == true)
        end
    end)
    master:SetPoint("TOPLEFT", 0, -42)

    local test = Theme.CreateButton(container, C.TEXT.SHOTS_TEST, 150, 22, "default", function()
        local shots = GetScreenshotter()

        if shots then
            shots:TakeNow(C.TEXT.SHOTS_REASON_MANUAL)
        end
    end)
    test:SetPoint("TOPRIGHT", 0, -38)

    local status = Theme.CreateText(container, "GameFontHighlightSmall", "accent")
    status:SetPoint("TOPLEFT", 0, -64)
    status:SetPoint("TOPRIGHT", 0, -64)

    local triggers = Theme.CreateCard(container, C.TEXT.SHOTS_TRIGGERS_TITLE)
    triggers:SetPoint("TOPLEFT", 0, -92)
    triggers:SetPoint("TOPRIGHT", 0, -92)
    triggers:SetHeight(30 + 5 * ROW_HEIGHT + 8)

    AddCheckboxColumns(triggers, TRIGGER_COLUMNS, C.SHOTS_TRIGGER_LABELS, self.triggerBoxes, function(key, checked)
        local shots = GetScreenshotter()

        if shots then
            shots:SetTrigger(key, checked)
        end
    end)

    local intervalTop = -30 - (4 * ROW_HEIGHT)

    local interval = Theme.CreateCheckbox(triggers, C.SHOTS_TRIGGER_LABELS.interval, function(self)
        local shots = GetScreenshotter()

        if shots then
            shots:SetTrigger("interval", self:GetChecked() == true)
        end
    end)
    interval:SetPoint("TOPLEFT", COLUMN_X[1], intervalTop)
    self.triggerBoxes.interval = interval

    local intervalValue = Theme.CreateText(triggers, "GameFontHighlightSmall", "muted")

    local slider = Theme.CreateSlider(triggers, 150, C.SHOTS_INTERVAL_MIN, C.SHOTS_INTERVAL_MAX, 5, function(_, value)
        intervalValue:SetText(string.format(C.TEXT.SHOTS_INTERVAL, value))

        local shots = GetScreenshotter()

        if shots and shots:GetInterval() ~= value then
            shots:SetInterval(value)
        end
    end)
    slider:SetPoint("TOPLEFT", COLUMN_X[2], intervalTop - 2)
    intervalValue:SetPoint("LEFT", slider, "RIGHT", 10, 0)

    local options = Theme.CreateCard(container, C.TEXT.SHOTS_OPTIONS_TITLE)
    options:SetPoint("TOPLEFT", triggers, "BOTTOMLEFT", 0, -12)
    options:SetPoint("TOPRIGHT", triggers, "BOTTOMRIGHT", 0, -12)
    options:SetHeight(30 + 2 * ROW_HEIGHT + 8)

    AddCheckboxColumns(options, OPTION_COLUMNS, C.SHOTS_OPTION_LABELS, self.optionBoxes, function(key, checked)
        local shots = GetScreenshotter()

        if shots then
            shots:SetOption(key, checked)
        end
    end)

    container:SetScript("OnShow", function()
        ScreenshotterView:Refresh()
    end)

    self.container = container
    self.master = master
    self.testButton = test
    self.statusText = status
    self.intervalSlider = slider
    self.intervalValue = intervalValue

    local shots = GetScreenshotter()

    if shots then
        shots:OnChanged(function()
            if container:IsVisible() then
                ScreenshotterView:Refresh()
            end
        end)
    end

    return container
end

local function SetControlEnabled(control, enabled)
    if enabled then
        control:Enable()
    else
        control:Disable()
    end
end

function ScreenshotterView:Refresh()
    if not self.container then
        return
    end

    local shots = GetScreenshotter()

    if not shots then
        return
    end

    local text, color = ScreenshotterView.StatusText()
    self.statusText:SetText(text)
    self.statusText:SetTextColor(ns.Theme.Color(color))

    self.master:SetChecked(shots:IsEnabled())

    local active = shots:IsActive()

    for key, box in pairs(self.triggerBoxes) do
        box:SetChecked(shots:IsTriggerOn(key))
        SetControlEnabled(box, active)
    end

    for key, box in pairs(self.optionBoxes) do
        box:SetChecked(shots:IsOptionOn(key))
        SetControlEnabled(box, active)
    end

    local minutes = shots:GetInterval()
    self.intervalSlider:SetValue(minutes)
    self.intervalValue:SetText(string.format(C.TEXT.SHOTS_INTERVAL, minutes))

    local sliderOn = active and shots:IsTriggerOn("interval")
    self.intervalSlider:EnableMouse(sliderOn)
    self.intervalSlider:SetAlpha(sliderOn and 1 or 0.4)
    self.intervalValue:SetTextColor(ns.Theme.Color(sliderOn and "muted" or "disabled"))
end

ns:RegisterModule("UI.ScreenshotterView", ScreenshotterView)

ns.UI = ns.UI or {}
ns.UI.ScreenshotterView = ScreenshotterView
