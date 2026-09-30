local _, ns = ...

local C = ns.constants
local U = ns.utils

local CharacterStats = {}

local restrictedValuesDetected = false

local PRIMARY_STATS = {
    {
        index = 1,
        key = "strength",
        label = _G.STAT_STRENGTH or "Strength",
    },
    {
        index = 2,
        key = "agility",
        label = _G.STAT_AGILITY or "Agility",
    },
    {
        index = 3,
        key = "stamina",
        label = _G.STAT_STAMINA or "Stamina",
    },
    {
        index = 4,
        key = "intellect",
        label = _G.STAT_INTELLECT or "Intellect",
    },
}

local PRIMARY_STAT_LABELS = {
    [1] = _G.STAT_STRENGTH or "Strength",
    [2] = _G.STAT_AGILITY or "Agility",
    [4] = _G.STAT_INTELLECT or "Intellect",
}

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end

    return pcall(fn, ...)
end

local function IsRestrictedValue(value)
    if value == nil then
        return false
    end

    if type(issecretvalue) == "function" then
        local success, isSecret =
            pcall(issecretvalue, value)

        if success and isSecret == true then
            restrictedValuesDetected = true
            return true
        end
    end

    if type(canaccessvalue) == "function" then
        local success, canAccess =
            pcall(canaccessvalue, value)

        if success and canAccess == false then
            restrictedValuesDetected = true
            return true
        end
    end

    return false
end

local function ToSafeNumber(value)
    if IsRestrictedValue(value) then
        return nil
    end

    return U.ToSafeNumber(value)
end

local lastHealthCurrent = nil

local function ParseLooseNumber(value)
    local numberValue = ToSafeNumber(value)

    if numberValue ~= nil then
        return numberValue
    end

    if IsRestrictedValue(value) then
        return nil
    end

    local ok, valueType = pcall(type, value)

    if not ok or valueType ~= "string" then
        return nil
    end

    local cleaned = string.gsub(value, ",", "")

    return tonumber(cleaned)
end

local function ClampResource(current, max)
    if current == nil or current < 0 then
        return nil
    end

    if max ~= nil and current > max then
        return nil
    end

    return current
end

local function FirstNumberInHealthText(text)
    if IsRestrictedValue(text) or type(text) ~= "string" then
        return nil
    end

    if string.find(text, "%", 1, true) then
        return nil
    end

    local cleaned = string.gsub(text, ",", "")
    local current = string.match(cleaned, "(%d+)%s*/%s*%d+")

    if current == nil then
        current = string.match(cleaned, "^%s*(%d+)%s*$")
    end

    return tonumber(current)
end

local function FontStringText(fontString)
    if type(fontString) ~= "table" or type(fontString.GetText) ~= "function" then
        return nil
    end

    local success, value = SafeCall(fontString.GetText, fontString)

    if not success then
        return nil
    end

    return value
end

local function ReadStatusBarNumber(bar)
    if type(bar) ~= "table" or IsRestrictedValue(bar) then
        return nil
    end

    if type(bar.GetValue) == "function" then
        local success, value = SafeCall(bar.GetValue, bar)

        if success then
            local numberValue = ParseLooseNumber(value)

            if numberValue ~= nil then
                return numberValue
            end
        end
    end

    local text = FontStringText(bar.TextString)
        or FontStringText(bar.HealthBarText)
        or FontStringText(_G.PlayerFrameHealthBarText)

    return FirstNumberInHealthText(text)
end

local function ReadPlayerHealthBar()
    local bar = _G.PlayerFrameHealthBar

    if type(bar) ~= "table" and type(PlayerFrame) == "table" then
        bar = PlayerFrame.healthbar
            or PlayerFrame.HealthBar
            or PlayerFrame.PlayerFrameHealthBar
    end

    return ReadStatusBarNumber(bar)
end

local function RememberHealth(current)
    local numberValue = ParseLooseNumber(current)

    if numberValue ~= nil and numberValue >= 0 then
        lastHealthCurrent = numberValue
    end
