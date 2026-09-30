local _, ns = ...

local C = ns.constants
local U = ns.utils

local Screenshotter = {}

Screenshotter.refusedEvents = {}

-- Triggers this close together share one screenshot, e.g. a level-up that
-- also earns an achievement.
local MERGE_SECONDS = 3
-- The game reports SCREENSHOT_SUCCEEDED a moment after Screenshot(); the
-- Biography claims the reason within this window.
local REASON_SECONDS = 10
local HIDE_UI_SHOT_DELAY = 0.1
local HIDE_UI_RESTORE_DELAY = 0.3

Screenshotter.TRIGGERS = {
    { key = "levelUp", delay = 5, default = true },
    { key = "death", delay = 1, default = true },
    { key = "achievement", delay = 3, default = true },
    { key = "boss", delay = 2, default = true },
    { key = "pvp", delay = 3, default = true },
    { key = "duel", delay = 1, default = true },
    { key = "collection", delay = 1, default = true },
    { key = "login", delay = 5, default = false },
    { key = "interval", delay = 0, default = false },
}

Screenshotter.OPTIONS = {
    { key = "hideUI", default = true },
    { key = "stamp", default = true },
    { key = "sound", default = true },
    { key = "chat", default = true },
}

Screenshotter.INTERVAL_MIN = C.SHOTS_INTERVAL_MIN
Screenshotter.INTERVAL_MAX = C.SHOTS_INTERVAL_MAX
Screenshotter.INTERVAL_DEFAULT = C.SHOTS_INTERVAL_DEFAULT

local SOUND_KITS = { "IG_MAINMENU_OPTION_CHECKBOX_ON", "U_CHAT_SCROLL_BUTTON" }

local TRIGGER_BY_KEY = {}

for _, trigger in ipairs(Screenshotter.TRIGGERS) do
    TRIGGER_BY_KEY[trigger.key] = trigger
end

local pending = nil
local lastShotAt = nil
local pendingReason = nil
local pendingReasonAt = nil
local intervalToken = 0
local stampFrame = nil
local listeners = {}

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

local function Read(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local ok, value = pcall(fn, ...)

    if not ok or IsSecret(value) then
        return nil
    end

    return value
end

local function Clock()
    return Read(GetTime) or Read(time) or 0
end

local function After(seconds, callback)
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(seconds, callback)
    else
        callback()
    end
end

local function SafeName(value)
    if IsSecret(value) or not U.IsNonEmptyString(value) then
        return nil
    end

    return U.Trim(value)
end

function Screenshotter.FillDefaults(settings)
    if type(settings) ~= "table" then
        return settings
    end

    if settings.enabled == nil then
        settings.enabled = true
    end

    settings.triggers = type(settings.triggers) == "table" and settings.triggers or {}
    settings.options = type(settings.options) == "table" and settings.options or {}

    for _, trigger in ipairs(Screenshotter.TRIGGERS) do
        if settings.triggers[trigger.key] == nil then
            settings.triggers[trigger.key] = trigger.default
        end
    end

    for _, option in ipairs(Screenshotter.OPTIONS) do
        if settings.options[option.key] == nil then
            settings.options[option.key] = option.default
        end
    end

    if tonumber(settings.interval) == nil then
        settings.interval = Screenshotter.INTERVAL_DEFAULT
    end

    return settings
end

local function GetSettings()
    local db = ns.state and ns.state.db

    if type(db) ~= "table" then
        return nil
    end

    if type(db.screenshotter) ~= "table" then
        db.screenshotter = {}
    end

    return Screenshotter.FillDefaults(db.screenshotter)
end

local function Notify()
    for _, callback in ipairs(listeners) do
        pcall(callback)
    end
end

function Screenshotter:OnChanged(callback)
    if type(callback) == "function" then
        table.insert(listeners, callback)
    end
end

function Screenshotter:IsMementoLoaded()
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return Read(isLoaded, "Memento") == true
end

function Screenshotter:IsEnabled()
    local settings = GetSettings()
    return settings ~= nil and settings.enabled == true
end

function Screenshotter:IsPaused()
    return self:IsMementoLoaded()
end

function Screenshotter:IsActive()
    return ns:IsFeatureOn("screenshots") and self:IsEnabled() and not self:IsPaused()
end

function Screenshotter:IsTriggerOn(key)
    local settings = GetSettings()
    return settings ~= nil and settings.triggers[key] == true
end

function Screenshotter:IsOptionOn(key)
    local settings = GetSettings()
    return settings ~= nil and settings.options[key] == true
end

function Screenshotter:GetInterval()
    local settings = GetSettings()
    local minutes = settings and tonumber(settings.interval) or Screenshotter.INTERVAL_DEFAULT

    return math.max(Screenshotter.INTERVAL_MIN, math.min(Screenshotter.INTERVAL_MAX, math.floor(minutes)))
end

function Screenshotter:SetEnabled(enabled)
    local settings = GetSettings()

    if settings then
        settings.enabled = enabled == true
        self:RefreshInterval()
        Notify()
    end
end

function Screenshotter:SetTrigger(key, enabled)
    local settings = GetSettings()

    if settings and TRIGGER_BY_KEY[key] then
        settings.triggers[key] = enabled == true
        self:RefreshInterval()
        Notify()
    end
end

function Screenshotter:SetOption(key, enabled)
    local settings = GetSettings()

    if settings and settings.options[key] ~= nil then
        settings.options[key] = enabled == true
        Notify()
    end
end

function Screenshotter:SetInterval(minutes)
    local settings = GetSettings()

    if settings then
        settings.interval = math.max(Screenshotter.INTERVAL_MIN, math.min(Screenshotter.INTERVAL_MAX, math.floor(tonumber(minutes) or Screenshotter.INTERVAL_DEFAULT)))
        self:RefreshInterval()
        Notify()
    end
end

function Screenshotter.StampText()
    local name = SafeName(Read(UnitName, "player")) or "Unknown"
    local realm = SafeName(Read(GetRealmName))
    local level = Read(UnitLevel, "player")
    local parts = { realm and (name .. " " .. realm) or name }

    if tonumber(level) then
        table.insert(parts, "level " .. level)
    end

    table.insert(parts, Read(date, "%Y-%m-%d %H:%M") or "")

    return table.concat(parts, ", ")
end

-- Parented to nothing so it stays visible while UIParent is hidden.
local function ShowStamp()
    local Theme = ns.Theme

    if not Theme then
        return
    end

    if not stampFrame then
        stampFrame = Theme.CreatePanel(nil, "dark", "border")
        stampFrame:SetSize(300, 24)
        stampFrame:SetPoint("BOTTOM", 0, 60)
        stampFrame:SetFrameStrata("TOOLTIP")

        local text = Theme.CreateText(stampFrame, "GameFontHighlightSmall", "text")
        text:SetPoint("CENTER", 0, 0)
        text:SetJustifyH("CENTER")
        stampFrame.text = text
    end

    stampFrame.text:SetText(Screenshotter.StampText())
    stampFrame:SetWidth(math.max(160, (stampFrame.text:GetStringWidth() or 0) + 24))
    stampFrame:Show()
end

local function HideStamp()
    if stampFrame then
        stampFrame:Hide()
    end
end

local function PlayShutter()
    if type(PlaySound) ~= "function" or type(SOUNDKIT) ~= "table" then
        return
    end

    for _, name in ipairs(SOUND_KITS) do
        if SOUNDKIT[name] and pcall(PlaySound, SOUNDKIT[name]) then
            return
        end
    end
end

local function PrintShot(reason)
    if not DEFAULT_CHAT_FRAME or type(DEFAULT_CHAT_FRAME.AddMessage) ~= "function" then
        return
    end

    local accent = ns.Theme and ns.Theme.ColorCode("accent") or ""
    pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format(C.TEXT.SHOTS_CHAT, accent, reason))
