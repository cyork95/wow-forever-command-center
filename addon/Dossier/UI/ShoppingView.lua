local _, ns = ...

local C = ns.constants

local ShoppingView = {}

ShoppingView.container = nil
ShoppingView.rows = {}
ShoppingView.offset = 0

local ROW_COUNT = 14
local ROW_HEIGHT = 20
local LIST_TOP = -52
local BUTTON_SIZE = 18

local function GetList()
    return ns.Data and ns.Data.ShoppingList
end

local function FormatCount(value)
    local list = GetList()
    return list and list.FormatCount(value) or tostring(value)
end

local function IsShift()
    return type(IsShiftKeyDown) == "function" and IsShiftKeyDown() == true
end

-- Recipes first, then items with the short ones on top.
function ShoppingView.Entries()
    local list = GetList()
    local entries = {}

    if not list then
        return entries
    end

    for _, recipe in ipairs(list:GetRecipes()) do
        table.insert(entries, { kind = "recipe", recipe = recipe })
    end

    for _, row in ipairs(list:GetRows()) do
        table.insert(entries, { kind = "item", row = row })
    end

    return entries
end

function ShoppingView.RecipeText(recipe)
    local text = string.format("%s x%s", recipe.name or "Recipe", FormatCount(recipe.count))

    if recipe.profession then
        text = text .. " (" .. recipe.profession .. ")"
    end

    return text
end

function ShoppingView.SummaryText()
    local list = GetList()

    if not list then
        return ""
    end

    local rows = list:GetRows()
    local ready = 0

    for _, row in ipairs(rows) do
        if row.short == 0 then
            ready = ready + 1
        end
    end

    local text = #rows > 0 and string.format(C.TEXT.SHOPPING_SUMMARY, ready, #rows) or ""
    local imported = list:GetImportedFrom()

    if imported then
        text = text .. (text ~= "" and "   " or "") .. string.format(C.TEXT.SHOPPING_IMPORTED, imported)
    end

    return text
end

local function ShowTooltip(row)
    local entry = row.entry

    if not entry or not GameTooltip or type(GameTooltip.SetOwner) ~= "function" then
        return
    end

    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")

    if entry.kind == "recipe" then
        local recipe = entry.recipe
        GameTooltip:AddLine(ShoppingView.RecipeText(recipe))

        if recipe.pending then
            GameTooltip:AddLine(GetList().PendingText(recipe), 1, 0.6, 0.3, true)
        end

        for _, reagent in ipairs(recipe.reagents) do
            GameTooltip:AddLine(string.format("%s x%s", reagent.name or "Item", FormatCount(reagent.count * recipe.count)), 1, 1, 1)
        end
    else
        local data = entry.row
        GameTooltip:AddLine(data.name or ("Item " .. data.itemID))
        GameTooltip:AddLine(string.format(C.TEXT.SHOPPING_TOOLTIP_HAVE, FormatCount(data.bags), FormatCount(data.bank)), 1, 1, 1)

        for _, source in ipairs(data.sources) do
            GameTooltip:AddLine(source, 0.7, 0.7, 0.7)
        end

        GameTooltip:AddLine(C.TEXT.SHOPPING_TOOLTIP_HINT, 0.6, 0.6, 0.6, true)
    end

    GameTooltip:Show()
end

local function HideTooltip()
    if GameTooltip and type(GameTooltip.Hide) == "function" then
        GameTooltip:Hide()
    end
end

local function Step()
    return IsShift() and 5 or 1
end

