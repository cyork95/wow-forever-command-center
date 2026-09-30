local addonName, ns = ...

local C = ns.constants

-- Dossier's page in the game's Settings > AddOns list. It shows the same
-- options as the Options tab, plus a button that opens the Dossier window.
local Page = {}

Page.panel = nil
Page.categoryID = nil
Page.options = nil

local WIDTH = 580
local LEFT = 16
local OPTIONS_TOP = -70

local function GetCommands()
    return ns:GetModule("Commands")
end

local function HideGameSettings()
    local gameSettings = _G.SettingsPanel

    if not gameSettings or type(gameSettings.IsShown) ~= "function" or not gameSettings:IsShown() then
        return
    end

    if type(HideUIPanel) == "function" then
        pcall(HideUIPanel, gameSettings)
    else
        gameSettings:Hide()
    end
end

function Page:Build()
    if self.panel then
        return self.panel
    end

    local Theme = ns.Theme
    local panel = CreateFrame("Frame")
    panel.name = C.ADDON_TITLE or "Dossier"

    local title = Theme.CreateText(panel, "GameFontNormalLarge", "accent")
    title:SetPoint("TOPLEFT", LEFT, -16)
    title:SetText(string.format("%s %s", panel.name, C.VERSION or ""))

    local description = Theme.CreateText(panel, "GameFontHighlightSmall", "muted")
    description:SetPoint("TOPLEFT", LEFT, -40)
    description:SetWidth(WIDTH - 140)
    description:SetJustifyH("LEFT")
    description:SetText(C.TEXT.SETTINGS_PAGE_DESCRIPTION)

    local open = Theme.CreateButton(panel, C.TEXT.BUTTON_OPEN_DOSSIER, 120, 22, "primary", function()
        HideGameSettings()

        local commands = GetCommands()

        if commands and type(commands.OpenTab) == "function" then
            commands:OpenTab("export")
        end
    end)
    open:SetPoint("TOPLEFT", LEFT + WIDTH - 120, -16)

    local view = ns.UI and ns.UI.OptionsView

    if view and type(view.New) == "function" then
        self.options = view.New(panel, WIDTH, { top = OPTIONS_TOP, left = LEFT })
    end

    panel.OnCommit = function() end
    panel.OnDefault = function() end
    panel.OnRefresh = function()
        if Page.options then
            Page.options:Refresh()
        end
    end

    self.panel = panel
    self.openButton = open

    return panel
end

function Page:Register()
    if self.categoryID or self.legacy then
        return true
    end

    local panel = self:Build()

    if type(Settings) == "table" and type(Settings.RegisterCanvasLayoutCategory) == "function" then
        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, panel.name)

        if ok and category then
            pcall(Settings.RegisterAddOnCategory, category)

            local idOk, id = pcall(category.GetID, category)
            self.categoryID = idOk and id or panel.name

            return true
        end
    end

    if type(InterfaceOptions_AddCategory) == "function" then
        self.legacy = pcall(InterfaceOptions_AddCategory, panel)
        return self.legacy
    end

    return false
end

-- Opens the game's Settings window at the Dossier page.
function Page:Open()
    if not self:Register() then
        return false
    end

    if self.categoryID and type(Settings) == "table" and type(Settings.OpenToCategory) == "function" then
        return (pcall(Settings.OpenToCategory, self.categoryID))
    end

    if self.legacy and type(InterfaceOptionsFrame_OpenToCategory) == "function" then
        -- The old options window needs two calls to land on the page the first time.
        pcall(InterfaceOptionsFrame_OpenToCategory, self.panel)
        pcall(InterfaceOptionsFrame_OpenToCategory, self.panel)
        return true
    end

    return false
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, _, loadedName)
    if loadedName ~= addonName then
        return
    end

    self:UnregisterEvent("ADDON_LOADED")
    pcall(Page.Register, Page)
end)

ns:RegisterModule("UI.SettingsPanel", Page)

ns.UI = ns.UI or {}
ns.UI.SettingsPanel = Page
