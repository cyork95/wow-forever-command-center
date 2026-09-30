local _, ns = ...

local U = ns.utils
local C = ns.constants

local Currencies = {}

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end

    return pcall(fn, ...)
end

local function SafeNumber(value)
    return U.ToSafeNumber(value)
end

local function SafeString(value, fallback)
    local text = U.SafeString(value, fallback or "")
    text = U.Trim(text)

    if text ~= "" then
        return text
    end

    return fallback or ""
end

local function AddDiagnostic(diagnostics, message)
    if type(diagnostics) ~= "table" then
        return
    end

    if not U.IsNonEmptyString(message) then
        return
    end

    U.SafeInsert(diagnostics, message)
end

local function SetIfPresent(entry, key, value)
    if value ~= nil then
        entry[key] = value
    end
end

local function GetMoneyCopper(diagnostics)
    if type(GetMoney) ~= "function" then
        AddDiagnostic(
            diagnostics,
            "GetMoney API unavailable."
        )

        return 0
    end

    local success, money =
        SafeCall(GetMoney)

    if not success then
        AddDiagnostic(
            diagnostics,
            "GetMoney API call failed."
        )

        return 0
    end

    return SafeNumber(money) or 0
end

local function GetCurrencyIDFromLink(link)
    if type(link) ~= "string" or link == "" then
        return nil
    end

    local currencyID =
        link:match("currency:(%d+)")

    if currencyID then
        return tonumber(currencyID)
    end

    return nil
end

local function GetCurrencyListLink(index)
    if C_CurrencyInfo
        and type(C_CurrencyInfo.GetCurrencyListLink)
            == "function"
    then
        local success, link =
            SafeCall(
                C_CurrencyInfo.GetCurrencyListLink,
                index
            )

        if success
            and type(link) == "string"
            and link ~= ""
        then
            return link
        end
    end

    if type(GetCurrencyListLink) == "function" then
        local success, link =
            SafeCall(
                GetCurrencyListLink,
                index
            )

        if success
            and type(link) == "string"
            and link ~= ""
        then
            return link
        end
    end

    return nil
end

local function GetCurrencyIDForListIndex(index)
    local link =
        GetCurrencyListLink(index)

    return GetCurrencyIDFromLink(link)
end

local function EnrichCurrency(entry)
    if type(entry) ~= "table" then
        return
    end

    local currencyID =
        SafeNumber(entry.currencyID)

    if currencyID == nil then
        return
    end

    if not C_CurrencyInfo
        or type(C_CurrencyInfo.GetCurrencyInfo)
            ~= "function"
    then
        return
    end

    local success, info =
        SafeCall(
            C_CurrencyInfo.GetCurrencyInfo,
            currencyID
        )

    if not success
        or type(info) ~= "table"
    then
        return
    end

    if not U.IsNonEmptyString(entry.name)
        and U.IsNonEmptyString(info.name)
    then
        entry.name = info.name
    end

    if entry.quantity == nil then
        entry.quantity =
            SafeNumber(info.quantity)
    end

    if entry.maxQuantity == nil then
        entry.maxQuantity =
            SafeNumber(info.maxQuantity)
    end

    if entry.maxWeeklyQuantity == nil then
        entry.maxWeeklyQuantity =
            SafeNumber(info.maxWeeklyQuantity)
    end

    if entry.quantityEarnedThisWeek == nil then
        entry.quantityEarnedThisWeek =
            SafeNumber(
                info.quantityEarnedThisWeek
            )
    end

    if entry.totalEarned == nil then
        entry.totalEarned =
            SafeNumber(info.totalEarned)
    end

    if entry.canEarnPerWeek == nil then
        entry.canEarnPerWeek =
            info.canEarnPerWeek
    end

    if entry.discovered == nil then
        entry.discovered =
            info.discovered
    end

    if entry.isShowInBackpack == nil then
        entry.isShowInBackpack =
            info.isShowInBackpack
    end

    if entry.isTypeUnused == nil then
        entry.isTypeUnused =
            info.isTypeUnused
    end

    if entry.isTradeable == nil then
        entry.isTradeable =
            info.isTradeable
    end

    if entry.quality == nil then
        entry.quality =
            SafeNumber(info.quality)
    end

    if entry.iconFileID == nil then
        entry.iconFileID =
            SafeNumber(info.iconFileID)
    end
