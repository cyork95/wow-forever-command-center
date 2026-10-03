local _, ns = ...

local C = ns.constants

local Tracker = {}

local dismissedZone = nil
local WIDTH = 260
local LINE_HEIGHT = 16
local TOP_OFFSET = 32

local function Account()
    return ns.Account
end

local function Settings()
    local bucket = Account() and Account().Bucket("tracker")

    if type(bucket) ~= "table" then
        return nil
    end

    if bucket.autoOpen == nil then
        bucket.autoOpen = true
    end

    if type(bucket.lines) ~= "table" then
        bucket.lines = {}
    end

    if bucket.opacity == nil then
        bucket.opacity = C.KILLS_PANEL_DEFAULT_OPACITY
    end

    return bucket
end

function Tracker:IsEnabled()
    local settings = Settings()
    return settings ~= nil and settings.shown == true
end

function Tracker:IsLocked()
    local settings = Settings()
    return settings ~= nil and settings.locked == true
end

function Tracker:IsAutoOpen()
    local settings = Settings()
    return settings == nil or settings.autoOpen ~= false
end

function Tracker:SetAutoOpen(on)
    local settings = Settings()

    if settings then
        settings.autoOpen = on == true
    end
end

function Tracker:IsLineOn(key)
    local settings = Settings()
    return settings == nil or settings.lines[key] ~= false
end

function Tracker:SetLine(key, enabled)
    local settings = Settings()

    if settings then
        settings.lines[key] = enabled == true
        self:Refresh()
    end
end

function Tracker:GetOpacity()
    local settings = Settings()
    local value = settings and tonumber(settings.opacity)

    if not value then
        return C.KILLS_PANEL_DEFAULT_OPACITY
    end

    return math.max(0, math.min(100, value))
end

function Tracker:SetOpacity(percent)
    local settings = Settings()

    if settings then
        settings.opacity = math.max(0, math.min(100, math.floor((tonumber(percent) or 0) + 0.5)))
    end

    self:ApplyOpacity()
end

function Tracker:ApplyOpacity()
    if self.frame then
        ns.Theme.SetBackdropAlpha(self.frame, "panel", "border", self:GetOpacity() / 100)
    end
end

local function SavePosition(frame)
    local settings = Settings()

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

local function Zone()
    return Account() and Account().Zone() or nil
end

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function RareLine(unit)
    if type(UnitExists) ~= "function" or UnitExists(unit) ~= true then
        return nil
    end

    local classification = type(UnitClassification) == "function" and UnitClassification(unit) or nil

    if classification ~= "rare" and classification ~= "rareelite" then
        return nil
    end

    local name = UnitName(unit) or "Rare"
    local place = Zone() or "here"
    local x, y = nil, nil

    if C_Map and type(C_Map.GetBestMapForUnit) == "function" and type(C_Map.GetPlayerMapPosition) == "function" then
        local okMap, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        local okPos, pos, posY = pcall(C_Map.GetPlayerMapPosition, mapID, "player")

        if okMap and okPos then
            if type(pos) == "table" then
                x, y = pos.x, pos.y
            elseif type(pos) == "number" then
                x, y = pos, posY
            end

            if type(x) == "number" and x <= 1 then
                x = math.floor(x * 1000 + 0.5) / 10
            end

            if type(y) == "number" and y <= 1 then
                y = math.floor(y * 1000 + 0.5) / 10
            end
        end
    end

    if x and y then
        return string.format("|cffffd36b%s|r  |cff8d9aa3%s %.1f, %.1f|r", name, place, x, y)
    end

    return "|cffffd36b" .. name .. "|r  |cff8d9aa3" .. place .. "|r"
end

function Tracker:Lines()
    local lines = {}
    local zone = Zone()
    local tasks = ns.Data and ns.Data.Tasks

    if self:IsLineOn("tasks") and tasks and ns:IsFeatureOn("tasks") then
        local shown = false

        for _, task in ipairs(tasks:Open(Account().CharacterKey())) do
            if not task.zone or task.zone == "" or task.zone == zone then
                if not shown then
                    table.insert(lines, "|cffffd36bStill to do|r")
                    shown = true
                end

                table.insert(lines, "|cff7ee0e6" .. (task.name or "Task") .. "|r  |cff8d9aa3" .. tasks:Cadence(task) .. "|r")
            end
        end
    end

    local shop = ns.Data and ns.Data.ShoppingList

    if self:IsLineOn("shopping") and shop and ns:IsFeatureOn("shopping") and type(shop.GetShortRows) == "function" then
        local shorts = shop:GetShortRows()
        local shown = false

        for _, row in ipairs(shorts or {}) do
            local name = row.name or row.text

            if name then
                if not shown then
                    table.insert(lines, "|cffb7e3a1Shopping short|r")
                    shown = true
                end

                table.insert(lines, string.format("|cffb7e3a1%s|r  |cffffd36b%s still needed|r", name, tostring(row.short or 0)))
            end
        end
    end

    if self:IsLineOn("rares") and ns:IsFeatureOn("kills") then
        local shown = false
        local bucket = Account() and Account().Database() and Account().Database().rares or {}

        local function AddRare(line)
            if not shown then
                table.insert(lines, "|cffffcc66Rares here|r")
                shown = true
            end

            table.insert(lines, "  " .. line)
        end

        for _, rare in pairs(bucket) do
            if type(rare) == "table" and rare.name and rare.zone == zone then
                local place = rare.x and rare.y and string.format("%.1f, %.1f", rare.x, rare.y) or ""
                AddRare("|cffffd36b" .. rare.name .. "|r" .. (place ~= "" and ("  |cff8d9aa3" .. place .. "|r") or ""))
            end
        end

        for _, unit in ipairs({ "target", "mouseover" }) do
            local line = RareLine(unit)

            if line then
                AddRare(line)
            end
        end
    end

    return lines