end

local function Snap()
    pcall(Screenshot)

    if Screenshotter:IsOptionOn("sound") then
        PlayShutter()
    end
end

local function RestoreInterface()
    if UIParent and type(UIParent.Show) == "function" then
        pcall(UIParent.Show, UIParent)
    end

    HideStamp()
end

local function Capture(reason)
    reason = U.IsNonEmptyString(reason) and reason or C.TEXT.SHOTS_REASON_MANUAL
    lastShotAt = Clock()
    pendingReason = reason
    pendingReasonAt = lastShotAt
    Screenshotter.lastReason = reason

    if Screenshotter:IsOptionOn("chat") then
        PrintShot(reason)
    end

    local canHide = Screenshotter:IsOptionOn("hideUI")
        and UIParent
        and not Read(InCombatLockdown)

    if not canHide then
        Snap()
        return
    end

    local ok = pcall(function()
        UIParent:Hide()

        if Screenshotter:IsOptionOn("stamp") then
            ShowStamp()
        end
    end)

    if not ok then
        RestoreInterface()
        Snap()
        return
    end

    After(HIDE_UI_SHOT_DELAY, Snap)
    After(HIDE_UI_RESTORE_DELAY, RestoreInterface)
end

function Screenshotter:TakeNow(reason)
    Capture(reason)
end

-- Returns the reason for the screenshot the game just saved, once.
function Screenshotter:ConsumeReason()
    if not pendingReason or Clock() - (pendingReasonAt or 0) > REASON_SECONDS then
        pendingReason = nil
        return nil
    end

    local reason = pendingReason
    pendingReason = nil

    return reason
end

local function Fire()
    local shot = pending
    pending = nil

    if shot and Screenshotter:IsActive() then
        Capture(table.concat(shot.reasons, ", "))
    end
end

function Screenshotter:Trigger(key, reason)
    local trigger = TRIGGER_BY_KEY[key]

    if not trigger or not self:IsActive() or not self:IsTriggerOn(key) then
        return false
    end

    reason = U.IsNonEmptyString(reason) and reason or C.SHOTS_TRIGGER_REASONS[key]

    if pending then
        for _, existing in ipairs(pending.reasons) do
            if existing == reason then
                return true
            end
        end

        table.insert(pending.reasons, reason)
        return true
    end

    if lastShotAt and Clock() - lastShotAt < MERGE_SECONDS then
        return false
    end

    pending = { reasons = { reason } }
    After(trigger.delay, Fire)

    return true
