// Site UX pass: global character picker, no House tab, no per-tab pickers.
// Run: node scripts/tests/test-site-ux.mjs
// Static asserts on index.html plus vm asserts against assets/app.js with a
// fake DOM and synthetic fixtures only.

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

// Static markup: one header picker above the tab bar; house and per-tab
// pickers gone.
const html = readFileSync(path.join(repo, "index.html"), "utf8");
assert(html.includes('id="character-picker"'), "header carries the global character picker");
assert(html.indexOf("<header") < html.indexOf('id="character-picker"')
  && html.indexOf('id="character-picker"') < html.indexOf('<nav class="tabs"'),
  "picker sits in the header above the tab bar");
assert(html.includes('id="tab-journal"') && html.includes('id="panel-journal"') && html.includes('id="journal-list"'),
  "journal tab button, panel, and list in markup");
assert(/data-tab="roster"[^>]*>Bio</.test(html), "first tab label reads Bio");
assert(!html.includes("tab-house") && !html.includes("panel-house") && !html.includes('data-tab="house"'),
  "no house tab button or panel in markup");
for (const id of ["prof-character", "quest-character", "macro-character", "alto-character"]) {
  assert(!html.includes(`id="${id}"`), `per-tab select ${id} removed from markup`);
}

// vm harness with fake DOM.
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
const requestedIds = [];
const byId = new Map();
const document = {
  createElement: (tag) => makeNode(tag),
  createTextNode: (t) => String(t),
  getElementById: (id) => {
    requestedIds.push(id);
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

const ux = vm.runInContext(`({
  TABS, state, selectCharacter, selectedCharacter, showTab, render, renderAltoholic, loadStore, renderBio,
})`, context);

function seedRoster() {
  ux.state.characters = [
    { id: "fixturin", name: "Fixturin Testmend", race: "Night Elf", className: "Druid", spec: "Test", professions: [], roles: [] },
    { id: "sorinis", name: "Sorinis Testmend", race: "Night Elf", className: "Druid", spec: "Test", professions: [], roles: [] },
  ];
  ux.state.selected = "fixturin";
  ux.state.checklist = [];
  ux.state.macros = [
    { id: "m-shared", name: "Shared Fixture", scope: "shared", lines: [] },
    { id: "m-sorinis", name: "Sorinis Fixture", scope: "character", character: "sorinis", lines: [] },
  ];
  ux.state.publicChars = { characters: [{ name: "Fixturin Testmend", professions: [{ name: "Mining", current: 10, max: 75 }] }] };
  vm.runInContext("attCache = null;", context);
}

// Tab list: house gone, order kept.
assert(!ux.TABS.includes("house"), "TABS drops house");
assert(ux.TABS.join(",") === "roster,hunts,journey,journal,mail,altoholic,professions,lockouts,tasks,dungeons,quests,macros",
  "remaining tabs keep their relative order");

// Tab bar invariant (tab-grid-fix): the desktop .tabs grid must fit every
// tab button in one row without hard-coding the tab count, so adding a tab
// can never silently re-wrap the bar the way repeat(10, ...) did at 11 tabs.
const css = readFileSync(path.join(repo, "assets", "site.css"), "utf8");
const firstMedia = css.indexOf("@media");
const desktopCss = firstMedia === -1 ? css : css.slice(0, firstMedia);
const desktopTabs = desktopCss.match(/\.tabs\s*\{([^}]*)\}/);
assert(desktopTabs, "desktop .tabs rule found outside media queries");
assert(!/repeat\s*\(\s*\d+/.test(desktopTabs[1]),
  "desktop .tabs grid does not hard-code a column count");
assert(/auto-fit|auto-fill/.test(desktopTabs[1]),
  "desktop .tabs grid fits every tab in one row regardless of count");
const tabButtons = html.match(/<button[^>]*class="tab"[^>]*>/g) || [];
assert(tabButtons.length > 0 && tabButtons.length === ux.TABS.length,
  `tab button count in markup (${tabButtons.length}) matches TABS (${ux.TABS.length})`);

// A stale #house hash falls back to roster.
seedRoster();
ux.showTab("house");
assert(ux.state.tab === "roster", "unknown house hash falls back to roster");

// Header picker change re-renders a character-scoped view for the new character.
seedRoster();
vm.runInContext("render();", context);
assert(source.includes('getElementById("character-picker").addEventListener("change"'),
  "main wires the header picker to selectCharacter");
byId.get("character-picker").addEventListener("change", (event) => ux.selectCharacter(event.target.value));
const picker = byId.get("character-picker");
assert(picker && picker.children.length === 2, "header picker lists the roster characters");
assert(picker.value === "fixturin", "header picker reflects the selected character");
picker.handlers.change({ target: { value: "sorinis" } });
assert(ux.state.selected === "sorinis", "picker change updates the selection");
assert(JSON.parse(localStorage.getItem("wow-forever-command-center-v1")).selected === "sorinis",
  "picker change persists through the saved-state mechanism");
const macroText = textOf(byId.get("macro-list"));
assert(macroText.includes("Sorinis Fixture") && macroText.includes("Shared Fixture"),
  "macros re-render for the newly selected character");
assert(textOf(byId.get("character-picker")) === "" || byId.get("character-picker").value === "sorinis",
  "header picker stays on the new character after re-render");

// Altoholic follows the global selection; never a blank picker.
seedRoster();
ux.state.selected = "sorinis";
vm.runInContext("renderAltoholic();", context);
assert(textOf(byId.get("alto-note")).includes("No scan saved for Sorinis Testmend yet."),
  "altoholic reports the selected character with no scan");
assert(!requestedIds.includes("alto-character"), "altoholic never touches a character picker");
ux.state.selected = "fixturin";
vm.runInContext("renderAltoholic();", context);
assert(textOf(byId.get("alto-note")).includes("Canonical scan for Fixturin Testmend."),
  "altoholic lights up for the scanned selection");

// Selection syncs the header picker (Bio has no per-card controls).
seedRoster();
vm.runInContext("selectCharacter('sorinis');", context);
assert(byId.get("character-picker").value === "sorinis", "selection updates the header picker");

// No-scan altoholic with an empty roster explains itself without a picker.
ux.state.characters = [];
vm.runInContext("renderAltoholic();", context);
assert(textOf(byId.get("alto-note")).length > 0, "altoholic no-roster state shows its explanatory note");

// Bio view: single selected character, populated and empty backstory states.
seedRoster();
const fixtureStories = JSON.parse(readFileSync(path.join(repo, "data", "private", "fixtures", "backstories.fixture.json"), "utf8")).backstories; ux.state.backstories = fixtureStories;
ux.state.guides = [{ id: "g-fixture", title: "Fixture Guide", url: "https://example.invalid/fixture", appliesTo: ["fixturin"] }];
ux.state.selected = "fixturin";
vm.runInContext("renderBio();", context);
const bioText = textOf(byId.get("roster"));
assert(bioText.includes("Fixturin Testmend"), "bio shows the selected character name");
assert(bioText.includes("Night Elf"), "bio shows the race line from roster data");
assert(bioText.includes("The Unwritten"), "bio shows the backstory title as section heading");
assert(bioText.includes("practice sword"), "bio renders backstory prose, not an expander");
assert(bioText.includes("Fixture Guide"), "bio carries the guides line");
assert(!bioText.includes("No backstory yet."), "populated bio shows no empty line");
assert(byId.get("roster").children.every((c) => c.tag !== "details" && c.className !== "char-card"),
  "bio carries no expander or card markup");
ux.state.selected = "sorinis";
vm.runInContext("renderBio();", context);
const emptyBio = textOf(byId.get("roster"));
assert(emptyBio.includes("No backstory yet."), "unwritten character shows the honest line");
assert(emptyBio.includes("Sorinis Testmend"), "empty bio still renders the character header");
assert(!emptyBio.includes("Fixture Guide"), "guides line follows appliesTo mapping");

// Portrait slot: path present renders an <img>; absent renders the monogram.
ux.state.backstories = { fixturin: { ...fixtureStories.fixturin, portrait: "assets/portraits/fixturin.jpg" } };
ux.state.selected = "fixturin";
vm.runInContext("renderBio();", context);
const frame = byId.get("roster").children[0].children[0];
assert(frame.className === "portrait", "portrait renders in a frame");
assert(frame.children[0].tag === "img" && frame.children[0].getAttribute("src") === "assets/portraits/fixturin.jpg",
  "portrait path renders an <img> with that src");
ux.state.backstories = fixtureStories;
vm.runInContext("renderBio();", context);
const mono = byId.get("roster").children[0].children[0].children[0];
assert(mono.className === "portrait-mono" && textOf(mono) === "FT",
  "absent portrait renders the monogram placeholder with initials");

// A saved pre-Bio tab value still loads (tab ids unchanged, label only).
localStorage.setItem("wow-forever-command-center-v1", JSON.stringify({ selected: "sorinis", scope: "character", tab: "roster" }));
vm.runInContext("loadStore();", context);
assert(ux.state.tab === "roster", "saved pre-Bio tab value still loads");
assert(ux.state.selected === "sorinis", "saved selection survives loadStore");


if (failures) {
  console.error(`FAIL test-site-ux (${failures} assertions)`);
  process.exit(1);
}
console.log("PASS test-site-ux");