local function CreateRow(parent, index)
    local Theme = ns.Theme
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 4, -4 - ((index - 1) * ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", -4, -4 - ((index - 1) * ROW_HEIGHT))

    local highlight = row:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints()
    highlight:SetColorTexture(Theme.Color("cardHover"))
    highlight:Hide()

    local remove = Theme.CreateButton(row, "x", BUTTON_SIZE, 16, "default", function()
        local list = GetList()
        local entry = row.entry

        if not list or not entry then
            return
        end

        if entry.kind == "recipe" then
            list:RemoveRecipe(entry.recipe.recipeID)
        else
            list:Remove(entry.row.itemID)
        end
    end)
    remove:SetPoint("RIGHT", -2, 0)

    local plus = Theme.CreateButton(row, "+", BUTTON_SIZE, 16, "default", function()
        local list = GetList()
        local entry = row.entry

        if not list or not entry then
            return
        end

        if entry.kind == "recipe" then
            list:ChangeRecipeCount(entry.recipe.recipeID, Step())
        else
            list:ChangeTarget(entry.row.itemID, Step())
        end
    end)
    plus:SetPoint("RIGHT", remove, "LEFT", -3, 0)

    local minus = Theme.CreateButton(row, "-", BUTTON_SIZE, 16, "default", function()
        local list = GetList()
        local entry = row.entry

        if not list or not entry then
            return
        end

        if entry.kind == "recipe" then
            list:ChangeRecipeCount(entry.recipe.recipeID, -Step())
        else
            list:ChangeTarget(entry.row.itemID, -Step())
        end
    end)
    minus:SetPoint("RIGHT", plus, "LEFT", -3, 0)

    local status = Theme.CreateText(row, "GameFontHighlightSmall", "muted")
    status:SetPoint("RIGHT", minus, "LEFT", -10, 0)
    status:SetWidth(90)
    status:SetJustifyH("LEFT")
    status:SetWordWrap(false)

    local count = Theme.CreateText(row, "GameFontHighlightSmall", "text")
    count:SetPoint("RIGHT", status, "LEFT", -8, 0)
    count:SetWidth(80)
    count:SetJustifyH("RIGHT")
    count:SetWordWrap(false)

    local name = Theme.CreateText(row, "GameFontHighlightSmall", "text")
    name:SetPoint("LEFT", 6, 0)
    name:SetPoint("RIGHT", count, "LEFT", -8, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)

    row:SetScript("OnEnter", function(self)
        highlight:Show()
        ShowTooltip(self)
    end)
    row:SetScript("OnLeave", function()
        highlight:Hide()
        HideTooltip()
    end)

    row.nameText = name
    row.countText = count
    row.statusText = status
    row.minusButton = minus
    row.plusButton = plus
    row.removeButton = remove
    row:Hide()

    return row
end

function ShoppingView:Submit()
    local list = GetList()
    local text = self.input and self.input:GetText() or ""

    if not list or text == "" then
        return false
    end

    local ok, reason = list:Add(text)
    self.messageShown = not ok
    self.messageText:SetTextColor(ns.Theme.Color("warning"))

    if ok then
        self.input:SetText("")
    elseif reason == "duplicate" then
        self.messageText:SetText(C.TEXT.SHOPPING_DUPLICATE)
    else
        local _, linkName = list.ParseItemLink(text)
        self.messageText:SetText(string.format(C.TEXT.SHOPPING_NOT_FOUND, linkName or text))
    end

    self:Refresh()

    return ok
end

function ShoppingView:Suggest()
    local list = GetList()

    if not list then
        return {}
    end

    local added = list:SuggestFromBags()
    self.messageShown = true

    if #added > 0 then
        self.messageText:SetTextColor(ns.Theme.Color("accent"))
        self.messageText:SetText(string.format(C.TEXT.SHOPPING_SUGGESTED, #added, #added == 1 and "" or "s"))
    else
        self.messageText:SetTextColor(ns.Theme.Color("warning"))
        self.messageText:SetText(C.TEXT.SHOPPING_SUGGEST_NONE)
    end

    self:Refresh()

    return added
end

-- A dragged item goes straight onto the list.
function ShoppingView:AcceptCursor()
    if type(GetCursorInfo) ~= "function" then
        return false
    end

    local kind, itemID, link = GetCursorInfo()

    if kind ~= "item" then
        return false
    end

    if type(ClearCursor) == "function" then
        ClearCursor()
    end

    self.input:SetText(type(link) == "string" and link or tostring(itemID))

    return self:Submit()
end

local function HookShiftClick(input)
    local function Insert(link)
        if type(link) == "string" and input:HasFocus() then
            input:Insert(link)
        end
    end

    if type(hooksecurefunc) ~= "function" then
        return
    end

    if type(ChatEdit_InsertLink) == "function" then
        hooksecurefunc("ChatEdit_InsertLink", Insert)
    elseif type(ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
        hooksecurefunc(ChatFrameUtil, "InsertLink", Insert)
    end
end

function ShoppingView:Build(parent)
    if self.container then
        return self.container
    end

    local Theme = ns.Theme
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints()

    local add = Theme.CreateButton(container, C.TEXT.SHOPPING_ADD, 80, 22, "primary", function()
        ShoppingView:Submit()
    end)
    add:SetPoint("TOPRIGHT", 0, 0)

    local input = CreateFrame("EditBox", nil, container, Theme.BACKDROP_TEMPLATE)
    input:SetHeight(22)
    input:SetPoint("TOPLEFT", 0, 0)
    input:SetPoint("RIGHT", add, "LEFT", -6, 0)
    input:SetAutoFocus(false)
    input:SetFontObject(ChatFontNormal)
    input:SetTextInsets(6, 6, 0, 0)
    Theme.ApplyBackdrop(input, "dark", "border")

    local placeholder = Theme.CreateText(input, "GameFontHighlightSmall", "disabled")
    placeholder:SetPoint("LEFT", 7, 0)
    placeholder:SetText(C.TEXT.SHOPPING_PLACEHOLDER)

    input:SetScript("OnTextChanged", function(self, userInput)
        placeholder:SetShown((self:GetText() or "") == "")

        if userInput then
            ShoppingView.messageShown = false
        end
    end)
    input:SetScript("OnEnterPressed", function()
        ShoppingView:Submit()
    end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    input:SetScript("OnReceiveDrag", function() ShoppingView:AcceptCursor() end)
    input:SetScript("OnMouseDown", function() ShoppingView:AcceptCursor() end)
    HookShiftClick(input)

    local summary = Theme.CreateText(container, "GameFontHighlightSmall", "muted")
    summary:SetPoint("TOPLEFT", 0, -30)
    summary:SetJustifyH("LEFT")

    local message = Theme.CreateText(container, "GameFontHighlightSmall", "warning")
    message:SetPoint("TOPRIGHT", 0, -30)
    message:SetJustifyH("RIGHT")

    local list = Theme.CreatePanel(container, "dark", "border")
    list:SetPoint("TOPLEFT", 0, LIST_TOP)
    list:SetPoint("TOPRIGHT", 0, LIST_TOP)
    list:SetHeight(ROW_COUNT * ROW_HEIGHT + 8)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        ShoppingView.offset = math.max(0, ShoppingView.offset - delta * 3)
        ShoppingView:Refresh()
    end)

    for index = 1, ROW_COUNT do
        self.rows[index] = CreateRow(list, index)
    end

    local empty = Theme.CreateText(list, "GameFontHighlightSmall", "muted")
    empty:SetPoint("TOPLEFT", 10, -10)
    empty:SetPoint("TOPRIGHT", -10, -10)
    empty:SetJustifyH("LEFT")
    empty:SetText(C.TEXT.SHOPPING_EMPTY)

    local remind = Theme.CreateCheckbox(container, C.TEXT.SHOPPING_REMIND, function(self)
        local current = GetList()

        if current then
            current:SetRemind(self:GetChecked() == true)
        end
    end)
    remind:SetPoint("BOTTOMLEFT", 0, 6)

    local clear = Theme.CreateButton(container, C.TEXT.SHOPPING_CLEAR, 110, 22, "default", function()
        local current = GetList()

        if current then
            current:ClearFinished()
        end
    end)
    clear:SetPoint("BOTTOMRIGHT", 0, 0)

    local suggest = Theme.CreateButton(container, C.TEXT.SHOPPING_SUGGEST, 130, 22, "default", function()
        ShoppingView:Suggest()
    end)
    suggest:SetPoint("RIGHT", clear, "LEFT", -6, 0)

    container:SetScript("OnShow", function()
        ShoppingView:Refresh()
    end)

    self.container = container
    self.input = input
    self.addButton = add
    self.summaryText = summary
    self.messageText = message
    self.list = list
    self.emptyText = empty
    self.remindToggle = remind
    self.clearButton = clear
    self.suggestButton = suggest

    local data = GetList()

    if data then
        data:OnChanged(function()
            if container:IsVisible() then
                ShoppingView:Refresh()
            end
        end)
    end

    return container
end

function ShoppingView:Refresh()
    if not self.container then
        return
    end

    local list = GetList()

    if not list then
        return
    end

    local entries = ShoppingView.Entries()
    local pendingNote = nil
    self.offset = math.min(self.offset, math.max(0, #entries - ROW_COUNT))

    for index, row in ipairs(self.rows) do
        local entry = entries[self.offset + index]
        row.entry = entry

        if not entry then
            row:Hide()
        elseif entry.kind == "recipe" then
            local recipe = entry.recipe
            row.nameText:SetText(ShoppingView.RecipeText(recipe))
            row.nameText:SetTextColor(ns.Theme.Color("accent"))
            row.countText:SetText("")
            row.statusText:SetText(recipe.pending and C.TEXT.SHOPPING_PENDING_SHORT or "")
            row.statusText:SetTextColor(ns.Theme.Color("warning"))
            row:Show()

            if recipe.pending and not pendingNote then
                pendingNote = list.PendingText(recipe)
            end
        else
            local data = entry.row
            row.nameText:SetText(data.name or ("Item " .. data.itemID))
            row.nameText:SetTextColor(ns.Theme.Color("text"))
            row.countText:SetText(FormatCount(data.have) .. " / " .. FormatCount(data.need))

            if data.short == 0 then
                row.statusText:SetText(C.TEXT.SHOPPING_READY)
                row.statusText:SetTextColor(ns.Theme.Color("accent"))
            else
                row.statusText:SetText(string.format(C.TEXT.SHOPPING_NEED, FormatCount(data.short)))
                row.statusText:SetTextColor(ns.Theme.Color("warning"))
            end

            row:Show()
        end
    end

    self.emptyText:SetShown(#entries == 0)
    self.summaryText:SetText(ShoppingView.SummaryText())

    if not self.messageShown then
        self.messageText:SetTextColor(ns.Theme.Color("warning"))
        self.messageText:SetText(pendingNote or "")
    end

    self.remindToggle:SetChecked(list:IsRemindOn())
end

ns:RegisterModule("UI.ShoppingView", ShoppingView)

ns.UI = ns.UI or {}
ns.UI.ShoppingView = ShoppingView
