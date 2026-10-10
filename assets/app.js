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

const TABS = ["roster", "hunts", "mail", "altoholic", "professions", "lockouts", "tasks", "dungeons", "quests", "macros", "house"];

const HUNT_GROUPS = [
  { id: "equipment", label: "Equipment", types: ["Gear", "Set", "Trinket", "Jewelry", "Relic"] },
  { id: "mounts", label: "Mounts", types: ["Mount"] },
  { id: "pets", label: "Pets", types: ["Pet"] },
  { id: "toys", label: "Toys", types: ["Vanity"] },
  { id: "recipes", label: "Recipes", types: ["Recipe", "Profession"] },
  { id: "discoveries", label: "Discoveries", types: ["Discovery"] },
  { id: "keepsakes", label: "Keepsakes", types: ["Tabard"] },
  { id: "milestones", label: "Milestones", types: ["Milestone"] }
];

const state = {
  house: null,
  characters: [],
  checklist: [],
  stats: { updated: null, characters: {} },
  addons: null,
  dungeons: null,
  dungeonQuery: "",
  quests: null,
  questLoading: false,
  questQuery: "",
  altoholic: null,
  altoName: "",
  books: null,
  openBookRegions: new Set(),
  openBookMaps: new Set(),
  professions: null,
  profLoading: false,
  macros: null,
  macroLoading: false,
  profView: "known",
  profQuery: "",
  openDungeons: new Set(),
  selected: "flann",
  scope: "character",
  place: "",
  query: "",
  type: "",
  openId: "",
  tab: "roster",
  checks: {},
  attempts: {},
  tasks: [],
  taskChecks: {},
  sheetLive: false,
  sheetWriting: 0
};

function loadStore() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORE_KEY) || "{}");
    if (saved.selected) state.selected = saved.selected;
    if (saved.scope) state.scope = saved.scope;
    if (typeof saved.place === "string") state.place = saved.place;
    if (["known", "make", "learn", "all"].includes(saved.profView)) state.profView = saved.profView;
    if (TABS.includes(saved.tab)) state.tab = saved.tab;
  } catch {
    state.checks = {};
    state.attempts = {};
  }
  saveStore();
}

function saveStore() {
  localStorage.setItem(STORE_KEY, JSON.stringify({
    selected: state.selected,
    scope: state.scope,
    place: state.place,
    profView: state.profView,
    tab: state.tab
  }));
}

function noteSheet(message) {
  const node = document.getElementById("sheet-status");
  if (!node) return;
  node.hidden = !message;
  node.textContent = message || "";
}

function sheetMiss() {
  if (!window.SheetStore || !SheetStore.canWrite()) {
    return "The sheet did not save. Add the script URL and write secret under Sheet writes.";
  }
  return "The sheet did not save.";
}

function manualChecked(id, characterId) {
  const row = state.checks[id];
  return !!(row && row[characterId]);
}

function writeLocalCheck(id, characterId, checked) {
  if (!state.checks[id]) state.checks[id] = {};
  state.checks[id][characterId] = !!checked;
}

async function commitChecks(changes) {
  state.sheetWriting += 1;
  const saved = [];
  let failed = false;
  try {
    if (!window.SheetStore || !SheetStore.canWrite()) failed = true;
    else {
      for (const change of changes) {
        const result = await SheetStore.post("toggleHunt", {
          id: change.id,
          characterId: state.selected,
          checked: change.checked
        });
        if (!result.ok) {
          failed = true;
          break;
        }
        saved.push(change);
      }
    }
    if (!failed) {
      noteSheet("");
      return;
    }
    changes.forEach((change) => writeLocalCheck(change.id, state.selected, change.prev));
    for (const change of saved) {
      await SheetStore.post("toggleHunt", {
        id: change.id,
        characterId: state.selected,
        checked: change.prev
      });
    }
    noteSheet(sheetMiss());
    renderChecklist();
    renderDungeons();
  } finally {
    state.sheetWriting -= 1;
  }
}

async function persistTries(id, count, prev) {
  state.sheetWriting += 1;
  try {
    const result = window.SheetStore && SheetStore.canWrite()
      ? await SheetStore.post("setTries", { id, characterId: state.selected, count })
      : { ok: false };
    if (result.ok) {
      noteSheet("");
      return;
    }
    if (!state.attempts[id]) state.attempts[id] = {};
    if (!prev) delete state.attempts[id][state.selected];
    else state.attempts[id][state.selected] = prev;
    noteSheet(sheetMiss());
    renderChecklist();
  } finally {
    state.sheetWriting -= 1;
  }
}

async function commitTask(id, checked, prev) {
  state.sheetWriting += 1;
  try {
    const result = window.SheetStore && SheetStore.canWrite()
      ? await SheetStore.post("toggleTask", { id, characterId: state.selected, checked })
      : { ok: false };
    if (result.ok) {
      noteSheet("");
      return;
    }
    if (!state.taskChecks[id]) state.taskChecks[id] = {};
    state.taskChecks[id][state.selected] = prev;
    noteSheet(sheetMiss());
    renderLedgerBoards();
  } finally {
    state.sheetWriting -= 1;
  }
}

function attemptCount(id) {
  const row = state.attempts[id] || {};
  const n = Number(row[state.selected]);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : 0;
}

function setAttempts(id, value) {
  const n = Math.max(0, Math.floor(Number(value) || 0));
  const prev = attemptCount(id);
  if (!state.attempts[id]) state.attempts[id] = {};
  if (n === 0) delete state.attempts[id][state.selected];
  else state.attempts[id][state.selected] = n;
  persistTries(id, n, prev);
}

function huntGroup(item) {
  return HUNT_GROUPS.find((group) => group.types.includes(item.type))
    || { id: "other", label: "Other", types: [] };
}

const RECIPE_PREFIX = /^(recipe|plans|pattern|formula|schematic|manual|design|technique):\s*/i;

function nameKey(value) {
  return String(value || "").trim().toLowerCase();
}

function buildOwned() {
  const items = new Map();
  const recipes = new Map();
  const looted = new Map();
  const lootedRecipes = new Map();
  const kills = new Map();
  const put = (map, name, note) => {
    const key = nameKey(name);
    if (key && !map.has(key)) map.set(key, note);
  };
  const lives = Object.entries(state.stats.characters || {}).map(([id, live]) => {
    const character = state.characters.find((c) => c.id === id);
    return { who: character ? character.name.split(" ")[0] : id, live };
  });
  lives.forEach(({ who, live }) => {
    asList(live.gear).forEach((piece) => put(items, piece.name, `Worn by ${who}`));
    asList(live.items).forEach((name) => put(items, name, `In ${who}'s bags`));
    asList(live.owned).forEach((name) => put(items, name, `Owned by ${who}`));
    Object.values(live.recipes || {}).forEach((list) => {
      asList(list).forEach((name) => put(recipes, name, `${who} knows it`));
    });
    asList(live.looted).forEach((name) => {
      put(looted, name, `Looted by ${who}`);
      if (RECIPE_PREFIX.test(name)) put(lootedRecipes, name.replace(RECIPE_PREFIX, ""), `Looted by ${who}`);
    });
    Object.entries(live.huntKills || {}).forEach(([mob, count]) => {
      const key = nameKey(mob);
      if (!kills.has(key)) kills.set(key, []);
      kills.get(key).push({ mob, who, count: Number(count) || 0 });
    });
  });
  state.owned = { items, recipes, looted, lootedRecipes, kills };
}

function ownedNote(item) {
  const owned = state.owned;
  if (!owned || !item.name) return "";
  const key = nameKey(item.name);
  const held = owned.items.get(key);
  if (held) return held;
  if (item.type === "Recipe" || RECIPE_PREFIX.test(item.name)) {
    const base = nameKey(item.name.replace(RECIPE_PREFIX, ""));
    const known = owned.recipes.get(base);
    if (known) return known;
    return owned.looted.get(key) || owned.lootedRecipes.get(base) || "";
  }
  return owned.looted.get(key) || "";
}

function killLog(mobs) {
  const owned = state.owned;
  const rows = [];
  new Set(asList(mobs).map(nameKey)).forEach((key) => {
    ((owned && owned.kills.get(key)) || []).forEach((row) => rows.push(row));
  });
  const total = rows.reduce((sum, row) => sum + row.count, 0);
  const text = rows.map((row) => `${row.mob} ${row.count} (${row.who})`).join(", ");
  return { total, text };
}

function buildDrops() {
  const drops = new Map();
  const dropDungeons = new Map();
  const put = (name, where, dungeon) => {
    const key = nameKey(name);
    if (!key) return;
    if (!drops.has(key)) drops.set(key, []);
    drops.get(key).push(where);
    if (!dropDungeons.has(key)) dropDungeons.set(key, new Set());
    dropDungeons.get(key).add(dungeon);
  };
  const dungeons = asList(state.dungeons && state.dungeons.dungeons);
  dungeons.forEach((dungeon) => {
    asList(dungeon.bosses).forEach((boss) => {
      asList(boss.loot).forEach((item) => put(item.name, `${boss.name} in ${dungeon.name}`, dungeon.name));
    });
    asList(dungeon.quests).forEach((quest) => {
      asList(quest.rewardItems).forEach((item) => put(item.name, `the ${quest.name} quest in ${dungeon.name}`, dungeon.name));
    });
  });
  const hunts = new Set();
  const lootLinks = new Map();
  const linkLoot = (name, entry, parent) => {
    const key = nameKey(name);
    if (!key) return;
    if (!lootLinks.has(key)) lootLinks.set(key, []);
    lootLinks.get(key).push({ entry, parent: parent || null });
  };
  const places = new Map();
  state.checklist.forEach((hunt) => {
    const entries = [hunt, ...asList(hunt.parts)];
    entries.forEach((entry) => hunts.add(nameKey(entry.name)));
    linkLoot(hunt.name, hunt, null);
    asList(hunt.parts).forEach((part) => linkLoot(part.name, part, hunt));
    const zone = nameKey(hunt.zone);
    const inDungeons = new Set(dungeons
      .map((dungeon) => dungeon.name)
      .filter((name) => zone.includes(nameKey(name).replace(/^the /, ""))));
    entries.forEach((entry) => (dropDungeons.get(nameKey(entry.name)) || []).forEach((name) => inDungeons.add(name)));
    const kind = inDungeons.size ? "dungeon"
      : hunt.type === "Milestone" || hunt.source === "Pack" ? "none"
      : "world";
    places.set(hunt.id, { kind, dungeons: [...inDungeons] });
  });
  state.drops = drops;
  state.huntNames = hunts;
  state.lootLinks = lootLinks;
  state.places = places;
}

