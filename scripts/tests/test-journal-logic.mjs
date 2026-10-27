// Backstories + Journal file validation and logic (board: backstories-journal).
// Run: node scripts/tests/test-journal-logic.mjs
// Validates the committed data files, then exercises journal filtering/sorting
// in a vm with synthetic fixture entries only. Fixture text lives under gitignored
// data/private/fixtures/ and never leaves scripts/tests/ + fixtures.

import { readFileSync, existsSync, readdirSync } from "node:fs";
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

const roster = JSON.parse(readFileSync(path.join(repo, "data", "characters.json"), "utf8"));
const rosterIds = roster.map((c) => c.id);
assert(rosterIds.length > 0, "roster has character ids to validate against");

// Committed backstories seed: parses, keys are roster ids, paragraphs are
// arrays of strings. Ships empty; text arrives via data-only commits.
const backstoriesDoc = JSON.parse(readFileSync(path.join(repo, "data", "backstories.json"), "utf8"));
assert(backstoriesDoc.schemaVersion === 1, "backstories.json schemaVersion is 1");
assert(backstoriesDoc.backstories && typeof backstoriesDoc.backstories === "object", "backstories.json carries a backstories map");
for (const [id, entry] of Object.entries(backstoriesDoc.backstories)) {
  assert(rosterIds.includes(id), `backstory key ${id} is a roster id`);
  assert(typeof entry.title === "string" && entry.title.length > 0, `backstory ${id} has a title`);
  assert(Array.isArray(entry.paragraphs) && entry.paragraphs.every((p) => typeof p === "string"), `backstory ${id} paragraphs is an array of strings`);
  assert(entry.facts && typeof entry.facts === "object" && !Array.isArray(entry.facts), `backstory ${id} facts is an object`);
}
assert(Object.keys(backstoriesDoc.backstories).sort().join(",") === "malavus,skyrinis,sorinis,thorin",
  "backstories.json carries the four approved entries (malavus, skyrinis, sorinis, thorin)");

// Committed journals seed: shape plus character ids in roster. Ships empty.
const journalsDoc = JSON.parse(readFileSync(path.join(repo, "data", "journals.json"), "utf8"));
assert(journalsDoc.schemaVersion === 1, "journals.json schemaVersion is 1");
assert(Array.isArray(journalsDoc.entries), "journals.json carries an entries array");
for (const entry of journalsDoc.entries) {
  assert(typeof entry.id === "string" && entry.id.length > 0, "journal entry has an id");
  assert(rosterIds.includes(entry.character), `journal entry ${entry.id} names a roster character`);
  assert(typeof entry.date === "string" && /^\d{4}-\d{2}-\d{2}/.test(entry.date), `journal entry ${entry.id} carries an ISO date`);
  assert(typeof entry.title === "string" && entry.title.length > 0, `journal entry ${entry.id} has a title`);
  assert(Array.isArray(entry.body) && entry.body.every((p) => typeof p === "string"), `journal entry ${entry.id} body is an array of strings`);
  assert(Array.isArray(entry.facts) && entry.facts.every((f) => typeof f === "string"), `journal entry ${entry.id} facts is an array of strings`);
  assert(typeof entry.source === "string", `journal entry ${entry.id} names a source`);
}
assert(journalsDoc.entries.length === 0, "journals.json seed stays empty (entries publish via data-only commits)");

// Fixture entries: obviously fake, gitignored, fixture character only.
const fixtureDir = path.join(repo, "data", "private", "fixtures");
for (const f of ["journals.fixture.json", "backstories.fixture.json"]) {
  assert(existsSync(path.join(fixtureDir, f)), `gitignored fixture present: ${f}`);
}
const fixtureJournals = JSON.parse(readFileSync(path.join(fixtureDir, "journals.fixture.json"), "utf8"));
const fixtureBackstories = JSON.parse(readFileSync(path.join(fixtureDir, "backstories.fixture.json"), "utf8"));
assert(fixtureJournals.entries.length === 4, "fixture journals carry 4 entries (3 fixture + 1 scoping probe)");