end

local healthWatch = CreateFrame("Frame")

healthWatch:RegisterEvent("UNIT_HEALTH")
healthWatch:RegisterEvent("UNIT_MAXHEALTH")
healthWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
healthWatch:SetScript("OnEvent", function(_, event, unit)
    if event ~= "PLAYER_ENTERING_WORLD" and unit ~= "player" then
        return
    end

    if type(UnitHealth) ~= "function" then
        return
    end

    local success, value = SafeCall(UnitHealth, "player")

    if success then
        RememberHealth(value)
    end
end)

local function SafeText(value, fallback)
    if IsRestrictedValue(value) then
        return fallback or "Unknown"
    end

    local text =
        U.SafeString(value, "")

    text = U.Trim(text)

    if text ~= "" then
        return text
    end

    return fallback or "Unknown"
end

local function SafeArithmetic(callback)
    if type(callback) ~= "function" then
        return nil
    end

    local success, result =
        pcall(callback)

    if not success then
        return nil
    end

    return ToSafeNumber(result)
end

local function GetPowerLabel(powerToken, fallback)
    local safeToken =
        SafeText(powerToken, "")

    if safeToken == "" then
        return fallback or "Resource"
    end

    local globalLabel =
        _G[safeToken]

    local safeGlobalLabel =
        SafeText(globalLabel, "")

    if safeGlobalLabel ~= "" then
        return safeGlobalLabel
    end

    local normalized =
        safeToken:gsub("_", " ")

    normalized =
        normalized:lower()

    normalized =
        normalized:gsub(
            "^%l",
            string.upper
        )

    return normalized
end

local function CollectIdentity()
    local name = nil
    local realm = nil
    local faction = nil
    local localizedFaction = nil

    if type(UnitName) == "function" then
        local success, value =
            SafeCall(UnitName, "player")

        if success then
            name = value
        end
    end

    if type(GetRealmName) == "function" then
        local success, value =
            SafeCall(GetRealmName)

        if success then
            realm = value
        end
    end

    if type(UnitFactionGroup) == "function" then
        local success

        success,
            faction,
            localizedFaction =
            SafeCall(
                UnitFactionGroup,
                "player"
            )

        if not success then
            faction = nil
            localizedFaction = nil
        end
    end

    name =
        SafeText(
            name,
            "Unknown"
        )

    realm =
        SafeText(
            realm,
            ""
        )

    faction =
        SafeText(
            faction or localizedFaction,
            "Neutral"
        )

    local fullName = name

    if realm ~= "" then
        fullName =
            string.format(
                "%s-%s",
                name,
                realm
            )
    end

    return {
        name = name,
        realm = realm,
        fullName = fullName,
        faction = faction,
    }
end

local function CollectItemLevel()
    if type(GetAverageItemLevel) ~= "function" then
        return nil
    end

    local success,
        average,
        equipped,
        pvp =
        SafeCall(GetAverageItemLevel)

    if not success then
        return nil
    end

    average =
        ToSafeNumber(average)

    equipped =
        ToSafeNumber(equipped)

    pvp =
        ToSafeNumber(pvp)

    if average == nil
        and equipped == nil
        and pvp == nil
    then
        return nil
    end

    return {
        average = average,
        equipped = equipped,
        pvp = pvp,
    }
end

local function CollectPrimaryStats()
    if type(UnitStat) ~= "function" then
        return {}
    end

    local stats = {}

    for _, statInfo in ipairs(PRIMARY_STATS) do
        local success,
            base,
            effective,
            positive,
            negative =
            SafeCall(
                UnitStat,
                "player",
                statInfo.index
            )

        if success then
            local safeBase =
                ToSafeNumber(base)

            local safeEffective =
                ToSafeNumber(effective)

            local safePositive =
                ToSafeNumber(positive)

            local safeNegative =
                ToSafeNumber(negative)

            if safeBase ~= nil
                or safeEffective ~= nil
                or safePositive ~= nil
                or safeNegative ~= nil
            then
                stats[statInfo.key] = {
                    key =
                        statInfo.key,

                    label =
                        SafeText(
                            statInfo.label,
                            statInfo.key
                        ),

                    base =
                        safeBase,

                    effective =
                        safeEffective
                        or safeBase,

                    positive =
                        safePositive,

                    negative =
                        safeNegative,
                }
            end
        end
    end

    return stats
