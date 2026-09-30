local _, ns = ...

local C = ns.constants
local U = ns.utils

local ProfessionDetails = {}

local PROFESSION_CACHE_VERSION = 5

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end

    return pcall(fn, ...)
end

local function AddDiagnostic(diagnostics, message)
    if type(diagnostics) ~= "table" then
        return
    end

    if not U.IsNonEmptyString(message) then
        return
    end

    U.SafeInsert(
        diagnostics,
        message
    )
end

local function GetTimestamp()
    if type(time) ~= "function" then
        return nil
    end

    local success, value =
        SafeCall(time)

    if not success then
        return nil
    end

    return U.ToSafeNumber(value)
end

local function GetPlayerIdentity()
    local characterName = nil
    local realmName = nil

    if type(UnitName) == "function" then
        local success, value =
            SafeCall(
                UnitName,
                "player"
            )

        if success
            and U.IsNonEmptyString(value)
        then
            characterName = value
        end
    end

    if type(GetRealmName) == "function" then
        local success, value =
            SafeCall(
                GetRealmName
            )

        if success
            and U.IsNonEmptyString(value)
        then
            realmName = value
        end
    end

    return
        realmName or "UnknownRealm",
        characterName or "UnknownCharacter"
end

local function GetSnapshotStore(
    createIfMissing
)
    if not ns.state
        or type(ns.state.db) ~= "table"
    then
        return nil
    end

    local db =
        ns.state.db

    if createIfMissing
        and type(db.professionCache)
            ~= "table"
    then
        db.professionCache =
            {}
    end

    if type(db.professionCache)
        ~= "table"
    then
        return nil
    end

    local realmName,
        characterName =
        GetPlayerIdentity()

    if createIfMissing
        and type(
            db.professionCache[
                realmName
            ]
        ) ~= "table"
    then
        db.professionCache[
            realmName
        ] = {}
    end

    local realmStore =
        db.professionCache[
            realmName
        ]

    if type(realmStore) ~= "table" then
        return nil
    end

    if createIfMissing
        and type(
            realmStore[
                characterName
            ]
        ) ~= "table"
    then
        realmStore[
            characterName
        ] = {}
    end

    local characterStore =
        realmStore[
            characterName
        ]

    if type(characterStore)
        ~= "table"
    then
        return nil
    end

    return characterStore
end

local function NormalizeProfessionID(
    value
)
    local professionID =
        U.ToSafeNumber(value)

    if professionID ~= nil
        and professionID > 0
    then
        return professionID
    end

    return nil
end

local function BuildCacheKey(
    professionName,
    professionID
)
    professionID =
        NormalizeProfessionID(
            professionID
        )

    if professionID ~= nil then
        return
            "id:"
            .. tostring(
                professionID
            )
    end

    if U.IsNonEmptyString(
        professionName
    )
    then
        return
            "name:"
            .. string.lower(
                professionName
            )
    end

    return nil
end

local function IsValidSnapshot(
    snapshot
)
    if type(snapshot) ~= "table" then
        return false
    end

    if snapshot.cacheVersion
        ~= PROFESSION_CACHE_VERSION
    then
        return false
    end

    if not U.IsNonEmptyString(
        snapshot.cacheKey
    )
    then
        return false
    end

    if not U.IsNonEmptyString(
        snapshot.name
    )
    then
        return false
    end

    if type(snapshot.recipes)
        ~= "table"
    then
        return false
    end

    return true
end

local function CleanupStore(store)
    if type(store) ~= "table" then
        return
    end

    for key, snapshot
        in pairs(store)
    do
        if not IsValidSnapshot(
            snapshot
        )
        then
            store[key] =
                nil
        end
    end
end

