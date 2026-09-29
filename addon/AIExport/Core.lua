local addonName, ns = ...

_G.AIExport = ns

ns.name = addonName or "AIExport"
ns.state = ns.state or {}
ns.modules = ns.modules or {}

ns.state.bankOpen = false
ns.state.tradeSkillOpen = false
ns.state.lastTradeSkillUpdate = nil
ns.state.selectedSections = ns.state.selectedSections or {}

local eventFrame = CreateFrame("Frame")
ns.eventFrame = eventFrame

local function GetCurrentTimestamp()
    if type(time) == "function" then
        local success, timestamp = pcall(time)

        if success and type(timestamp) == "number" then
            return timestamp
        end
    end

    return nil
end

local function InitializeDatabase()
    AIExportDBChar =
        AIExportDBChar or {}

    ns.state.db = AIExportDBChar
    ns.db = ns.state.db

    ns.state.db.bankCache =
        ns.state.db.bankCache or {}

    ns.state.db.professionCache =
        ns.state.db.professionCache or {}

    ns.state.db.lockoutsCache =
        ns.state.db.lockoutsCache or {}

    ns.state.db.collectedAppearanceItemNameCache =
        ns.state.db.collectedAppearanceItemNameCache or {}

    ns.state.db.kills =
        ns.state.db.kills or {}

    ns.state.db.screenshotter =
        ns.state.db.screenshotter or {}

    local screenshotter = ns.Data and ns.Data.Screenshotter

    if screenshotter then
        screenshotter.FillDefaults(ns.state.db.screenshotter)
    end

    ns.state.db.session =
        ns.state.db.session or {}

    local session = ns.Data and ns.Data.Session

    if session then
        session.FillDefaults(ns.state.db.session)
    end

    ns.state.bankOpen = false
    ns.state.tradeSkillOpen = false

    ns.state.minimapButtonAngle =
        ns.state.db.minimapButtonAngle

    ns.state.minimapIconVisible =
        ns.state.db.minimapIconVisible

    ns.state.verboseItemTypes =
        ns.state.db.verboseItemTypes == true

    ns.state.selectedSections =
        ns.state.db.selectedSections or {}
end

local function InitializeCommands()
    local commandsModule = ns:GetModule("Commands")

    if commandsModule
        and type(commandsModule.Initialize) == "function"
    then
        commandsModule:Initialize()
    end
end

local function UpdateBankCache()
    local bankModule = ns:GetModule("Data.Bank")

    if bankModule
        and type(bankModule.UpdateCacheFromLive) == "function"
    then
        bankModule:UpdateCacheFromLive()
    end
end

local function UpdateProfessionCache()
    local professionModule =
        ns:GetModule("Data.ProfessionDetails")

    if professionModule
        and type(professionModule.UpdateCacheFromTradeSkillWindow)
            == "function"
    then
        professionModule:UpdateCacheFromTradeSkillWindow()
    end
end

local function UpdateLockoutsCache()
    local lockoutsModule = ns:GetModule("Data.Lockouts")

    if lockoutsModule
        and type(lockoutsModule.UpdateCacheFromLive) == "function"
    then
        lockoutsModule:UpdateCacheFromLive()
    end
end