end

local function CollectResourceStats()
    local powerType = 0
    local powerToken = "MANA"

    if type(UnitPowerType) == "function" then
        local success,
            rawPowerType,
            rawPowerToken =
            SafeCall(
                UnitPowerType,
                "player"
            )

        if success then
            powerType =
                ToSafeNumber(rawPowerType)
                or 0

            powerToken =
                SafeText(
                    rawPowerToken,
                    "MANA"
                )
        end
    end

    local primaryCurrent = nil
    local primaryMax = nil

    if type(UnitPower) == "function" then
        local success, value =
            SafeCall(
                UnitPower,
                "player",
                powerType
            )

        if success then
            primaryCurrent =
                ParseLooseNumber(value)
        end
    end

    if type(UnitPowerMax) == "function" then
        local success, value =
            SafeCall(
                UnitPowerMax,
                "player",
                powerType
            )

        if success then
            primaryMax =
                ParseLooseNumber(value)
        end
    end

    local healthCurrent = nil
    local healthMax = nil

    if type(UnitHealth) == "function" then
        local success, value =
            SafeCall(
                UnitHealth,
                "player"
            )

        if success then
            healthCurrent =
                ParseLooseNumber(value)
        end
    end

    if healthCurrent == nil then
        local fromBar = ReadPlayerHealthBar()
        local dead = false

        if type(UnitIsDeadOrGhost) == "function" then
            local success, value = SafeCall(UnitIsDeadOrGhost, "player")
            dead = success and value == true
        end

        if fromBar ~= nil and (fromBar > 0 or dead) then
            healthCurrent = fromBar
        end
    end

    if healthCurrent == nil then
        healthCurrent = lastHealthCurrent
    end

    if type(UnitHealthMax) == "function" then
        local success, value =
            SafeCall(
                UnitHealthMax,
                "player"
            )

        if success then
            healthMax =
                ParseLooseNumber(value)
        end
    end

    healthCurrent = ClampResource(healthCurrent, healthMax)

    if healthCurrent == nil and healthMax ~= nil then
        local dead = false

        if type(UnitIsDeadOrGhost) == "function" then
            local success, value = SafeCall(UnitIsDeadOrGhost, "player")
            dead = success and value == true
        end

        healthCurrent = dead and 0 or healthMax
    end

    if healthCurrent ~= nil then
        lastHealthCurrent = healthCurrent
    end

    local manaPowerType = 0

    if Enum
        and Enum.PowerType
        and Enum.PowerType.Mana ~= nil
    then
        manaPowerType =
            Enum.PowerType.Mana
    end

    local manaCurrent = nil
    local manaMax = nil

    if type(UnitPower) == "function" then
        local success, value =
            SafeCall(
                UnitPower,
                "player",
                manaPowerType
            )

        if success then
            manaCurrent =
                ParseLooseNumber(value)
        end
    end

    if type(UnitPowerMax) == "function" then
        local success, value =
            SafeCall(
                UnitPowerMax,
                "player",
                manaPowerType
            )

        if success then
            manaMax =
                ParseLooseNumber(value)
        end
    end

    manaCurrent = ClampResource(manaCurrent, manaMax)
    primaryCurrent = ClampResource(primaryCurrent, primaryMax)

    local manaAvailable =
        manaMax ~= nil
        and manaMax > 0

    return {
        health = {
            current = healthCurrent,
            max = healthMax,
        },

        primary = {
            type = powerType,
            token = powerToken,

            label =
                GetPowerLabel(
                    powerToken,
                    "Resource"
                ),

            current = primaryCurrent,
            max = primaryMax,
        },

        mana = {
            available = manaAvailable,
            current = manaCurrent,
            max = manaMax,
            resourceType = "MANA",

            label =
                GetPowerLabel(
                    "MANA",
                    "Mana"
                ),
        },
    }
