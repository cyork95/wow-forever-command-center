local _, ns = ...

local C = ns.constants

-- The live Session panel. It started as the kill panel, so the module and its
-- saved settings (db.killPanel) keep that name.
local KillPanel = {}

KillPanel.frame = nil

local WIDTH = 240
local LINE_HEIGHT = 14
local TOP_OFFSET = 32
local REFRESH_SECONDS = 1
local TOOLTIP_ITEMS = 15
local RESET_POPUP = "DOSSIER_SESSION_RESET"

local function GetSettings()
    local db = ns.state and ns.state.db

    if type(db) ~= "table" then
        return nil
    end

    if type(db.killPanel) ~= "table" then
        db.killPanel = {}
    end

    if type(db.killPanel.lines) ~= "table" then
        db.killPanel.lines = {}
    end

    return db.killPanel
end

local function GetSession()
    return ns.Data and ns.Data.Session
end

local function FormatCount(value)
    local session = GetSession()
    return session and session.FormatCount(value) or tostring(value)
end

function KillPanel:IsEnabled()
    local settings = GetSettings()
    return settings ~= nil and settings.shown == true
end

function KillPanel:IsLocked()
    local settings = GetSettings()
    return settings ~= nil and settings.locked == true
end

function KillPanel:IsLineOn(key)
    local settings = GetSettings()
    return settings == nil or settings.lines[key] ~= false
end

function KillPanel:SetLine(key, enabled)
    local settings = GetSettings()

    if settings then
        settings.lines[key] = enabled == true
        self:Refresh()
    end
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

function KillPanel:ConfirmReset()
    local session = GetSession()

    if not session then
        return
    end

    if type(StaticPopup_Show) ~= "function" or type(StaticPopupDialogs) ~= "table" then
        session:Reset()
        return
    end

    StaticPopupDialogs[RESET_POPUP] = StaticPopupDialogs[RESET_POPUP] or {
        text = C.TEXT.SESSION_RESET_CONFIRM,
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function()
            local current = GetSession()

            if current then
                current:Reset()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopup_Show(RESET_POPUP)
end

function KillPanel.TitleText(summary)
    local label = string.upper(C.TEXT.SESSION_PANEL_TITLE)
    local session = GetSession()
    local clock = session and session.FormatClock(summary.seconds) or ""

    if summary.status == "paused" then
        return string.format("%s  %s  %s", label, clock, C.TEXT.SESSION_PAUSED)
    end

    return string.format("%s  %s", label, clock)
end

-- The stat lines shown for the ticked panel lines.
function KillPanel.StatLines(summary)
    local session = GetSession()
    local lines = {}

    if KillPanel:IsLineOn("kills") and ns:IsFeatureOn("kills") then
        table.insert(lines, string.format(C.TEXT.SESSION_LINE_KILLS, FormatCount(summary.kills), FormatCount(summary.killsPerHour)))
    end

    if KillPanel:IsLineOn("gathered") then
        table.insert(lines, string.format(C.TEXT.SESSION_LINE_GATHERED, FormatCount(summary.gathered), FormatCount(summary.gatheredPerHour)))

        local parts = {}

        for index, entry in ipairs(summary.byType) do
            if index > 3 then
                break
            end

            table.insert(parts, string.format("%s %s", entry.label, FormatCount(entry.count)))
        end

        if #parts > 0 then
            table.insert(lines, "  " .. table.concat(parts, ", "))
        end
    end

    if KillPanel:IsLineOn("gold") and session then
        table.insert(lines, string.format(C.TEXT.SESSION_LINE_GOLD, session.FormatGold(summary.gold), session.FormatGold(summary.goldPerHour)))
    end

    if KillPanel:IsLineOn("xp") then
        local text = string.format(C.TEXT.SESSION_LINE_XP, FormatCount(summary.xp), FormatCount(summary.xpPerHour))

        if summary.timeToLevel and session then
            text = text .. string.format(C.TEXT.SESSION_LINE_LEVEL, session.FormatDuration(summary.timeToLevel))
        end

        table.insert(lines, text)
    end

    return lines
end

function KillPanel.ListText(summary)
    if #(summary.creatures or {}) == 0 then
        return C.TEXT.KILLS_PANEL_EMPTY
    end

    local lines = {}
    local nameColor = ns.Theme.ColorCode("text")

    for _, creature in ipairs(summary.creatures) do
        table.insert(lines, string.format("%s%s|r  x%s", nameColor, creature.name, FormatCount(creature.count)))
    end

    return table.concat(lines, "\n")
end

local function ShowTooltip(frame)
    local session = GetSession()

    if not session or not GameTooltip or type(GameTooltip.SetOwner) ~= "function" then
        return
    end

    local summary = session:GetSummary()

    GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
    GameTooltip:AddLine(C.TEXT.SESSION_TOOLTIP_TITLE)

    if #summary.items == 0 then
        GameTooltip:AddLine(C.TEXT.SESSION_TOOLTIP_EMPTY, 0.7, 0.7, 0.7)
    end

    for index, item in ipairs(summary.items) do
        if index > TOOLTIP_ITEMS then
            GameTooltip:AddLine(string.format(C.TEXT.SESSION_TOOLTIP_MORE, #summary.items - TOOLTIP_ITEMS), 0.7, 0.7, 0.7)
            break
        end

        GameTooltip:AddDoubleLine(
            item.name or "Unknown item",
            string.format(C.TEXT.SESSION_TOOLTIP_ITEM, FormatCount(item.count), FormatCount(item.perHour)),
            1, 1, 1, 1, 1, 1
        )
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(C.TEXT.SESSION_TOOLTIP_HELP, 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

local function HideTooltip()
    if GameTooltip and type(GameTooltip.Hide) == "function" then
        GameTooltip:Hide()
    end
end

local function EnsureFrame()
    if KillPanel.frame then
        return KillPanel.frame
    end

    local Theme = ns.Theme
    local frame = Theme.CreatePanel(UIParent, "panel", "border", "DossierSessionPanel")
    frame:SetSize(WIDTH, 120)
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

    frame:SetScript("OnEnter", ShowTooltip)
    frame:SetScript("OnLeave", HideTooltip)

    local settings = GetSettings()

    if settings and settings.point then
        frame:SetPoint(settings.point, UIParent, settings.relativePoint or settings.point, settings.x or 0, settings.y or 0)
    else
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -40, 80)
    end

    local close = Theme.CreateCloseButton(frame, function()
        KillPanel:SetShown(false)
    end)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -6, -5)

    local lock = Theme.CreateButton(frame, C.TEXT.KILLS_PANEL_LOCK, 52, 18, "default", function()
        local current = GetSettings()

        if current then
            current.locked = not KillPanel:IsLocked()
            KillPanel:Refresh()
        end
    end)
    lock:SetPoint("RIGHT", close, "LEFT", -4, 0)

    local header = CreateFrame("Button", nil, frame)
    header:SetPoint("TOPLEFT", 4, -4)
    header:SetPoint("RIGHT", lock, "LEFT", -4, 0)
    header:SetHeight(20)
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    header:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            KillPanel:ConfirmReset()
            return
        end

        local session = GetSession()

        if session then
            session:Toggle()
        end
    end)
    header:SetScript("OnEnter", function() ShowTooltip(frame) end)
    header:SetScript("OnLeave", HideTooltip)

    local title = Theme.CreateText(header, "GameFontNormalSmall", "accent")
    title:SetPoint("LEFT", 6, 0)
    title:SetPoint("RIGHT", 0, 0)
    title:SetJustifyH("LEFT")
    title:SetJustifyV("MIDDLE")
    title:SetWordWrap(false)

    local statsText = Theme.CreateText(frame, "GameFontHighlightSmall", "text")
    statsText:SetPoint("TOPLEFT", 10, -TOP_OFFSET)
    statsText:SetWidth(WIDTH - 20)
    statsText:SetSpacing(2)

    local listText = Theme.CreateText(frame, "GameFontHighlightSmall", "muted")
    listText:SetWidth(WIDTH - 20)
    listText:SetSpacing(2)

    local elapsed = 0

    frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + (delta or 0)

        if elapsed >= REFRESH_SECONDS then
            elapsed = 0
            KillPanel:Refresh()
        end
    end)

    frame:Hide()

    KillPanel.frame = frame
    KillPanel.header = header
    KillPanel.titleText = title
    KillPanel.lockButton = lock
    KillPanel.statsText = statsText
    KillPanel.listText = listText
    KillPanel:ApplyOpacity()

    return frame