local function OnEvent(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then
            return
        end

        InitializeDatabase()
        InitializeCommands()

        return
    end

    if event == "PLAYER_LOGIN" then
        ns.state.bankOpen = false
        ns.state.tradeSkillOpen = false

        InitializeCommands()

        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        local commandsModule = ns:GetModule("Commands")

        if commandsModule
            and type(
                commandsModule.RestoreMinimapButtonAngleDeferred
            ) == "function"
        then
            commandsModule:RestoreMinimapButtonAngleDeferred(
                ns.state.minimapButtonAngle
            )
        end

        return
    end

    if event == "BANKFRAME_OPENED" then
        ns.state.bankOpen = true

        UpdateBankCache()

        return
    end

    if event == "BANKFRAME_CLOSED" then
        ns.state.bankOpen = false

        return
    end

    if event == "PLAYERBANKSLOTS_CHANGED"
        or event == "BAG_UPDATE"
        or event == "BAG_UPDATE_DELAYED"
    then
        if ns:IsBankOpen() then
            UpdateBankCache()
        end

        return
    end

    if event == "TRADE_SKILL_SHOW"
        or event == "TRADE_SKILL_LIST_UPDATE"
    then
        ns.state.tradeSkillOpen = true
        ns.state.lastTradeSkillUpdate =
            GetCurrentTimestamp()

        UpdateProfessionCache()

        return
    end

    if event == "TRADE_SKILL_DATA_SOURCE_CHANGED"
        or event == "TRADE_SKILL_DETAILS_UPDATE"
    then
        if ns:IsTradeSkillWindowOpen() then
            ns.state.lastTradeSkillUpdate =
                GetCurrentTimestamp()

            UpdateProfessionCache()
        end

        return
    end

    if event == "TRADE_SKILL_CLOSE" then
        ns.state.tradeSkillOpen = false

        return
    end

    if event == "UPDATE_INSTANCE_INFO" then
        UpdateLockoutsCache()
    end
end

local function RegisterEventIfAvailable(eventName)
    if not eventFrame
        or type(eventFrame.RegisterEvent) ~= "function"
    then
        return false
    end

    local success = pcall(
        eventFrame.RegisterEvent,
        eventFrame,
        eventName
    )

    return success == true
end

RegisterEventIfAvailable("ADDON_LOADED")
RegisterEventIfAvailable("PLAYER_LOGIN")
RegisterEventIfAvailable("PLAYER_ENTERING_WORLD")

RegisterEventIfAvailable("BANKFRAME_OPENED")
RegisterEventIfAvailable("BANKFRAME_CLOSED")
RegisterEventIfAvailable("PLAYERBANKSLOTS_CHANGED")
RegisterEventIfAvailable("BAG_UPDATE")
RegisterEventIfAvailable("BAG_UPDATE_DELAYED")

RegisterEventIfAvailable("TRADE_SKILL_SHOW")
RegisterEventIfAvailable("TRADE_SKILL_LIST_UPDATE")
RegisterEventIfAvailable("TRADE_SKILL_DATA_SOURCE_CHANGED")
RegisterEventIfAvailable("TRADE_SKILL_DETAILS_UPDATE")
RegisterEventIfAvailable("TRADE_SKILL_CLOSE")

RegisterEventIfAvailable("UPDATE_INSTANCE_INFO")

eventFrame:SetScript("OnEvent", OnEvent)

function ns:IsBankOpen()
    return self.state
        and self.state.bankOpen == true
end

function ns:IsTradeSkillWindowOpen()
    if self.state
        and self.state.tradeSkillOpen == true
    then
        return true
    end

    if ProfessionsFrame
        and type(ProfessionsFrame.IsShown) == "function"
        and ProfessionsFrame:IsShown()
    then
        return true
    end

    if TradeSkillFrame
        and type(TradeSkillFrame.IsShown) == "function"
        and TradeSkillFrame:IsShown()
    then
        return true
    end

    return false
end

function ns:RegisterModule(name, module)
    if type(name) ~= "string" or name == "" then
        return
    end

    if type(module) ~= "table" then
        return
    end

    self.modules[name] = module
end

function ns:GetModule(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end

    return self.modules[name]
end

function ns:SetMinimapButtonAngle(angle)
    if angle == nil then
        return
    end

    self.state.minimapButtonAngle = angle

    if self.state.db then
        self.state.db.minimapButtonAngle = angle
    end
end

function ns:GetMinimapButtonAngle()
    return self.state.minimapButtonAngle
end

function ns:SetMinimapIconVisible(isVisible)
    local visible = isVisible ~= false

    self.state.minimapIconVisible = visible

    if self.state.db then
        self.state.db.minimapIconVisible = visible
    end
end

function ns:IsMinimapIconVisible()
    if self.state.minimapIconVisible == nil then
        return true
    end

    return self.state.minimapIconVisible == true
end

function ns:SetVerboseItemTypesEnabled(isEnabled)
    local enabled = isEnabled == true

    self.state.verboseItemTypes = enabled

    if self.state.db then
        self.state.db.verboseItemTypes = enabled
    end
end

function ns:IsVerboseItemTypesEnabled()
    if self.state.verboseItemTypes == nil
        and self.state.db
    then
        self.state.verboseItemTypes =
            self.state.db.verboseItemTypes == true
    end

    return self.state.verboseItemTypes == true
end

function ns:SetDetailedExport(isEnabled)
    local enabled = isEnabled == true

    self.state.detailedExport = enabled

    if self.state.db then
        self.state.db.detailedExport = enabled
    end
end

function ns:IsDetailedExport()
    if self.state.detailedExport == nil
        and self.state.db
    then
        self.state.detailedExport =
            self.state.db.detailedExport == true
    end

    return self.state.detailedExport == true
end

function ns:SetSelectedSections(selectedSections)
    if type(selectedSections) ~= "table" then
        return
    end

    self.state.selectedSections = selectedSections

    if self.state.db then
        self.state.db.selectedSections =
            selectedSections
    end
end

function ns:GetSelectedSections()
    return self.state.selectedSections or {}
end