end

local function CollectArmorStats()
    if type(UnitArmor) ~= "function" then
        return nil
    end

    local success,
        baseArmor,
        effectiveArmor =
        SafeCall(
            UnitArmor,
            "player"
        )

    if not success then
        return nil
    end

    baseArmor =
        ToSafeNumber(baseArmor)

    effectiveArmor =
        ToSafeNumber(effectiveArmor)

    if baseArmor == nil
        and effectiveArmor == nil
    then
        return nil
    end

    return {
        base = baseArmor,

        effective =
            effectiveArmor
            or baseArmor,
    }
end

local function CollectXPStats()
    local currentXP = nil
    local maxXP = nil

    if type(UnitXP) == "function" then
        local success, value =
            SafeCall(
                UnitXP,
                "player"
            )

        if success then
            currentXP =
                ToSafeNumber(value)
        end
    end

    if type(UnitXPMax) == "function" then
        local success, value =
            SafeCall(
                UnitXPMax,
                "player"
            )

        if success then
            maxXP =
                ToSafeNumber(value)
        end
    end

    local isMaxLevel =
        maxXP ~= nil
        and maxXP <= 0

    if maxXP == nil
        or maxXP <= 0
    then
        return {
            available = false,
            isMaxLevel = isMaxLevel,
            current = currentXP,
            max = maxXP,
            toLevel = nil,
            progressPercent = nil,
            rested = nil,
        }
    end

    local toLevel = nil
    local progressPercent = nil

    if currentXP ~= nil then
        toLevel =
            SafeArithmetic(function()
                return maxXP - currentXP
            end)

        progressPercent =
            SafeArithmetic(function()
                return (
                    currentXP
                    / maxXP
                ) * 100
            end)
    end

    local rested = nil

    if type(GetXPExhaustion) == "function" then
        local success, value =
            SafeCall(GetXPExhaustion)

        if success then
            rested =
                ToSafeNumber(value)
        end
    end

    return {
        available = true,
        isMaxLevel = false,
        current = currentXP,
        max = maxXP,
        toLevel = toLevel,
        progressPercent = progressPercent,
        rested = rested,
    }
end

local function CollectAttackPowerStats()
    if type(UnitAttackPower) ~= "function" then
        return nil
    end

    local success,
        base,
        positive,
        negative =
        SafeCall(
            UnitAttackPower,
            "player"
        )

    if not success then
        return nil
    end

    base =
        ToSafeNumber(base)

    positive =
        ToSafeNumber(positive)

    negative =
        ToSafeNumber(negative)

    if base == nil
        and positive == nil
        and negative == nil
    then
        return nil
    end

    local effective = nil

    if base ~= nil then
        effective =
            SafeArithmetic(function()
                return base
                    + (positive or 0)
                    + (negative or 0)
            end)
    end

    return {
        base = base,
        positive = positive,
        negative = negative,
        effective = effective,
    }
end

local function GetRatingValue(ratingID)
    if ratingID == nil then
        return nil
    end

    if type(GetCombatRating) ~= "function" then
        return nil
    end

    local success, value =
        SafeCall(
            GetCombatRating,
            ratingID
        )

    if not success then
        return nil
    end

    return ToSafeNumber(value)
end

local function GetRatingBonus(ratingID)
    if ratingID == nil then
        return nil
    end

    if type(GetCombatRatingBonus) ~= "function" then
        return nil
    end

    local success, value =
        SafeCall(
            GetCombatRatingBonus,
            ratingID
        )

    if not success then
        return nil
    end

    return ToSafeNumber(value)
end

