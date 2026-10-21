local _, ns = ...

local C = ns.constants

local QuestJourney = {}

-- Collector for the "Quest history" export section. The journey comes from the
-- Questie companion, so the Other-addons feature switch and the per-addon
-- Questie switch both gate it: with either off, or Questie not loaded, or no
-- journey recorded, this collects no events and the section stays out of the
-- export entirely.
function QuestJourney:Collect()
    local companions = ns.Companions
    local data = nil

    if companions
        and type(companions.IsEnabled) == "function"
        and companions:IsEnabled("questie")
    then
        data = companions:Read("questie", "ReadJourney")
    end

    local events = {}
    local counts = nil
    local omitted = 0

    if type(data) == "table" then
        if type(data.events) == "table" then
            events = data.events
        end

        if type(data.counts) == "table" then
            counts = data.counts
        end

        if type(data.omitted) == "number" then
            omitted = data.omitted
        end
    end

    return {
        key = C.SECTIONS.QUEST_HISTORY,
        title = C.SECTION_LABELS[C.SECTIONS.QUEST_HISTORY],
        events = events,
        counts = counts,
        omitted = omitted,
    }
end

ns.Data = ns.Data or {}
ns.Data.QuestJourney = QuestJourney
ns:RegisterModule("Data.QuestJourney", QuestJourney)