// Fixture text must never leak into committed files. scripts/tests/ is the
// only committed tree where fixture names may appear.
const committedFiles = ["index.html", "assets/app.js", "assets/site.css", "data/backstories.json", "data/journals.json", "scripts/butler-pack.ps1", "docs/canonical-json.md", "AGENTS.md"];
for (const f of readdirSync(path.join(repo, "data"))) {
  if (f.endsWith(".json")) committedFiles.push(`data/${f}`);
}
const committedHay = committedFiles
  .map((f) => { try { return readFileSync(path.join(repo, f), "utf8"); } catch { return ""; } })
  .join("\n");
assert(!committedHay.includes("fixturin") && !committedHay.includes("Fixturin"), "no fixture character in committed files (scripts/tests/ excluded)");

// vm harness with fake DOM (same shape as test-site-ux.mjs).
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

const source = readFileSync(path.join(repo, "assets", "app.js"), "utf8");
const stripped = source.replace(/\nmain\(\);\s*$/, "");
assert(stripped !== source, "main() auto-run stripped for vm load");

function makeStore(seed) {
  const data = { ...(seed || {}) };
  return {
    getItem: (key) => (key in data ? data[key] : null),
    setItem: (key, value) => { data[key] = String(value); },
    removeItem: (key) => { delete data[key]; },
    data,
  };
}
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
const localStorage = makeStore();
const location = { href: "http://example.invalid/", hash: "" };
const history = { replaceState() {} };
const context = vm.createContext({ localStorage, document, location, history, URL, fetch: async () => { throw new Error("no fetch in test"); }, console });
vm.runInContext(stripped, context, { filename: "app.js" });

const jx = vm.runInContext(`({
  state, journalFor, journalAll, renderJournal, setJournalView,
})`, context);

jx.state.characters = [
  { id: "fixturin", name: "Fixturin Testmend", race: "Night Elf", className: "Druid", spec: "Test", professions: [], roles: [] },
];
jx.state.selected = "fixturin";
jx.state.backstories = fixtureBackstories.backstories;
jx.state.journals = fixtureJournals.entries;
jx.state.journalView = "picked";

// Journal filtering: picked view sees only its own entries, newest first.
const mine = jx.journalFor("fixturin");
assert(mine.map((e) => e.id).join(",") === "j-fixture-3,j-fixture-2,j-fixture-1",
  "picked journal sorts newest-first by ISO date");
assert(jx.journalFor("sorinis").map((e) => e.id).join(",") === "j-fixture-x",
  "other roster id resolves only its own entry");
assert(jx.journalAll().map((e) => e.id).join(",") === "j-fixture-x,j-fixture-3,j-fixture-2,j-fixture-1",
  "all-characters view interleaves every entry newest-first");

// Journal rendering, picked view: own entries only, honest empty state.
vm.runInContext("renderJournal();", context);
const pickedText = textOf(byId.get("journal-list"));
assert(pickedText.includes("Third fixture session") && pickedText.includes("First fixture session"),
  "picked view lists the selected character entries");
assert(!pickedText.includes("Other character fixture session"), "picked view excludes other characters");
assert(pickedText.includes("Session record: Newest fact"), "entry card carries a Session record footer");
assert(textOf(byId.get("journal-note")).includes("Fixturin Testmend"), "picked note names the selected character");

// Journal rendering, empty: honest line, no invented content.
jx.state.journals = [];
vm.runInContext("renderJournal();", context);
assert(textOf(byId.get("journal-list")).includes("No journal entries yet."), "empty journal shows the honest line");
jx.state.journals = fixtureJournals.entries;

// Journal rendering, all view: interleaved with the character named.
jx.setJournalView("all");
const allText = textOf(byId.get("journal-list"));
assert(allText.includes("Other character fixture session") && allText.includes("Third fixture session"),
  "all view interleaves every character");
assert(allText.includes("Fixturin Testmend"), "all view names the character on fixture cards");
assert(jx.state.journalView === "all", "toggle flips the journal view");
assert(JSON.parse(localStorage.getItem("wow-forever-command-center-v1")).journalView === "all",
  "toggle persists through the saved-state mechanism");
jx.setJournalView("picked");

if (failures) {
  console.error(`FAIL test-journal-logic (${failures} assertions)`);
  process.exit(1);
}
console.log("PASS test-journal-logic");