function lootLinksFor(item) {
  const links = (state.lootLinks && state.lootLinks.get(nameKey(item.name))) || [];
  const pieces = links.filter((link) => link.parent);
  return pieces.length ? pieces : links;
}

function lootTrackable(item) {
  return nameKey(item.slot) !== "quest item";
}

function dropStoreKey(item) {
  return `drop:${item.id || nameKey(item.name)}`;
}

function lootInHand(item) {
  if (!lootTrackable(item)) return false;
  if (ownedNote(item)) return true;
  const links = lootLinksFor(item);
  if (links.length) return links.some((link) => isChecked(link.entry));
  return manualChecked(dropStoreKey(item), state.selected);
}

function setLootCheck(item, checked) {
  const links = lootLinksFor(item);
  if (!links.length) {
    noteSheet("That drop is not a hunt on the sheet, so the check was not saved.");
    renderDungeons();
    return;
  }
  const changes = [];
  links.forEach((link) => {
    if (!link.parent && link.entry.parts && checked && !piecesReady(link.entry)) return;
    const prev = manualChecked(link.entry.id, state.selected);
    writeLocalCheck(link.entry.id, state.selected, checked);
    changes.push({ id: link.entry.id, checked, prev });
    if (link.parent && !piecesReady(link.parent)) {
      const prevParent = manualChecked(link.parent.id, state.selected);
      if (prevParent) {
        writeLocalCheck(link.parent.id, state.selected, false);
        changes.push({ id: link.parent.id, checked: false, prev: prevParent });
      }
    }
  });
  renderChecklist();
  renderDungeons();
  if (changes.length) commitChecks(changes);
}

function dungeonGear(dungeon) {
  const seen = new Set();
  const gear = [];
  const add = (item) => {
    if (!item || !lootTrackable(item)) return;
    const key = String(item.id || nameKey(item.name));
    if (seen.has(key)) return;
    seen.add(key);
    gear.push(item);
  };
  asList(dungeon.bosses).forEach((boss) => asList(boss.loot).forEach(add));
  asList(dungeon.quests).filter(questFactionShown).forEach((quest) => {
    asList(quest.rewardItems).forEach(add);
  });
  return gear;
}

function huntPlace(item) {
  return (state.places && state.places.get(item.id)) || { kind: "world", dungeons: [] };
}

function matchesPlace(item) {
  if (!state.place) return true;
  const place = huntPlace(item);
  if (state.place.startsWith("dungeon:")) return place.dungeons.includes(state.place.slice(8));
  return place.kind === state.place;
}

function fillPlaceOptions() {
  const select = document.getElementById("place");
  const used = new Set();
  state.checklist.forEach((item) => huntPlace(item).dungeons.forEach((name) => used.add(name)));
  const order = asList(state.dungeons && state.dungeons.dungeons).map((dungeon) => dungeon.name);
  const options = [
    ["", "Anywhere"],
    ["dungeon", "Dungeons"],
    ...order.filter((name) => used.has(name)).map((name) => [`dungeon:${name}`, `\u00a0\u00a0\u00a0${name}`]),
    ["world", "Open world"],
    ["none", "No trip (packs, milestones)"]
  ];
  select.replaceChildren(...options.map(([value, label]) => el("option", { value, text: label })));
  if (!options.some(([value]) => value === state.place)) state.place = "";
  select.value = state.place;
}

function dropNote(name) {
  const where = (state.drops && state.drops.get(nameKey(name))) || [];
  return where.length ? `Drops from ${where.join(" or ")}.` : "";
}

function huntMobs(item) {
  return [...asList(item.mobs), ...asList(item.parts).flatMap((part) => asList(part.mobs))];
}

function isChecked(item) {
  if (ownedNote(item)) return true;
  if (state.scope === "house") {
    const people = state.characters.filter((character) => matchesCharacter(item, character));
    const list = people.length ? people : state.characters;
    if (list.some((character) => manualChecked(item.id, character.id))) return true;
    return !state.sheetLive && !!item.defaultDone;
  }
  if (manualChecked(item.id, state.selected)) return true;
  if (!state.sheetLive) return !!item.defaultDone;
  return false;
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
    if (!matchesPlace(item)) return false;
    if (!q) return true;
    const parts = (item.parts || []).map((part) => `${part.name} ${part.how || ""}`).join(" ");
    const hay = `${item.name} ${item.zone} ${item.notes} ${item.how || ""} ${item.type} ${parts} ${huntPlace(item).dungeons.join(" ")}`.toLowerCase();
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
  const base = `${house.player} · ${house.faction} · ${house.ruleset} · ${house.edition}`;
  const fallback = state.sheetLive
    ? ""
    : " Showing the saved copy. The Google Sheet did not load, so checks on this page are not saved.";
  document.getElementById("lede").textContent = base + fallback;
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
    button.style.setProperty("--class", CLASS_COLOR[character.className] || "var(--gold)");
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
  const skills = new Map(asList(live.professions).map((p) => [p.name, p]));
  const skillLabel = (name, skill) => {
    if (!skill) return name;
    return skill.max ? `${name} ${skill.current}/${skill.max}` : `${name} ${skill.current}`;
  };
  character.professions.forEach((name) => {
    profs.append(el("span", { text: skillLabel(name, skills.get(name)) }));
  });
  skills.forEach((skill, name) => {
    if (!character.professions.includes(name)) {
      profs.append(el("span", { class: "extra", text: skillLabel(name, skill) }));
    }
  });
  identity.append(profs);
  identity.append(el("p", { class: "meta", text: character.talentNote }));
  if (character.talentUrl) {
    identity.append(el("a", { href: character.talentUrl, target: "_blank", rel: "noreferrer", text: "Open the saved talent tree" }));
  }
  if (character.pairsWith) {
    identity.append(el("p", { text: `Pairs with ${character.pairsWith}.` }));
  }
  const recipeGroups = Object.entries(live.recipes || {}).filter(([, list]) => asList(list).length);
  if (recipeGroups.length) {
    const total = recipeGroups.reduce((sum, [, list]) => sum + asList(list).length, 0);
    const box = el("details", { class: "recipes" });
    box.append(el("summary", { text: `${total} known recipes` }));
    recipeGroups.forEach(([prof, list]) => {
      box.append(el("h4", { text: prof }));
      box.append(el("p", { class: "meta", text: asList(list).join(", ") }));
    });
    identity.append(box);
  }

  const stats = el("article", { class: "card" });
  stats.append(el("h3", { text: "Stats" }));
  const updated = state.stats.updated
    ? `Updated ${state.stats.updated}.`
    : (state.sheetLive
      ? "No row on the sheet yet. Paste this character's JSON into the Import tab."
      : "No addon export merged yet. Level, gear, and gold show up here after the next dump.");
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
  Object.entries(live.collections || {}).forEach(([label, value]) => grid.append(statBox(label, value)));
  stats.append(grid);
  const sources = Object.entries(live.sources || {})
    .map(([name, when]) => (when ? `${name} ${String(when).slice(5, 10).replace("-", "/")}` : name));
  if (sources.length) stats.append(el("p", { class: "meta sources", text: `From ${sources.join(" · ")}` }));
  const record = ledgerRecord(character);
  if (record) {
    const goldLines = asList(record.gold).slice(0, 6).map((row) => {
      const when = formatWhen(row.time);
      return `${when ? `${when} ` : ""}${row.source || "gold"} ${formatGold(row.delta)}`;
    });
    const currencyLines = asList(record.currencies).slice(0, 6).map((row) => `${row.name} ${row.quantity}`);
    const repLines = asList(record.reputations).slice(0, 6).map((row) => `${row.name} ${row.standing || row.value || ""}`.trim());
    const bits = [...goldLines, ...currencyLines, ...repLines];
    if (bits.length) stats.append(el("p", { class: "meta", text: bits.join(" · ") }));
  }

  if (asList(live.gear).length) {
    const table = el("table", { class: "gear" });
    const head = el("tr");
    ["Slot", "Item", "ilvl"].forEach((label) => head.append(el("th", { text: label })));
    table.append(el("thead", {}, [head]));
    const body = el("tbody");
    asList(live.gear).forEach((piece) => {
      const row = el("tr");
      row.append(el("td", { text: dash(piece.slot) }));
      row.append(el("td", { text: dash(piece.name) }));
      row.append(el("td", { text: dash(piece.itemLevel) }));
      body.append(row);
    });
    table.append(body);
    stats.append(table);
  }

  const lifetime = el("article", { class: "card lifetime" });
  lifetime.append(el("h3", { text: "Statistics" }));
  const groups = statisticGroups(live.statistics);
  if (!groups.length) {
    lifetime.append(el("p", { class: "empty-note", text: "Open the character window and use the bottom tab on the right. The scan does not read Dossier's Statistics section yet, so paste the counters you care about into the export under statistics." }));
  } else {
    const wrap = el("div", { class: "stat-groups" });
    groups.forEach((group) => {
      const block = el("section");
      block.append(el("h4", { text: group.name }));
      const list = el("dl");
      group.rows.forEach((row) => {
        const line = el("div");
        line.append(el("dt", { text: dash(row.name) }));
        line.append(el("dd", { text: dash(row.value) }));
        list.append(line);
      });
      block.append(list);
      wrap.append(block);
    });
    lifetime.append(wrap);
  }

  const shots = asList(state.screenshots)
    .filter((shot) => String(shot.file || "").startsWith(`assets/shots/${character.id}/`))
    .sort((a, b) => String(b.takenAt).localeCompare(String(a.takenAt)));
  if (shots.length) {
    identity.append(el("h4", { class: "shots-head", text: `Screenshots (${shots.length})` }));
    const grid = el("div", { class: "shots" });
    shots.forEach((shot) => {
      const when = new Date(shot.takenAt);
      const date = Number.isNaN(when.getTime())
        ? ""
        : when.toLocaleDateString(undefined, { month: "short", day: "numeric" });
      const label = shot.caption || `Screenshot from ${date}`;
      const link = el("a", { href: shot.file, target: "_blank", rel: "noreferrer", "aria-label": `Open full size: ${label}` }, [
        el("img", { src: shot.file, alt: label, loading: "lazy" })
      ]);
      grid.append(el("figure", {}, [
        link,
        el("figcaption", { text: [date, shot.caption].filter(Boolean).join(" · ") })
      ]));
    });
    identity.append(grid);
  }
  sheet.replaceChildren(identity, stats, lifetime);
}

