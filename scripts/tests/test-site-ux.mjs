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
  TABS, state, selectCharacter, selectedCharacter, showTab, render, renderAltoholic,
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
assert(ux.TABS.join(",") === "roster,hunts,journey,mail,altoholic,professions,lockouts,tasks,dungeons,quests,macros",
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

// Roster cards keep working and sync the header picker.
seedRoster();
vm.runInContext("selectCharacter('sorinis');", context);
assert(byId.get("character-picker").value === "sorinis", "roster-card selection updates the header picker");

// No-scan altoholic with an empty roster explains itself without a picker.
ux.state.characters = [];
vm.runInContext("renderAltoholic();", context);
assert(textOf(byId.get("alto-note")).length > 0, "altoholic no-roster state shows its explanatory note");

if (failures) {
  console.error(`FAIL test-site-ux (${failures} assertions)`);
  process.exit(1);
}
console.log("PASS test-site-ux");
