local _, ns = ...

local U = ns.utils

local function TreeName(H, index)
    local ok, first, second = H.SafeCall(GetTalentTabInfo, index)

    if ok then
        if type(first) == "string" and first ~= "" then
            return first
        end

        if type(second) == "string" and second ~= "" then
            return second
        end
    end

    return "Tree " .. index
end

local function SumRanks(ranks)
    local total = 0

    if type(ranks) == "table" then
        for _, rank in pairs(ranks) do
            total = total + (U.ToSafeNumber(rank) or 0)
        end
    end

    return total
end

local function BuildNames(builds, playerClass)
    local names = {}

    if type(builds) ~= "table" then
        return names
    end

    for key, build in pairs(builds) do
        if type(build) == "table" then
            local class = build.cls or build.class

            if not class or not playerClass or class == playerClass then
                table.insert(names, tostring(build.name or build.title or key))
            end
        end
    end

    table.sort(names)

    return names
end

ns.Companions:Register({
    id = "talentsforever",
    title = "Talents Forever",
    addons = { "TalentsForeverBook" },
    adds = "Your planned talent build and any saved builds for your class.",
    Collect = function(_, H)
        local db = TalentsForeverBookDB

        if type(db) ~= "table" then
            error("TalentsForeverBookDB missing")
        end

        local key = H.FindCharacterKey(db.chars)
        local row = key and db.chars[key]
        local plan = type(row) == "table" and row.plan or nil
        local _, _, playerClass = H.SafeCall(UnitClass, "player")
        local lines = {}

        if type(plan) == "table" and type(plan.ranks) == "table" then
            local trees = {}
            local total = 0

            for index, ranks in ipairs(plan.ranks) do
                local points = SumRanks(ranks)
                total = total + points
                table.insert(trees, string.format("%s %d", TreeName(H, index), points))
            end

            if total > 0 then
                table.insert(
                    lines,
                    string.format(
                        "Planned build%s: %s (%d points)",
                        plan.level and (" for level " .. tostring(plan.level)) or "",
                        table.concat(trees, " / "),
                        total
                    )
                )

                if type(plan.order) == "table" and #plan.order > 0 then
                    table.insert(lines, string.format("Pick order saved: %d steps", #plan.order))
                end
            else
                table.insert(lines, "No talent plan saved for this character yet.")
            end
        end

        local talented = U.ToSafeNumber(type(row) == "table" and row.talented or nil)

        if talented and talented > 0 then
            table.insert(lines, "Points spent following the plan: " .. talented)
        end

        local builds = BuildNames(db.builds, type(playerClass) == "string" and playerClass or nil)

        if #builds > 0 then
            table.insert(lines, string.format("Saved builds (%d): %s", #builds, table.concat(builds, ", ")))
        end

        return lines
    end,
})
