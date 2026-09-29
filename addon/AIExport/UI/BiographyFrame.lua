local _, ns = ...

local C = ns.constants
local U = ns.utils

local BiographyFrame = {}

BiographyFrame.frame = nil
BiographyFrame.scrollFrame = nil
BiographyFrame.content = nil
BiographyFrame.text = nil
BiographyFrame.pageLabel = nil
BiographyFrame.olderButton = nil
BiographyFrame.newerButton = nil
BiographyFrame.page = nil

local FRAME_WIDTH = 560
local FRAME_HEIGHT = 520
local ROWS_PER_PAGE = 40
local BUTTON_WIDTH = 90
local BUTTON_HEIGHT = 22

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
    local total = #events

    if total == 0 then
        return C.TEXT.BIOGRAPHY_EMPTY
    end

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
                table.insert(lines, "|cffffd100" .. entryDate .. "|r")
            end

            table.insert(
                lines,
                string.format(
                    "|cff9d9d9d%s|r  %s",
                    biography:FormatTime(entry.t),
                    U.SafeString(entry.text, "")
                )
            )
        end
    end

    return table.concat(lines, "\n")
end

local function CreateButton(parent, label, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")

    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetText(label)
    button:SetScript("OnClick", onClick)

    return button
end

function BiographyFrame:Refresh()
    if not self.frame then
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

    self.text:SetText(BuildPageText(events, self.page))

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

    local width = self.scrollFrame:GetWidth()

    if width and width > 0 then
        self.content:SetWidth(width)
        self.text:SetWidth(width - 8)
    end

    self.content:SetHeight(
        math.max(
            (self.text:GetStringHeight() or 0) + 12,
            self.scrollFrame:GetHeight() or 1
        )
    )

    self.scrollFrame:SetVerticalScroll(0)
end

function BiographyFrame:ShowPage(page)
    self.page = page
    self:Refresh()
end

local function EnsureFrame()
    if BiographyFrame.frame then
        return BiographyFrame.frame
    end

    local frame = CreateFrame(
        "Frame",
        "AIExportBiographyFrame",
        UIParent,
        "BasicFrameTemplateWithInset"
    )

    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    if frame.TitleText then
        frame.TitleText:SetText(C.TEXT.BIOGRAPHY_WINDOW_TITLE)
    end

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "AIExportBiographyFrame")
    end

    local scrollFrame = CreateFrame(
        "ScrollFrame",
        "AIExportBiographyScrollFrame",
        frame,
        "UIPanelScrollFrameTemplate"
    )

    scrollFrame:SetPoint("TOPLEFT", 16, -32)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 48)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(FRAME_WIDTH - 50, 1)
    scrollFrame:SetScrollChild(content)

    local text = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 4, -4)
    text:SetWidth(FRAME_WIDTH - 58)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")

    local olderButton = CreateButton(frame, C.TEXT.BUTTON_OLDER, function()
        BiographyFrame:ShowPage((BiographyFrame.page or 1) - 1)
    end)
    olderButton:SetPoint("BOTTOMLEFT", 16, 16)

    local newerButton = CreateButton(frame, C.TEXT.BUTTON_NEWER, function()
        BiographyFrame:ShowPage((BiographyFrame.page or 1) + 1)
    end)
    newerButton:SetPoint("BOTTOMRIGHT", -16, 16)

    local pageLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    pageLabel:SetPoint("BOTTOM", 0, 22)

    frame:SetScript("OnShow", function()
        BiographyFrame:Refresh()
    end)

    BiographyFrame.frame = frame
    BiographyFrame.scrollFrame = scrollFrame
    BiographyFrame.content = content
    BiographyFrame.text = text
    BiographyFrame.pageLabel = pageLabel
    BiographyFrame.olderButton = olderButton
    BiographyFrame.newerButton = newerButton

    local biography = GetBiography()

    if biography and type(biography.OnChanged) == "function" then
        biography:OnChanged(function()
            if frame:IsShown() then
                BiographyFrame:Refresh()
            end
        end)
    end

    return frame
end

function BiographyFrame:Show()
    local frame = EnsureFrame()

    self.page = nil
    frame:Show()
end

function BiographyFrame:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function BiographyFrame:Toggle()
    local frame = EnsureFrame()

    if frame:IsShown() then
        frame:Hide()
    else
        self:Show()
    end
end

ns:RegisterModule(
    "UI.BiographyFrame",
    BiographyFrame
)

ns.UI = ns.UI or {}
ns.UI.BiographyFrame = BiographyFrame
