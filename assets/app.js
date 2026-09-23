const CLASS_COLOR = {
  Druid: "var(--druid)",
  Hunter: "var(--hunter)",
  Mage: "var(--mage)",
  Priest: "var(--priest)",
  Warlock: "var(--warlock)",
  Shaman: "var(--shaman)"
};

const STAT_KEYS = [
  "Strength", "Agility", "Stamina", "Intellect", "Spirit",
  "Armor", "Attack Power", "Spell Power", "Melee Crit", "Spell Crit", "Hit"
];

const STORE_KEY = "wow-forever-command-center-v1";

const state = {
  house: null,
  characters: [],
  checklist: [],
  stats: { updated: null, characters: {} },
  selected: "skyrinis",
  scope: "character",
  query: "",
  type: "",
  checks: {}
};

function loadStore() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORE_KEY) || "{}");
    if (saved.selected) state.selected = saved.selected;
    if (saved.checks) state.checks = saved.checks;
    if (saved.scope) state.scope = saved.scope;
  } catch {
    state.checks = {};
  }
}

function saveStore() {
  localStorage.setItem(STORE_KEY, JSON.stringify({
    selected: state.selected,
    scope: state.scope,
    checks: state.checks
  }));
}

function isChecked(item) {
  if (Object.prototype.hasOwnProperty.call(state.checks, item.id)) return state.checks[item.id];
  return !!item.defaultDone;
}

function selectedCharacter() {
  return state.characters.find((c) => c.id === state.selected) || state.characters[0];
}

function matchesCharacter(item, character) {
  const owners = item.owners || [];
  if (owners.includes("horde")) return false;
  if (owners.includes("all") || owners.includes("alliance")) return true;
  if (owners.includes(character.id)) return true;
  return owners.some((role) => (character.roles || []).includes(role));
}

function visibleItems() {
  const character = selectedCharacter();
  const q = state.query.trim().toLowerCase();
  return state.checklist.filter((item) => {
    if (state.scope === "character" && !matchesCharacter(item, character)) return false;
    if (state.type && item.type !== state.type) return false;
    if (!q) return true;
    const hay = `${item.name} ${item.zone} ${item.notes} ${item.type}`.toLowerCase();
    return hay.includes(q);
  });
}

function dash(value) {
  if (value === null || value === undefined || value === "") return "—";
  return String(value);
}

function formatGold(copper) {
  if (copper === null || copper === undefined || copper === "") return "—";
  const n = Number(copper);
  if (!Number.isFinite(n)) return "—";
  const gold = Math.floor(n / 10000);
  const silver = Math.floor((n % 10000) / 100);
  const left = n % 100;
  return `${gold}g ${silver}s ${left}c`;
}

function formatPlayed(seconds) {
  if (!seconds && seconds !== 0) return "—";
  const n = Number(seconds);
  if (!Number.isFinite(n)) return "—";
  const hours = Math.floor(n / 3600);
  const minutes = Math.floor((n % 3600) / 60);
  return `${hours}h ${minutes}m`;
}

function el(tag, attrs, children) {
  const node = document.createElement(tag);
  Object.entries(attrs || {}).forEach(([key, value]) => {
    if (key === "class") node.className = value;
    else if (key === "text") node.textContent = value;
    else if (key.startsWith("on") && typeof value === "function") node.addEventListener(key.slice(2), value);
    else if (value !== null && value !== undefined) node.setAttribute(key, value);
  });
  (children || []).forEach((child) => {
    if (child) node.append(child);
  });
  return node;
}

function renderHouse() {
  const house = state.house;
  document.getElementById("lede").textContent =
    `${house.player} · ${house.faction} · ${house.ruleset} · ${house.edition}`;
  const chips = document.getElementById("chips");
  chips.replaceChildren();
  [
    `Beta ${house.beta} · cap ${house.betaCap}`,
    `Names ${house.nameReservation}`,
    `Launch ${house.launch}`,
    `Raids ${house.raids}`
  ].forEach((text) => chips.append(el("span", { class: "chip", text })));
  const rules = document.getElementById("rules");
  rules.replaceChildren();
  house.rules.forEach((rule) => rules.append(el("li", { text: rule })));
}

