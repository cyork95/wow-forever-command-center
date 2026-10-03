local _, ns = ...

local C = ns.constants

-- The general options and feature switches. The Options tab and the game's
-- Settings > AddOns page each build their own set, and every set refreshes
-- when any of them changes.
local OptionsView = {}

OptionsView.sets = {}

local GENERAL_HEIGHT = 84
local ROW_HEIGHT = 36
local ROW_GAP = 3

local function GetCommands()
    return ns:GetModule("Commands")
end

local function SetMinimapVisible(visible)
    local commands = GetCommands()

    if commands and type(commands.SetMinimapButtonVisible) == "function" then
        commands:SetMinimapButtonVisible(visible)
    elseif type(ns.SetMinimapIconVisible) == "function" then
        ns:SetMinimapIconVisible(visible)
    end
end

local function IsOn(method, default)
    if type(ns[method]) ~= "function" then
        return default
    end

    return ns[method](ns) == true
end

function OptionsView.RefreshAll()
    for _, set in ipairs(OptionsView.sets) do
        set:Refresh()
    end
end

local function Refresh(set)
    set.minimapCheckbox:SetChecked(IsOn("IsMinimapIconVisible", true))
    set.verboseCheckbox:SetChecked(IsOn("IsVerboseItemTypesEnabled", false))
    set.detailedCheckbox:SetChecked(IsOn("IsDetailedExport", false))

    for id, row in pairs(set.rows) do
        row.checkbox:SetChecked(ns:IsFeatureOn(id))
    end
end

local function OptionCheckbox(parent, label, y, apply)
    local checkbox = ns.Theme.CreateCheckbox(parent, label, function(self)
        apply(self:GetChecked() == true)
        OptionsView.RefreshAll()
    end)
    checkbox:SetPoint("TOPLEFT", 10, y)

    return checkbox
end

-- extras.top and extras.left offset the set inside its parent.
function OptionsView.New(parent, width, extras)
    extras = extras or {}

    local Theme = ns.Theme
    local left = extras.left or 0
    local set = { rows = {}, Refresh = Refresh }

    if not width or width < 100 then
        width = 548
    end

    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", left, extras.top or 0)
    scroll:SetPoint("BOTTOMRIGHT", -4, 0)

    local container = CreateFrame("Frame", nil, scroll)
    width = math.max(100, width - 28)
    container:SetWidth(width)
    scroll:SetScrollChild(container)

    local general = Theme.CreateCard(container, C.TEXT.LABEL_GENERAL)
    general:SetSize(width, GENERAL_HEIGHT)
    general:SetPoint("TOPLEFT", 0, 0)

    set.minimapCheckbox = OptionCheckbox(general, C.TEXT.LABEL_SHOW_MINIMAP_ICON, -28, SetMinimapVisible)
    set.verboseCheckbox = OptionCheckbox(general, C.TEXT.LABEL_VERBOSE_ITEM_TYPES, -46, function(on)
        if type(ns.SetVerboseItemTypesEnabled) == "function" then
            ns:SetVerboseItemTypesEnabled(on)
        end
    end)
    set.detailedCheckbox = OptionCheckbox(general, C.TEXT.LABEL_DETAILED_EXPORT, -64, function(on)
        if type(ns.SetDetailedExport) == "function" then
            ns:SetDetailedExport(on)
        end
    end)

    set.reloadButton = Theme.CreateButton(general, C.TEXT.BUTTON_RELOAD_UI, 110, 22, "default", function()
        if type(ReloadUI) == "function" then
            ReloadUI()
        end
    end)
    set.reloadButton:SetPoint("TOPRIGHT", -10, -24)

    local featuresTitle = Theme.CreateText(container, "GameFontNormalSmall", "accent")
    featuresTitle:SetPoint("TOPLEFT", 0, -GENERAL_HEIGHT - 10)
    featuresTitle:SetText(string.upper(C.TEXT.LABEL_FEATURES))

    local description = Theme.CreateText(container, "GameFontHighlightSmall", "muted")
    description:SetPoint("TOPLEFT", 0, -GENERAL_HEIGHT - 26)
    description:SetWidth(width)
    description:SetJustifyH("LEFT")
    description:SetText(C.TEXT.FEATURES_DESCRIPTION)

    local y = -GENERAL_HEIGHT - 58

    for _, feature in ipairs(C.FEATURES) do
        local row = Theme.CreateCard(container)
        row:SetSize(width, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, y)

        -- Lua 5.1 reuses the loop variable, so the handler must close over its own id.
        local featureID = feature.id
        local checkbox = Theme.CreateCheckbox(row, feature.label, function(self)
            ns:SetFeatureOn(featureID, self:GetChecked() == true)
        end)
        checkbox:SetPoint("TOPLEFT", 10, -6)
        checkbox.label:SetFontObject("GameFontHighlight")

        local text = Theme.CreateText(row, "GameFontHighlightSmall", "muted")
        text:SetPoint("TOPLEFT", 31, -21)
        text:SetWidth(width - 42)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
        text:SetText(feature.description)

        set.rows[feature.id] = { checkbox = checkbox, text = text }
        y = y - ROW_HEIGHT - ROW_GAP
    end

    local alwaysOn = Theme.CreateText(container, "GameFontHighlightSmall", "muted")
    alwaysOn:SetPoint("TOPLEFT", 0, y - 4)
    alwaysOn:SetWidth(width)
    alwaysOn:SetJustifyH("LEFT")
    alwaysOn:SetText(C.TEXT.FEATURES_ALWAYS_ON)
    container:SetHeight(math.abs(y) + 36)

    container:SetScript("OnShow", function()
        set:Refresh()
    end)

    set.container = container
    set.description = description
    set.general = general

    table.insert(OptionsView.sets, set)
    set:Refresh()

    return set
end

ns:OnFeatureChanged(function()
    OptionsView.RefreshAll()
end)

ns:RegisterModule("UI.OptionsView", OptionsView)

ns.UI = ns.UI or {}
ns.UI.OptionsView = OptionsView