end

function Screenshotter:RefreshInterval()
    intervalToken = intervalToken + 1

    if not self:IsActive() or not self:IsTriggerOn("interval") then
        return
    end

    local token = intervalToken

    local function Tick()
        if token ~= intervalToken then
            return
        end

        Screenshotter:Trigger("interval", string.format(C.TEXT.SHOTS_REASON_INTERVAL, Screenshotter:GetInterval()))
        After(Screenshotter:GetInterval() * 60, Tick)
    end

    After(self:GetInterval() * 60, Tick)
end

local function AchievementName(achievementID)
    local ok, _, name = pcall(GetAchievementInfo, achievementID)
    return ok and SafeName(name) or nil
end

local function CollectionReason(event, id)
    local name = nil

    if event == "NEW_MOUNT_ADDED" and C_MountJournal then
        name = SafeName(Read(C_MountJournal.GetMountInfoByID, id))
    elseif event == "NEW_TOY_ADDED" and C_ToyBox then
        local ok, _, toyName = pcall(C_ToyBox.GetToyInfo, id)
        name = ok and SafeName(toyName) or nil
    elseif event == "NEW_RECIPE_LEARNED" then
        name = SafeName(C_Spell and Read(C_Spell.GetSpellName, id) or Read(GetSpellInfo, id))
    elseif event == "NEW_PET_ADDED" and C_PetJournal then
        local ok, _, customName, _, _, _, _, _, petName = pcall(C_PetJournal.GetPetInfoByPetID, id)
        name = ok and (SafeName(customName) or SafeName(petName)) or nil
    end

    local label = C.SHOTS_COLLECTION_LABELS[event]

    return name and string.format("%s: %s", label, name) or label
end

local eventFrame = CreateFrame("Frame")
local registeredEvents = {}

local function Register(event)
    local ok, result = pcall(eventFrame.RegisterEvent, eventFrame, event)
    ok = ok and result ~= false

    if ok then
        table.insert(registeredEvents, event)
    else
        table.insert(Screenshotter.refusedEvents, event)
    end

    return ok
end

-- The whole feature. SetEnabled is the "take screenshots automatically" setting inside it.
function Screenshotter:SetFeatureActive(on, loading)
    ns.Features.SetEvents(eventFrame, registeredEvents, on)

    if not on then
        pending = nil
    end

    if not loading then
        self:RefreshInterval()
        Notify()
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if not ns:IsFeatureOn("screenshots") then
        return
    end

    if event == "PLAYER_LEVEL_UP" then
        local level = ...
        Screenshotter:Trigger("levelUp", not IsSecret(level) and tonumber(level) and string.format(C.TEXT.SHOTS_REASON_LEVEL, level) or nil)
    elseif event == "PLAYER_DEAD" then
        Screenshotter:Trigger("death")
    elseif event == "ACHIEVEMENT_EARNED" then
        local achievementID = ...
        local name = not IsSecret(achievementID) and AchievementName(achievementID) or nil
        Screenshotter:Trigger("achievement", name and string.format(C.TEXT.SHOTS_REASON_ACHIEVEMENT, name) or nil)
    elseif event == "ENCOUNTER_END" then
        local _, encounterName, _, _, success = ...

        if not IsSecret(success) and tonumber(success) == 1 then
            local name = SafeName(encounterName)
            Screenshotter:Trigger("boss", name and string.format(C.TEXT.SHOTS_REASON_BOSS, name) or nil)
        end
    elseif event == "PVP_MATCH_COMPLETE" then
        Screenshotter:Trigger("pvp")
    elseif event == "DUEL_FINISHED" then
        Screenshotter:Trigger("duel")
    elseif C.SHOTS_COLLECTION_LABELS[event] then
        local id = ...
        Screenshotter:Trigger("collection", CollectionReason(event, not IsSecret(id) and id or nil))
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = ...

        if isLogin == true then
            Screenshotter:Trigger("login")
        end

        -- /reload does not fire PLAYER_LOGIN, so the interval timer has to start here too.
        if isLogin == true or isReload == true then
            GetSettings()
            Screenshotter:RefreshInterval()
        end
    elseif event == "PLAYER_LOGIN" then
        GetSettings()
        Screenshotter:RefreshInterval()
    end
end)

Register("PLAYER_LOGIN")
Register("PLAYER_ENTERING_WORLD")
Register("PLAYER_LEVEL_UP")
Register("PLAYER_DEAD")
Register("ACHIEVEMENT_EARNED")
Register("ENCOUNTER_END")
Register("PVP_MATCH_COMPLETE")
Register("DUEL_FINISHED")

for event in pairs(C.SHOTS_COLLECTION_LABELS) do
    Register(event)
end

ns:RegisterModule("Data.Screenshotter", Screenshotter)

ns.Data = ns.Data or {}
ns.Data.Screenshotter = Screenshotter