function renderRoster() {
  const roster = document.getElementById("roster");
  roster.replaceChildren();
  state.characters.forEach((character) => {
    const button = el("button", {
      class: "char",
      type: "button",
      "aria-pressed": character.id === state.selected ? "true" : "false",
      onclick: () => selectCharacter(character.id)
    });
    const who = el("div", { class: "who" });
    who.append(el("span", { class: "dot", style: `background:${CLASS_COLOR[character.className] || "var(--gold)"}` }));
    who.append(document.createTextNode(character.name));
    button.append(who);
    button.append(el("small", { text: `${character.race} · ${character.className} · ${character.spec}` }));
    roster.append(button);
  });
}

function statBox(label, value) {
  return el("div", { class: "stat" }, [
    el("span", { text: label }),
    el("b", { text: dash(value) })
  ]);
}

function renderSheet() {
  const character = selectedCharacter();
  const live = (state.stats.characters || {})[character.id] || {};
  const sheet = document.getElementById("sheet");
  const identity = el("article", { class: "card" });
  identity.append(el("h3", { text: character.name }));
  identity.append(el("p", { class: "meta", text: `${character.race} · ${character.className} · ${character.spec}` }));
  if (!character.betaSafe) {
    identity.append(el("p", { class: "warn", text: "Reserved name. Do not use this character in beta." }));
  }
  identity.append(el("p", { text: character.blurb }));
  const profs = el("div", { class: "profs" });
  const skills = new Map((live.professions || []).map((p) => [p.name, p]));
  character.professions.forEach((name) => {
    const skill = skills.get(name);
    const label = skill ? `${name} ${skill.current}/${skill.max}` : name;
    profs.append(el("span", { text: label }));
  });
  identity.append(profs);
  identity.append(el("p", { class: "meta", text: character.talentNote }));
  if (character.talentUrl) {
    identity.append(el("a", { href: character.talentUrl, target: "_blank", rel: "noreferrer", text: "Open the saved talent tree" }));
  }
  if (character.pairsWith) {
    identity.append(el("p", { text: `Pairs with ${character.pairsWith}.` }));
  }

  const stats = el("article", { class: "card" });
  stats.append(el("h3", { text: "Stats" }));
  const updated = state.stats.updated
    ? `Export merged ${state.stats.updated}.`
    : "No addon export merged yet. Level, gear, and gold show up here after the next dump.";
  stats.append(el("p", { class: "empty-note", text: updated }));
  const grid = el("div", { class: "stat-grid" });
  [
    ["Level", live.level],
    ["Zone", [live.zone, live.subzone].filter(Boolean).join(" · ")],
    ["Health", live.health],
    [live.powerType || "Power", live.power],
    ["Gold", live.goldCopper === undefined ? null : formatGold(live.goldCopper)],
    ["Played", live.playedSeconds === undefined ? null : formatPlayed(live.playedSeconds)]
  ].forEach(([label, value]) => grid.append(statBox(label, value)));
  const extra = live.stats || {};
  STAT_KEYS.forEach((key) => grid.append(statBox(key, extra[key])));
  stats.append(grid);

  if (Array.isArray(live.gear) && live.gear.length) {
    const table = el("table", { class: "gear" });
    const head = el("tr");
    ["Slot", "Item", "ilvl"].forEach((label) => head.append(el("th", { text: label })));
    table.append(el("thead", {}, [head]));
    const body = el("tbody");
    live.gear.forEach((piece) => {
      const row = el("tr");
      row.append(el("td", { text: dash(piece.slot) }));
      row.append(el("td", { text: dash(piece.name) }));
      row.append(el("td", { text: dash(piece.itemLevel) }));
      body.append(row);
    });
    table.append(body);
    stats.append(table);
  }

  sheet.replaceChildren(identity, stats);
}

function badgeClass(item) {
  if (item.status === "Parked") return "badge parked";
  if (item.priority === "Medium") return "badge medium";
  if (item.priority === "Low") return "badge low";
  return "badge";
}

