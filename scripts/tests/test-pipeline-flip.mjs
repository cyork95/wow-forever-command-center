// Pipeline flip (board #72): repo data is the primary numbers source.
// Run: node scripts/tests/test-pipeline-flip.mjs
// Loads app.js in a vm with stubbed browser globals (the trailing main()
// auto-run is stripped) and asserts: no Sheet endpoints remain in the read
// path, Bio/stats surfaces render from data/stats.json entries (including a
// launch character), Butler-style absent-data entries render honestly (empty
// itemCounts/crafts, null Titles, no Areas explored row), the kept beta trio
// still renders, and biography/<id>.json timelines render newest-first.

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

function textOf(node) {
  if (node == null) return "";
  if (typeof node === "string") return node;
  let out = node._text || "";
  for (const kid of node.children || []) out += textOf(kid);
  return out;
}

function makeNode(tag) {
  return {
    tag, children: [], attrs: {}, _text: "", handlers: {},
    className: "", value: "", hidden: false, tabIndex: 0,
    style: { setProperty() {} }, dataset: {},
    get options() { return this.children; },
    get textContent() { return textOf(this); },
    set textContent(v) { this._text = String(v); this.children = []; },
    setAttribute(k, v) { this.attrs[k] = String(v); },
    getAttribute(k) { return this.attrs[k]; },
    addEventListener(type, fn) { this.handlers[type] = fn; },
    append(...kids) { for (const k of kids.flat(9)) if (k) this.children.push(k); },
    replaceChildren(...kids) { this.children = kids.flat(9).filter(Boolean); },
  };
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

// 0. The Sheet is out of the read path: no Sheet endpoints in site code,
// and every boot-time loadJson target is repo-local (data/ or biography/).
assert(!/docs\.google|gviz|output=csv|script\.google/i.test(source),
  "no Sheet endpoints (docs.google/gviz/output=csv/script.google) in app.js");
const html = readFileSync(path.join(repo, "index.html"), "utf8");
assert(!/docs\.google[^"]*output=csv|gviz|script\.google/i.test(html),
  "no Sheet data URLs in index.html");
const bootTargets = new Set();
for (const m of source.matchAll(/loadJson\("([^"]+)"\)/g)) bootTargets.add(m[1]);
for (const m of source.matchAll(/loadJson\(`([^`]+)`\)/g)) {
  if (!m[1].includes("${")) bootTargets.add(m[1]);
}
assert(bootTargets.has("data/stats.json"), "boot loads data/stats.json");
assert([...bootTargets].every((t) => t.startsWith("data/") || t.startsWith("biography/")),
  `every loadJson target is repo-local: ${[...bootTargets].join(", ")}`);
assert(source.includes("biography/${character.id}.json"),
  "boot loads biography/<character-id>.json per roster character");

const localStorage = makeStore();
const byId = new Map();
const document = {
  createElement: (tag) => makeNode(tag),
  createTextNode: (t) => String(t),
  getElementById: (id) => {
    if (!byId.has(id)) byId.set(id, makeNode("div"));
    return byId.get(id);
  },
  querySelectorAll: () => [],
  querySelector: () => makeNode("div"),
};
const location = { href: "http://example.invalid/", hash: "" };
const history = { replaceState() {} };
// The Sheet is mocked unavailable: any network fetch throws.
const context = vm.createContext({
  localStorage, document, location, history, window: {}, URL,
  fetch: async () => { throw new Error("sheet unavailable"); }, console,
});

const stripped = source.replace(/\nmain\(\);\s*$/, "");
assert(stripped !== source, "main() auto-run stripped for vm load");
vm.runInContext(stripped, context, { filename: "app.js" });

const t = vm.runInContext(`({
  state, selectedCharacter, selectCharacter, renderSheet, renderBio,
  renderProfessions, buildOwned, ownedNote, killLog, partChecked,
  biographyFor, biographyEvents, renderBiography,
})`, context);

const rosterDoc = JSON.parse(readFileSync(path.join(repo, "data", "characters.json"), "utf8"));
const zephinis = rosterDoc.find((c) => c.id === "zephinis");
assert(zephinis && zephinis.name === "Zephinis Starhollow", "zephinis launch character on the roster");

// Butler-style entry for a launch character: text-export shape with honest
// gaps (no itemCounts/crafts IDs, no Areas explored row, Titles unknown).
const butlerEntry = {
  character: "Zephinis Starhollow",
  exportedAt: "2026-11-05T01:00:00",
  addon: "Dossier",
  level: 5,
  zone: "Dun Morogh",
  subzone: "Coldridge Valley",
  goldCopper: 1250,
  health: 120,
  powerType: "Mana",
  power: 60,
  playedSeconds: 900,
  stats: { Strength: 10, Stamina: 12 },
  professions: [{ name: "Mining", current: 10, max: 75 }],
  gear: [{ slot: "Main Hand", name: "Worn Axe", itemLevel: 5, quality: "Common" }],
  owned: ["Prairie Chicken"],
  looted: [],
  huntKills: { Hogger: 3 },
  itemCounts: {},
  crafts: {},
  collections: { Mounts: 0, Pets: 0, Toys: 0, Titles: null, Achievements: 1 },
  statistics: {
    Kills: [{ name: "Total kills", value: "11" }],
    Character: [
      { name: "Deaths", value: "1" },
      { name: "Quests completed", value: "4" }
    ]
  },
  sources: { Dossier: "2026-11-05T01:00:00" }
};

function seedLaunch() {
  t.state.characters = [zephinis];
  t.state.selected = "zephinis";
  t.state.checklist = [
    { id: "h-pet", type: "collection", name: "Prairie Chicken" },
    { id: "h-hogger", type: "gear", name: "Hogger's Shank", mobs: ["Hogger"] }
  ];
  t.state.stats = { updated: "2026-11-05", characters: { zephinis: butlerEntry } };
  t.state.screenshots = [];
  t.state.ledger = {};
  t.state.checks = {};
  t.state.attempts = {};
  t.state.backstories = {};
  t.state.tallies = {};
  t.state.guides = [];
  t.state.biography = {};
  vm.runInContext("buildOwned();", context);
}

// 1. Bio/stats surfaces render from the stats.json entry (launch character).
seedLaunch();
vm.runInContext("renderSheet();", context);
const sheetText = textOf(byId.get("sheet"));
assert(sheetText.includes("Zephinis Starhollow"), "sheet renders the launch character name");
assert(sheetText.includes("5") && sheetText.includes("Dun Morogh"), "sheet renders level and zone from stats.json");
assert(sheetText.includes("12s"), "sheet renders gold from stats.json goldCopper");
assert(sheetText.includes("Mining 10/75"), "sheet renders profession ranks from stats.json");
assert(sheetText.includes("Total kills") && sheetText.includes("11"), "statistics group renders from stats.json");
assert(sheetText.includes("Quests completed") && sheetText.includes("4"), "character statistics render");
assert(!sheetText.includes("NaN") && !sheetText.includes("undefined"),
  "sheet shows no NaN/undefined for the Butler entry");

// Hunt checks derive from owned / looted / huntKills against checklist.json.
assert(t.ownedNote({ name: "Prairie Chicken" }) === "Owned by Zephinis",
  "owned entry drives the matching checklist row");
const hogger = t.killLog(["Hogger"]);
assert(hogger.total === 3 && hogger.text.includes("Zephinis"),
  "huntKills drive the kill log for the matching mob hunt");
assert(t.partChecked({ type: "collection", name: "Prairie Chicken" }, { name: "Prairie Chicken" }) === true,
  "collection part with an owned match checks itself");

// 2. Absent data renders as absent, never as fabricated zeros.
assert(sheetText.includes("Titles"), "collections Titles row still renders");
assert(!/Titles\s*0/.test(sheetText), "null Titles never renders as 0");
assert(sheetText.includes("—"), "absent values render as an em dash");
assert(!sheetText.includes("Areas explored"), "missing Areas explored row stays missing");
const titlesDash = sheetText.includes("Titles—");
assert(titlesDash, "null Titles renders as Titles + em dash");

// Empty crafts/itemCounts: professions view stays honest, never throws.
t.state.professions = { version: "v1", professions: { Mining: [] } };
vm.runInContext("renderProfessions();", context);
const profText = textOf(byId.get("prof-list"));
assert(profText.includes("None known yet"), "empty crafts render the honest empty line");
assert(!profText.includes("NaN") && !profText.includes("undefined"),
  "professions view shows no NaN/undefined for empty itemCounts/crafts");

// 3. The kept beta trio still renders after the flip, content untouched.
const statsDoc = JSON.parse(readFileSync(path.join(repo, "data", "stats.json"), "utf8"));
const betaIds = ["flann", "ullrathor", "trendirun"];
assert(betaIds.every((id) => statsDoc.characters[id]), "beta trio entries present in stats.json");
for (const id of betaIds) {
  const entry = statsDoc.characters[id];
  assert(entry.collections && entry.statistics, `${id} entry keeps collections and statistics`);
}
t.state.characters = betaIds.map((id) => ({
  id, name: { flann: "Flann Anvilhew", ullrathor: "Ullrathor Highgale", trendirun: "Trendirun ebook" }[id],
  race: "Test", className: "Druid", spec: "Test", professions: [], roles: [],
  blurb: "Beta archive.", talentNote: "Beta archive.", talentLinks: []
}));
t.state.stats = statsDoc;
vm.runInContext("buildOwned();", context);
for (const id of betaIds) {
  t.state.selected = id;
  vm.runInContext("renderSheet();", context);
  const betaText = textOf(byId.get("sheet"));
  const entry = statsDoc.characters[id];
  assert(betaText.includes(String(entry.level)), `${id} renders its kept level ${entry.level}`);
  assert(betaText.includes("Areas explored"), `${id} renders its Areas explored row`);
  assert(!betaText.includes("NaN") && !betaText.includes("undefined"), `${id} renders without NaN/undefined`);
}

// 4. Biography read path: ticket-shaped file renders newest-first on Bio.
const bioDoc = {
  character: "Thorin Caskmend",
  updated: "2026-11-05T01:56:00",
  count: 3,
  events: [
    { t: 1790000000, at: "2026-11-04T19:07:00", kind: "level", text: "Reached level 2 in Dun Morogh", level: 2 },
    { t: 1790000100, at: "2026-11-04T19:14:00", kind: "quest", text: "Turned in Dwarven Outfitters", questID: 311 },
    { t: 1790000200, at: "2026-11-04T19:20:00", kind: "screenshot", text: "Screenshot taken", reason: "Reached level 2" }
  ]
};
const thorin = rosterDoc.find((c) => c.id === "thorin");
t.state.characters = [thorin, zephinis];
t.state.selected = "thorin";
t.state.backstories = {};
t.state.biography = { thorin: bioDoc };
t.state.stats = { updated: null, characters: {} };
vm.runInContext("renderBio();", context);
const bioText = textOf(byId.get("roster"));
assert(bioText.includes("Biography"), "bio renders the timeline heading when a file is present");
assert(bioText.includes("2026-11-05"), "bio renders the file updated date");
const questAt = bioText.indexOf("Turned in Dwarven Outfitters");
const levelAt = bioText.indexOf("Reached level 2 in Dun Morogh");
assert(questAt !== -1 && levelAt !== -1 && questAt < levelAt,
  "biography events render newest-first");
assert(bioText.includes("Reached level 2"), "screenshot reason renders with its event");
assert(bioText.includes("No backstory yet."), "timeline renders alongside the honest no-backstory line");
t.state.selected = "zephinis";
vm.runInContext("renderBio();", context);
assert(!textOf(byId.get("roster")).includes("Biography"),
  "no timeline and no error when the biography file is absent");

if (failures) {
  console.error(`FAIL test-pipeline-flip (${failures} assertions)`);
  process.exit(1);
}
console.log("PASS test-pipeline-flip");
