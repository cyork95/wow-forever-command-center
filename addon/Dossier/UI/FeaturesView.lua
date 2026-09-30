local _, ns = ...

local C = ns.constants

local FeaturesView = {}

FeaturesView.container = nil
FeaturesView.rows = {}

local ROW_HEIGHT = 42
local ROW_GAP = 4

function FeaturesView:Build(parent)
    if self.container then
        return self.container
    end

    local Theme = ns.Theme
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints()

    local width = parent:GetWidth()

    if not width or width < 100 then
        width = 548
    end

    local description = Theme.CreateText(container, "GameFontHighlightSmall", "muted")
    description:SetPoint("TOPLEFT", 0, 0)
    description:SetWidth(width)
    description:SetJustifyH("LEFT")
    description:SetText(C.TEXT.FEATURES_DESCRIPTION)

    local y = -40

    for _, feature in ipairs(C.FEATURES) do
        local row = Theme.CreateCard(container)
        row:SetSize(width, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, y)

        local checkbox = Theme.CreateCheckbox(row, feature.label, function(self)
            ns:SetFeatureOn(feature.id, self:GetChecked() == true)
        end)
        checkbox:SetPoint("TOPLEFT", 10, -8)
        checkbox.label:SetFontObject("GameFontHighlight")

        local text = Theme.CreateText(row, "GameFontHighlightSmall", "muted")
        text:SetPoint("TOPLEFT", 31, -25)
        text:SetWidth(width - 42)
        text:SetJustifyH("LEFT")
        text:SetText(feature.description)

        self.rows[feature.id] = { checkbox = checkbox, text = text }
        y = y - ROW_HEIGHT - ROW_GAP
    end

    local alwaysOn = Theme.CreateText(container, "GameFontHighlightSmall", "muted")
    alwaysOn:SetPoint("TOPLEFT", 0, y - 6)
    alwaysOn:SetWidth(width)
    alwaysOn:SetJustifyH("LEFT")
    alwaysOn:SetText(C.TEXT.FEATURES_ALWAYS_ON)

    container:SetScript("OnShow", function()
        FeaturesView:Refresh()
    end)

    self.container = container
    self.description = description

    ns:OnFeatureChanged(function()
        FeaturesView:Refresh()
    end)

    self:Refresh()

    return container
end

function FeaturesView:Refresh()
    for id, row in pairs(self.rows) do
        row.checkbox:SetChecked(ns:IsFeatureOn(id))
    end
end

ns:RegisterModule("UI.FeaturesView", FeaturesView)

ns.UI = ns.UI or {}
ns.UI.FeaturesView = FeaturesView
