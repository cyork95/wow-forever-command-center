local _, ns = ...

local C = ns.constants

local KillPanel = {}

KillPanel.frame = nil

local WIDTH = 220
local HEIGHT = 196
local RATE_REFRESH_SECONDS = 5

local function GetSettings()
    local db = ns.state and ns.state.db

    if type(db) ~= "table" then
        return nil
    end

    if type(db.killPanel) ~= "table" then
        db.killPanel = {}
    end

    return db.killPanel
end

local function FormatCount(value)
    local text = tostring(math.floor(tonumber(value) or 0))
    return (text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

function KillPanel:IsEnabled()
    local settings = GetSettings()
    return settings ~= nil and settings.shown == true
end

function KillPanel:IsLocked()
    local settings = GetSettings()
    return settings ~= nil and settings.locked == true
end

function KillPanel:GetOpacity()
    local settings = GetSettings()
    local value = settings and tonumber(settings.opacity)

    if not value then
        return C.KILLS_PANEL_DEFAULT_OPACITY
    end

    return math.max(0, math.min(100, value))
end

function KillPanel:SetOpacity(percent)
    local settings = GetSettings()

    if settings then
        settings.opacity = math.max(0, math.min(100, math.floor((tonumber(percent) or 0) + 0.5)))
    end

    self:ApplyOpacity()
end

function KillPanel:ApplyOpacity()
    if self.frame then
        ns.Theme.SetBackdropAlpha(self.frame, "panel", "border", self:GetOpacity() / 100)
    end
end

local function SavePosition(frame)
    local settings = GetSettings()

    if not settings or type(frame.GetPoint) ~= "function" then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)

    if point then
        settings.point = point
        settings.relativePoint = relativePoint
        settings.x = x
        settings.y = y
    end
end

local function EnsureFrame()
    if KillPanel.frame then
        return KillPanel.frame
    end

    local Theme = ns.Theme
    local frame = Theme.CreatePanel(UIParent, "panel", "border", "AIExportKillPanel")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    if type(frame.SetClampedToScreen) == "function" then
        frame:SetClampedToScreen(true)
    end

    frame:SetScript("OnDragStart", function(self)
        if not KillPanel:IsLocked() then
            self:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)

    local settings = GetSettings()

    if settings and settings.point then
        frame:SetPoint(settings.point, UIParent, settings.relativePoint or settings.point, settings.x or 0, settings.y or 0)
    else
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -40, 80)
    end

    local title = Theme.CreateText(frame, "GameFontNormalSmall", "accent")
    title:SetPoint("TOPLEFT", 10, -9)
    title:SetText(string.upper(C.TEXT.KILLS_PANEL_TITLE))

    local close = Theme.CreateCloseButton(frame, function()
        KillPanel:SetShown(false)
    end)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -6, -5)

    local lock = Theme.CreateButton(frame, C.TEXT.KILLS_PANEL_LOCK, 56, 18, "default", function()
        local current = GetSettings()

        if current then
            current.locked = not KillPanel:IsLocked()
            KillPanel:Refresh()
        end
    end)
    lock:SetPoint("RIGHT", close, "LEFT", -4, 0)

    local sessionText = Theme.CreateText(frame, "GameFontHighlightSmall", "text")
    sessionText:SetPoint("TOPLEFT", 10, -32)
    sessionText:SetWidth(WIDTH - 20)

    local listText = Theme.CreateText(frame, "GameFontHighlightSmall", "muted")
    listText:SetPoint("TOPLEFT", 10, -52)
    listText:SetWidth(WIDTH - 20)
    listText:SetSpacing(2)

    local elapsed = 0

    frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + (delta or 0)

        if elapsed >= RATE_REFRESH_SECONDS then
            elapsed = 0
            KillPanel:Refresh()
        end
    end)

    frame:Hide()

    KillPanel.frame = frame
    KillPanel.lockButton = lock
    KillPanel.sessionText = sessionText
    KillPanel.listText = listText
    KillPanel:ApplyOpacity()

    return frame
end

function KillPanel.ListText(session)
    if #(session.creatures or {}) == 0 then
        return C.TEXT.KILLS_PANEL_EMPTY
    end

    local lines = {}
    local nameColor = ns.Theme.ColorCode("text")

    for _, creature in ipairs(session.creatures) do
        table.insert(lines, string.format("%s%s|r  x%s", nameColor, creature.name, FormatCount(creature.count)))
    end

    return table.concat(lines, "\n")
end

function KillPanel:Refresh()
    if not self.frame or not self.frame:IsShown() then
        return
    end

    local kills = ns.Data and ns.Data.Kills

    if not kills then
        return
    end

    local session = kills:GetSession()

    self.sessionText:SetText(string.format(
        C.TEXT.KILLS_PANEL_SESSION,
        FormatCount(session.kills),
        FormatCount(session.killsPerHour)
    ))
    self.listText:SetText(KillPanel.ListText(session))
    self.lockButton:SetLabel(self:IsLocked() and C.TEXT.KILLS_PANEL_UNLOCK or C.TEXT.KILLS_PANEL_LOCK)
end

function KillPanel:SetShown(shown)
    local settings = GetSettings()

    if settings then
        settings.shown = shown == true
    end

    if shown then
        EnsureFrame():Show()
        self:Refresh()
    elseif self.frame then
        self.frame:Hide()
    end

    local view = ns.UI and ns.UI.KillsView

    if view and view.panelToggle then
        view.panelToggle:SetChecked(shown == true)
    end
end

function KillPanel:Toggle()
    self:SetShown(not self:IsEnabled())
end

function KillPanel:IsShown()
    return self.frame ~= nil and self.frame:IsShown()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    if KillPanel:IsEnabled() then
        KillPanel:SetShown(true)
    end
end)

if ns.Data and ns.Data.Kills then
    ns.Data.Kills:OnChanged(function()
        KillPanel:Refresh()
    end)
end

ns:RegisterModule("UI.KillPanel", KillPanel)

ns.UI = ns.UI or {}
ns.UI.KillPanel = KillPanel