local function ExtractProfessionContext(
    info
)
    if type(info) ~= "table" then
        return nil
    end

    local name =
        U.IsNonEmptyString(
            info.professionName
        )
        and info.professionName
        or nil

    if not name
        and U.IsNonEmptyString(
            info.parentProfessionName
        )
    then
        name =
            info.parentProfessionName
    end

    if not name then
        return nil
    end

    local expansionName =
        U.IsNonEmptyString(
            info.expansionName
        )
        and info.expansionName
        or nil

    if expansionName == "Unknown" then
        expansionName =
            nil
    end

    return {
        name =
            name,

        professionID =
            NormalizeProfessionID(
                info.professionID
            )
            or NormalizeProfessionID(
                info.parentProfessionID
            ),

        parentProfessionID =
            NormalizeProfessionID(
                info.parentProfessionID
            ),

        parentProfessionName =
            U.IsNonEmptyString(
                info.parentProfessionName
            )
            and info.parentProfessionName
            or nil,

        expansionName =
            expansionName,

        rank =
            U.ToSafeNumber(
                info.skillLevel
            ),

        maxRank =
            U.ToSafeNumber(
                info.maxSkillLevel
            ),

        modifier =
            U.ToSafeNumber(
                info.skillModifier
            ),

        profession =
            U.ToSafeNumber(
                info.profession
            ),

        isPrimaryProfession =
            type(
                info.isPrimaryProfession
            ) == "boolean"
            and info.isPrimaryProfession
            or nil,
    }
end

local function GetProfessionContext(
    diagnostics
)
    if type(C_TradeSkillUI)
        ~= "table"
    then
        AddDiagnostic(
            diagnostics,
            "C_TradeSkillUI API unavailable."
        )

        return nil
    end

    local childContext = nil

    if type(
        C_TradeSkillUI.GetChildProfessionInfo
    ) == "function"
    then
        local success, info =
            SafeCall(
                C_TradeSkillUI.GetChildProfessionInfo
            )

        if success then
            childContext =
                ExtractProfessionContext(
                    info
                )
        end
    end

    local baseContext = nil

    if type(
        C_TradeSkillUI.GetBaseProfessionInfo
    ) == "function"
    then
        local success, info =
            SafeCall(
                C_TradeSkillUI.GetBaseProfessionInfo
            )

        if success then
            baseContext =
                ExtractProfessionContext(
                    info
                )
        end
    end

    local context =
        childContext
        or baseContext

    if not context then
        AddDiagnostic(
            diagnostics,
            "Current profession information is unavailable."
        )

        return nil
    end

    if baseContext then
        context.baseProfessionName =
            baseContext.name

        context.baseProfessionID =
            baseContext.professionID

        if context.professionID == nil then
            context.professionID =
                baseContext.professionID
        end

        if context.rank == nil then
            context.rank =
                baseContext.rank
        end

        if context.maxRank == nil then
            context.maxRank =
                baseContext.maxRank
        end

        if context.modifier == nil then
            context.modifier =
                baseContext.modifier
        end

        if context.isPrimaryProfession
            == nil
        then
            context.isPrimaryProfession =
                baseContext.isPrimaryProfession
        end
    end

    return context
end

local function GetRecipeDifficulty(
    recipeInfo
)
    if type(recipeInfo) ~= "table" then
        return nil
    end

    local value =
        recipeInfo.relativeDifficulty

    if value == nil then
        value =
            recipeInfo.difficulty
    end

    if value == nil then
        return nil
    end

    if type(value) == "number"
        or type(value) == "string"
    then
        return tostring(value)
    end

    return nil
end

local function GetRecipeLink(
    recipeID
)
    if not C_TradeSkillUI
        or type(
            C_TradeSkillUI.GetRecipeLink
        ) ~= "function"
    then
        return nil
    end

    local success, link =
        SafeCall(
            C_TradeSkillUI.GetRecipeLink,
            recipeID
        )

    if success
        and U.IsNonEmptyString(link)
    then
        return link
    end

    return nil
end