end

function Tracker:Refresh()
    if not self.frame or not self.frame:IsShown() or not self.text then
        return
    end

    local lines = self:Lines()
    local zone = Zone()
    local title = "|cffffd36b" .. string.upper(C.TEXT.TASK_PANEL_TITLE) .. "|r"

    if zone and zone ~= "" then
        title = title .. "  |cff7ee0e6" .. zone .. "|r"
    end

    self.titleText:SetText(title)
    self.text:SetText(#lines > 0 and table.concat(lines, "\n") or ("|cff8d9aa3" .. C.TEXT.TASK_PANEL_EMPTY .. "|r"))
    self.frame:SetHeight(TOP_OFFSET + math.max(#lines, 1) * LINE_HEIGHT + 12)

    if self.lockButton then
        self.lockButton:SetLabel(self:IsLocked() and C.TEXT.KILLS_PANEL_UNLOCK or C.TEXT.KILLS_PANEL_LOCK)
    end
end

local function EnsureFrame()
    if Tracker.frame then
        return Tracker.frame
    end

    local Theme = ns.Theme
    local frame = Theme.CreatePanel(UIParent, "panel", "border", "DossierTracker")
    frame:SetSize(WIDTH, 120)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    if type(frame.SetClampedToScreen) == "function" then
        frame:SetClampedToScreen(true)
    end

    local settings = Settings()

    if settings and settings.point then
        frame:SetPoint(settings.point, UIParent, settings.relativePoint or settings.point, settings.x or 0, settings.y or 0)
    else
        frame:SetPoint("LEFT", UIParent, "LEFT", 40, 40)
    end

    frame:SetScript("OnDragStart", function(self)
        if not Tracker:IsLocked() then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)

    local close = Theme.CreateCloseButton(frame, function()
        dismissedZone = Zone()
        Tracker:SetShown(false)
    end)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -6, -5)

    local lock = Theme.CreateButton(frame, C.TEXT.KILLS_PANEL_LOCK, 52, 18, "default", function()
        local current = Settings()

        if current then
            current.locked = not Tracker:IsLocked()
            Tracker:Refresh()
        end
    end)
    lock:SetPoint("RIGHT", close, "LEFT", -4, 0)

    local title = Theme.CreateText(frame, "GameFontNormalSmall", "accent")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetPoint("RIGHT", lock, "LEFT", -6, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)

    local text = Theme.CreateText(frame, "GameFontHighlightSmall", "text")
    text:SetPoint("TOPLEFT", 10, -TOP_OFFSET)
    text:SetWidth(WIDTH - 20)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetSpacing(2)

    Tracker.frame = frame
    Tracker.text = text
    Tracker.titleText = title
    Tracker.lockButton = lock
    Tracker:ApplyOpacity()

    return frame
end

local refreshingView = false

function Tracker:SetShown(shown)
    if shown and not ns:IsFeatureOn("tasks") then
        return
    end

    local settings = Settings()

    if settings then
        settings.shown = shown == true
    end

    if shown then
        EnsureFrame():Show()
        self:Refresh()
    elseif self.frame then
        self.frame:Hide()
    end

    local view = ns.UI and ns.UI.TasksView

    if not refreshingView and view and view.Refresh then
        refreshingView = true
        view:Refresh()
        refreshingView = false
    end
end

function Tracker:Show()
    self:SetShown(true)
end

function Tracker:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function Tracker:ConsiderZone()
    if not ns:IsFeatureOn("tasks") or InCombat() then
        return
    end

    local settings = Settings()

    if not settings or settings.autoOpen == false then
        return
    end

    local zone = Zone()

    if zone and zone == dismissedZone then
        return
    end

    dismissedZone = nil

    if #self:Lines() == 0 then
        return
    end

    self:Show()
end

function Tracker:SetFeatureActive(on)
    if not on then
        self:Hide()
    end
end

local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(_, event)
    if not ns:IsFeatureOn("tasks") then
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        Tracker:Hide()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if Tracker:IsEnabled() then
            EnsureFrame():Show()
            Tracker:Refresh()
        end
        return
    end

    if event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        Tracker:ConsiderZone()
        return
    end

    if Tracker.frame and Tracker.frame:IsShown() then
        Tracker:Refresh()
    end
end)

pcall(eventFrame.RegisterEvent, eventFrame, "ZONE_CHANGED_NEW_AREA")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_ENTERING_WORLD")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_TARGET_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "UPDATE_MOUSEOVER_UNIT")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_REGEN_DISABLED")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_REGEN_ENABLED")

ns.UI = ns.UI or {}
ns.UI.TrackerWindow = Tracker
ns:RegisterModule("UI.TrackerWindow", Tracker)