function renderChecklist() {
  const items = visibleItems();
  const done = items.filter(isChecked).length;
  document.getElementById("check-count").textContent = `${done} of ${items.length} checked`;
  const bar = document.getElementById("progress-bar");
  bar.style.width = items.length ? `${Math.round((done / items.length) * 100)}%` : "0";

  const list = document.getElementById("checklist");
  list.replaceChildren();
  if (!items.length) {
    list.append(el("p", { class: "empty-note", text: "Nothing on this filter." }));
    return;
  }

  const groups = [
    ["For this character", (item) => (item.owners || []).includes(selectedCharacter().id) || (item.owners || []).some((role) => (selectedCharacter().roles || []).includes(role))],
    ["Shared hunts", (item) => !((item.owners || []).includes(selectedCharacter().id) || (item.owners || []).some((role) => (selectedCharacter().roles || []).includes(role))) && item.source !== "Pack"],
    ["Already in the pack", (item) => item.source === "Pack"]
  ];

  const buckets = state.scope === "character"
    ? groups.map(([label, test]) => [label, items.filter(test)]).filter(([, rows]) => rows.length)
    : [["Whole house", items]];

  buckets.forEach(([label, rows]) => {
    list.append(el("div", { class: "group-label", text: label }));
    rows.forEach((item) => {
      const checked = isChecked(item);
      const box = el("input", { type: "checkbox", id: `check-${item.id}` });
      box.checked = checked;
      box.addEventListener("change", () => {
        state.checks[item.id] = box.checked;
        saveStore();
        renderChecklist();
      });
      const copy = el("div");
      copy.append(el("strong", { text: item.name }));
      copy.append(el("div", { class: "sub", text: `${item.type} · ${item.zone} · level ${item.minLevel}+ · ${item.notes}` }));
      const row = el("label", { class: `check${checked ? " done" : ""}${item.status === "Parked" ? " parked" : ""}` }, [
        box,
        copy,
        el("span", { class: badgeClass(item), text: item.status === "Parked" ? "Parked" : item.priority })
      ]);
      list.append(row);
    });
  });
}

function fillTypes() {
  const select = document.getElementById("type-filter");
  const types = [...new Set(state.checklist.map((item) => item.type))].sort();
  types.forEach((type) => select.append(el("option", { value: type, text: type })));
}

function selectCharacter(id) {
  state.selected = id;
  saveStore();
  const url = new URL(location.href);
  url.searchParams.set("c", id);
  history.replaceState(null, "", url);
  renderRoster();
  renderSheet();
  renderChecklist();
}

function exportChecks() {
  const blob = new Blob([JSON.stringify({
    exportedAt: new Date().toISOString(),
    selected: state.selected,
    checks: state.checks
  }, null, 2)], { type: "application/json" });
  const link = el("a", { href: URL.createObjectURL(blob), download: "forever-checklist.json" });
  link.click();
  URL.revokeObjectURL(link.href);
}

function importChecks(file) {
  const reader = new FileReader();
  reader.onload = () => {
    try {
      const data = JSON.parse(String(reader.result));
      if (!data.checks || typeof data.checks !== "object") throw new Error("missing checks");
      state.checks = data.checks;
      if (data.selected) state.selected = data.selected;
      saveStore();
      render();
    } catch {
      window.alert("That file is not a checklist export.");
    }
  };
  reader.readAsText(file);
}

function render() {
  renderHouse();
  renderRoster();
  renderSheet();
  renderChecklist();
}

async function loadJson(path) {
  const response = await fetch(path);
  if (!response.ok) throw new Error(`${path} ${response.status}`);
  return response.json();
}

async function main() {
  loadStore();
  const params = new URLSearchParams(location.search);
  if (params.get("c")) state.selected = params.get("c");
  try {
    const [house, characters, checklist, stats] = await Promise.all([
      loadJson("data/house.json"),
      loadJson("data/characters.json"),
      loadJson("data/checklist.json"),
      loadJson("data/stats.json")
    ]);
    state.house = house;
    state.characters = characters;
    state.checklist = checklist;
    state.stats = stats;
  } catch (error) {
    document.getElementById("lede").textContent = "The tracker data did not load. Open the GitHub Pages site, or serve this folder over http.";
    console.error(error);
    return;
  }
  if (!state.characters.some((c) => c.id === state.selected)) state.selected = state.characters[0].id;
  document.getElementById("scope").value = state.scope;
  fillTypes();
  document.getElementById("search").addEventListener("input", (event) => {
    state.query = event.target.value;
    renderChecklist();
  });
  document.getElementById("type-filter").addEventListener("change", (event) => {
    state.type = event.target.value;
    renderChecklist();
  });
  document.getElementById("scope").addEventListener("change", (event) => {
    state.scope = event.target.value;
    saveStore();
    renderChecklist();
  });
  document.getElementById("export-checks").addEventListener("click", exportChecks);
  document.getElementById("import-checks").addEventListener("change", (event) => {
    const file = event.target.files && event.target.files[0];
    if (file) importChecks(file);
    event.target.value = "";
  });
  render();
}

main();