end

local function ShouldSkipCurrency(entry)
    if type(entry) ~= "table" then
        return true
    end

    if not U.IsNonEmptyString(entry.name) then
        return true
    end

    local quantity =
        SafeNumber(entry.quantity)

    local maxQuantity =
        SafeNumber(entry.maxQuantity)

    local maxWeeklyQuantity =
        SafeNumber(entry.maxWeeklyQuantity)

    if entry.discovered == false
        and (quantity == nil or quantity == 0)
        and (maxQuantity == nil or maxQuantity == 0)
        and (
            maxWeeklyQuantity == nil
            or maxWeeklyQuantity == 0
        )
        and entry.isShowInBackpack ~= true
    then
        return true
    end

    return false
end

local function AddCategory(
    categories,
    categoriesByName,
    name
)
    local categoryName =
        SafeString(name, "Other")

    if categoryName == "" then
        categoryName = "Other"
    end

    if not categoriesByName[categoryName] then
        local category = {
            name = categoryName,
            entries = {},
        }

        categoriesByName[categoryName] =
            category

        U.SafeInsert(
            categories,
            category
        )
    end

    return categoriesByName[categoryName]
end

local function AddEntry(
    categories,
    categoriesByName,
    entries,
    entry
)
    if ShouldSkipCurrency(entry) then
        return
    end

    local category =
        AddCategory(
            categories,
            categoriesByName,
            entry.category
        )

    U.SafeInsert(
        category.entries,
        entry
    )

    U.SafeInsert(
        entries,
        entry
    )
end

local function CollectModernCurrencyList(
    diagnostics
)
    if not C_CurrencyInfo then
        return nil
    end

    if type(C_CurrencyInfo.GetCurrencyListSize)
        ~= "function"
    then
        return nil
    end

    if type(C_CurrencyInfo.GetCurrencyListInfo)
        ~= "function"
    then
        return nil
    end

    local success, size =
        SafeCall(
            C_CurrencyInfo.GetCurrencyListSize
        )

    size =
        success
        and SafeNumber(size)
        or nil

    if size == nil then
        AddDiagnostic(
            diagnostics,
            "C_CurrencyInfo currency list size unavailable."
        )

        return {}, {}
    end

    local categories = {}
    local categoriesByName = {}
    local entries = {}

    local currentCategory = "Other"

    for index = 1, size do
        local infoSuccess, info =
            SafeCall(
                C_CurrencyInfo.GetCurrencyListInfo,
                index
            )

        if infoSuccess
            and type(info) == "table"
        then
            if info.isHeader == true then
                currentCategory =
                    SafeString(
                        info.name,
                        "Other"
                    )
            else
                local entry = {
                    category =
                        currentCategory,

                    currencyID =
                        SafeNumber(
                            info.currencyTypesID
                        )
                        or SafeNumber(
                            info.currencyID
                        )
                        or GetCurrencyIDForListIndex(
                            index
                        ),
                }

                SetIfPresent(
                    entry,
                    "name",
                    info.name
                )

                SetIfPresent(
                    entry,
                    "quantity",
                    SafeNumber(info.quantity)
                )

                SetIfPresent(
                    entry,
                    "maxQuantity",
                    SafeNumber(info.maxQuantity)
                )

                SetIfPresent(
                    entry,
                    "maxWeeklyQuantity",
                    SafeNumber(
                        info.maxWeeklyQuantity
                    )
                )

                SetIfPresent(
                    entry,
                    "quantityEarnedThisWeek",
                    SafeNumber(
                        info.quantityEarnedThisWeek
                    )
                )

                SetIfPresent(
                    entry,
                    "totalEarned",
                    SafeNumber(info.totalEarned)
                )

                SetIfPresent(
                    entry,
                    "canEarnPerWeek",
                    info.canEarnPerWeek
                )

                SetIfPresent(
                    entry,
                    "discovered",
                    info.discovered
                )

                SetIfPresent(
                    entry,
                    "isShowInBackpack",
                    info.isShowInBackpack
                )

                SetIfPresent(
                    entry,
                    "isTypeUnused",
                    info.isTypeUnused
                )

                SetIfPresent(
                    entry,
                    "isTradeable",
                    info.isTradeable
                )

                SetIfPresent(
                    entry,
                    "quality",
                    SafeNumber(info.quality)
                )

                SetIfPresent(
                    entry,
                    "iconFileID",
                    SafeNumber(info.iconFileID)
                )

                EnrichCurrency(entry)

                AddEntry(
                    categories,
                    categoriesByName,
                    entries,
                    entry
                )
            end
        else
            AddDiagnostic(
                diagnostics,
                string.format(
                    "Currency list row %d unavailable.",
                    index
                )
            )
        end
    end

    return categories, entries