end

local function CountLines(text)
    local _, breaks = string.gsub(text or "", "\n", "")
    return breaks + 1
end

function KillPanel:Refresh()
    if not self.frame or not self.frame:IsShown() then
        return
    end

    local session = GetSession()

    if not session then
        return
    end

    local summary = session:GetSummary()
    local stats = KillPanel.StatLines(summary)
    local height = TOP_OFFSET

    self.titleText:SetText(KillPanel.TitleText(summary))
    self.statsText:SetText(table.concat(stats, "\n"))
    self.statsText:SetShown(#stats > 0)
    height = height + #stats * LINE_HEIGHT

    self.listText:ClearAllPoints()

    if self:IsLineOn("recent") and ns:IsFeatureOn("kills") then
        local list = KillPanel.ListText(summary)
        local offset = TOP_OFFSET + #stats * LINE_HEIGHT + (#stats > 0 and 8 or 0)

        self.listText:SetPoint("TOPLEFT", 10, -offset)
        self.listText:SetText(list)
        self.listText:Show()
        height = offset + CountLines(list) * LINE_HEIGHT
    else
        self.listText:Hide()
    end

    self.frame:SetHeight(height + 10)
    self.lockButton:SetLabel(self:IsLocked() and C.TEXT.KILLS_PANEL_UNLOCK or C.TEXT.KILLS_PANEL_LOCK)
end

function KillPanel:SetShown(shown)
    if shown and not ns:IsFeatureOn("session") then
        ns.Features.PrintOff("session")
        return
    end

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

    local view = ns.UI and ns.UI.SessionView

    if view and view.panelToggle then
        view.panelToggle:SetChecked(shown == true)
    end
end

function KillPanel:Toggle()
    if not ns:IsFeatureOn("session") then
        ns.Features.PrintOff("session")
        return
    end

    self:SetShown(not self:IsEnabled())
end

function KillPanel:IsShown()
    return self.frame ~= nil and self.frame:IsShown()
end

-- Hiding for the Session switch keeps the saved "shown" choice, so the panel
-- comes back when Session is turned on again.
function KillPanel:SetFeatureActive(on)
    if not on then
        if self.frame then
            self.frame:Hide()
        end
    elseif self:IsEnabled() then
        EnsureFrame():Show()
        self:Refresh()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    if KillPanel:IsEnabled() and ns:IsFeatureOn("session") then
        KillPanel:SetShown(true)
    end
end)

if ns.Data and ns.Data.Session then
    ns.Data.Session:OnChanged(function()
        KillPanel:Refresh()
    end)
end

if ns.Data and ns.Data.Kills then
    ns.Data.Kills:OnChanged(function()
        KillPanel:Refresh()
    end)
end

ns:RegisterModule("UI.KillPanel", KillPanel)

ns.UI = ns.UI or {}
ns.UI.KillPanel = KillPanel