function statisticGroups(statistics) {
  if (!statistics) return [];
  if (Array.isArray(statistics)) {
    return statistics.length ? [{ name: "Statistics", rows: statistics }] : [];
  }
  return Object.entries(statistics).map(([name, rows]) => ({
    name,
    rows: Array.isArray(rows)
      ? rows
      : Object.entries(rows || {}).map(([label, value]) => ({ name: label, value }))
  })).filter((group) => group.rows.length);
}

function badgeClass(item) {
  if (item.status === "Parked") return "badge parked";
  if (item.priority === "Medium") return "badge medium";
  if (item.priority === "Low") return "badge low";
  return "badge";
}

function whoLabel(item) {
  const names = {
    all: "Whole house",
    alliance: "Any Alliance",
    horde: "Horde test",
    melee: "Melee",
    loremaster: "Loremasters",
    crafter: "Crafters",
    hunter: "Hunters",
    caster: "Casters"
  };
  return (item.owners || []).map((id) => {
    const character = state.characters.find((entry) => entry.id === id);
    return character ? character.name : (names[id] || id);
  }).join(", ");
}

function fact(label, value) {
  return el("div", { class: "fact" }, [
    el("span", { text: label }),
    el("b", { text: value })
  ]);
}

function piecesReady(item) {
  if (!item.parts || !item.parts.length) return true;
  const need = item.need || item.parts.length;
  return item.parts.filter((part) => isChecked(part)).length >= need;
}

function renderTries(id, label) {
  const tries = attemptCount(id);
  const count = el("input", {
    class: "try-count",
    type: "number",
    min: "0",
    step: "1",
    value: String(tries),
    "aria-label": `Tries for ${label}`
  });
  count.addEventListener("click", (event) => event.stopPropagation());
  count.addEventListener("change", () => {
    setAttempts(id, count.value);
    renderChecklist();
  });
  const step = (delta) => {
    setAttempts(id, attemptCount(id) + delta);
    renderChecklist();
  };
  return el("div", { class: "tries" }, [
    el("span", { text: "Tries" }),
    el("button", { type: "button", text: "−", "aria-label": "One fewer try", onclick: () => step(-1) }),
    count,
    el("button", { type: "button", text: "+", "aria-label": "Log a try", onclick: () => step(1) })
  ]);
}

function renderPart(item, part) {
  const checked = isChecked(part);
  const found = ownedNote(part);
  const box = el("input", { type: "checkbox", "aria-label": `Got ${part.name}`, title: found || null });
  box.checked = checked;
  if (found || state.scope === "house") box.disabled = true;
  if (state.scope === "house" && !found) box.title = "Switch to this character to check this hunt.";
  box.addEventListener("click", (event) => event.stopPropagation());
  box.addEventListener("change", () => {
    if (state.scope === "house") {
      box.checked = isChecked(part);
      return;
    }
    const changes = [];
    const prev = manualChecked(part.id, state.selected);
    writeLocalCheck(part.id, state.selected, box.checked);
    changes.push({ id: part.id, checked: box.checked, prev });
    if (!piecesReady(item)) {
      const prevParent = manualChecked(item.id, state.selected);
      if (prevParent) {
        writeLocalCheck(item.id, state.selected, false);
        changes.push({ id: item.id, checked: false, prev: prevParent });
      }
    }
    renderChecklist();
    renderDungeons();
    commitChecks(changes);
  });
  const partKills = killLog(part.mobs);
  const partDrop = dropNote(part.name);
  const copy = el("div", { class: "part-copy" }, [
    el("strong", { text: part.name }),
    el("p", { text: found ? `${found}. ${part.how || ""}` : part.how || "" }),
    partDrop ? el("p", { class: "drop-note", text: partDrop }) : null,
    partKills.total ? el("p", { class: "kill-log", text: `KillDex: ${partKills.text}` }) : null
  ]);
  return el("div", { class: `part${checked ? " done" : ""}` }, [
    box,
    copy,
    renderTries(part.id, part.name)
  ]);
}

function renderHunt(item) {
  const checked = isChecked(item);
  const open = state.openId === item.id;
  const tries = attemptCount(item.id);
  const group = huntGroup(item);
  const ready = piecesReady(item);
  const pieceCount = item.parts ? item.parts.filter((part) => isChecked(part)).length : 0;
  const found = ownedNote(item);
  const box = el("input", {
    type: "checkbox",
    "aria-label": `Got ${item.name}`,
    title: found || null
  });
  box.checked = checked;
  if (state.scope === "house" || (item.parts && !ready) || found) box.disabled = true;
  if (state.scope === "house" && !found) box.title = "Switch to this character to check this hunt.";
  box.addEventListener("click", (event) => event.stopPropagation());
  box.addEventListener("change", () => {
    if (state.scope === "house") {
      box.checked = isChecked(item);
      return;
    }
    if (item.parts && box.checked && !piecesReady(item)) {
      box.checked = false;
      return;
    }
    const prev = manualChecked(item.id, state.selected);
    writeLocalCheck(item.id, state.selected, box.checked);
    renderChecklist();
    renderDungeons();
    commitChecks([{ id: item.id, checked: box.checked, prev }]);
  });

  const summary = el("button", {
    type: "button",
    class: "hunt-open",
    "aria-expanded": open ? "true" : "false",
    onclick: () => {
      state.openId = open ? "" : item.id;
      renderChecklist();
    }
  });
  summary.append(el("strong", { text: item.name }));
  const meta = `${group.label} · ${item.zone} · level ${item.minLevel}+`;
  const pieceText = item.parts
    ? `${pieceCount} of ${item.need || item.parts.length} pieces`
    : "";
  const kills = killLog(huntMobs(item));
  const killText = kills.total ? `${kills.total} ${kills.total === 1 ? "kill" : "kills"} logged` : "";
  const attemptText = [meta, pieceText, found, killText, tries ? `${tries} ${tries === 1 ? "try" : "tries"}` : ""]
    .filter(Boolean)
    .join(" · ");
  summary.append(el("span", { class: "sub", text: attemptText }));

  const row = el("div", { class: "hunt-row" }, [
    box,
    summary,
    el("span", { class: badgeClass(item), text: item.status === "Parked" ? "Parked" : item.priority })
  ]);

  const card = el("article", {
    class: `hunt group-${group.id}${checked ? " done" : ""}${item.status === "Parked" ? " parked" : ""}${open ? " open" : ""}`
  }, [row]);

  if (!open) return card;

  const detailKids = [
    el("p", { class: "hunt-notes", text: item.notes }),
    item.how ? el("p", { text: item.how }) : null,
    dropNote(item.name) ? el("p", { class: "drop-note", text: dropNote(item.name) }) : null,
    el("div", { class: "facts" }, [
      fact("Zone", item.zone),
      fact("From", `level ${item.minLevel}`),
      fact("Source", item.source),
      fact("For", whoLabel(item))
    ])
  ];
  if (kills.total && !item.parts) {
    detailKids.push(el("p", { class: "kill-log", text: `KillDex: ${kills.text}` }));
  }
  if (item.parts) {
    const need = item.need || item.parts.length;
    detailKids.push(el("p", {
      class: "piece-rule",
      text: need === item.parts.length
        ? "Every piece has to be checked before this hunt can be checked off."
        : `Check ${need} of ${item.parts.length} pieces before this hunt can be checked off.`
    }));
    item.parts.forEach((part) => detailKids.push(renderPart(item, part)));
  } else {
    detailKids.push(renderTries(item.id, item.name));
  }
  card.append(el("div", { class: "hunt-detail" }, detailKids));
  return card;
}

function renderChecklist() {
  const items = visibleItems();
  const done = items.filter(isChecked).length;
  document.getElementById("check-count").textContent = `${done} of ${items.length} in hand`;
  const bar = document.getElementById("progress-bar");
  bar.style.width = items.length ? `${Math.round((done / items.length) * 100)}%` : "0";

  const list = document.getElementById("checklist");
  list.replaceChildren();
  if (!items.length) {
    const books = renderLibraryBooks();
    list.append(books || el("p", { class: "empty-note", text: "Nothing on this filter." }));
    return;
  }

  const rank = { High: 0, Medium: 1, Low: 2 };
  HUNT_GROUPS.forEach((group) => {
    const rows = items
      .filter((item) => group.types.includes(item.type))
      .sort((a, b) => {
        const parked = (a.status === "Parked") - (b.status === "Parked");
        if (parked) return parked;
        const priority = (rank[a.priority] ?? 3) - (rank[b.priority] ?? 3);
        if (priority) return priority;
        return a.name.localeCompare(b.name);
      });
    if (!rows.length) return;
    const got = rows.filter(isChecked).length;
    const head = el("div", { class: "group-label" }, [
      el("span", { text: group.label }),
      el("em", { text: `${got} / ${rows.length}` })
    ]);
    const block = el("section", { class: `hunt-group group-${group.id}` }, [head]);
    rows.forEach((item) => block.append(renderHunt(item)));
    list.append(block);
  });
  const books = renderLibraryBooks();
  if (books) list.append(books);
}