local function GetHighestSpellCritChance()
    if type(GetSpellCritChance) ~= "function" then
        return nil
    end

    local highestCrit = nil

    for school = 2, 7 do
        local success, value =
            SafeCall(
                GetSpellCritChance,
                school
            )

        if success then
            local crit =
                ToSafeNumber(value)

            if crit ~= nil
                and (
                    highestCrit == nil
                    or crit > highestCrit
                )
            then
                highestCrit = crit
            end
        end
    end

    return highestCrit
end

local function BuildRating(
    key,
    label,
    ratingID,
    explicitBonus
)
    local rating =
        GetRatingValue(ratingID)

    local bonus =
        ToSafeNumber(explicitBonus)

    if bonus == nil then
        bonus =
            GetRatingBonus(ratingID)
    end

    if rating == nil
        and bonus == nil
    then
        return nil
    end

    return {
        key = key,
        label = SafeText(label, key),
        rating = rating,
        bonus = bonus,
    }
end

local function CollectCombatRatings()
    local critRating =
        _G.CR_CRIT_MELEE
        or _G.CR_CRIT_RANGED
        or _G.CR_CRIT_SPELL

    local hasteRating =
        _G.CR_HASTE_MELEE
        or _G.CR_HASTE_RANGED
        or _G.CR_HASTE_SPELL
        or _G.CR_HASTE

    local masteryRating =
        _G.CR_MASTERY

    local versatilityRating =
        _G.CR_VERSATILITY_DAMAGE_DONE

    local leechRating =
        _G.CR_LIFESTEAL

    local speedRating =
        _G.CR_SPEED

    local avoidanceRating =
        _G.CR_AVOIDANCE

    local critBonus = nil

    if type(GetCritChance) == "function" then
        local success, value =
            SafeCall(GetCritChance)

        if success then
            critBonus =
                ToSafeNumber(value)
        end
    end

    if critBonus == nil then
        critBonus =
            GetHighestSpellCritChance()
    end

    local hasteBonus = nil

    if type(GetHaste) == "function" then
        local success, value =
            SafeCall(GetHaste)

        if success then
            hasteBonus =
                ToSafeNumber(value)
        end
    end

    local masteryBonus = nil

    if type(GetMasteryEffect) == "function" then
        local success, value =
            SafeCall(GetMasteryEffect)

        if success then
            masteryBonus =
                ToSafeNumber(value)
        end
    end

    return {
        crit =
            BuildRating(
                "crit",
                _G.STAT_CRITICAL_STRIKE
                    or "Critical Strike",
                critRating,
                critBonus
            ),

        haste =
            BuildRating(
                "haste",
                _G.STAT_HASTE
                    or "Haste",
                hasteRating,
                hasteBonus
            ),

        mastery =
            BuildRating(
                "mastery",
                _G.STAT_MASTERY
                    or "Mastery",
                masteryRating,
                masteryBonus
            ),

        versatility =
            BuildRating(
                "versatility",
                _G.STAT_VERSATILITY
                    or "Versatility",
                versatilityRating
            ),

        leech =
            BuildRating(
                "leech",
                _G.STAT_LIFESTEAL
                    or "Leech",
                leechRating
            ),

        speed =
            BuildRating(
                "speed",
                _G.STAT_SPEED
                    or "Speed",
                speedRating
            ),

        avoidance =
            BuildRating(
                "avoidance",
                _G.STAT_AVOIDANCE
                    or "Avoidance",
                avoidanceRating
            ),
    }
end

local function GetSpecSelectionEnabled(classID)
    classID =
        ToSafeNumber(classID)

    if classID == nil
        or not C_SpecializationInfo
        or type(
            C_SpecializationInfo.IsSpecSelectionEnabled
        ) ~= "function"
    then
        return nil
    end

    local success, enabled =
        SafeCall(
            C_SpecializationInfo.IsSpecSelectionEnabled,
            classID
        )

    if success
        and type(enabled) == "boolean"
    then
        return enabled
    end

    return nil
end