local function GetRecipeSkillLine(
    recipeID
)
    if not C_TradeSkillUI
        or type(
            C_TradeSkillUI.GetTradeSkillLineForRecipe
        ) ~= "function"
    then
        return nil, nil, nil
    end

    local success,
        tradeSkillID,
        skillLineName,
        parentTradeSkillID =
        SafeCall(
            C_TradeSkillUI.GetTradeSkillLineForRecipe,
            recipeID
        )

    if not success then
        return nil, nil, nil
    end

    return
        NormalizeProfessionID(
            tradeSkillID
        ),
        U.IsNonEmptyString(
            skillLineName
        )
        and skillLineName
        or nil,
        NormalizeProfessionID(
            parentTradeSkillID
        )
end

local function BuildRecipeEntry(
    recipeID
)
    recipeID =
        U.ToSafeNumber(
            recipeID
        )

    if recipeID == nil then
        return nil
    end

    local recipeInfo = nil

    if C_TradeSkillUI
        and type(
            C_TradeSkillUI.GetRecipeInfo
        ) == "function"
    then
        local success, value =
            SafeCall(
                C_TradeSkillUI.GetRecipeInfo,
                recipeID
            )

        if success
            and type(value) == "table"
        then
            recipeInfo =
                value
        end
    end

    local link =
        GetRecipeLink(
            recipeID
        )

    local name = nil

    if recipeInfo
        and U.IsNonEmptyString(
            recipeInfo.name
        )
    then
        name =
            recipeInfo.name
    end

    if not name
        and U.IsNonEmptyString(link)
    then
        name =
            U.GetItemNameFromLink(
                link
            )
    end

    local tradeSkillID,
        skillLineName,
        parentTradeSkillID =
        GetRecipeSkillLine(
            recipeID
        )

    if not name then
        return nil
    end

    local entry = {
        recipeID =
            recipeID,

        name =
            name,

        link =
            link,

        tradeSkillID =
            tradeSkillID,

        skillLineName =
            skillLineName,

        parentTradeSkillID =
            parentTradeSkillID,
    }

    if recipeInfo then
        entry.categoryID =
            U.ToSafeNumber(
                recipeInfo.categoryID
            )

        entry.difficulty =
            GetRecipeDifficulty(
                recipeInfo
            )

        if type(recipeInfo.learned)
            == "boolean"
        then
            entry.learned =
                recipeInfo.learned
        end

        if type(recipeInfo.favorite)
            == "boolean"
        then
            entry.favorite =
                recipeInfo.favorite
        end

        if type(recipeInfo.disabled)
            == "boolean"
        then
            entry.disabled =
                recipeInfo.disabled
        end

        if type(recipeInfo.isGatheringRecipe)
            == "boolean"
        then
            entry.isGatheringRecipe =
                recipeInfo.isGatheringRecipe
        end

        if type(recipeInfo.isEnchantingRecipe)
            == "boolean"
        then
            entry.isEnchantingRecipe =
                recipeInfo.isEnchantingRecipe
        end
    end

    return entry
end

local function CollectRecipes(
    diagnostics
)
    local recipes = {}

    if not C_TradeSkillUI
        or type(
            C_TradeSkillUI.GetAllRecipeIDs
        ) ~= "function"
    then
        AddDiagnostic(
            diagnostics,
            "C_TradeSkillUI.GetAllRecipeIDs API unavailable."
        )

        return recipes
    end

    local success,
        recipeIDs =
        SafeCall(
            C_TradeSkillUI.GetAllRecipeIDs
        )

    if not success then
        AddDiagnostic(
            diagnostics,
            "C_TradeSkillUI.GetAllRecipeIDs call failed."
        )

        return recipes
    end

    if type(recipeIDs) ~= "table" then
        return recipes
    end

    local seen = {}

    for _, rawRecipeID
        in pairs(recipeIDs)
    do
        local recipeID =
            U.ToSafeNumber(
                rawRecipeID
            )

        if recipeID ~= nil
            and not seen[recipeID]
        then
            seen[recipeID] =
                true

            local entry =
                BuildRecipeEntry(
                    recipeID
                )

            if entry then
                U.SafeInsert(
                    recipes,
                    entry
                )
            end
        end
    end

    table.sort(
        recipes,
        function(left, right)
            local leftName =
                string.lower(
                    left.name
                    or ""
                )

            local rightName =
                string.lower(
                    right.name
                    or ""
                )

            if leftName ~= rightName then
                return
                    leftName
                    < rightName
            end

            return
                (
                    U.ToSafeNumber(
                        left.recipeID
                    )
                    or 0
                )
                <
                (
                    U.ToSafeNumber(
                        right.recipeID
                    )
                    or 0
                )
        end
    )

    return recipes
