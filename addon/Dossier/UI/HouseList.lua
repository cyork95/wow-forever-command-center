local _, ns = ...

local HouseList = {}

local function Menu(parent, width, initialLabel, onPick)
    local Theme = ns.Theme
    local button = Theme.CreateButton(parent, initialLabel or "Choose", width, 22, "default", function(self)
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

    if type(list.SetFrameLevel) == "function" then
        list:SetFrameLevel(40)
    end

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
    button.rows = {}

    function button:SetChoices(choices, selected)
        self.choices = choices or {}
        self.selected = selected
        local label = "Choose"

        for _, choice in ipairs(self.choices) do
            if choice.id == selected then
                label = choice.label
            end
        end

        self:SetLabel(label)

        local height = 4

        for index, choice in ipairs(self.choices) do
            local pickedId = choice.id
            local pickedLabel = choice.label
            local row = self.rows[index]

            if not row then
                row = Theme.CreateButton(list, pickedLabel, width - 8, 20, "default", function() end)
                self.rows[index] = row
            end

            row:SetLabel(pickedLabel)
            row:SetScript("OnClick", function()
                self.selected = pickedId
                self:SetLabel(pickedLabel)
                list:Hide()
                onPick(pickedId)
            end)
            Theme.SetBorderColor(row, pickedId == selected and "accent" or "border")
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 4, -height)
            row:Show()
            height = height + 22
        end

        for index = #self.choices + 1, #self.rows do
            self.rows[index]:Hide()
        end

        list:SetHeight(math.max(height + 4, 8))
    end

    return button
end

local STANDING_COLORS = {
    Hated = { 0.78, 0.16, 0.16 },
    Hostile = { 0.86, 0.28, 0.14 },
    Unfriendly = { 0.90, 0.48, 0.16 },
    Neutral = { 0.90, 0.78, 0.28 },
    Friendly = { 0.28, 0.72, 0.32 },
    Honored = { 0.22, 0.62, 0.78 },
    Revered = { 0.36, 0.46, 0.90 },
    Exalted = { 0.64, 0.40, 0.92 },
}

local function AttachBlocks(box)
    local Theme = ns.Theme
    local pool = {}
    local used = {}

    local function Take(kind, factory)
        for index, frame in ipairs(pool) do
            if frame.kind == kind then
                table.remove(pool, index)
                frame:Show()
                table.insert(used, frame)
                return frame
            end
        end

        local frame = factory()
        frame.kind = kind
        frame:Show()
        table.insert(used, frame)
        return frame
    end

    function box:SetBlocks(blocks)
        for _, frame in ipairs(used) do
            frame:Hide()
            table.insert(pool, frame)
        end

        used = {}
        self.text:SetText("")
        self.text:Hide()

        local width = (self.scrollFrame:GetWidth() or 280) - 8
        local y = 0

        for _, block in ipairs(blocks or {}) do
            if block.kind == "bar" then
                local row = Take("bar", function()
                    local frame = CreateFrame("Frame", nil, self.content)
                    frame:SetHeight(28)
                    local name = Theme.CreateText(frame, "GameFontHighlightSmall", "text")
                    name:SetPoint("TOPLEFT", 0, 0)
                    local right = Theme.CreateText(frame, "GameFontHighlightSmall", "muted")
                    right:SetPoint("TOPRIGHT", 0, 0)
                    local bar = CreateFrame("StatusBar", nil, frame)
                    bar:SetPoint("BOTTOMLEFT", 0, 2)
                    bar:SetPoint("BOTTOMRIGHT", 0, 2)
                    bar:SetHeight(8)
                    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
                    bar:SetMinMaxValues(0, 1)
                    local back = bar:CreateTexture(nil, "BACKGROUND")
                    back:SetAllPoints()
                    back:SetTexture("Interface\\Buttons\\WHITE8x8")
                    back:SetVertexColor(0.08, 0.09, 0.1, 0.9)
                    frame.name = name
                    frame.right = right
                    frame.bar = bar
                    return frame
                end)
                row:SetWidth(width)
                row.name:SetText(block.label or "")
                row.right:SetText(block.right or "")
                local maxValue = tonumber(block.max) or 0
                local value = tonumber(block.value) or 0
                row.bar:SetMinMaxValues(0, maxValue > 0 and maxValue or 1)
                row.bar:SetValue(maxValue > 0 and math.min(value, maxValue) or 0)
                local color = STANDING_COLORS[block.color] or { 0.25, 0.78, 0.82 }
                row.bar:SetStatusBarColor(color[1], color[2], color[3])
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 4, -y)
                y = y + 32
            else
                local line = Take("line", function()
                    local text = Theme.CreateText(self.content, "GameFontHighlightSmall", "text")
                    text:SetJustifyH("LEFT")
                    text:SetJustifyV("TOP")
                    text:SetWordWrap(true)
                    return text
                end)
                local font = block.kind == "heading" and "GameFontNormal" or "GameFontHighlightSmall"
                line:SetFontObject(font)
                line:SetTextColor(Theme.Color(block.kind == "heading" and "accent" or "text"))
                line:SetWidth(width)
                line:SetText(block.text or "")
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT", 4, -y)
                y = y + (line:GetStringHeight() or 14) + (block.kind == "heading" and 8 or 3)
            end
        end

        self.content:SetWidth(width)
        self.content:SetHeight(math.max(y + 8, self.scrollFrame:GetHeight() or 1))

        if type(self.scrollFrame.UpdateScrollChildRect) == "function" then
            self.scrollFrame:UpdateScrollChildRect()
        end
    end
end

function HouseList.Build(page, options)
    local Theme = ns.Theme
    local state = {
        character = "all",
        period = options.period or "all",
        source = options.source or "summary",
        query = "",
    }

    local function ChoiceLabel(choices, id, fallback)
        for _, choice in ipairs(choices or {}) do
            if choice.id == id then
                return choice.label
            end
        end

        return fallback
    end

    local characters = Menu(page, 180, "All characters", function(id)
        state.character = id
        state.refresh()
    end)
    characters:SetPoint("TOPLEFT", 0, 0)

    local periods = nil

    if options.periods then
        periods = Menu(page, 120, ChoiceLabel(options.periods, state.period, "All"), function(id)
            state.period = id
            state.refresh()
        end)
        periods:SetPoint("LEFT", characters, "RIGHT", 8, 0)
    end

    local sources = nil

    if options.sources then
        sources = Menu(page, 150, ChoiceLabel(options.sources, state.source, "Summary"), function(id)
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
    AttachBlocks(box)

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

        if options.blocks then
            box:SetBlocks(options.blocks(state) or {})
        else
            box.text:Show()
            box:SetText(options.text and options.text(state) or "")
        end
    end

    page:SetScript("OnShow", function()
        state.refresh()
    end)

    state.refresh()

    return state
end

ns.UI = ns.UI or {}
ns.UI.HouseList = HouseList
