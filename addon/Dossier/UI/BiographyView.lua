local _, ns = ...

local C = ns.constants
local U = ns.utils

local BiographyView = {}

BiographyView.container = nil
BiographyView.scrollBox = nil
BiographyView.pageLabel = nil
BiographyView.olderButton = nil
BiographyView.newerButton = nil
BiographyView.page = nil

local ROWS_PER_PAGE = 40

BiographyView.ROWS_PER_PAGE = ROWS_PER_PAGE

local function GetBiography()
    return ns.Data and ns.Data.Biography
end

local function GetEvents()
    local biography = GetBiography()

    if biography and type(biography.GetEvents) == "function" then
        return biography:GetEvents()
    end

    return {}
end

local function GetPageCount(total)
    if total <= 0 then
        return 1
    end

    return math.ceil(total / ROWS_PER_PAGE)
end

local function BuildPageText(events, page)
    local biography = GetBiography()
    local Theme = ns.Theme
    local total = #events

    if total == 0 then
        return C.TEXT.BIOGRAPHY_EMPTY
    end

    local dateColor = Theme.ColorCode("accent")
    local timeColor = Theme.ColorCode("muted")
    local first = (page - 1) * ROWS_PER_PAGE + 1
    local last = math.min(page * ROWS_PER_PAGE, total)
    local lines = {}
    local currentDate = nil

    for index = first, last do
        local entry = events[index]

        if type(entry) == "table" then
            local entryDate = biography:FormatDate(entry.t)

            if entryDate ~= currentDate then
                if currentDate ~= nil then
                    table.insert(lines, "")
                end

                currentDate = entryDate
                table.insert(lines, dateColor .. entryDate .. "|r")
            end

            table.insert(
                lines,
                string.format(
                    "%s%s|r  %s",
                    timeColor,
                    biography:FormatTime(entry.t),
                    U.SafeString(entry.text, "")
                )
            )
        end
    end

    return table.concat(lines, "\n")
end

function BiographyView:Build(parent)
    if self.container then
        return self.container
    end

    local Theme = ns.Theme
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints()

    local description = Theme.CreateText(container, "GameFontHighlightSmall", "muted")
    description:SetPoint("TOPLEFT", 0, 0)
    description:SetPoint("TOPRIGHT", 0, 0)
    description:SetText(C.TEXT.LABEL_BIOGRAPHY_DESCRIPTION)

    local scrollBox = Theme.CreateScrollText(
        container,
        "DossierBiographyScrollFrame",
        "GameFontHighlight"
    )
    scrollBox:SetPoint("TOPLEFT", 0, -24)
    scrollBox:SetPoint("BOTTOMRIGHT", 0, 36)

    local olderButton = Theme.CreateButton(container, C.TEXT.BUTTON_OLDER, 90, 22, "default", function()
        BiographyView:ShowPage((BiographyView.page or 1) - 1)
    end)
    olderButton:SetPoint("BOTTOMLEFT", 0, 4)

    local newerButton = Theme.CreateButton(container, C.TEXT.BUTTON_NEWER, 90, 22, "default", function()
        BiographyView:ShowPage((BiographyView.page or 1) + 1)
    end)
    newerButton:SetPoint("BOTTOMRIGHT", 0, 4)

    local pageLabel = Theme.CreateText(container, "GameFontHighlightSmall", "muted")
    pageLabel:SetPoint("BOTTOM", 0, 10)
    pageLabel:SetJustifyH("CENTER")

    container:SetScript("OnShow", function()
        BiographyView:Refresh()
    end)

    self.container = container
    self.scrollBox = scrollBox
    self.pageLabel = pageLabel
    self.olderButton = olderButton
    self.newerButton = newerButton

    local biography = GetBiography()

    if biography and type(biography.OnChanged) == "function" then
        biography:OnChanged(function()
            if container:IsVisible() then
                BiographyView:Refresh()
            end
        end)
    end

    return container
end

function BiographyView:Refresh()
    if not self.container then
        return
    end

    local events = GetEvents()
    local total = #events
    local pageCount = GetPageCount(total)

    if self.page == nil or self.page > pageCount then
        self.page = pageCount
    end

    if self.page < 1 then
        self.page = 1
    end

    self.scrollBox:SetText(BuildPageText(events, self.page))

    self.pageLabel:SetText(
        string.format(
            "Page %d of %d  -  %d events",
            self.page,
            pageCount,
            total
        )
    )

    if self.page > 1 then
        self.olderButton:Enable()
    else
        self.olderButton:Disable()
    end

    if self.page < pageCount then
        self.newerButton:Enable()
    else
        self.newerButton:Disable()
    end
end

function BiographyView:ShowPage(page)
    self.page = page
    self:Refresh()
end

function BiographyView:ShowNewest()
    self.page = nil
    self:Refresh()
end

ns:RegisterModule("UI.BiographyView", BiographyView)

ns.UI = ns.UI or {}
ns.UI.BiographyView = BiographyView