end

local function CollectLegacyCurrencyList(
    diagnostics
)
    if type(GetCurrencyListSize)
        ~= "function"
    then
        return nil
    end

    if type(GetCurrencyListInfo)
        ~= "function"
    then
        return nil
    end

    local success, size =
        SafeCall(GetCurrencyListSize)

    size =
        success
        and SafeNumber(size)
        or nil

    if size == nil then
        AddDiagnostic(
            diagnostics,
            "Legacy currency list size unavailable."
        )

        return {}, {}
    end

    local categories = {}
    local categoriesByName = {}
    local entries = {}

    local currentCategory = "Other"

    for index = 1, size do
        local infoSuccess,
            name,
            isHeader,
            isExpanded,
            isUnused,
            isWatched,
            count,
            icon,
            maximum,
            hasWeeklyLimit,
            currentWeeklyAmount,
            _,
            itemID =
            SafeCall(
                GetCurrencyListInfo,
                index
            )

        if infoSuccess then
            if isHeader == true then
                currentCategory =
                    SafeString(
                        name,
                        "Other"
                    )
            else
                local entry = {
                    category =
                        currentCategory,

                    name =
                        SafeString(
                            name,
                            ""
                        ),

                    currencyID =
                        GetCurrencyIDForListIndex(
                            index
                        ),

                    quantity =
                        SafeNumber(count),

                    maxQuantity =
                        SafeNumber(maximum),

                    canEarnPerWeek =
                        hasWeeklyLimit == true,

                    quantityEarnedThisWeek =
                        SafeNumber(
                            currentWeeklyAmount
                        ),

                    isTypeUnused =
                        isUnused == true,

                    isShowInBackpack =
                        isWatched == true,

                    iconFileID =
                        SafeNumber(icon),

                    itemID =
                        SafeNumber(itemID),

                    isExpanded =
                        isExpanded == true,
                }

                EnrichCurrency(entry)

                AddEntry(
                    categories,
                    categoriesByName,
                    entries,
                    entry
                )
            end
        else
            AddDiagnostic(
                diagnostics,
                string.format(
                    "Legacy currency list row %d unavailable.",
                    index
                )
            )
        end
    end

    return categories, entries
end

local function CollectCurrencyList(
    diagnostics
)
    local categories, entries =
        CollectModernCurrencyList(
            diagnostics
        )

    if categories ~= nil
        and entries ~= nil
    then
        return categories, entries
    end

    categories, entries =
        CollectLegacyCurrencyList(
            diagnostics
        )

    if categories ~= nil
        and entries ~= nil
    then
        return categories, entries
    end

    AddDiagnostic(
        diagnostics,
        "Currency list API unavailable in this Forever build."
    )

    return {}, {}
end

function Currencies:Collect()
    local diagnostics = {}

    local moneyCopper =
        GetMoneyCopper(diagnostics)

    local categories, entries =
        CollectCurrencyList(
            diagnostics
        )

    return {
        key =
            C.SECTIONS.CURRENCIES,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.CURRENCIES
            ],

        money =
            moneyCopper,

        count =
            #entries,

        categories =
            categories,

        entries =
            entries,

        diagnostics =
            diagnostics,
    }
end

ns:RegisterModule(
    "Data.Currencies",
    Currencies
)

ns.Data = ns.Data or {}
ns.Data.Currencies = Currencies