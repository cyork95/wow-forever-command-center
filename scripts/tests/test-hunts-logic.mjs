// Focused checks for the Hunts #39 logic in assets/app.js.
// Run: node scripts/tests/test-hunts-logic.mjs
// Loads app.js in a vm with stubbed browser globals (the trailing main()
// auto-run is stripped) and asserts the pure logic: bucket helpers, the
// v1 -> v2 check migration, ATT obtained matching, mission progress and its
// honest no-data states, rarity text, and typed guide refs. Exit non-zero
// on the first failure; prints ok lines like the PowerShell suite.

import { readFileSync } from "node:fs";
import vm from "node:vm";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const source = readFileSync(path.join(repo, "assets", "app.js"), "utf8");

let failures = 0;
function assert(condition, message) {
  if (!condition) {
    failures += 1;
    console.error(`ASSERT FAILED: ${message}`);
  } else {
    console.log(`ok - ${message}`);
  }
}

function makeStore(seed) {
  const data = { ...(seed || {}) };
  return {
    getItem: (key) => (key in data ? data[key] : null),
    setItem: (key, value) => { data[key] = String(value); },
    removeItem: (key) => { delete data[key]; },
    data,
  };
}

const localStorage = makeStore();
const document = new Proxy({}, {
  get: () => () => ({ addEventListener() {}, replaceChildren() {}, append() {}, set textContent(_) {}, get textContent() { return ""; } }),
});
const context = vm.createContext({ localStorage, document, fetch: async () => { throw new Error("no fetch in test"); }, console });

const stripped = source.replace(/\nmain\(\);\s*$/, "");
assert(stripped !== source, "main() auto-run stripped for vm load");
assert(!/\nmain\(\);/.test(stripped), "no remaining main() invocation");
vm.runInContext(stripped, context, { filename: "app.js" });

const t = vm.runInContext(`({
  huntBucket, huntKind, checkKey, manualState, migrateV1Checks, loadHunts,
  attSets, isObtained, rarityText, characterQuestSet, missionProgress,
  missionComplete, guideLine, ACCOUNT_CHECK, HUNT_STORE_KEY, HUNT_STORE_KEY_V1,
  state, HUNT_GROUPS,
})`, context);

// 0. Checklist batch (#28/#29/#32/#33): committed file totals and entries.
const checklist = JSON.parse(readFileSync(path.join(repo, "data", "checklist.json"), "utf8"));
assert(checklist.length === 47, `checklist carries 47 entries, got ${checklist.length}`);
assert(checklist.filter((h) => h.type === "collection").length === 26, "collections total 26");
assert(checklist.filter((h) => h.type === "gear").length === 15, "gear hunts total 15");
const huntById = Object.fromEntries(checklist.map((h) => [h.id, h]));
const violet = huntById["violet-vestments"];
assert(violet && checklist.filter((h) => h.id === "violet-vestments").length === 1, "violet-vestments exists exactly once");
assert(violet.zone === "City of Dalaran", "violet-vestments zoned to City of Dalaran");
assert(violet.targetCharacters.includes("malavus") && violet.targetCharacters.includes("lucinis"), "violet-vestments targets malavus and lucinis");
assert(!violet.notes.includes("stats are still hidden"), "violet-vestments drops the stale datamine wording");
assert(violet.status === "Planned", "violet-vestments is an active Planned hunt");
const oilskin = huntById["oilskin-leggings"];
assert(!!oilskin, "oilskin leggings entry exists");
assert(oilskin.notes.includes("Uldaman") && oilskin.notes.includes("Grimlok") && oilskin.notes.includes("Feral Combat +1"), "oilskin notes carry zone, boss, and bonus");
assert(oilskin.targetCharacters.includes("sorinis") && oilskin.targetCharacters.includes("skyrinis"), "oilskin targets both druids");
for (const name of ["Cerulean Prideclaw", "Spectral Bear", "Spectral Bear Cub", "Mystmane", "Azurky"]) {
  const entry = checklist.find((h) => h.name === name);
  assert(!!entry, `collection entry exists: ${name}`);
  assert(/unconfirmed/i.test(entry.notes), `collection entry notes say unconfirmed: ${name}`);
}

// 1. Bucket helpers.
t.state.checklist = [];
assert(t.huntBucket({ type: "collection" }) === "collection", "bucket collection");
assert(t.huntBucket({ type: "gear" }) === "gear", "bucket gear");
assert(t.huntBucket({ type: "mission" }) === "mission", "bucket mission");
assert(t.huntBucket({ kind: "Pet" }) === "", "untyped hunt has empty bucket");
assert(t.huntKind({ kind: "Pet", type: "collection" }) === "Pet", "kind preserved beside bucket");
assert(t.huntKind({ type: "Gear" }) === "Gear", "old files label from type");
assert(t.huntKind({ type: "collection" }) === "", "bucket alone labels nothing");
assert(t.HUNT_GROUPS.some((g) => g.id === "collections"), "collections group exists");
assert(t.HUNT_GROUPS.some((g) => g.id === "other"), "other group catches untyped hunts");

