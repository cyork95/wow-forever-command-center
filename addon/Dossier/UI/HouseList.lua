local _, ns = ...

local HouseList = {}

local function Menu(parent, width, onPick)
    local Theme = ns.Theme
    local button = Theme.CreateButton(parent, "All characters", width, 22, "default", function(self)
        if self.list:IsShown() then
            self.list:Hide()
        else
            self.list:Show()
        end
    end)

    local list = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    list:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    list:SetWidth(width)
    list:Hide()
    list:SetFrameStrata("DIALOG")

    if list.SetBackdrop then
        list:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        list:SetBackdropColor(0.08, 0.07, 0.05, 0.96)
        list:SetBackdropBorderColor(0.45, 0.36, 0.18, 1)
    end

    button.list = list
    button.choices = {}
    button.selected = nil

    function button:SetChoices(choices, selected)
        self.choices = choices or {}
        self.selected = selected
        local label = selected or "Choose"

        for _, choice in ipairs(self.choices) do
            if choice.id == selected then
                label = choice.label
            end
        end

        self:SetText(label)

        if self.rows then
            for _, row in ipairs(self.rows) do
                row:Hide()
            end
        end

        self.rows = {}
        local height = 4

        for index, choice in ipairs(self.choices) do
            local row = self.rows[index] or Theme.CreateButton(list, choice.label, width - 8, 20, "default", function()
                self.selected = choice.id
                self:SetText(choice.label)
                list:Hide()
                onPick(choice.id)
            end)
            row:SetText(choice.label)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 4, -height)
            row:Show()
            self.rows[index] = row
            height = height + 22
        end

        list:SetHeight(math.max(height + 4, 8))
    end

    return button
end

function HouseList.Build(page, options)
    local Theme = ns.Theme
    local state = {
        character = "all",
        period = options.period or "all",
        source = options.source or "summary",
        query = "",
    }

    local characters = Menu(page, 180, function(id)
        state.character = id
        state.refresh()
    end)
    characters:SetPoint("TOPLEFT", 0, 0)

    local periods = nil

    if options.periods then
        periods = Menu(page, 120, function(id)
            state.period = id
            state.refresh()
        end)
        periods:SetPoint("LEFT", characters, "RIGHT", 8, 0)
    end

    local sources = nil

    if options.sources then
        sources = Menu(page, 150, function(id)
            state.source = id
            state.refresh()
        end)
        sources:SetPoint("LEFT", periods or characters, "RIGHT", 8, 0)
    end

    if options.search then
        local search = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
        search:SetSize(160, 20)
        search:SetPoint("TOPLEFT", 0, -30)
        search:SetAutoFocus(false)
        search:SetScript("OnTextChanged", function(self)
            state.query = self:GetText() or ""
            state.refresh()
        end)
    end

    local box = Theme.CreateScrollText(page, nil, "GameFontHighlightSmall")
    box:SetPoint("TOPLEFT", 0, options.search and -56 or -32)
    box:SetPoint("BOTTOMRIGHT", 0, options.footer and 28 or 0)

    function state.refresh()
        local account = ns.Account
        local keys = options.keys and options.keys() or {}
        local choices = { { id = "all", label = "All characters" } }

        for _, key in ipairs(keys) do
            table.insert(choices, { id = key, label = key })
        end

        if state.character ~= "all" then
            local found = false

            for _, choice in ipairs(choices) do
                if choice.id == state.character then
                    found = true
                end
            end

            if not found then
                state.character = account and account.CharacterKey() or "all"
            end
        end

        characters:SetChoices(choices, state.character)

        if periods then
            periods:SetChoices(options.periods, state.period)
        end

        if sources then
            sources:SetChoices(options.sources, state.source)
        end

        box:SetText(options.text(state) or "")
    end

    page:SetScript("OnShow", function()
        state.refresh()
    end)

    return state
end

ns.UI = ns.UI or {}
ns.UI.HouseList = HouseList
