// Journey #51 route data validation (Phase J1) and progress-logic checks.
// Run: node scripts/tests/test-journey-logic.mjs
// Part A reads data/journey.json from disk and proves the route file parses,
// zone orders are unique/sequential, and every section key exists per zone.
// Part B loads assets/app.js in a vm (same harness as test-hunts-logic.mjs)
// and asserts the journey progress computation with synthetic fixtures only.

import { readFileSync } from "node:fs";
import vm from "node:vm";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");

let failures = 0;
function assert(condition, message) {
  if (!condition) {
    failures += 1;
    console.error(`ASSERT FAILED: ${message}`);
  } else {
    console.log(`ok - ${message}`);
  }
}

// Part A: route file validation.
const journeyPath = path.join(repo, "data", "journey.json");
let journey = null;
try {
  journey = JSON.parse(readFileSync(journeyPath, "utf8"));
  assert(true, "journey.json parses as JSON");
} catch (error) {
  assert(false, `journey.json parses as JSON (${error.message})`);
}
if (journey) {
  assert(journey.schemaVersion === 1, "schemaVersion is 1");
  assert(journey.character === "skyrinis", "route character is skyrinis");
  assert(Array.isArray(journey.zones) && journey.zones.length > 0, "at least one zone curated");
  const orders = journey.zones.map((zone) => zone.order);
  assert(new Set(orders).size === orders.length, "zone orders are unique");
  assert(orders.slice().sort((a, b) => a - b).every((order, index) => order === index + 1), "zone orders are sequential from 1");
  const sections = ["quests", "exploration", "collectibles", "rares", "boes", "professions", "guideRefs"];
  journey.zones.forEach((zone) => {
    assert(typeof zone.id === "string" && zone.id.length > 0, `zone has id (${zone.id})`);
    assert(typeof zone.name === "string" && zone.name.length > 0, `zone has name (${zone.name})`);
    sections.forEach((key) => {
      assert(Array.isArray(zone[key]), `zone ${zone.id} carries section ${key}`);
    });
    (zone.quests || []).forEach((quest) => {
      assert(typeof quest.name === "string" && quest.name.length > 0, `zone ${zone.id} quest has a name`);
      if (quest.id !== undefined && quest.id !== null) {
        assert(Number.isInteger(quest.id), `zone ${zone.id} quest id is an integer (${quest.id})`);
      }
    });
    const questIds = (zone.quests || []).map((quest) => quest.id).filter((id) => id !== undefined && id !== null);
    assert(new Set(questIds).size === questIds.length, `zone ${zone.id} has no duplicate quest ids`);
    (zone.collectibles || []).forEach((item) => {
      assert(typeof item.name === "string" && item.name.length > 0, `zone ${zone.id} collectible has a name`);
    });
    (zone.exploration || []).forEach((item) => {
      assert(typeof item.name === "string" && item.name.length > 0, `zone ${zone.id} exploration has a name`);
    });
  });
  // J1 complete-coverage snapshot: 142 Zephras Isle + 83 Elwynn Forest quests.
  const questTotal = journey.zones.reduce((sum, zone) => sum + (zone.quests || []).length, 0);
  assert(questTotal === 225, `route ships 225 quests (142 Zephras Isle + 83 Elwynn Forest), got ${questTotal}`);
}

// Part B: progress computation (pure logic, synthetic fixtures only).
function makeStore(seed) {
  const data = { ...(seed || {}) };
  return {
    getItem: (key) => (key in data ? data[key] : null),
    setItem: (key, value) => { data[key] = String(value); },
    removeItem: (key) => { delete data[key]; },
    data,
  };
}
const appSource = readFileSync(path.join(repo, "assets", "app.js"), "utf8");
const appStripped = appSource.replace(/\nmain\(\);\s*$/, "");
assert(appStripped !== appSource, "main() auto-run stripped for vm load");
const appStore = makeStore();
const appDocument = new Proxy({}, {
  get: () => () => ({ addEventListener() {}, replaceChildren() {}, append() {}, appendChild() {}, set textContent(_) {}, get textContent() { return ""; } }),
});
const appContext = vm.createContext({ localStorage: appStore, document: appDocument, fetch: async () => { throw new Error("no fetch in test"); }, console });
vm.runInContext(appStripped, appContext, { filename: "app.js" });
const resetAttCache = () => vm.runInContext("attCache = null;", appContext);

const j = vm.runInContext(`({
  journeyZones, journeyCharacterId, journeyQuestSet, journeyExplorationSet,
  journeyItemState, journeyZoneProgress, journeyOverall, journeyPriorityTargets,
  writeJourneyCheck, loadJourney, JOURNEY_STORE_KEY, state,
})`, appContext);

