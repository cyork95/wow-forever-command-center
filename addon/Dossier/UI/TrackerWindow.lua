local _, ns = ...

local Tracker = {}

local dismissedZone = nil

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

    return bucket
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
        return string.format("%s  %s %.1f, %.1f", name, place, x, y)
    end

    return name .. "  " .. place
end

function Tracker:Lines()
    local lines = {}
    local zone = Zone()
    local tasks = ns.Data and ns.Data.Tasks

    if tasks and ns:IsFeatureOn("tasks") then
        local shown = false

        for _, task in ipairs(tasks:Open(Account().CharacterKey())) do
            if not task.zone or task.zone == "" or task.zone == zone then
                if not shown then
                    table.insert(lines, "Still to do")
                    shown = true
                end

                table.insert(lines, "  " .. task.name .. "  " .. tasks:Cadence(task))
            end
        end
    end

    local shop = ns.Data and ns.Data.ShoppingList

    if shop and ns:IsFeatureOn("shopping") and type(shop.GetShortRows) == "function" then
        local shorts = shop:GetShortRows()
        local shown = false

        for _, row in ipairs(shorts or {}) do
            local name = row.name or row.text

            if name then
                if not shown then
                    table.insert(lines, "Shopping")
                    shown = true
                end

                table.insert(lines, string.format("  %s  %s", name, tostring(row.short or 0)))
            end
        end
    end

    if ns:IsFeatureOn("kills") then
        local shown = false
        local bucket = Account() and Account().Database() and Account().Database().rares or {}

        for _, rare in pairs(bucket) do
            if type(rare) == "table" and rare.name and rare.zone == zone then
                if not shown then
                    table.insert(lines, "Rares here")
                    shown = true
                end

                local place = rare.x and rare.y and string.format("%.1f, %.1f", rare.x, rare.y) or ""
                table.insert(lines, "  " .. rare.name .. (place ~= "" and ("  " .. place) or ""))
            end
        end

        for _, unit in ipairs({ "target", "mouseover" }) do
            local line = RareLine(unit)

            if line then
                if not shown then
                    table.insert(lines, "Rares here")
                    shown = true
                end

                table.insert(lines, "  " .. line)
            end
        end
    end

    return lines
end

function Tracker:Refresh()
    if not self.text then
        return
    end

    local lines = self:Lines()
    self.text:SetText(#lines > 0 and table.concat(lines, "\n") or "Nothing waiting in this zone.")
end

local function EnsureFrame()
    if Tracker.frame then
        return Tracker.frame
    end

    local Theme = ns.Theme
    local frame = Theme.CreatePanel(UIParent, "panel", "border", "DossierTracker")
    frame:SetSize(240, 220)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    if type(frame.SetClampedToScreen) == "function" then
        frame:SetClampedToScreen(true)
    end
    frame:SetPoint("LEFT", UIParent, "LEFT", 40, 40)
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    local title = Theme.CreateText(frame, "GameFontHighlight", "text")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Tasks")

    local close = Theme.CreateCloseButton(frame, function()
        dismissedZone = Zone()
        frame:Hide()
    end)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -6, -6)

    local toggle = Theme.CreateCheckbox(frame, "Open on zone change", function(self)
        local settings = Settings()

        if settings then
            settings.autoOpen = self:GetChecked() == true
        end
    end)
    toggle:SetPoint("BOTTOMLEFT", 10, 8)
    toggle:SetChecked(true)

    local text = Theme.CreateText(frame, "GameFontHighlightSmall", "text")
    text:SetPoint("TOPLEFT", 12, -32)
    text:SetPoint("BOTTOMRIGHT", -12, 32)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")

    Tracker.frame = frame
    Tracker.text = text
    Tracker.toggle = toggle

    return frame
end

function Tracker:Show()
    if not ns:IsFeatureOn("tasks") then
        return
    end

    local frame = EnsureFrame()
    local settings = Settings()

    if settings and self.toggle then
        self.toggle:SetChecked(settings.autoOpen ~= false)
    end

    frame:Show()
    self:Refresh()
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

ns.UI = ns.UI or {}
ns.UI.TrackerWindow = Tracker
ns:RegisterModule("UI.TrackerWindow", Tracker)