end

local function GetTradeSkillLink()
    if not C_TradeSkillUI
        or type(
            C_TradeSkillUI.GetTradeSkillListLink
        ) ~= "function"
    then
        return nil
    end

    local success, link =
        SafeCall(
            C_TradeSkillUI.GetTradeSkillListLink
        )

    if success
        and U.IsNonEmptyString(link)
    then
        return link
    end

    return nil
end

function ProfessionDetails:UpdateCacheFromTradeSkillWindow()
    if not ns:IsTradeSkillWindowOpen() then
        return nil
    end

    local diagnostics = {}

    local context =
        GetProfessionContext(
            diagnostics
        )

    if not context
        or not U.IsNonEmptyString(
            context.name
        )
    then
        return nil
    end

    local recipes =
        CollectRecipes(
            diagnostics
        )

    local cacheKey =
        BuildCacheKey(
            context.name,
            context.professionID
        )

    if not cacheKey then
        return nil
    end

    local store =
        GetSnapshotStore(
            true
        )

    if not store then
        return nil
    end

    CleanupStore(
        store
    )

    local snapshot = {
        name =
            context.name,

        professionID =
            context.professionID,

        parentProfessionID =
            context.parentProfessionID,

        parentProfessionName =
            context.parentProfessionName,

        baseProfessionID =
            context.baseProfessionID,

        baseProfessionName =
            context.baseProfessionName,

        expansionName =
            context.expansionName,

        profession =
            context.profession,

        isPrimaryProfession =
            context.isPrimaryProfession,

        rank =
            context.rank,

        maxRank =
            context.maxRank,

        modifier =
            context.modifier,

        tradeSkillLink =
            GetTradeSkillLink(),

        recipes =
            recipes,

        recipeCount =
            #recipes,

        lastUpdated =
            GetTimestamp(),

        cacheKey =
            cacheKey,

        cacheVersion =
            PROFESSION_CACHE_VERSION,

        diagnostics =
            diagnostics,
    }

    store[cacheKey] =
        snapshot

    return snapshot
end

function ProfessionDetails:GetCachedSnapshots()
    local store =
        GetSnapshotStore(
            false
        )

    if not store then
        return {}
    end

    CleanupStore(
        store
    )

    local snapshots = {}

    for _, snapshot
        in pairs(store)
    do
        if IsValidSnapshot(
            snapshot
        )
        then
            U.SafeInsert(
                snapshots,
                snapshot
            )
        end
    end

    table.sort(
        snapshots,
        function(left, right)
            local leftName =
                string.lower(
                    left.name
                    or ""
                )

            local rightName =
                string.lower(
                    right.name
                    or ""
                )

            if leftName ~= rightName then
                return
                    leftName
                    < rightName
            end

            return
                (
                    U.ToSafeNumber(
                        left.professionID
                    )
                    or 0
                )
                <
                (
                    U.ToSafeNumber(
                        right.professionID
                    )
                    or 0
                )
        end
    )

    return snapshots
end

local PROFESSION_IDENTITY_FIELDS = {
    "cacheKey",
    "name",
    "parentProfessionName",
    "baseProfessionName",
}

local function RememberProfession(known, snapshot)
    for _, field in ipairs(PROFESSION_IDENTITY_FIELDS) do
        if U.IsNonEmptyString(snapshot[field]) then
            known[string.lower(snapshot[field])] = true
        end
    end