// 2. v1 -> v2 migration.
t.state.checklist = [
  { id: "c1", type: "collection", parts: [{ id: "c1p" }] },
  { id: "g1", type: "gear" },
  { id: "m1", type: "mission" },
];
t.state.selected = "flann";
const v1 = {
  checks: {
    c1: { flann: true, trends: false },
    c1p: { flann: true },
    g1: { flann: true },
    m1: { x: true },
    ghost: { a: true },
  },
  attempts: { g1: { flann: 3 } },
};
const moved = t.migrateV1Checks(v1);
assert(moved.checks.c1[t.ACCOUNT_CHECK] === true, "collection collapses account-wide, checked wins");
assert(moved.checks.c1p[t.ACCOUNT_CHECK] === true, "collection part id follows parent bucket");
assert(moved.checks.g1.flann === true, "gear stays per-character");
assert(moved.checks.m1.x === true, "mission stays per-character");
assert(moved.dropped.includes("ghost"), "unknown hunt id dropped and reported");
assert(moved.attempts.g1.flann === 3, "attempts carry over untouched");
const moved2 = t.migrateV1Checks({ checks: { c9: { a: false } }, attempts: {} });
t.state.checklist = [{ id: "c9", type: "collection" }];
const moved2b = t.migrateV1Checks({ checks: { c9: { a: false } }, attempts: {} });
assert(moved2b.checks.c9[t.ACCOUNT_CHECK] === false, "explicit false survives migration");
assert(!("c9" in t.migrateV1Checks({ checks: { c9: {} }, attempts: {} }).checks), "empty row stays absent");

// 3. ATT obtained matching.
t.state.att = {
  account: { questsHave: [111], sourcesHave: [222] },
  obtainedTimeline: [{ name: "Fixture Helm", itemId: 424242, type: "ItemWithAppearance" }],
  characters: [],
};
vm.runInContext("attCache = null;", context);
assert(t.isObtained({ type: "collection", match: { questIds: [111] } }) !== "", "quest have marks obtained");
assert(t.isObtained({ type: "collection", match: { itemIds: [424242] } }) !== "", "timeline item id marks obtained");
assert(t.isObtained({ type: "collection", match: { itemIds: [222] } }) !== "", "source have marks obtained");
assert(t.isObtained({ type: "collection", match: { names: ["fixture helm"] } }) !== "", "timeline name matches case-insensitively");
assert(t.isObtained({ type: "collection", match: { names: ["Nope"] } }) === "", "unmatched name stays manual");
assert(t.isObtained({ type: "collection" }) === "", "no match block stays manual");
assert(t.isObtained({ type: "gear", match: { questIds: [111] } }) === "", "gear never auto-obtains");

// 4. Mission progress and honest empty states.
t.state.att = { account: {}, obtainedTimeline: [], characters: [{ canonicalId: "fixturin", questsHave: [7, 8] }] };
const prog = t.missionProgress({ type: "mission", quests: [7, 8, 9] }, "fixturin");
assert(prog.total === 3 && prog.done === 2 && !prog.noData, "mission progress 2 of 3");
assert(t.missionComplete({ type: "mission", quests: [7, 8] }, "fixturin"), "mission completes when all quests done");
assert(!t.missionComplete({ type: "mission", quests: [7, 8, 9] }, "fixturin"), "mission open until all quests done");
const blind = t.missionProgress({ type: "mission", quests: [7] }, "sorinis");
assert(blind.noData && blind.done === 0, "unscanned character renders no-data, not zero");
const bare = t.missionProgress({ type: "mission" }, "fixturin");
assert(bare.empty, "mission without quest list reports empty");

// 5. Rarity text beside a hunt.
t.state.rarity = { items: [{ id: "Fixture Dropper", name: "Fixture Dropper", attempts: 5, found: false }] };
assert(t.rarityText({ rarityId: "Fixture Dropper" }) === "Rarity tracked: 5 attempts", "attempts display");
t.state.rarity = { items: [{ id: "Fixture Quiet", name: "Fixture Quiet", attempts: null, found: true }] };
assert(t.rarityText({ rarityId: "Fixture Quiet" }) === "Rarity tracked: 0 attempts, found", "honest zeros with found flag");
assert(t.rarityText({}) === "", "no rarityId renders nothing");
t.state.rarity = null;
assert(t.rarityText({ rarityId: "Fixture Dropper" }) === "", "missing rarity file renders nothing");

// 6. Typed guide refs.
t.state.guides = [{ id: "g-one", title: "Guide One", url: "https://example.invalid/1" }];
assert(t.guideLine({ kind: "polestar", ref: "Fixture Guide" }).text.includes("Polestar"), "polestar ref is a display pointer");
assert(t.guideLine({ kind: "video", ref: "g-one" }).url === "https://example.invalid/1", "video ref resolves against guides.json");
assert(t.guideLine({ kind: "doc", ref: "g-missing" }).text.includes("not in guides.json"), "unknown guide id says so honestly");
assert(t.guideLine(null) === null, "absent guideRef renders nothing");

// 7. loadHunts end to end: v1 migrates once, v2 loads directly.
t.state.checklist = [{ id: "c1", type: "collection" }, { id: "g1", type: "gear" }];
t.state.selected = "flann";
Object.defineProperty(context, "localStorage", { value: makeStore({ "wow-forever-hunts-v1": JSON.stringify(v1) }), configurable: true });
const first = t.loadHunts();
assert(first.migrated && first.dropped.includes("ghost"), "v1 migrates on first v2 load");
const store = context.localStorage.data;
assert(store["wow-forever-hunts-v2"] !== undefined, "v2 persisted after migration");
assert(!("wow-forever-hunts-v1" in store), "v1 key retired after migration");
assert(JSON.parse(store["wow-forever-hunts-v2"]).checks.c1[t.ACCOUNT_CHECK] === true, "migrated collection check readable");
const second = t.loadHunts();
assert(!second.migrated, "v2 loads directly afterwards");

// 8. checkKey routing.
t.state.selected = "flann";
assert(t.checkKey({ type: "collection" }) === t.ACCOUNT_CHECK, "collections key by hunt alone");
assert(t.checkKey({ type: "gear" }) === "flann", "gear keys per character");

if (failures) {
  console.error(`FAIL test-hunts-logic (${failures} assertions)`);
  process.exit(1);
}
console.log("PASS test-hunts-logic");