local function CollectSpecialization(
    classID,
    sex
)
    if not C_SpecializationInfo then
        return nil
    end

    if type(
        C_SpecializationInfo.GetSpecialization
    ) ~= "function"
    then
        return nil
    end

    if type(
        C_SpecializationInfo.GetSpecializationInfo
    ) ~= "function"
    then
        return nil
    end

    local success, specIndex =
        SafeCall(
            C_SpecializationInfo.GetSpecialization
        )

    specIndex =
        success
        and ToSafeNumber(specIndex)
        or nil

    if specIndex == nil then
        return nil
    end

    local infoSuccess,
        specID,
        specName,
        _,
        _,
        role,
        primaryStat =
        SafeCall(
            C_SpecializationInfo.GetSpecializationInfo,
            specIndex,
            false,
            false,
            nil,
            sex
        )

    if not infoSuccess then
        return nil
    end

    primaryStat =
        ToSafeNumber(primaryStat)

    local selectionEnabled =
        GetSpecSelectionEnabled(
            classID
        )

    local displayName = ""

    if selectionEnabled ~= false then
        displayName =
            SafeText(
                specName,
                ""
            )
    end

    local displayRole = ""

    if selectionEnabled ~= false then
        displayRole =
            SafeText(
                role,
                ""
            )
    end

    return {
        index = specIndex,

        id =
            ToSafeNumber(specID),

        name =
            displayName,

        role =
            displayRole,

        primaryStat =
            primaryStat,

        primaryStatLabel =
            PRIMARY_STAT_LABELS[
                primaryStat
            ],

        selectionEnabled =
            selectionEnabled,

        rawName =
            SafeText(
                specName,
                ""
            ),

        rawRole =
            SafeText(
                role,
                ""
            ),
    }
end

function CharacterStats:Collect()
    restrictedValuesDetected = false

    local classLocalized = nil
    local classID = nil
    local raceLocalized = nil
    local level = nil
    local sex = nil

    if type(UnitClass) == "function" then
        local success,
            localizedClass,
            _,
            rawClassID =
            SafeCall(
                UnitClass,
                "player"
            )

        if success then
            classLocalized =
                localizedClass

            classID =
                ToSafeNumber(
                    rawClassID
                )
        end
    end

    if type(UnitSex) == "function" then
        local success, rawSex =
            SafeCall(
                UnitSex,
                "player"
            )

        if success then
            sex =
                ToSafeNumber(
                    rawSex
                )
        end
    end

    if type(UnitRace) == "function" then
        local success, localizedRace =
            SafeCall(
                UnitRace,
                "player"
            )

        if success then
            raceLocalized =
                localizedRace
        end
    end

    if type(UnitLevel) == "function" then
        local success, rawLevel =
            SafeCall(
                UnitLevel,
                "player"
            )

        if success then
            level =
                ToSafeNumber(rawLevel)
        end
    end

    local identity =
        CollectIdentity()

    local result = {
        key =
            C.SECTIONS.CHARACTER_STATS,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.CHARACTER_STATS
            ],

        name =
            identity.name,

        realm =
            identity.realm,

        fullName =
            identity.fullName,

        faction =
            identity.faction,

        level =
            level,

        race =
            SafeText(
                raceLocalized,
                "Unknown"
            ),

        class =
            SafeText(
                classLocalized,
                "Unknown"
            ),

        itemLevel =
            CollectItemLevel(),

        resources =
            CollectResourceStats(),

        xp =
            CollectXPStats(),

        attackPower =
            CollectAttackPowerStats(),

        specialization =
            CollectSpecialization(
                classID,
                sex
            ),

        combatRatings =
            CollectCombatRatings(),

        armor =
            CollectArmorStats(),

        primaryStats =
            CollectPrimaryStats(),
    }

    result.restrictedValuesDetected =
        restrictedValuesDetected == true

    return result
end

ns:RegisterModule(
    "Data.CharacterStats",
    CharacterStats
)

ns.Data = ns.Data or {}
ns.Data.CharacterStats = CharacterStats