end

local function ProfessionAlreadyListed(known, snapshot)
    for _, field in ipairs(PROFESSION_IDENTITY_FIELDS) do
        if U.IsNonEmptyString(snapshot[field])
            and known[string.lower(snapshot[field])]
        then
            return true
        end
    end

    return false
end

function ProfessionDetails:Collect()
    local professions = {}

    local available =
        false

    local cached =
        false

    local unavailableMessage =
        nil

    local newestTimestamp =
        nil

    local diagnostics = {}

    if ns:IsTradeSkillWindowOpen() then
        local liveSnapshot =
            self:UpdateCacheFromTradeSkillWindow()

        if liveSnapshot then
            available =
                true

            cached =
                false

            U.SafeInsert(
                professions,
                liveSnapshot
            )

            newestTimestamp =
                U.ToSafeNumber(
                    liveSnapshot.lastUpdated
                )

            -- The open window is only one craft. Keep saved snapshots for the others
            -- instead of filling those gaps from Profession Master.
            local listed = {}
            RememberProfession(listed, liveSnapshot)

            for _, snapshot in ipairs(self:GetCachedSnapshots()) do
                if not ProfessionAlreadyListed(listed, snapshot) then
                    U.SafeInsert(professions, snapshot)
                    RememberProfession(listed, snapshot)

                    local updated = U.ToSafeNumber(snapshot.lastUpdated)

                    if updated ~= nil and (newestTimestamp == nil or updated > newestTimestamp) then
                        newestTimestamp = updated
                    end
                end
            end
        end
    end

    if not available then
        local cachedSnapshots =
            self:GetCachedSnapshots()

        if #cachedSnapshots > 0 then
            available =
                true

            cached =
                true

            professions =
                cachedSnapshots

            for _, snapshot
                in ipairs(
                    cachedSnapshots
                )
            do
                local updated =
                    U.ToSafeNumber(
                        snapshot.lastUpdated
                    )

                if updated ~= nil
                    and (
                        newestTimestamp == nil
                        or updated
                            > newestTimestamp
                    )
                then
                    newestTimestamp =
                        updated
                end
            end
        else
            unavailableMessage =
                C.TEXT.PROFESSION_DETAILS_UNAVAILABLE_NO_CACHE
        end
    end

    local fallback = nil

    if ns.Companions then
        local known = {}

        for _, snapshot in ipairs(professions) do
            for _, field in ipairs({ "name", "parentProfessionName", "baseProfessionName" }) do
                if U.IsNonEmptyString(snapshot[field]) then
                    known[string.lower(snapshot[field])] = true
                end
            end
        end

        local missing = {}

        for _, profession in ipairs(ns.Companions:Read("professionmaster", "ReadProfessions") or {}) do
            if #(profession.recipes or {}) > 0
                and not known[string.lower(profession.name)]
            then
                table.insert(missing, profession)
            end
        end

        if #missing > 0 then
            fallback = {
                source = "Profession Master",
                note = C.TEXT.PROFESSION_MASTER_FALLBACK_NOTE,
                professions = missing,
            }
        end
    end

    U.SafeInsert(
        diagnostics,
        string.format(
            "Profession snapshots: %d",
            #professions
        )
    )

    U.SafeInsert(
        diagnostics,
        string.format(
            "Using cached profession data: %s",
            tostring(cached)
        )
    )

    return {
        key =
            C.SECTIONS.PROFESSION_DETAILS,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.PROFESSION_DETAILS
            ],

        available =
            available,

        cached =
            cached,

        lastUpdated =
            newestTimestamp,

        unavailableMessage =
            unavailableMessage,

        professions =
            professions,

        fallback =
            fallback,

        diagnostics =
            diagnostics,
    }
end

ns:RegisterModule(
    "Data.ProfessionDetails",
    ProfessionDetails
)

ns.Data = ns.Data or {}
ns.Data.ProfessionDetails =
    ProfessionDetails