function seedJourney() {
  j.state.journeyChecks = {};
  j.state.att = { account: {}, obtainedTimeline: [], characters: [] };
  resetAttCache();
  j.state.journey = {
    character: "fixturin",
    zones: [
      {
        id: "zone-a", name: "Fixture Vale", order: 2, levelBand: "1-5", summary: "",
        quests: [{ id: 90001, name: "Fixture Quest One" }, { name: "Unverified Errand" }],
        exploration: [{ name: "Fixture Hollow" }],
        collectibles: [{ name: "Fixture Trinket", kind: "Toy" }],
        rares: [{ name: "Fixture Rare", priority: true }],
        boes: [{ name: "Fixture Blade" }],
        professions: [{ skill: "Mining", target: 75 }],
        guideRefs: []
      },
      {
        id: "zone-b", name: "Fixture Glen", order: 1, levelBand: "5-10", summary: "",
        quests: [{ id: 90002, name: "Fixture Quest Two" }],
        exploration: [],
        collectibles: [],
        rares: [],
        boes: [],
        professions: [],
        guideRefs: []
      }
    ]
  };
}

// Zones render in order regardless of file order.
seedJourney();
assert(j.journeyZones().map((zone) => zone.id).join(",") === "zone-b,zone-a", "zones sort by order");
assert(j.journeyCharacterId() === "fixturin", "journey character id read from route file");

// No scan: quest with id and exploration render pending, never done.
seedJourney();
assert(j.journeyQuestSet() === null, "quest set null when the character has no scan");
const zoneA = j.state.journey.zones.find((zone) => zone.id === "zone-a");
let questState = j.journeyItemState(zoneA, "quests", zoneA.quests[0]);
assert(questState.pending && !questState.done && questState.auto, "unscanned quest with id is pending, not done");
let exploreState = j.journeyItemState(zoneA, "exploration", zoneA.exploration[0]);
assert(exploreState.pending && !exploreState.done, "unscanned exploration is pending, not done");

// Scanned quest completes by id; name-only quests stay manual.
seedJourney();
j.state.att = { account: {}, obtainedTimeline: [], characters: [{ canonicalId: "fixturin", questsHave: [90001] }] };
resetAttCache();
questState = j.journeyItemState(zoneA, "quests", zoneA.quests[0]);
assert(questState.done && !questState.pending, "quest id in the character set checks auto");
const manualQuest = j.journeyItemState(zoneA, "quests", zoneA.quests[1]);
assert(!manualQuest.auto && manualQuest.manual && !manualQuest.done, "quest without id is a manual tick");
j.writeJourneyCheck("zone-a", "Unverified Errand", true);
assert(j.journeyItemState(zoneA, "quests", zoneA.quests[1]).done, "manual quest tick persists in state");

// Collectibles check account-wide by timeline name, case-insensitively.
seedJourney();
j.state.att = { account: {}, obtainedTimeline: [{ name: "fixture trinket", type: "Toy", itemId: null }], characters: [] };
resetAttCache();
const collState = j.journeyItemState(zoneA, "collectibles", zoneA.collectibles[0]);
assert(collState.done && collState.auto, "collectible matches the account timeline by name");

// Rares, BoEs, and professions are manual ticks keyed by zone and name.
seedJourney();
assert(!j.journeyItemState(zoneA, "rares", zoneA.rares[0]).done, "rare starts unchecked");
j.writeJourneyCheck("zone-a", "Fixture Rare", true);
j.writeJourneyCheck("zone-a", "Mining 75", true);
assert(j.journeyItemState(zoneA, "rares", zoneA.rares[0]).done, "rare tick persists");
assert(j.journeyItemState(zoneA, "professions", zoneA.professions[0]).done, "profession tick keys on skill plus target");

// Gating: only quests, exploration, and collectibles gate DONE.
seedJourney();
j.state.att = {
  account: {},
  obtainedTimeline: [{ name: "Fixture Trinket", type: "Toy", itemId: null }],
  characters: [{ canonicalId: "fixturin", questsHave: [90001], explorationHave: ["Fixture Hollow"] }]
};
resetAttCache();
j.writeJourneyCheck("zone-a", "Unverified Errand", true);
let progress = j.journeyZoneProgress(zoneA);
assert(progress.gated, "zone gates DONE once quests, exploration, and collectibles clear");
assert(progress.total === 7 && progress.done === 4, "zone % counts rares, BoEs, and professions too");
j.writeJourneyCheck("zone-a", "Fixture Rare", true);
progress = j.journeyZoneProgress(zoneA);
assert(progress.gated && progress.done === 5, "a checked rare counts toward % without gating");

// Overall route: totals, current zone, and the priority list.
const overall = j.journeyOverall();
assert(overall.total === 8 && overall.done === 5, "overall totals span every zone");
assert(overall.current && overall.current.id === "zone-b", "current zone is the first not-DONE zone in order");
const targets = j.journeyPriorityTargets();
assert(targets.length === 1 && targets[0].name === "Fixture Rare" && targets[0].zone === "Fixture Vale" && targets[0].done, "priority items surface with their zone and state");



// Manual checks persist under the journey key and reload.
Object.defineProperty(appContext, "localStorage", { value: makeStore(), configurable: true });
j.state.journeyChecks = {};
j.writeJourneyCheck("zone-a", "Fixture Blade", true);
j.state.journeyChecks = {};
j.loadJourney();
assert(j.journeyItemState(zoneA, "boes", zoneA.boes[0]).done, "manual checks reload from localStorage");

if (failures) {
process.exit(1);
}
console.log("PASS test-journey-logic");