function bookSheetId(book) {
  const slug = String(book.name || "")
    .trim()
    .toLowerCase()
    .replace(/['’]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return `book:${slug}`;
}

function bookTurnedIn(book) {
  return manualChecked(bookSheetId(book), state.selected);
}

function renderBookMap(book) {
  const template = (state.books && state.books.mapUrl) || "";
  const pins = asList(book.pins).map((pin) => el("span", {
    class: `book-pin${pin.x > 70 ? " flip" : ""}`,
    style: `left:${pin.x}%;top:${pin.y}%`,
    title: `${pin.label || book.zone} ${pin.x}, ${pin.y}`
  }, [pin.label ? el("span", { text: pin.label }) : null]));
  return el("figure", { class: "book-map" }, [
    el("img", { src: template.replace("{mapId}", book.mapId), alt: `${book.zone} map`, loading: "lazy", width: "768", height: "512" }),
    ...pins
  ]);
}

function renderBook(book) {
  const done = bookTurnedIn(book);
  const box = el("input", { type: "checkbox", "aria-label": `Turned in ${book.name}` });
  box.checked = done;
  box.addEventListener("change", () => {
    const id = bookSheetId(book);
    const prev = manualChecked(id, state.selected);
    writeLocalCheck(id, state.selected, box.checked);
    renderChecklist();
    commitChecks([{ id, checked: box.checked, prev }]);
  });
  const pin = asList(book.pins)[0];
  const coords = pin ? `${pin.x}, ${pin.y}` : "";
  const mapOpen = state.openBookMaps.has(book.id);
  const kids = [
    el("strong", { text: book.name }),
    el("p", { class: "meta", text: [book.zone, coords, book.moved ? "moved in Forever, new spot not found yet" : ""].filter(Boolean).join(" · ") }),
    book.location ? el("p", { text: book.location }) : null,
    ...asList(book.notes).map((note) => el("p", { class: "meta", text: note }))
  ];
  if (book.mapId) {
    kids.push(el("button", {
      type: "button",
      class: "book-map-toggle",
      "aria-expanded": mapOpen ? "true" : "false",
      text: mapOpen ? "Hide map" : "Show map",
      onclick: () => {
        if (mapOpen) state.openBookMaps.delete(book.id);
        else state.openBookMaps.add(book.id);
        renderChecklist();
      }
    }));
    if (mapOpen) kids.push(renderBookMap(book));
  }
  return el("article", { class: `book${done ? " done" : ""}${book.moved ? " moved" : ""}` }, [
    box,
    el("div", { class: "book-copy" }, kids)
  ]);
}

function renderLibraryBooks() {
  const data = state.books;
  if (!data || !asList(data.books).length) return null;
  if (state.place && state.place !== "world") return null;
  const character = selectedCharacter();
  const isMage = character && character.className === "Mage";
  const q = nameKey(state.query);
  const all = asList(data.books).filter((book) => book.kind !== "mage" || isMage);
  const distinct = (books) => [...new Map(books.map((book) => [nameKey(book.name), book])).values()];
  const library = distinct(all.filter((book) => book.kind === "library"));
  const turnedIn = library.filter(bookTurnedIn).length;
  const shown = q ? all.filter((book) => nameKey(`${book.name} ${book.zone} ${book.location}`).includes(q)) : all;
  if (q && !shown.length) return null;

  const block = el("section", { class: "hunt-group group-library" }, [
    el("div", { class: "group-label" }, [
      el("span", { text: "Library books" }),
      el("em", { text: `${turnedIn} / 20 turned in by ${character.name}` })
    ])
  ]);
  const credit = el("p", { class: "meta book-credit" }, [
    document.createTextNode("Alliance turns books in to Garion Wendell in the Stormwind Mage Quarter (37.6, 80.8). Each book counts once. 10 pays a neck, 20 pays a ring. Spots and maps from "),
    el("a", { href: data.url, target: "_blank", rel: "noopener", text: data.source }),
    document.createTextNode(data.updated ? `, updated ${data.updated}.` : ".")
  ]);
  block.append(credit);

  const regions = [];
  shown.forEach((book) => { if (!regions.includes(book.region)) regions.push(book.region); });
  regions.forEach((region) => {
    const books = shown.filter((book) => book.region === region);
    const unique = distinct(books);
    const got = unique.filter(bookTurnedIn).length;
    const box = el("details", { class: "card dungeon book-region" });
    box.open = !!q || state.openBookRegions.has(region);
    box.addEventListener("toggle", () => {
      if (q) return;
      if (box.open) state.openBookRegions.add(region);
      else state.openBookRegions.delete(region);
    });
    const note = region === "Mage books" ? "turn in to Jennea Cannon for a Comprehension Charm" : "";
    box.append(el("summary", {}, [
      el("h3", { text: region }),
      el("span", { class: "meta", text: [`${got} of ${unique.length} turned in`, note].filter(Boolean).join(" · ") })
    ]));
    box.append(el("div", { class: "book-list" }, books.map(renderBook)));
    block.append(box);
  });
  return block;
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
  renderLedgerBoards();
  renderProfessions();
  renderQuests();
  renderMacros();
}

function cleanAddonText(value) {
  return String(value || "").replace(/\|T[^|]*\|t/g, "").replace(/\s+/g, " ").trim();
}

function versionLabel(version) {
  if (!version) return null;
  const text = String(version);
  return /^v/i.test(text) ? text : `v${text}`;
}

function asList(value) {
  if (!value) return [];
  if (Array.isArray(value)) return value;
  if (typeof value === "string") return [value];
  if (typeof value === "object" && Object.keys(value).length === 0) return [];
  return [value];
}

function renderAddons() {
  const root = document.getElementById("addon-list");
  const note = document.getElementById("addon-scan");
  if (!root || !note) return;
  root.replaceChildren();
  const scan = state.addons;
  if (!scan || !asList(scan.addons).length) {
    note.textContent = "No scan yet. Run scripts/scan-addons.ps1, then commit data/addons.json.";
    return;
  }
  const when = scan.scannedAt ? scan.scannedAt.slice(0, 10) : "an unknown date";
  note.textContent = `Scanned ${when}. ${scan.count || asList(scan.addons).length} installed.`;
  const groups = [
    ["Can feed the site", (addon) => addon.feedsSite],
    ["Interface", (addon) => !addon.feedsSite]
  ];
  groups.forEach(([label, pick]) => {
    const items = asList(scan.addons).filter(pick);
    if (!items.length) return;
    root.append(el("h3", { class: "group-label", text: label }));
    const grid = el("div", { class: "addon-grid" });
    items.forEach((addon) => {
      const card = el("article", { class: "card addon-card" });
      const head = el("div", { class: "who" });
      head.append(el("h3", { text: cleanAddonText(addon.title || addon.folder) }));
      if (addon.feedsSite) {
        head.append(el("span", { class: "badge", text: "Feeds the site" }));
      }
      card.append(head);
      const bits = [versionLabel(addon.version), cleanAddonText(addon.author)].filter(Boolean);
      if (addon.enabled === true) bits.push(addon.loaded === false ? "Enabled, not loaded" : "Loaded");
      if (addon.enabled === false) bits.push("Disabled");
      if (addon.uncataloged) bits.push("Not in the catalog");
      if (bits.length) card.append(el("p", { class: "meta", text: bits.join(" · ") }));
      card.append(el("p", { text: addon.purpose || "" }));
      const collects = asList(addon.collects);
      if (collects.length) {
        const list = el("ul");
        collects.forEach((item) => list.append(el("li", { text: item })));
        card.append(list);
      }
      const saves = asList(addon.savedVariables);
      if (saves.length) {
        const onDisk = addon.saveOnDisk ? "on disk" : "not saved yet";
        const details = el("details", { class: "saves" });
        details.append(el("summary", { text: `${saves.length} saved ${saves.length === 1 ? "variable" : "variables"}, ${onDisk}` }));
        details.append(el("p", { class: "meta", text: saves.join(", ") }));
        card.append(details);
      }
      grid.append(card);
    });
    root.append(grid);
  });
}

function itemMatches(item, q) {
  return nameKey(`${item.name} ${item.slot || ""}`).includes(q);
}

function renderLootItem(item) {
  const owned = ownedNote(item);
  const quality = nameKey(item.quality) || "common";
  const trackable = lootTrackable(item);
  const inHand = trackable && lootInHand(item);
  const bits = [item.slot, owned].filter(Boolean).join(" · ");
  const box = trackable ? el("input", {
    type: "checkbox",
    "data-loot-id": String(item.id || nameKey(item.name)),
    "aria-label": `Got ${item.name}`,
    title: owned || null
  }) : null;
  if (box) {
    box.checked = inHand;
    if (owned) box.disabled = true;
    box.addEventListener("change", () => setLootCheck(item, box.checked));
  }
  return el("li", { class: inHand || owned ? "owned" : null }, [
    box,
    el("span", { class: `item q-${quality}`, text: item.name }),
    state.huntNames && state.huntNames.has(nameKey(item.name)) ? el("span", { class: "badge", text: "Hunt" }) : null,
    bits ? el("small", { text: bits }) : null
  ]);
}

function questFactionShown(quest) {
  const faction = (state.house && state.house.faction) || "Alliance";
  return !quest.faction || quest.faction === "Both" || quest.faction === faction;
}

function renderQuest(quest) {
  const meta = [
    quest.level ? `Level ${quest.level}` : "",
    quest.requires ? `needs ${quest.requires}` : "",
    quest.faction && quest.faction !== "Both" ? quest.faction : "",
    quest.classOnly ? `${quest.classOnly} only` : ""
  ].filter(Boolean).join(" · ");
  const rewards = asList(quest.rewardItems);
  const kids = [
    el("strong", { text: quest.name }),
    meta ? el("small", { text: meta }) : null,
    quest.objective ? el("p", { text: quest.objective }) : null,
    quest.pickup ? el("p", { class: "meta", text: `Start: ${quest.pickup}${quest.turnin && quest.turnin !== quest.pickup ? ` · Turn in: ${quest.turnin}` : ""}` }) : null,
    quest.startItem ? el("p", { class: "meta", text: `Starts from ${quest.startItem.name}${quest.startItem.from ? `. ${quest.startItem.from}` : ""}` }) : null
  ];
  if (rewards.length) {
    kids.push(el("p", { class: "reward-label", text: quest.rewardChoice && rewards.length > 1 ? "Choose one" : "Reward" }));
    kids.push(el("ul", { class: "loot" }, rewards.map(renderLootItem)));
  }
  if (quest.rewards) kids.push(el("p", { class: "meta", text: quest.rewards }));
  if (quest.note) kids.push(el("p", { class: "meta", text: quest.note }));
  if (asList(quest.noteItems).length) kids.push(el("ul", { class: "loot" }, asList(quest.noteItems).map(renderLootItem)));
  return el("article", { class: "quest" }, kids);
}

function renderDungeons() {
  const root = document.getElementById("dungeon-list");
  const note = document.getElementById("dungeon-source");
  if (!root || !note) return;
  const scroller = document.scrollingElement;
  const scrollY = scroller ? scroller.scrollTop : 0;
  const focusId = document.activeElement && document.activeElement.getAttribute("data-loot-id");
  root.replaceChildren();
  const journal = state.dungeons;
  if (!journal || !asList(journal.dungeons).length) {
    note.textContent = "No journal yet. Install Forever Dungeon Journal, run scripts/scan-addons.ps1, then commit data/dungeons.json.";
    return;
  }
  const q = nameKey(state.dungeonQuery);
  const version = versionLabel(journal.version);
  note.textContent = `From ${journal.source}${version ? ` ${version}` : ""}. Beta loot can change.`;
  let shown = 0;
  asList(journal.dungeons).forEach((dungeon) => {
    const wholeDungeon = !q || nameKey(`${dungeon.name} ${dungeon.location}`).includes(q);
    const bosses = asList(dungeon.bosses).map((boss) => {
      const names = [boss.name, ...asList(boss.aliases)];
      const bossHit = wholeDungeon || names.some((name) => nameKey(name).includes(q));
      const loot = bossHit ? asList(boss.loot) : asList(boss.loot).filter((item) => itemMatches(item, q));
      return { boss, names, loot, show: bossHit || loot.length > 0 };
    }).filter((row) => row.show);
    const factionQuests = asList(dungeon.quests).filter(questFactionShown);
    const quests = wholeDungeon ? factionQuests : factionQuests.filter((quest) => {
      const hay = [quest.name, quest.objective, quest.pickup, quest.startItem && quest.startItem.name,
        ...asList(quest.rewardItems).map((item) => item.name)].join(" ");
      return nameKey(hay).includes(q);
    });
    if (!bosses.length && !quests.length) return;
    shown++;

    const allLoot = asList(dungeon.bosses).flatMap((boss) => asList(boss.loot));
    const gear = dungeonGear(dungeon);
    const inHand = gear.filter(lootInHand).length;
    const summaryBits = [
      dungeon.level ? `Level ${dungeon.level}` : "",
      dungeon.location,
      `${asList(dungeon.bosses).length} bosses`,
      `${allLoot.length} drops`,
      gear.length ? `${inHand} of ${gear.length} in hand` : ""
    ].filter(Boolean).join(" · ");
    const box = el("details", { class: "card dungeon" });
    box.open = !!q || state.openDungeons.has(dungeon.name);
    box.addEventListener("toggle", () => {
      if (q) return;
      if (box.open) state.openDungeons.add(dungeon.name);
      else state.openDungeons.delete(dungeon.name);
    });
    box.append(el("summary", {}, [
      el("h3", { text: dungeon.name }),
      el("span", { class: "meta", text: summaryBits })
    ]));
    if (dungeon.description) box.append(el("p", { class: "dungeon-blurb", text: dungeon.description }));

    if (bosses.length) {
      const grid = el("div", { class: "boss-grid" });
      bosses.forEach(({ boss, names, loot }) => {
        const kills = killLog(names);
        const aliases = asList(boss.aliases);
        grid.append(el("section", { class: "boss" }, [
          el("h4", { text: boss.name }),
          aliases.length || boss.note
            ? el("small", { text: [aliases.length ? `Also called ${aliases.join(", ")}` : "", boss.note].filter(Boolean).join(" · ") })
            : null,
          kills.total ? el("p", { class: "kill-log", text: `KillDex: ${kills.total} ${kills.total === 1 ? "kill" : "kills"}` }) : null,
          loot.length
            ? el("ul", { class: "loot" }, loot.map(renderLootItem))
            : el("p", { class: "meta", text: "No recorded drops." })
        ]));
      });
      box.append(el("h4", { class: "group-label", text: "Bosses and drops" }));
      box.append(grid);
    }

    const hidden = asList(dungeon.quests).length - factionQuests.length;
    if (quests.length || (wholeDungeon && hidden)) {
      box.append(el("h4", { class: "group-label" }, [
        el("span", { text: "Quests" }),
        hidden ? el("em", { text: `${hidden} for the other faction hidden` }) : null
      ]));
      if (quests.length) box.append(el("div", { class: "quest-list" }, quests.map(renderQuest)));
    }
    root.append(box);
  });
  if (!shown) root.append(el("p", { class: "empty-note", text: "Nothing in the journal matches that." }));
  if (scroller) scroller.scrollTop = scrollY;
  if (focusId) {
    const next = root.querySelector(`[data-loot-id="${CSS.escape(focusId)}"]`);
    if (next) next.focus();
  }
}

async function loadProfessions() {
  if (state.professions || state.profLoading) return;
  state.profLoading = true;
  try {
    state.professions = await loadJson("data/professions.json");
  } catch (error) {
    state.professions = { professions: {}, items: {}, missing: true };
    console.error(error);
  }
  state.profLoading = false;
  renderProfessions();
}

function itemName(id) {
  const items = (state.professions && state.professions.items) || {};
  return items[String(id)] || "";
}

function renderItemName(id, fallback) {
  const name = itemName(id) || fallback;
  if (name) return el("span", { text: name });
  return el("a", {
    href: `https://www.wowhead.com/classic/item=${id}`,
    target: "_blank",
    rel: "noreferrer",
    "data-wowhead": `item=${id}&domain=classic`,
    text: `Item ${id}`
  });
}

function craftDifficulty(craft, skill) {
  const [orange, yellow, green, grey] = asList(craft.levels);
  if (orange === undefined) return { id: "unknown", label: "" };
  if (skill < orange) return { id: "locked", label: `Needs ${orange}` };
  if (yellow !== undefined && skill < yellow) return { id: "orange", label: "Orange" };
  if (green !== undefined && skill < green) return { id: "yellow", label: "Yellow" };
  if (grey !== undefined && skill < grey) return { id: "green", label: "Green" };
  return { id: "grey", label: "Grey" };
}

function makeCount(craft, counts) {
  let most = Infinity;
  asList(craft.reagents).forEach(([id, need]) => {
    const have = Number(counts[String(id)]) || 0;
    most = Math.min(most, Math.floor(have / (Number(need) || 1)));
  });
  return Number.isFinite(most) ? most : 0;
}

function characterProfessions(character, live) {
  const all = Object.keys((state.professions && state.professions.professions) || {});
  const names = [...asList(character.professions)];
  Object.keys(live.crafts || {}).forEach((name) => { if (!names.includes(name)) names.push(name); });
  asList(live.professions).forEach((p) => { if (p && !names.includes(p.name)) names.push(p.name); });
  return names.filter((name) => all.includes(name));
}

function renderCraft(craft, known, skill, counts) {
  const difficulty = craftDifficulty(craft, skill);
  const quality = nameKey(craft.quality) || "common";
  const canMake = known ? makeCount(craft, counts) : 0;
  const head = el("div", { class: "craft-head" }, [
    el("span", { class: `diff diff-${difficulty.id}`, title: difficulty.label || null }),
    el("strong", { class: `item q-${quality}`, text: craft.makes ? `${craft.name} ×${craft.makes}` : craft.name }),
    difficulty.id === "locked" ? el("small", { text: difficulty.label }) : null,
    known && canMake ? el("span", { class: "badge medium", text: `Can make ${canMake}` }) : null
  ]);
  const reagents = el("ul", { class: "reagents" }, asList(craft.reagents).map(([id, need]) => {
    const have = Number(counts[String(id)]) || 0;
    return el("li", { class: have >= need ? "have" : "short" }, [
      el("span", { text: `${need}× ` }),
      renderItemName(id),
      el("small", { text: ` (${have})` })
    ]);
  }));
  const kids = [head, reagents];
  if (!known) {
    const learn = craft.learn || {};
    if (learn.how === "Recipe") {
      asList(learn.recipes).forEach((recipe) => {
        const name = itemName(recipe.id);
        const owned = name ? ownedNote({ name }) : "";
        kids.push(el("p", { class: "learn" }, [
          el("span", { text: "Learn from " }),
          renderItemName(recipe.id),
          owned ? el("span", { class: "owned-note", text: ` · ${owned}` }) : null,
          asList(recipe.where).length ? el("span", { class: "meta", text: ` · ${asList(recipe.where).join(" · ")}` }) : null
        ]));
      });
    } else {
      const where = asList(learn.where).join(", ");
      kids.push(el("p", { class: "learn", text: where ? `${learn.how}: ${where}` : learn.how || "Unknown" }));
    }
  }
  return el("article", { class: `craft${known ? " known" : ""}` }, kids);
}

function renderProfessions() {
  const root = document.getElementById("prof-list");
  const note = document.getElementById("prof-source");
  const picker = document.getElementById("prof-character");
  if (!root || !note || !picker || !state.characters.length) return;
  if (picker.options.length !== state.characters.length) {
    picker.replaceChildren(...state.characters.map((c) => el("option", { value: c.id, text: c.name })));
  }
  picker.value = state.selected;
  document.getElementById("prof-view").value = state.profView;
  root.replaceChildren();
  const skillsRoot = document.getElementById("prof-skills");
  if (skillsRoot) {
    const cards = Object.entries(ledgerCharacters()).map(([key, record]) => {
      const skills = asList(record.professions);
      return el("article", { class: "card" }, [
        el("h3", { text: key }),
        el("p", { text: skills.length ? skills.map((skill) => `${skill.name} ${skill.current}${skill.max ? `/${skill.max}` : ""}`).join("   ") : "No skills saved yet." })
      ]);
    });
    skillsRoot.replaceChildren(...(cards.length ? cards : [el("p", { class: "empty-note", text: "No profession skills saved yet. Log in on a character to record them." })]));
  }
  const data = state.professions;
  if (!data) {
    note.textContent = "Loading the craft list…";
    return;
  }
  if (data.missing) {
    note.textContent = "No craft list yet. Run scripts/scan-addons.ps1, then commit data/professions.json.";
    return;
  }
  const version = versionLabel(data.version);
  note.textContent = `Recipe list${version ? ` ${version}` : ""}. Reagent counts cover bags, bank, and mail.`;

  const character = selectedCharacter();
  const live = (state.stats.characters || {})[character.id] || {};
  const counts = live.itemCounts || {};
  const q = nameKey(state.profQuery);
  const names = characterProfessions(character, live);
  if (!names.length) {
    root.append(el("p", { class: "empty-note", text: `${character.name} has no professions on record yet.` }));
    return;
  }
  names.forEach((name) => {
    const crafts = asList(data.professions[name]);
    const knownIds = new Set(asList((live.crafts || {})[name]).map(Number));
    const skillRow = asList(live.professions).find((p) => p && p.name === name);
    const skill = skillRow ? Number(skillRow.current) || 0 : 0;
    const known = crafts.filter((craft) => knownIds.has(craft.id));
    const makeable = known.filter((craft) => makeCount(craft, counts) > 0);
    let rows = state.profView === "known" ? known
      : state.profView === "make" ? makeable
      : state.profView === "learn" ? crafts.filter((craft) => !knownIds.has(craft.id) && (craft.learn || {}).how !== "Not available")
      : crafts;
    if (q) {
      rows = rows.filter((craft) => {
        const reagentNames = asList(craft.reagents).map(([id]) => itemName(id)).join(" ");
        return nameKey(`${craft.name} ${reagentNames}`).includes(q);
      });
    }
    rows = [...rows].sort((a, b) => (asList(a.levels)[0] || 0) - (asList(b.levels)[0] || 0) || a.name.localeCompare(b.name));

    const skillText = skillRow ? (skillRow.max ? `${skill}/${skillRow.max}` : `${skill}`) : "not learned";
    const box = el("section", { class: "card profession" });
    box.append(el("div", { class: "who" }, [
      el("h3", { text: name }),
      el("span", { class: "meta", text: [skillText, `${known.length} of ${crafts.length} known`, makeable.length ? `${makeable.length} can make now` : ""].filter(Boolean).join(" · ") })
    ]));
    if (!rows.length) {
      const empty = state.profView === "known" ? "None known yet. Opening this profession's window in game updates the list."
        : state.profView === "make" ? "Nothing to make from what is in the bags."
        : "Nothing here.";
      box.append(el("p", { class: "empty-note", text: q ? "Nothing matches that search." : empty }));
    } else {
      const shown = rows.slice(0, 200);
      box.append(el("div", { class: "craft-list" }, shown.map((craft) => renderCraft(craft, knownIds.has(craft.id), skill, counts))));
      if (rows.length > shown.length) box.append(el("p", { class: "meta", text: `Showing the first ${shown.length} of ${rows.length}. Search to narrow it.` }));
    }
    root.append(box);
  });
  if (window.$WowheadPower && typeof window.$WowheadPower.refreshLinks === "function") window.$WowheadPower.refreshLinks();
}

async function loadMacros() {
  if (state.macros || state.macroLoading) return;
  state.macroLoading = true;
  try {
    state.macros = await loadJson("data/macros.json");
  } catch (error) {
    state.macros = [];
    console.error(error);
  }
  state.macroLoading = false;
  renderMacros();
}

async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch (error) {
    const box = el("textarea", { readonly: "", style: "position:fixed;opacity:0" });
    box.value = text;
    document.body.append(box);
    box.select();
    const ok = document.execCommand("copy");
    box.remove();
    return ok;
  }
}

function renderMacro(macro) {
  const text = asList(macro.lines).join("\n");
  const owner = state.characters.find((c) => c.id === macro.character);
  const copy = el("button", { type: "button", class: "macro-copy", text: "Copy" });
  copy.addEventListener("click", async () => {
    copy.textContent = (await copyText(text)) ? "Copied" : "Select and copy";
    setTimeout(() => { copy.textContent = "Copy"; }, 1500);
  });
  return el("article", { class: "macro" }, [
    el("div", { class: "macro-head" }, [
      el("img", {
        class: "macro-icon",
        src: `https://wow.zamimg.com/images/wow/icons/large/${macro.icon || "inv_misc_questionmark"}.jpg`,
        alt: "",
        width: "40",
        height: "40",
        loading: "lazy"
      }),
      el("strong", { text: macro.name }),
      el("span", {
        class: macro.scope === "character" ? "badge medium" : "badge",
        text: macro.scope === "character" ? (owner ? owner.name : "Character") : "Shared"
      }),
      copy
    ]),
    el("pre", { class: "macro-body", text }),
    macro.note ? el("p", { class: "meta", text: macro.note }) : null
  ]);
}

function renderMacros() {
  const root = document.getElementById("macro-list");
  const note = document.getElementById("macro-source");
  const picker = document.getElementById("macro-character");
  if (!root || !note || !picker || !state.characters.length) return;
  if (picker.options.length !== state.characters.length) {
    picker.replaceChildren(...state.characters.map((c) => el("option", { value: c.id, text: c.name })));
  }
  picker.value = state.selected;
  root.replaceChildren();
  if (!state.macros) {
    note.textContent = "Loading macros…";
    return;
  }
  const who = state.characters.find((c) => c.id === state.selected);
  const shared = state.macros.filter((m) => m.scope !== "character");
  const own = state.macros.filter((m) => m.scope === "character" && m.character === state.selected);
  note.textContent = "Shared macros work on every character on the account. Character macros belong to one toon.";
  const groups = [
    { label: "Shared", rows: shared, empty: "No shared macros yet." },
    { label: `${who ? who.name : "Character"} only`, rows: own, empty: "No character macros for this toon yet." }
  ];
  groups.forEach((group) => {
    root.append(el("h3", { class: "group-label" }, [
      el("span", { text: group.label }),
      el("em", { text: `${group.rows.length} ${group.rows.length === 1 ? "macro" : "macros"}` })
    ]));
    root.append(group.rows.length
      ? el("div", { class: "macro-list" }, group.rows.map(renderMacro))
      : el("p", { class: "empty-note", text: group.empty }));
  });
}

function showTab(id) {
  if (!TABS.includes(id)) id = "roster";
  state.tab = id;
  saveStore();
  document.querySelectorAll(".tab").forEach((tab) => {
    const on = tab.dataset.tab === id;
    tab.setAttribute("aria-selected", on ? "true" : "false");
    tab.tabIndex = on ? 0 : -1;
  });
  document.querySelectorAll("[data-panel]").forEach((panel) => {
    panel.hidden = panel.dataset.panel !== id;
  });
  if (id === "professions") loadProfessions();
  if (id === "quests") loadQuests();
  if (id === "macros") loadMacros();
  const url = new URL(location.href);
  url.hash = id === "roster" ? "" : id;
  history.replaceState(null, "", url);
}

function bindTabs() {
  document.querySelectorAll(".tab").forEach((tab) => {
    tab.addEventListener("click", () => showTab(tab.dataset.tab));
  });
  document.querySelector(".tabs").addEventListener("keydown", (event) => {
    if (event.key !== "ArrowRight" && event.key !== "ArrowLeft") return;
    event.preventDefault();
    const tabs = [...document.querySelectorAll(".tab")];
    const index = tabs.findIndex((tab) => tab.getAttribute("aria-selected") === "true");
    const step = event.key === "ArrowRight" ? 1 : -1;
    const next = tabs[(index + step + tabs.length) % tabs.length];
    next.focus();
    showTab(next.dataset.tab);
  });
}

function questCatalog() {
  const rows = asList(state.quests && state.quests.quests);
  const byId = new Map();
  rows.forEach((quest) => {
    if (quest && quest.id != null) byId.set(Number(quest.id), quest);
  });
  return byId;
}

async function loadQuests() {
  if (state.quests || state.questLoading) return;
  state.questLoading = true;
  try {
    state.quests = await loadJson("data/quests.json");
  } catch {
    state.quests = { quests: [], missing: true };
  }
  state.questLoading = false;
  renderQuests();
}

function renderFinishedQuest(quest) {
  const bits = [quest.level ? `Level ${quest.level}` : "", quest.turnedIn ? `Turned in ${quest.turnedIn}` : ""].filter(Boolean);
  return el("article", { class: "quest" }, [
    el("strong", { text: quest.name }),
    bits.length ? el("small", { text: bits.join(" · ") }) : null
  ]);
}

function renderQuests() {
  const root = document.getElementById("quest-list");
  const note = document.getElementById("quest-source");
  const picker = document.getElementById("quest-character");
  if (!root || !note || !picker || !state.characters.length) return;
  if (picker.options.length !== state.characters.length) {
    picker.replaceChildren(...state.characters.map((c) => el("option", { value: c.id, text: c.name })));
  }
  picker.value = state.selected;
  root.replaceChildren();
  const data = state.quests;
  if (!data) {
    note.textContent = "Loading finished quests…";
    return;
  }
  const character = selectedCharacter();
  const live = (state.stats.characters || {})[character.id] || {};
  const done = asList(live.completedQuests).map(Number).filter((id) => id);
  if (!Object.prototype.hasOwnProperty.call(live, "completedQuests")) {
    note.textContent = "No quest scan yet. Log out or /reload, then run the addon scan.";
    return;
  }
  const version = versionLabel(data.version);
  note.textContent = `From ${data.source || "Questie"}${version ? ` ${version}` : ""}. ${character.name} has ${done.length} finished ${done.length === 1 ? "quest" : "quests"}.`;
  if (!done.length) {
    root.append(el("p", { class: "empty-note", text: "No finished quests on this scan." }));
    return;
  }
  const catalog = questCatalog();
  const turnedIn = new Map();
  characterLedgerKeys(character).forEach((key) => {
    asList(ledgerCharacters()[key] && ledgerCharacters()[key].quests).forEach((quest) => {
      const id = Number(quest.questID);
      if (id && quest.time) turnedIn.set(id, formatWhen(quest.time));
    });
  });
  const q = nameKey(state.questQuery);
  const rows = done.map((id) => {
    const known = catalog.get(id);
    return {
      id,
      name: known && known.name ? known.name : `Quest ${id}`,
      level: known && known.level ? known.level : null,
      zone: known && known.zone ? known.zone : "Other",
      turnedIn: turnedIn.get(id) || ""
    };
  }).filter((quest) => !q || nameKey(`${quest.name} ${quest.zone}`).includes(q));
  if (!rows.length) {
    root.append(el("p", { class: "empty-note", text: "Nothing matches that search." }));
    return;
  }
  const zones = new Map();
  rows.forEach((quest) => {
    if (!zones.has(quest.zone)) zones.set(quest.zone, []);
    zones.get(quest.zone).push(quest);
  });
  [...zones.keys()].sort((a, b) => {
    if (a === "Other") return 1;
    if (b === "Other") return -1;
    return a.localeCompare(b);
  }).forEach((zone) => {
    const quests = zones.get(zone).sort((a, b) => (a.level || 0) - (b.level || 0) || a.name.localeCompare(b.name));
    const box = el("section", { class: "card quest-zone" });
    box.append(el("div", { class: "who" }, [
      el("h3", { text: zone }),
      el("span", { class: "meta", text: `${quests.length} finished` })
    ]));
    box.append(el("div", { class: "quest-list" }, quests.map(renderFinishedQuest)));
    root.append(box);
  });
}

function ledgerCharacters() {
  const table = state.ledger && state.ledger.characters;
  return table && typeof table === "object" ? table : {};
}

function characterLedgerKeys(character) {
  const first = String(character && character.name || "").split(" ")[0].toLowerCase();
  if (!first) return [];
  return Object.keys(ledgerCharacters()).filter((key) => key.split("-")[0].toLowerCase() === first);
}

function ledgerRecord(character) {
  const keys = characterLedgerKeys(character);
  return keys.length ? ledgerCharacters()[keys[0]] : null;
}

function formatWhen(seconds) {
  const n = Number(seconds);
  if (!n) return "";
  return new Date(n * 1000).toLocaleString(undefined, { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" });
}

function lockoutCard(key, lockouts) {
  const saved = asList(lockouts.saved);
  const runs = asList(lockouts.runs);
  const savedNodes = saved.length ? saved.map((entry) => {
    const progress = Number(entry.progress) || 0;
    const encounters = Number(entry.encounters) || 0;
    const ratio = encounters > 0 ? Math.min(100, Math.round((progress / encounters) * 100)) : 0;
    const done = encounters > 0 && progress >= encounters;
    const detail = [entry.difficulty, entry.resetText].filter(Boolean).join(" · ");
    return el("div", { class: "lock-row" }, [
      el("div", { class: "lock-top" }, [
        el("strong", { text: entry.name || "Instance" }),
        el("span", { text: encounters > 0 ? `${progress}/${encounters}` : "" })
      ]),
      detail ? el("p", { class: "meta", text: detail }) : null,
      el("div", { class: "lock-bar", "aria-hidden": "true" }, [
        el("div", { style: `width:${ratio}%;background:${done ? "var(--teal)" : "var(--gold)"}` })
      ])
    ]);
  }) : [el("p", { class: "meta", text: "No saved instances." })];
  const runNodes = runs.length ? runs.map((run) => {
    const levels = run.levelFrom && run.levelTo && run.levelTo !== run.levelFrom ? `${run.levelFrom} to ${run.levelTo}` : "";
    const gold = Number(run.gold);
    return el("div", { class: "lock-run" }, [
      el("span", { class: "when", text: formatWhen(run.entered) || "—" }),
      el("span", { class: "name", text: run.name || "Instance" }),
      el("span", { text: formatPlayed(run.seconds) }),
      levels ? el("span", { class: "muted", text: levels }) : null,
      gold ? el("span", { text: formatGold(gold) }) : null,
      Number(run.mobs) > 0 ? el("span", { class: "muted", text: `${run.mobs} kills` }) : null
    ]);
  }) : [el("p", { class: "meta", text: "No instance runs yet." })];
  return el("article", { class: "card lock-card" }, [
    el("h3", { text: key }),
    el("h4", { text: "Saved now" }),
    ...savedNodes,
    el("h4", { text: "Recent runs" }),
    ...runNodes
  ]);
}

function renderLedgerBoards() {
  const book = state.ledger || {};
  const people = ledgerCharacters();
  const names = Object.keys(people).sort();
  const empty = names.length ? "" : "No ledger save yet. Log out in game, then run scripts/scan-addons.ps1.";
  const card = (title, lines) => el("article", { class: "card" }, [
    el("h3", { text: title }),
    ...lines.map((line) => el("p", { text: line }))
  ]);

  const ledgerRoot = document.getElementById("ledger-list");
  const ledgerNote = document.getElementById("ledger-note");
  if (ledgerRoot && ledgerNote) {
    ledgerNote.textContent = empty || `Gold for ${names.length} characters.`;
    ledgerRoot.replaceChildren(...names.map((key) => {
      const rows = asList(people[key].gold).slice(0, 12);
      return card(key, rows.length ? rows.map((row) => `${formatWhen(row.time)}  ${row.source || "other"}  ${formatGold(row.delta)}${row.detail ? `  ${row.detail}` : ""}`) : ["No gold changes saved."]);
    }));
  }

  const currencyRoot = document.getElementById("currencies-list");
  const currencyNote = document.getElementById("currencies-note");
  if (currencyRoot && currencyNote) {
    currencyNote.textContent = empty || "Latest currency totals.";
    currencyRoot.replaceChildren(...names.map((key) => {
      const rows = asList(people[key].currencies);
      return card(key, rows.length ? rows.map((row) => `${row.name}  ${row.quantity}`) : ["No currencies saved."]);
    }));
  }

  const repRoot = document.getElementById("reputation-list");
  const repNote = document.getElementById("reputation-note");
  if (repRoot && repNote) {
    repNote.textContent = empty || "Latest reputation standings.";
    repRoot.replaceChildren(...names.map((key) => {
      const rows = asList(people[key].reputations);
      return card(key, rows.length ? rows.map((row) => `${row.name}  ${row.standing || row.value || ""}`.trim()) : ["No reputation saved."]);
    }));
  }

  const mailRoot = document.getElementById("mail-list");
  const mailNote = document.getElementById("mail-note");
  if (mailRoot && mailNote) {
    mailNote.textContent = empty || "Sent and received letters.";
    mailRoot.replaceChildren(...names.map((key) => {
      const rows = asList(people[key].mail);
      return card(key, rows.length ? rows.map((letter) => `${formatWhen(letter.time)}  ${letter.direction || ""}  ${letter.who || ""}  ${letter.subject || ""}  ${formatGold(letter.gold || 0)}  ${letter.status || ""}`) : ["No mail recorded yet."]);
    }));
  }

  const rareRoot = document.getElementById("rares-list");
  const rareNote = document.getElementById("rares-note");
  if (rareRoot && rareNote) {
    const rares = asList(book.rares);
    rareNote.textContent = rares.length ? `${rares.length} rares recorded.` : "No rares recorded yet.";
    rareRoot.replaceChildren(...rares.map((rare) => {
      const place = rare.x != null && rare.y != null ? `${rare.zone || "Unknown zone"} ${Number(rare.x).toFixed(1)}, ${Number(rare.y).toFixed(1)}` : (rare.zone || "Unknown zone");
      const loot = asList(rare.loot);
      return card(`${rare.name || "Rare"}  ${rare.character || ""}`, [
        `${rare.kills || 0}  ${place}`,
        loot.length ? loot.join(", ") : "No drops recorded yet."
      ]);
    }));
  }

  const lockRoot = document.getElementById("lockouts-list");
  const lockNote = document.getElementById("lockouts-note");
  if (lockRoot && lockNote) {
    lockNote.textContent = empty || "Saved instances and recent runs.";
    lockRoot.replaceChildren(...names.map((key) => lockoutCard(key, people[key].lockouts || {})));
  }

  const sessionRoot = document.getElementById("sessions-list");
  const sessionNote = document.getElementById("sessions-note");
  if (sessionRoot && sessionNote) {
    sessionNote.textContent = empty || "Finished sessions.";
    sessionRoot.replaceChildren(...names.map((key) => {
      const rows = asList(people[key].sessions);
      return card(key, rows.length ? rows.map((entry) => `${formatWhen(entry.start)}  ${entry.zone || ""}  ${entry.seconds || 0}s  ${formatGold(entry.gold || 0)}  ${entry.xp || 0} XP`) : ["No finished sessions yet."]);
    }));
  }

  const taskRoot = document.getElementById("tasks-list");
  const taskNote = document.getElementById("tasks-note");
  if (taskRoot && taskNote) {
    const who = selectedCharacter();
    const tasks = asList(state.tasks);
    const cadenceLabel = {
      daily: "Each day",
      weekly: "Each week",
      monthly: "Each month",
      yearly: "Each year",
      once: "Just once"
    };
    if (!state.sheetLive) taskNote.textContent = "The sheet did not load, so there is no task list.";
    else if (!tasks.length) taskNote.textContent = "No tasks on the sheet yet.";
    else taskNote.textContent = who ? `Checks for ${who.name}.` : "Checks for this character.";
    const taskLine = (task) => {
      const done = !!(state.taskChecks[task.id] && state.taskChecks[task.id][state.selected]);
      const box = el("input", { type: "checkbox", "aria-label": `Done: ${task.name || "Task"}` });
      box.checked = done;
      box.addEventListener("change", () => {
        if (!state.taskChecks[task.id]) state.taskChecks[task.id] = {};
        state.taskChecks[task.id][state.selected] = box.checked;
        renderLedgerBoards();
        commitTask(task.id, box.checked, done);
      });
      const cadence = cadenceLabel[task.cadence] || task.cadence || "Just once";
      const place = task.zone ? ` · ${task.zone}` : "";
      return el("div", { class: "task-row" }, [
        box,
        el("div", {}, [
          el("strong", { text: task.name || "Task" }),
          el("span", { text: `${cadence}${place}` }),
          task.notes ? el("p", { class: "meta", text: task.notes }) : null
        ])
      ]);
    };
    const taskCard = el("article", { class: "card task-board" }, [
      el("h3", { text: who ? who.name : "Tasks" }),
      ...(tasks.length ? tasks.map(taskLine) : [el("p", { class: "meta", text: "Nothing on the list." })])
    ]);
    const noteCards = names.map((key) => {
      const notes = asList(people[key].notes);
      return el("article", { class: "card task-board" }, [
        el("h3", { text: key }),
        el("h4", { text: "Notes" }),
        notes.length ? el("div", { class: "note-grid" }, notes.map((note) => el("div", { class: "note-card" }, [
          note.title ? el("strong", { text: note.title }) : null,
          el("p", { text: note.text || "" })
        ].filter(Boolean)))) : el("p", { class: "meta", text: "No notes yet." })
      ]);
    });
    taskRoot.replaceChildren(taskCard, ...noteCards);
  }
}

function renderAltoholic() {
  const note = document.getElementById("alto-note");
  const picker = document.getElementById("alto-character");
  const sheet = document.getElementById("alto-sheet");
  if (!note || !picker || !sheet) return;
  const people = asList(state.altoholic && state.altoholic.characters);
  if (!people.length) {
    note.textContent = "No Altoholic save yet. Log out in game, then run scripts/scan-addons.ps1.";
    picker.replaceChildren();
    sheet.replaceChildren();
    return;
  }
  if (!people.some((person) => person.name === state.altoName)) state.altoName = people[0].name;
  picker.replaceChildren(...people.map((person) => el("option", {
    value: person.name,
    text: person.realm ? `${person.name} · ${person.realm}` : person.name,
    selected: person.name === state.altoName ? "selected" : null
  })));
  const person = people.find((row) => row.name === state.altoName) || people[0];
  const when = state.altoholic.updated ? state.altoholic.updated.replace("T", " ") : "an unknown time";
  note.textContent = `Saved by Altoholic at ${when}.`;
  const place = [person.subZone, person.zone].filter(Boolean).join(", ");
  const identity = [`Level ${person.level || "?"}`, person.race, person.class].filter(Boolean).join(" ");
  const professions = asList(person.professions);
  const gear = asList(person.gear);
  const bags = asList(person.bags);
  const stats = person.stats && typeof person.stats === "object" ? person.stats : null;
  const questGroups = asList(person.quests);
  const reputations = asList(person.reputations);
  const currencies = asList(person.currencies);
  const mail = asList(person.mail);
  const bar = (label, value, max, right) => {
    const ratio = max > 0 ? Math.min(100, Math.round((value / max) * 100)) : 0;
    return el("div", { class: "lock-row" }, [
      el("div", { class: "lock-top" }, [
        el("strong", { text: label }),
        el("span", { text: right || (max > 0 ? `${value}/${max}` : "") })
      ]),
      el("div", { class: "lock-bar", "aria-hidden": "true" }, [
        el("div", { style: `width:${ratio}%;background:var(--gold)` })
      ])
    ]);
  };
  sheet.replaceChildren(el("article", { class: "card lock-card alto-sheet" }, [
    el("h3", { text: person.name }),
    el("p", { class: "alto-meta" }, [
      el("strong", { text: identity }),
      document.createTextNode(place ? ` · ${place}` : ""),
      document.createTextNode(` · ${formatGold(person.gold || 0)}`),
      person.played ? document.createTextNode(` · ${formatPlayed(person.played)} played`) : null,
      person.itemLevel ? document.createTextNode(` · item level ${person.itemLevel}`) : null,
      person.rested ? document.createTextNode(" · rested") : null
    ].filter(Boolean)),
    el("h4", { text: "Gear" }),
    ...(gear.length ? [el("div", { class: "alto-gear" }, gear.map((piece) => el("div", { class: "lock-run" }, [
      el("span", { class: "muted", text: piece.slot }),
      el("span", { class: "name", text: piece.name })
    ])))] : [el("p", { class: "meta", text: "No gear saved. Open the character sheet in game." })]),
    el("h4", { text: "Bags" }),
    ...(bags.length ? bags.map((bag) => el("div", { class: "alto-bag" }, [
      el("h5", { text: bag.name }),
      el("ul", { class: "alto-items" }, asList(bag.items).map((item) => {
        const count = Number(item.count) || 1;
        return el("li", { text: count > 1 ? `${count} ${item.name}` : item.name });
      }))
    ])) : [el("p", { class: "meta", text: "No bags saved. Open the bags in game." })]),
    el("h4", { text: "Stats" }),
    stats ? el("div", { class: "alto-stats" }, [
      ["Health", stats.health],
      [stats.powerType || "Power", stats.power],
      ["Strength", stats.strength],
      ["Agility", stats.agility],
      ["Stamina", stats.stamina],
      ["Intellect", stats.intellect],
      ["Armor", stats.armor],
      ["Melee", stats.melee],
      ["Attack power", stats.attackPower],
      ["Spell damage", stats.spellDamage],
      ["Healing", stats.spellHealing],
      ["Spell crit", stats.spellCrit ? `${stats.spellCrit}%` : ""]
    ].filter((pair) => pair[1] !== null && pair[1] !== undefined && pair[1] !== "").map((pair) => el("span", { text: `${pair[0]} ${pair[1]}` }))) : el("p", { class: "meta", text: "No stat snapshot saved." }),
    el("h4", { text: "Quest log" }),
    ...(questGroups.length ? questGroups.map((group) => el("div", { class: "alto-bag" }, [
      el("h5", { text: group.zone }),
      el("ul", { class: "alto-items" }, asList(group.quests).map((quest) => el("li", {
        text: quest.ready ? `${quest.name} · ready` : quest.name
      })))
    ])) : [el("p", { class: "meta", text: "No quests in the log." })]),
    el("h4", { text: "Professions" }),
    ...(professions.length ? professions.map((skill) => {
      const value = Number(skill.rank) || 0;
      const max = Number(skill.max) || 0;
      return bar(skill.name, value, max > 0 ? max : Math.max(value, 1), max > 0 ? `${value}/${max}` : String(value));
    }) : [el("p", { class: "meta", text: "No profession ranks saved." })]),
    el("h4", { text: "Reputation" }),
    ...(reputations.length ? reputations.map((row) => el("div", { class: "lock-run" }, [
      el("span", { class: "name", text: row.name }),
      el("span", { text: row.standing || "" }),
      row.next ? el("span", { class: "muted", text: `${row.progress || 0}/${row.next}` }) : null
    ])) : [el("p", { class: "meta", text: "No reputation saved." })]),
    el("h4", { text: "Currencies" }),
    ...(currencies.length ? currencies.map((row) => el("div", { class: "lock-run" }, [
      el("span", { class: "name", text: row.name }),
      el("span", { text: String(row.quantity) })
    ])) : [el("p", { class: "meta", text: "No currencies saved." })]),
    el("h4", { text: "Mail" }),
    ...(mail.length ? mail.map((letter) => el("div", { class: "lock-run" }, [
      el("span", { class: "name", text: letter.sender || "Unknown" }),
      el("span", { text: letter.subject || "" }),
      Number(letter.money) ? el("span", { text: formatGold(letter.money) }) : null,
      letter.daysLeft ? el("span", { class: "muted", text: `${letter.daysLeft} days left` }) : null
    ])) : [el("p", { class: "meta", text: "No mail saved. Open a mailbox on that character." })])
  ]));
}

function render() {
  renderHouse();
  renderRoster();
  renderSheet();
  renderChecklist();
  renderLedgerBoards();
  renderAltoholic();
  renderProfessions();
  renderDungeons();
  renderQuests();
  renderMacros();
}

async function loadJson(path) {
  const response = await fetch(path, { cache: "no-cache" });
  if (!response.ok) throw new Error(`${path} ${response.status}`);
  return response.json();
}

function applySheet(live) {
  state.stats = live.stats;
  state.checklist = live.checklist;
  state.checks = live.checks || {};
  state.attempts = live.attempts || {};
  state.tasks = live.tasks || [];
  state.taskChecks = live.taskChecks || {};
  state.sheetLive = true;
}

async function reloadSheet() {
  if (!state.sheetLive || state.sheetWriting || !window.SheetStore) return;
  const live = await SheetStore.loadLive();
  if (!live) {
    noteSheet("The sheet did not refresh.");
    return;
  }
  applySheet(live);
  buildOwned();
  buildDrops();
  noteSheet("");
  render();
}

function bindSheetSettings() {
  const url = document.getElementById("sheet-script-url");
  const secret = document.getElementById("sheet-secret");
  const note = document.getElementById("sheet-write-note");
  const button = document.getElementById("sheet-save-write");
  if (!url || !secret || !button || !window.SheetStore) return;
  const saved = SheetStore.readWriteSettings();
  url.value = saved.scriptUrl || "";
  secret.value = saved.writeSecret || "";
  if (note && SheetStore.writeSource() === "file") {
    note.textContent = "This computer is using data/sheet.local.json for writes. The fields below are for a browser that does not have that file.";
  }
  button.addEventListener("click", () => {
    SheetStore.saveWriteSettings(url.value.trim(), secret.value);
    if (!note) return;
    note.textContent = SheetStore.writeSource() === "file"
      ? "Saved in this browser. data/sheet.local.json still wins on the next load here."
      : "Saved in this browser.";
  });
}

async function main() {
  loadStore();
  const params = new URLSearchParams(location.search);
  const hash = location.hash.replace("#", "");
  if (TABS.includes(hash)) state.tab = hash;
  if (params.get("c")) state.selected = params.get("c");
  bindTabs();
  showTab(state.tab);
  try {
    const [house, characters, checklist, stats, addons, ledger, altoholic, screenshots, dungeons, books] = await Promise.all([
      loadJson("data/house.json"),
      loadJson("data/characters.json"),
      loadJson("data/checklist.json"),
      loadJson("data/stats.json"),
      loadJson("data/addons.json").catch(() => null),
      loadJson("data/ledger.json").catch(() => ({ characters: {}, rares: [] })),
      loadJson("data/altoholic.json").catch(() => ({ characters: [] })),
      loadJson("data/screenshots.json").catch(() => []),
      loadJson("data/dungeons.json").catch(() => null),
      loadJson("data/library-books.json").catch(() => null)
    ]);
    state.books = books;
    state.house = house;
    state.characters = characters;
    state.checklist = checklist;
    state.stats = stats;
    state.addons = addons;
    state.ledger = ledger;
    state.altoholic = altoholic;
    state.screenshots = screenshots;
    state.dungeons = dungeons;
    const live = window.SheetStore ? await SheetStore.loadLive() : null;
    if (live) applySheet(live);
    else {
      state.sheetLive = false;
      state.checks = {};
      state.attempts = {};
      state.tasks = [];
      state.taskChecks = {};
    }
    buildOwned();
    buildDrops();
  } catch (error) {
    document.getElementById("lede").textContent = "The tracker data did not load. Open the GitHub Pages site, or serve this folder over http.";
    console.error(error);
    return;
  }
  const explicit = params.get("c");
  const chosen = state.characters.find((c) => c.id === state.selected);
  const asked = explicit && state.characters.some((c) => c.id === explicit);
  if (!chosen || (!asked && chosen.betaSafe === false)) {
    const standIn = state.characters.find((c) => c.id === "flann")
      || state.characters.find((c) => c.betaSafe);
    if (standIn) state.selected = standIn.id;
  }
  saveStore();
  document.getElementById("scope").value = state.scope;
  fillPlaceOptions();
  document.getElementById("place").addEventListener("change", (event) => {
    state.place = event.target.value;
    saveStore();
    renderChecklist();
  });
  document.getElementById("search").addEventListener("input", (event) => {
    state.query = event.target.value;
    renderChecklist();
  });
  document.getElementById("prof-character").addEventListener("change", (event) => selectCharacter(event.target.value));
  document.getElementById("macro-character").addEventListener("change", (event) => selectCharacter(event.target.value));
  document.getElementById("prof-view").addEventListener("change", (event) => {
    state.profView = event.target.value;
    saveStore();
    renderProfessions();
  });
  document.getElementById("prof-search").addEventListener("input", (event) => {
    state.profQuery = event.target.value;
    renderProfessions();
  });
  document.getElementById("dungeon-search").addEventListener("input", (event) => {
    state.dungeonQuery = event.target.value;
    renderDungeons();
  });
  document.getElementById("quest-character")?.addEventListener("change", (event) => selectCharacter(event.target.value));
  document.getElementById("alto-character")?.addEventListener("change", (event) => {
    state.altoName = event.target.value;
    renderAltoholic();
  });
  document.getElementById("quest-search")?.addEventListener("input", (event) => {
    state.questQuery = event.target.value;
    renderQuests();
  });
  document.getElementById("scope").addEventListener("change", (event) => {
    state.scope = event.target.value;
    saveStore();
    renderChecklist();
  });
  bindSheetSettings();
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") reloadSheet();
  });
  render();
}

main();
