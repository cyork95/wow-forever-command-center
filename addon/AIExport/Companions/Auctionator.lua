local _, ns = ...

local U = ns.utils

local CALLER_ID = "AIExport"
local BAG_COUNT = NUM_BAG_SLOTS or 4
local LINE_LIMIT = 40

local function ReadSlot(H, bag, slot)
    if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
        local ok, info = H.SafeCall(C_Container.GetContainerItemInfo, bag, slot)

        if ok and type(info) == "table" then
            return info.hyperlink, info.stackCount, info.isBound
        end

        return nil
    end

    local ok, _, count, _, _, _, _, link = H.SafeCall(GetContainerItemInfo, bag, slot)

    if ok then
        return link, count, nil
    end

    return nil
end

local function SlotCount(H, bag)
    local getter = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local ok, count = H.SafeCall(getter, bag)

    return ok and U.ToSafeNumber(count) or 0
end

ns.Companions:Register({
    id = "auctionator",
    title = "Auctionator",
    addons = { "Auctionator" },
    adds = "The auction price of each stack in your bags, plus a total.",
    Collect = function(_, H)
        local api = H.Get(Auctionator, "API", "v1")

        if not api or type(api.GetAuctionPriceByItemLink) ~= "function" then
            error("Auctionator.API.v1 missing")
        end

        local items = {}
        local order = {}
        local unpriced = 0

        for bag = 0, BAG_COUNT do
            for slot = 1, SlotCount(H, bag) do
                local link, count, isBound = ReadSlot(H, bag, slot)

                if link and not isBound then
                    local ok, price = pcall(api.GetAuctionPriceByItemLink, CALLER_ID, link)
                    price = ok and U.ToSafeNumber(price) or nil
                    local name = H.LinkName(link) or link

                    if price and price > 0 then
                        if not items[name] then
                            items[name] = { name = name, count = 0, price = price }
                            table.insert(order, items[name])
                        end

                        items[name].count = items[name].count + (U.ToSafeNumber(count) or 1)
                    else
                        unpriced = unpriced + 1
                    end
                end
            end
        end

        if #order == 0 then
            return { "No bag items have an auction price yet. Scan the auction house with Auctionator first." }
        end

        local total = 0

        for _, item in ipairs(order) do
            item.value = item.price * item.count
            total = total + item.value
        end

        table.sort(order, function(a, b) return a.value > b.value end)

        local lines = {
            string.format(
                "Bag value at auction: %s (%s priced, %s without a price)",
                H.FormatMoney(total),
                H.Plural(#order, "item"),
                H.Plural(unpriced, "stack")
            ),
        }

        for index, item in ipairs(order) do
            if index > LINE_LIMIT then
                table.insert(lines, string.format("  ...and %d more", #order - LINE_LIMIT))
                break
            end

            table.insert(
                lines,
                string.format(
                    "  %s x%d at %s each = %s",
                    item.name,
                    item.count,
                    H.FormatMoney(item.price),
                    H.FormatMoney(item.value)
                )
            )
        end

        return lines
    end,
})
