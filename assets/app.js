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

const TABS = ["roster", "hunts", "journey", "journal", "mail", "altoholic", "professions", "lockouts", "tasks", "dungeons", "quests", "macros", "guild"];

const HUNT_GROUPS = [
  { id: "collections", label: "Collections", types: ["collection"] },
  { id: "gear", label: "Gear hunts", types: ["gear"] },
  { id: "missions", label: "Class missions", types: ["mission"] },
  { id: "other", label: "Other", types: [] }
];

const state = {
  characters: [],
  checklist: [],
  journey: null,
  journeyChecks: {},
  backstories: null,
  journals: null,
  journalView: "picked",
  launch: null,
  guild: null,
  stats: { updated: null, characters: {} },
  addons: null,
  dungeons: null,
  dungeonQuery: "",
  quests: null,
  questLoading: false,
  questQuery: "",
  publicChars: null,
  guides: [],
  att: null,
  rarity: null,
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
  selected: "",
  scope: "character",
  place: "",
  query: "",
  type: "",
  openId: "",
  tab: "roster",
  checks: {},
  attempts: {},
  tasks: [],
  taskChecks: {}
};

function loadStore() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORE_KEY) || "{}");
    if (saved.selected) state.selected = saved.selected;
    if (saved.scope) state.scope = saved.scope;
    if (["picked", "all"].includes(saved.journalView)) state.journalView = saved.journalView;
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
    tab: state.tab,
    journalView: state.journalView
  }));
}

// The Google Sheet is retired (see the footer): hunt, attempt and task
// checks live only in this page view. Toggling updates the board;
// reloading resets to the saved copy. The commit functions below are
// kept as no-ops so every toggle call site behaves the same.

function manualChecked(id, characterId) {
  const row = state.checks[id];
  return !!(row && row[characterId]);
}

function writeLocalCheck(id, characterId, checked) {
  if (!state.checks[id]) state.checks[id] = {};
  state.checks[id][characterId] = !!checked;
  persistHunts();
}

var HUNT_STORE_KEY = 'wow-forever-hunts-v2';
var HUNT_STORE_KEY_V1 = 'wow-forever-hunts-v1';

// Collection checks are account-wide: one shared check per hunt, keyed by
// hunt alone. Gear and mission checks stay per character.
var ACCOUNT_CHECK = "*";

function huntBucket(item) {
  return item.type === "collection" || item.type === "gear" || item.type === "mission" ? item.type : "";
}

// Display category. checklist.json carries kind (the pre-#39 type); fall
// back to a non-bucket type so older files still label themselves.
function huntKind(item) {
  if (item.kind) return item.kind;
  if (item.type && huntBucket(item) !== item.type) return item.type;
  return "";
}

function checkKey(item) {
  return huntBucket(item) === "collection" ? ACCOUNT_CHECK : state.selected;
}

// Tri-state manual read: true / false / null when nothing was recorded,
// so defaults apply only when the hunter never touched the box.
function manualState(id, key) {
  const row = state.checks[id];
  if (!row || !Object.prototype.hasOwnProperty.call(row, key)) return null;
  return !!row[key];
}

// Best-effort v1 -> v2 migration. Checks whose hunt id survives unchanged
// carry over: gear and mission checks keep their per-character shape,
// collection checks collapse to one account-wide check (checked wins when
// several characters had it checked). Attempts carry over untouched.
// Anything unmapped (unknown hunt id) is dropped and reported.
function migrateV1Checks(saved) {
  const out = { checks: {}, attempts: {}, dropped: [] };
  if (saved.attempts && typeof saved.attempts === "object") out.attempts = saved.attempts;
  const rows = (saved.checks && typeof saved.checks === "object") ? saved.checks : {};
  const parentOf = {};
  state.checklist.forEach((item) => (item.parts || []).forEach((part) => { parentOf[part.id] = item; }));
  Object.keys(rows).forEach((id) => {
    const item = state.checklist.find((hunt) => hunt.id === id);
    const parent = parentOf[id];
    if (!item && !parent) { out.dropped.push(id); return; }
    const bucket = huntBucket(item || parent);
    const values = rows[id] || {};
    if (bucket === "collection") {
      const keys = Object.keys(values);
      if (!keys.length) return;
      if (keys.some((key) => !!values[key])) out.checks[id] = { [ACCOUNT_CHECK]: true };
      else if (keys.some((key) => Object.prototype.hasOwnProperty.call(values, key) && !values[key])) {
        out.checks[id] = { [ACCOUNT_CHECK]: false };
      }
    } else {
      out.checks[id] = values;
    }
  });
  return out;
}

let attCache = null;

// Have-sets from the ATT public projection: account quest/source ids plus
// every Collection History timeline name (lowercased) and item id.
function attSets() {
  if (attCache) return attCache;
  const sets = { quests: new Set(), sources: new Set(), names: new Map(), itemIds: new Set() };
  const att = state.att;
  if (att && att.account) {
    (att.account.questsHave || []).forEach((id) => sets.quests.add(Number(id)));
    (att.account.sourcesHave || []).forEach((id) => sets.sources.add(Number(id)));
  }
  ((att && att.obtainedTimeline) || []).forEach((entry) => {
    if (entry && entry.name) sets.names.set(String(entry.name).trim().toLowerCase(), entry);
    if (entry && entry.itemId !== null && entry.itemId !== undefined) sets.itemIds.add(Number(entry.itemId));
  });
  attCache = sets;
  return sets;
}

// A curated collection want renders OBTAINED when its item/quest id lands
// in the ATT have-sets or the Collection History timeline. Returns the
// reason string, or "" when nothing matched (manual toggles then apply).
function isObtained(item) {
  if (huntBucket(item) !== "collection") return "";
  const sets = attSets();
  const match = item.match || {};
  for (const questId of match.questIds || []) {
    if (sets.quests.has(Number(questId))) return "Obtained (AllTheThings quest record).";
  }
  for (const itemId of match.itemIds || []) {
    if (sets.sources.has(Number(itemId)) || sets.itemIds.has(Number(itemId))) return "Obtained (AllTheThings).";
  }
  for (const name of match.names || []) {
    if (sets.names.has(String(name).trim().toLowerCase())) return "Obtained (ATT Collection History).";
  }
  return "";
}

function rarityFor(item) {
  if (!item.rarityId || !state.rarity) return null;
  const rows = state.rarity.items || [];
  return rows.find((entry) => entry.id === item.rarityId || entry.name === item.rarityId) || null;
}

// Attempts/time display beside a hunt. Rarity never decides obtained
// status; honest zeros render as zeros.
function rarityText(item) {
  const row = rarityFor(item);
  if (!row) return "";
  const n = Number(row.attempts);
  const tries = Number.isFinite(n) && n > 0 ? `${n} ${n === 1 ? "attempt" : "attempts"}` : "0 attempts";
  return `Rarity tracked: ${tries}${row.found ? ", found" : ""}`;
}

// Per-character completed quest set from the roster-gated ATT projection.
// Null when this character has no scan yet: missions then render an honest
// no-data state and light up once launch characters are scanned.
function characterQuestSet(characterId) {
  const rows = (state.att && state.att.characters) || [];
  const row = rows.find((entry) => entry.canonicalId === characterId);
  if (!row || !Array.isArray(row.questsHave)) return null;
  return new Set(row.questsHave.map(Number));
}

function missionProgress(item, characterId) {
  const quests = Array.isArray(item.quests) ? item.quests.map(Number) : [];
  if (!quests.length) return { total: 0, done: 0, empty: true, noData: false };
  const set = characterQuestSet(characterId);
  if (!set) return { total: quests.length, done: 0, empty: false, noData: true };
  return { total: quests.length, done: quests.filter((quest) => set.has(quest)).length, empty: false, noData: false };
}

function missionComplete(item, characterId) {
  const progress = missionProgress(item, characterId);
  return !progress.empty && !progress.noData && progress.total > 0 && progress.done >= progress.total;
}

function missionText(item, characterId) {
  const progress = missionProgress(item, characterId);
  if (progress.empty) return "No quest list yet";
  if (progress.noData) return "No scan data yet";
  return `${progress.done} of ${progress.total} quests`;
}

function questName(questId) {
  const catalog = questCatalog();
  const known = catalog.get(Number(questId));
  return known && known.name ? known.name : `Quest ${questId}`;
}

// Typed guide target: { kind: "polestar" | "video" | "doc", ref }. Video
// and doc refs resolve against guides.json ids; polestar refs are free-text
// in-game guide names (Polestar's SV is never parsed for progress).
function guideLine(ref) {
  if (!ref || !ref.ref) return null;
  if (ref.kind === "polestar") return { text: `In-game guide: ${ref.ref} (Polestar)` };
  const guides = state.guides || [];
  const guide = guides.find((entry) => entry.id === ref.ref);
  if (guide) return { title: guide.title, url: guide.url };
  return { text: `Guide ref ${ref.ref} (not in guides.json yet)` };
}

function partChecked(item, part) {
  if (ownedNote(part)) return true;
  if (huntBucket(item) === "collection") {
    const saved = manualState(part.id, ACCOUNT_CHECK);
    if (saved !== null) return saved;
    return !!part.defaultDone;
  }
  return isChecked(part);
}

function persistHunts() {
  try {
    localStorage.setItem(HUNT_STORE_KEY, JSON.stringify({ checks: state.checks, attempts: state.attempts }));
  } catch (error) { /* private window: checks stay in memory for this page view */ }
}

function loadHunts() {
  let saved = null;
  try { saved = JSON.parse(localStorage.getItem(HUNT_STORE_KEY) || 'null'); } catch (error) { saved = null; }
  if (saved) {
    if (saved.checks && typeof saved.checks === 'object') state.checks = saved.checks;
    if (saved.attempts && typeof saved.attempts === 'object') state.attempts = saved.attempts;
    return { migrated: false, dropped: [] };
  }
  let legacy = null;
  try { legacy = JSON.parse(localStorage.getItem(HUNT_STORE_KEY_V1) || 'null'); } catch (error) { legacy = null; }
  if (!legacy) return { migrated: false, dropped: [] };
  const moved = migrateV1Checks(legacy);
  state.checks = moved.checks;
  state.attempts = moved.attempts;
  persistHunts();
  try { localStorage.removeItem(HUNT_STORE_KEY_V1); } catch (error) { /* ignore */ }
  return { migrated: true, dropped: moved.dropped };
}

function resetHunts() {
  state.checks = {};
  state.attempts = {};
  try { localStorage.removeItem(HUNT_STORE_KEY); } catch (error) { /* ignore */ }
  try { localStorage.removeItem(HUNT_STORE_KEY_V1); } catch (error) { /* ignore */ }
  renderChecklist();
  renderDungeons();
}
var JOURNEY_STORE_KEY = 'wow-forever-journey-v1';

// Route data for the Journey tab (data/journey.json): zones in running order
// for the journey character. Progress renders from data/att.public.json plus
// device-local manual checks; adding a zone later is data-only.
function journeyZones() {
  var zones = (state.journey && state.journey.zones) || [];
  return zones.slice().sort(function (a, b) { return (a.order || 0) - (b.order || 0); });
}

function journeyCharacterId() {
  return (state.journey && state.journey.character) || "skyrinis";
}

// Per-character completed quest set for the journey character. Null when he
// has no scan yet: quest and exploration items then render an honest pending
// state instead of fake zeros or false completions.
function journeyQuestSet() {
  return characterQuestSet(journeyCharacterId());
}

// Per-character exploration set for the journey character, when the
// projection carries one (ids or names). Null until scanned.
function journeyExplorationSet() {
  var rows = (state.att && state.att.characters) || [];
  var row = null;
  rows.forEach(function (entry) {
    if (entry && entry.canonicalId === journeyCharacterId()) row = entry;
  });
  if (!row || row.explorationHave === null || row.explorationHave === undefined) return null;
  if (!Array.isArray(row.explorationHave)) return null;
  var set = { ids: [], names: [] };
  row.explorationHave.forEach(function (value) {
    if (typeof value === "number" || /^\d+$/.test(String(value))) {
      if (set.ids.indexOf(Number(value)) < 0) set.ids.push(Number(value));
    } else if (value) {
      var name = String(value).trim().toLowerCase();
      if (set.names.indexOf(name) < 0) set.names.push(name);
    }
  });
  return set;
}

function journeyDisplayName(zone, section, item) {
  if (item.name) return item.name;
  if (section === "professions") return item.skill + " " + item.target;
  return "Unnamed route item";
}

// One route item resolves to done / auto / pending / manual. Quests with a
// verified id, exploration, and collectibles check automatically at render;
// quests without ids, rares, BoEs, and profession milestones are manual ticks
// stored under the journey localStorage key.
function journeyItemState(zone, section, item) {
  var name = journeyDisplayName(zone, section, item);
  if (section === "quests" && item.id !== undefined && item.id !== null) {
    var questSet = journeyQuestSet();
    if (!questSet) return { done: false, auto: true, pending: true, reason: "Skyrinis has not been scanned yet." };
    var questDone = questSet.has(Number(item.id));
    return { done: questDone, auto: true, pending: false, reason: questDone ? "Skyrinis completed this quest." : "" };
  }
  if (section === "exploration") {
    var exploreSet = journeyExplorationSet();
    if (!exploreSet) return { done: false, auto: true, pending: true, reason: "Skyrinis has not been scanned yet." };
    var explored = exploreSet.names.indexOf(name.trim().toLowerCase()) >= 0;
    return { done: explored, auto: true, pending: false, reason: explored ? "Skyrinis explored this area." : "" };
  }
  if (section === "collectibles") {
    var sets = attSets();
    var held = sets.names.has(name.trim().toLowerCase());
    return { done: held, auto: true, pending: false, reason: held ? "Obtained (account collection history)." : "" };
  }
  var key = zone.id + "::" + name;
  var saved = state.journeyChecks[key];
  return { done: !!saved, auto: false, pending: false, manual: true, key: key, reason: "" };
}

function journeySectionLabel(section) {
  return {
    quests: "Quests",
    exploration: "Exploration",
    collectibles: "Collectibles",
    rares: "Rares",
    boes: "BoE targets",
    professions: "Profession milestones",
    guideRefs: "Notes and guides"
  }[section] || section;
}

// Only Quests, Exploration, and Collectibles gate a zone DONE. Rares, BoEs,
// and profession milestones count toward the zone % but never gate.
var JOURNEY_GATING = ["quests", "exploration", "collectibles"];

var JOURNEY_SECTIONS = ["quests", "exploration", "collectibles", "rares", "boes", "professions"];

function journeyZoneProgress(zone) {
  var total = 0;
  var done = 0;
  var gated = true;
  var pending = false;
  JOURNEY_SECTIONS.forEach(function (section) {
    ((zone && zone[section]) || []).forEach(function (item) {
      total += 1;
      var status = journeyItemState(zone, section, item);
      if (status.done) done += 1;
      if (status.pending) pending = true;
      if (JOURNEY_GATING.indexOf(section) >= 0 && !status.done) gated = false;
    });
  });
  return { total: total, done: done, gated: gated, pending: pending };
}

function journeyOverall() {
  var zones = journeyZones();
  var total = 0;
  var done = 0;
  zones.forEach(function (zone) {
    var progress = journeyZoneProgress(zone);
    total += progress.total;
    done += progress.done;
  });
  var current = null;
  zones.forEach(function (zone) {
    if (!current && !journeyZoneProgress(zone).gated) current = zone;
  });
  return { total: total, done: done, current: current };
}

// Every route item carrying priority, with its zone, for the route header.
function journeyPriorityTargets() {
  var targets = [];
  journeyZones().forEach(function (zone) {
    JOURNEY_SECTIONS.forEach(function (section) {
      ((zone && zone[section]) || []).forEach(function (item) {
        if (item && item.priority) {
          targets.push({
            zone: zone.name,
            zoneId: zone.id,
            section: journeySectionLabel(section),
            name: journeyDisplayName(zone, section, item),
            done: journeyItemState(zone, section, item).done
          });
        }
      });
    });
  });
  return targets;
}

function persistJourney() {
  try {
    localStorage.setItem(JOURNEY_STORE_KEY, JSON.stringify({ checks: state.journeyChecks }));
  } catch (error) { /* private window: checks stay in memory for this page view */ }
}

function loadJourney() {
  var saved = null;
  try { saved = JSON.parse(localStorage.getItem(JOURNEY_STORE_KEY) || "null"); } catch (error) { saved = null; }
  state.journeyChecks = (saved && saved.checks && typeof saved.checks === "object") ? saved.checks : {};
}

function resetJourney() {
  state.journeyChecks = {};
  try { localStorage.removeItem(JOURNEY_STORE_KEY); } catch (error) { /* ignore */ }
  renderJourney();
}

function explicitlyUnchecked(id, characterId) {
  const row = state.checks[id];
  return !!(row && Object.prototype.hasOwnProperty.call(row, characterId) && !row[characterId]);
}

async function commitChecks() {
  // Sheet retired: the writeLocalCheck call at the toggle site already
  // updated this page view. Nothing to persist.
}

async function persistTries() {
  // Sheet retired: setAttempts already updated this page view.
}

async function commitTask() {
  // Sheet retired: the toggle site already updated this page view.
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
  persistHunts();
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
  if (huntKind(item) === "Recipe" || RECIPE_PREFIX.test(item.name)) {
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
      : huntKind(hunt) === "Milestone" || hunt.source === "Pack" ? "none"
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
    // That drop is not a tracked hunt, so the check cannot attach anywhere.
    renderDungeons();
    return;
  }
  const changes = [];
  links.forEach((link) => {
    if (!link.parent && link.entry.parts && checked && !piecesReady(link.entry)) return;
    const lootKey = checkKey(link.parent || link.entry);
    const prev = manualState(link.entry.id, lootKey);
    writeLocalCheck(link.entry.id, lootKey, checked);
    changes.push({ id: link.entry.id, checked, prev });
    if (link.parent && !piecesReady(link.parent)) {
      const parentKey = checkKey(link.parent);
      const prevParent = manualState(link.parent.id, parentKey);
      if (prevParent) {
        writeLocalCheck(link.parent.id, parentKey, false);
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
  if (isObtained(item) || ownedNote(item)) return true;
  const bucket = huntBucket(item);
  // Class missions are derived from quest completion data; manual checks
  // never apply.
  if (bucket === "mission") return missionComplete(item, state.selected);
  if (bucket === "collection") {
    const saved = manualState(item.id, ACCOUNT_CHECK);
    if (saved !== null) return saved;
    return !!item.defaultDone;
  }
  // Gear and legacy untyped hunts keep per-character behavior.
  if (state.scope === "house") {
    const people = state.characters.filter((character) => matchesCharacter(item, character));
    const list = people.length ? people : state.characters;
    if (list.some((character) => manualChecked(item.id, character.id))) return true;
    // Sheet retired: the saved copy in checklist.json is the only source.
    return !!item.defaultDone;
  }
  if (manualChecked(item.id, state.selected)) return true;
  if (explicitlyUnchecked(item.id, state.selected)) return false;
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
    const bucket = huntBucket(item);
    if (state.scope === "house") {
      if (bucket === "gear" || bucket === "mission") return false;
    } else {
      if (bucket === "collection") return false;
      if (!matchesCharacter(item, character)) return false;
    }
    if (!matchesPlace(item)) return false;
    if (!q) return true;
    const parts = (item.parts || []).map((part) => `${part.name} ${part.how || ""}`).join(" ");
    const hay = `${item.name} ${item.zone} ${item.notes} ${item.how || ""} ${item.type || ""} ${huntKind(item)} ${parts} ${huntPlace(item).dungeons.join(" ")}`.toLowerCase();
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

function backstoryFor(characterId) {
  return ((state.backstories || {})[characterId]) || null;
}
function tallyFor(characterId) {
  return ((state.tallies || {})[characterId]) || null;
}
function journalFor(characterId) {
  return asList(state.journals)
    .filter((entry) => entry && entry.character === characterId)
    .sort((a, b) => String(b.date || "").localeCompare(String(a.date || "")));
}

function journalAll() {
  return asList(state.journals).filter(Boolean)
    .sort((a, b) => String(b.date || "").localeCompare(String(a.date || "")));
}

function setJournalView(view) {
  state.journalView = view;
  saveStore();
  renderJournal();
}

function renderJournalEntry(entry) {
  const owner = state.characters.find((c) => c.id === entry.character);
  const card = el("article", { class: "card journal-entry" });
  const bits = [entry.date ? String(entry.date).slice(0, 10) : ""];
  if (state.journalView === "all" && owner) bits.push(owner.name);
  card.append(el("p", { class: "meta", text: bits.filter(Boolean).join(" · ") }));
  card.append(el("h3", { text: entry.title }));
  asList(entry.body).forEach((para) => card.append(el("p", { text: para })));
  if (asList(entry.facts).length) {
    card.append(el("p", { class: "meta session-record", text: `Session record: ${asList(entry.facts).join(" · ")}` }));
  }
  return card;
}

function renderJournal() {
  const root = document.getElementById("journal-list");
  const note = document.getElementById("journal-note");
  const view = document.getElementById("journal-view");
  if (!root || !note || !view || !state.characters.length) return;
  const who = selectedCharacter();
  view.replaceChildren(
    el("button", { type: "button", "aria-pressed": state.journalView === "all" ? "false" : "true", onclick: () => setJournalView("picked"), text: who ? who.name : "Selected character" }),
    el("button", { type: "button", "aria-pressed": state.journalView === "all" ? "true" : "false", onclick: () => setJournalView("all"), text: "All characters" })
  );
  root.replaceChildren();
  if (!state.journals) {
    note.textContent = "Loading journal…";
    return;
  }
  if (state.journalView === "all") {
    note.textContent = "Newest first, across the whole house. Butler-published session records.";
    const rows = journalAll();
    if (!rows.length) {
      root.append(el("p", { class: "empty-note", text: "No journal entries yet." }));
      return;
    }
    rows.forEach((entry) => root.append(renderJournalEntry(entry)));
    return;
  }
  note.textContent = `Newest first. Butler-published session records for ${who ? who.name : "this character"}.`;
  const rows = who ? journalFor(who.id) : [];
  if (!rows.length) {
    root.append(el("p", { class: "empty-note", text: "No journal entries yet." }));
    return;
  }
  rows.forEach((entry) => root.append(renderJournalEntry(entry)));
}

function bioInitials(name) {
  return String(name || "").split(/\s+/).filter(Boolean).slice(0, 2).map((word) => word[0]).join("").toUpperCase();
}

function bioMonogram(character) {
  const badge = el("div", { class: "portrait-mono" });
  badge.style.setProperty("--class", CLASS_COLOR[character.className] || "var(--gold)");
  badge.append(document.createTextNode(bioInitials(character.name)));
  return badge;
}

function renderPortrait(character, story) {
  const frame = el("div", { class: "portrait" });
  const path = story && story.portrait;
  if (typeof path === "string" && path) {
    const img = el("img", { class: "portrait-img", src: path, alt: `${character.name} portrait` });
    img.addEventListener("error", () => { img.replaceWith(bioMonogram(character)); });
    frame.append(img);
  } else {
    frame.append(bioMonogram(character));
  }
  return frame;
}

const LAUNCH_DAY = "2026-11-04";
const RAIDS_DAY = "2026-12-09";

function launchDayName(ymd) {
  const [y, m, d] = String(ymd).split("-").map(Number);
  return ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][new Date(y, m - 1, d).getDay()];
}

function dayCount(fromYmd, toYmd) {
  const [fy, fm, fd] = String(fromYmd).split("-").map(Number);
  const [ty, tm, td] = String(toYmd).split("-").map(Number);
  return Math.round((new Date(ty, tm - 1, td) - new Date(fy, fm - 1, fd)) / 86400000);
}

function dayLabel(n) {
  return `${n} day${n === 1 ? "" : "s"}`;
}

function launchStripText(today) {
  if (today >= RAIDS_DAY) return null;
  if (today === LAUNCH_DAY) return "Launch day  welcome to Forever.";
  if (today > LAUNCH_DAY) return `First raids in ${dayLabel(dayCount(today, RAIDS_DAY))}  December 9.`;
  return `Launch in ${dayLabel(dayCount(today, LAUNCH_DAY))}  ${launchDayName(LAUNCH_DAY)}, November 4`;
}

function renderLaunchStrip(todayOverride) {
  const strip = document.getElementById("launch-strip");
  if (!strip) return;
  const now = new Date();
  const today = todayOverride || `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
  const text = launchStripText(today);
  if (!text) {
    strip.hidden = true;
    strip.replaceChildren();
    return;
  }
  strip.hidden = false;
  strip.textContent = text;
}

var LAUNCH_STORE_KEY = "wow-forever-launch-v1";
var LAUNCH_CUTOFF = "2026-11-11";

function launchChecks() {
  try {
    return JSON.parse(localStorage.getItem(LAUNCH_STORE_KEY) || "{}") || {};
  } catch {
    return {};
  }
}

function renderLaunch(todayOverride) {
  const panel = document.getElementById("launch-panel");
  const progress = document.getElementById("launch-progress");
  const list = document.getElementById("launch-list");
  if (!panel || !progress || !list) return;
  const hide = () => {
    panel.hidden = true;
    progress.textContent = "";
    list.replaceChildren();
  };
  const items = asList(state.launch && state.launch.items);
  if (!items.length) {
    hide();
    return;
  }
  const now = new Date();
  const today = todayOverride || `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
  const checks = launchChecks();
  const done = items.filter((item) => item && checks[item.id]).length;
  if (done >= items.length || today > LAUNCH_CUTOFF) {
    hide();
    return;
  }
  panel.hidden = false;
  progress.textContent = `${done} of ${items.length} done`;
  list.replaceChildren();
  items.forEach((item) => {
    const row = el("label", { class: "launch-row" });
    const box = el("input", {
      type: "checkbox",
      onchange: () => {
        const saved = launchChecks();
        if (box.checked) saved[item.id] = true;
        else delete saved[item.id];
        try {
          localStorage.setItem(LAUNCH_STORE_KEY, JSON.stringify(saved));
        } catch {}
        renderLaunch();
      }
    });
    if (checks[item.id]) box.checked = true;
    row.append(box);
    row.append(el("span", { text: item.label }));
    list.append(row);
  });
}

function renderGuild() {
  const root = document.getElementById("guild-list");
  const note = document.getElementById("guild-note");
  if (!root || !note) return;
  root.replaceChildren();
  const guild = state.guild;
  if (!guild || !guild.charter) {
    note.textContent = "Guild charter not loaded.";
    return;
  }
  note.textContent = (guild.charter && guild.charter.byline) || "";
  asList(guild.charter.articles).forEach((article) => {
    root.append(el("h3", { text: article.heading }));
    asList(article.paragraphs).forEach((para) => root.append(el("p", { text: para })));
  });
  const facts = guild.facts || {};
  const factKeys = Object.keys(facts);
  const pairings = asList(guild.pairings);
  if (factKeys.length || pairings.length) {
    const grid = el("div", { class: "facts" });
    factKeys.forEach((label) => grid.append(el("div", { class: "fact" }, [
      el("span", { text: label }),
      el("b", { text: String(facts[label]) })
    ])));
    root.append(grid);
    pairings.forEach((line) => root.append(el("p", { class: "meta", text: line })));
  }
  const houses = asList(guild.houses);
  if (houses.length) {
    root.append(el("h3", { text: "The Houses" }));
    houses.forEach((house) => {
      root.append(el("h4", { text: house.name }));
      asList(house.paragraphs).forEach((para) => root.append(el("p", { text: para })));
    });
  }
}

function renderBio() {
  const bio = document.getElementById("roster");
  const character = selectedCharacter();
  bio.replaceChildren();
  if (!character) return;
  const story = backstoryFor(character.id);
  const head = el("div", { class: "bio-head" });
  head.append(renderPortrait(character, story));
  const titles = el("div", { class: "bio-titles" });
  titles.append(el("h3", { text: character.name }));
  titles.append(el("p", { class: "meta", text: `${character.race} · ${character.className} · ${character.spec}` }));
  head.append(titles);
  bio.append(head);
  if (story && Object.keys(story.facts || {}).length) {
    const grid = el("div", { class: "facts" });
    Object.entries(story.facts).forEach(([label, value]) => grid.append(el("div", { class: "fact" }, [
      el("span", { text: label }),
      el("b", { text: String(value) })
    ])));
    bio.append(grid);
  }
  const tally = tallyFor(character.id);
  if (tally && asList(tally.counters).length) {
    bio.append(el("h4", { text: tally.heading }));
    const counters = el("div", { class: "facts" });
    asList(tally.counters).forEach((counter) => counters.append(el("div", { class: "fact" }, [
      el("span", { text: counter.label }),
      el("b", { text: String(counter.value) })
    ])));
    bio.append(counters);
  }
  if (story) {
    bio.append(el("h4", { text: story.title }));
    asList(story.paragraphs).forEach((para) => bio.append(el("p", { text: para })));
  } else {
    bio.append(el("p", { class: "empty-note", text: "No backstory yet." }));
  }
  const myGuides = asList(state.guides).filter((guide) => asList(guide.appliesTo).includes(character.id));
  if (myGuides.length) {
    const guideLine = el("p", { class: "meta", text: "Guides: " });
    myGuides.forEach((guide, index) => {
      if (index) guideLine.append(document.createTextNode(" · "));
      guideLine.append(el("a", { href: guide.url, target: "_blank", rel: "noreferrer", text: guide.title }));
    });
    bio.append(guideLine);
  }
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
  asList(character.talentLinks).forEach((link) => {
    identity.append(el("a", { href: link.url, target: "_blank", rel: "noreferrer", text: link.label }));
  });
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
  // stats.json can carry a date from unrelated snapshots, so the
  // "updated" line is only shown when THIS character actually has data.
  const hasLive = live && Object.keys(live).length > 0;
  const updated = hasLive && state.stats.updated
    ? `Updated ${state.stats.updated}.`
    : "No addon export merged yet. Level, gear, and gold show up here after the first launch-roster export.";
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
    lifetime.append(el("p", { class: "empty-note", text: "No statistics recorded yet." }));
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
  return (item.targetCharacters || item.assignedTo || item.owners || []).map((id) => {
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
  return item.parts.filter((part) => partChecked(item, part)).length >= need;
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
  const parentKey = huntBucket(item) === "collection" ? ACCOUNT_CHECK : state.selected;
  const checked = partChecked(item, part);
  const found = ownedNote(part);
  const box = el("input", { type: "checkbox", "aria-label": `Got ${part.name}`, title: found || null });
  box.checked = checked;
  if (found || (state.scope === "house" && huntBucket(item) !== "collection")) box.disabled = true;
  if (state.scope === "house" && !found && huntBucket(item) !== "collection") box.title = "Switch to this character to check this hunt.";
  box.addEventListener("click", (event) => event.stopPropagation());
  box.addEventListener("change", () => {
    if (state.scope === "house" && huntBucket(item) !== "collection") {
      box.checked = partChecked(item, part);
      return;
    }
    const changes = [];
    const prev = manualState(part.id, parentKey);
    writeLocalCheck(part.id, parentKey, box.checked);
    changes.push({ id: part.id, checked: box.checked, prev });
    if (!piecesReady(item)) {
      const prevParent = manualState(item.id, parentKey);
      if (prevParent) {
        writeLocalCheck(item.id, parentKey, false);
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

function guideKids(item) {
  const guide = guideLine(item.guideRef);
  if (!guide) return [];
  if (guide.url) return [el("p", { class: "guide-ref" }, [el("a", { href: guide.url, text: guide.title })])];
  return [el("p", { class: "guide-ref", text: guide.text })];
}

function missionKids(item, bucket) {
  if (bucket !== "mission" || !Array.isArray(item.quests) || !item.quests.length) return [];
  const done = characterQuestSet(state.selected) || new Set();
  return item.quests.map((questId) => {
    const hit = done.has(Number(questId));
    return el("p", { class: `mission-quest ${hit ? "done" : "todo"}`, text: `${hit ? "Done" : "Todo"}: ${questName(questId)}` });
  });
}

function renderHunt(item) {
  const bucket = huntBucket(item);
  const checked = isChecked(item);
  const open = state.openId === item.id;
  const tries = attemptCount(item.id);
  const group = huntGroup(item);
  const ready = piecesReady(item);
  const pieceCount = item.parts ? item.parts.filter((part) => partChecked(item, part)).length : 0;
  const found = ownedNote(item);
  const auto = isObtained(item);
  const box = el("input", {
    type: "checkbox",
    "aria-label": `Got ${item.name}`,
    title: found || auto || null
  });
  box.checked = checked;
  if ((state.scope === "house" && bucket !== "collection") || (item.parts && !ready) || found || auto || bucket === "mission") box.disabled = true;
  if (state.scope === "house" && !found && !auto && bucket !== "collection") box.title = "Switch to this character to check this hunt.";
  box.addEventListener("click", (event) => event.stopPropagation());
  box.addEventListener("change", () => {
    if (bucket === "mission") {
      box.checked = isChecked(item);
      return;
    }
    if (state.scope === "house" && bucket !== "collection") {
      box.checked = isChecked(item);
      return;
    }
    if (item.parts && box.checked && !piecesReady(item)) {
      box.checked = false;
      return;
    }
    const huntKey = checkKey(item);
    const prev = manualState(item.id, huntKey);
    writeLocalCheck(item.id, huntKey, box.checked);
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
  const meta = `${huntKind(item) || group.label} · ${item.zone} · level ${item.minLevel}+`;
  const pieceText = item.parts
    ? `${pieceCount} of ${item.need || item.parts.length} pieces`
    : "";
  const kills = killLog(huntMobs(item));
  const killText = kills.total ? `${kills.total} ${kills.total === 1 ? "kill" : "kills"} logged` : "";
  const mission = bucket === "mission" ? missionText(item, state.selected) : "";
  const attemptText = [meta, pieceText, found || auto, rarityText(item), mission, killText, tries ? `${tries} ${tries === 1 ? "try" : "tries"}` : ""]
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
      fact("For", whoLabel(item)),
      rarityFor(item) ? fact("Rarity", rarityText(item)) : null,
      bucket === "collection" ? fact("Scope", "Whole house (shared check)") : null
    ]),
    ...guideKids(item),
    ...missionKids(item, bucket)
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
    if (books) { list.append(books); return; }
    list.append(el("p", { class: "empty-note", text: state.scope === "character"
      ? "No gear hunts or class missions for this character yet. Collections live in the Whole house view."
      : "No collection hunts on this filter." }));
    return;
  }

  const rank = { High: 0, Medium: 1, Low: 2 };
  HUNT_GROUPS.forEach((group) => {
    const rows = items
      .filter((item) => group.types.includes(item.type) || (!item.type && group.id === "other"))
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
  const buckets = new Set(items.map((item) => huntBucket(item)));
  if (state.scope === "character" && !buckets.has("gear") && !buckets.has("mission") && !buckets.has("")) {
    list.append(el("p", { class: "empty-note", text: "No gear hunts or class missions for this character yet. Collections live in the Whole house view." }));
  }
  if (state.scope === "house" && !buckets.has("collection") && !buckets.has("")) {
    list.append(el("p", { class: "empty-note", text: "No collection hunts yet." }));
  }
  const books = renderLibraryBooks();
  if (books) list.append(books);
}

function writeJourneyCheck(zoneId, name, checked) {
  state.journeyChecks[zoneId + "::" + name] = !!checked;
  persistJourney();
}

function renderJourneyItem(zone, section, item) {
  var status = journeyItemState(zone, section, item);
  var name = journeyDisplayName(zone, section, item);
  var star = item.priority ? " ★" : "";
  var box = el("input", {
    type: "checkbox",
    "aria-label": "Journey: " + name,
    title: status.reason || null
  });
  box.checked = status.done;
  if (!status.manual) {
    box.disabled = true;
  } else {
    box.addEventListener("change", function () {
      writeJourneyCheck(zone.id, name, box.checked);
      renderJourney();
    });
  }
  var bits = [];
  if (section === "quests" && item.id !== undefined && item.id !== null) bits.push("Quest " + item.id);
  if (section === "quests" && (item.id === undefined || item.id === null)) bits.push("Manual");
  if (section === "collectibles") bits.push(status.done ? status.reason : "Account-wide");
  if (section === "exploration" && status.pending) bits.push("character not yet scanned");
  if (section === "exploration" && !status.pending) bits.push(status.done ? "explored" : "unexplored");
  if (status.manual && item.note) bits.push(item.note);
  if (!status.manual && !status.pending && item.note) bits.push(item.note);
  if (status.pending && item.note) bits.push(item.note);
  var row = el("div", { class: "hunt-row journey-row" }, [
    box,
    el("span", { class: "journey-name", text: name + star }),
    el("span", { class: "sub", text: bits.join(" · ") })
  ]);
  if (status.done) row.classList.add("done");
  return row;
}

function renderJourneySection(zone, section) {
  var items = (zone && zone[section]) || [];
  var label = journeySectionLabel(section);
  var done = 0;
  items.forEach(function (item) {
    if (journeyItemState(zone, section, item).done) done += 1;
  });
  var block = el("section", { class: "journey-section" }, [
    el("div", { class: "group-label" }, [
      el("span", { text: label }),
      el("em", { text: done + " / " + items.length })
    ])
  ]);
  if (section === "guideRefs") {
    if (!items.length) {
      block.append(el("p", { class: "empty-note", text: "No curated guides for this zone yet." }));
      return block;
    }
    items.forEach(function (ref) {
      var line = guideLine(ref);
      if (!line) return;
      block.append(el("p", { class: "journey-guide" }, [
        line.url ? el("a", { href: line.url, text: line.title }) : el("span", { text: line.text })
      ]));
    });
    return block;
  }
  if (!items.length) {
    block.append(el("p", { class: "empty-note", text: "No curated targets in this section yet." }));
    return block;
  }
  items.forEach(function (item) {
    block.append(renderJourneyItem(zone, section, item));
  });
  return block;
}

function renderJourneyZone(zone) {
  var progress = journeyZoneProgress(zone);
  var percent = progress.total ? Math.round((progress.done / progress.total) * 100) : 0;
  var badge = progress.gated ? "DONE" : (progress.pending ? "AWAITING SCAN" : progress.done + " of " + progress.total);
  var card = el("article", { class: "journey-zone" + (progress.gated ? " done" : "") }, [
    el("div", { class: "journey-zone-head" }, [
      el("strong", { text: zone.order + ". " + zone.name }),
      el("span", { class: "badge", text: badge })
    ]),
    el("p", { class: "journey-zone-sub", text: (zone.levelBand ? "Level " + zone.levelBand : "") + (zone.summary ? " · " + zone.summary : "") }),
    el("div", { class: "progress", "aria-hidden": "true" }, [
      el("div", { style: "width: " + percent + "%" })
    ])
  ]);
  JOURNEY_SECTIONS.forEach(function (section) {
    card.append(renderJourneySection(zone, section));
  });
  card.append(renderJourneySection(zone, "guideRefs"));
  return card;
}

function renderJourney() {
  var head = document.getElementById("journey-head");
  var zonesRoot = document.getElementById("journey-zones");
  if (!head || !zonesRoot) return;
  head.replaceChildren();
  zonesRoot.replaceChildren();
  if (!state.journey) {
    head.append(el("p", { class: "empty-note", text: "Journey data did not load." }));
    return;
  }
  var zones = journeyZones();
  var overall = journeyOverall();
  var percent = overall.total ? Math.round((overall.done / overall.total) * 100) : 0;
  head.append(el("p", { text: overall.done + " of " + overall.total + " route items (" + percent + "%)" }));
  head.append(el("div", { class: "progress", "aria-hidden": "true" }, [
    el("div", { style: "width: " + percent + "%" })
  ]));
  head.append(el("p", {
    text: overall.current
      ? "Current zone: " + overall.current.name
      : "Route complete: every gating section is DONE."
  }));
  var targets = journeyPriorityTargets();
  if (targets.length) {
    var list = el("ul", { class: "journey-priority" });
    targets.forEach(function (target) {
      list.append(el("li", {
        text: "★ " + target.name + " (" + target.zone + " · " + target.section + ")" + (target.done ? " — done" : "")
      }));
    });
    head.append(el("p", { class: "journey-priority-head", text: "Priority targets" }));
    head.append(list);
  }
  var noData = zones.some(function (zone) { return journeyZoneProgress(zone).pending; });
  if (noData) {
    head.append(el("p", {
      class: "empty-note",
      text: "Skyrinis has not been scanned yet: auto items show as pending, never as zeros or completions. The curated route below displays in full."
    }));
  }
  zones.forEach(function (zone) {
    zonesRoot.append(renderJourneyZone(zone));
  });
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

function renderCharacterPicker() {
  const picker = document.getElementById("character-picker");
  if (!picker || !state.characters.length) return;
  if (picker.options.length !== state.characters.length) {
    picker.replaceChildren(...state.characters.map((c) => el("option", { value: c.id, text: c.name })));
  }
  picker.value = state.selected;
}

function selectCharacter(id) {
  state.selected = id;
  saveStore();
  const url = new URL(location.href);
  url.searchParams.set("c", id);
  history.replaceState(null, "", url);
  render();
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
    item.verified === false ? el("span", { class: "badge", text: "Unverified" }) : null,
    bits ? el("small", { text: bits }) : null
  ]);
}

function questFactionShown(quest) {
  const faction = "Alliance";
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
  note.textContent = `From ${journal.source}${version ? ` ${version}` : ""}.`;
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
    if (!bosses.length && !quests.length && !wholeDungeon) return;
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
  if (!root || !note || !state.characters.length) return;
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
  if (!root || !note || !state.characters.length) return;
  root.replaceChildren();
  if (!state.macros) {
    note.textContent = "Loading macros…";
    return;
  }
  const who = selectedCharacter();
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
  if (!root || !note || !state.characters.length) return;
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
  const book = state.ledger || {};
  // Placeholder example data is never rendered. The ledger only shows
  // real scan output; anything else renders the honest empty states.
  if (book.updated === "example") return {};
  const table = book.characters;
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
    // Redacted view: correspondent, date and item names only.
    // No bodies, no gold amounts, no subjects.
    let total = 0;
    const cards = names.map((key) => {
      const rows = asList(people[key].mail);
      total += rows.length;
      const lines = rows.map((letter) => {
        const items = asList(letter.items).map((entry) => String(entry)).filter(Boolean);
        return `${formatWhen(letter.time)} · ${letter.who || "Unknown sender"} · ${items.length ? items.join(", ") : "no items listed"}`;
      });
      return card(`${key} (${rows.length})`, lines.length ? lines : ["No mail recorded yet."]);
    });
    mailNote.textContent = empty || (total ? `${total} letters across ${names.length} characters. Names and items only.` : "Sent and received letters.");
    mailRoot.replaceChildren(...cards);
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
    taskNote.textContent = tasks.length ? (who ? `Checks for ${who.name}.` : "Checks for this character.") : "No task list yet. Tasks return with the canonical data.";
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
  const sheet = document.getElementById("alto-sheet");
  if (!note || !sheet) return;
  const character = selectedCharacter();
  if (!character) {
    note.textContent = "No roster characters yet.";
    sheet.replaceChildren();
    return;
  }
  // Phase 2a: roster-matched canonical scans only (data/characters.public.json,
  // itself generated from the private canonical set). Public view shows
  // professions with ranks, named reputations and named currencies. Numeric
  // currency values, gold, gear, bags, stats, quests and mail stay private.
  const roster = asList(state.characters);
  const scans = new Map(asList(state.publicChars && state.publicChars.characters).map((c) => [String(c.name || "").toLowerCase(), c]));
  if (!scans.size) {
    note.textContent = "No roster scan merged yet. Log in on a launch character and run a fresh export.";
    sheet.replaceChildren();
    return;
  }
  const person = scans.get(String(character.name || "").toLowerCase()) || null;
  const professions = asList(person && person.professions);
  const reputations = asList(person && person.reputations);
  const currencies = asList(person && person.currencies);
  note.textContent = person ? `Canonical scan for ${person.name}.` : `No scan saved for ${character.name} yet.`;
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
    el("h3", { text: character.name }),
    ...(!person ? [el("p", { class: "meta", text: "Log in on this character and run a fresh export to fill this tab." })] : []),
    el("h4", { text: "Professions" }),
    ...(professions.length ? professions.map((skill) => {
      const value = Number(skill.current) || 0;
      const max = Number(skill.max) || 0;
      return bar(skill.name, value, max > 0 ? max : Math.max(value, 1), max > 0 ? `${value}/${max}` : String(value));
    }) : [el("p", { class: "meta", text: "No profession ranks saved." })]),
    el("h4", { text: "Reputation" }),
    ...(reputations.length ? reputations.map((row) => el("div", { class: "lock-run" }, [
      el("span", { class: "name", text: row.name }),
      el("span", { text: row.standing || "" })
    ])) : [el("p", { class: "meta", text: "No reputation saved." })]),
    el("h4", { text: "Currencies" }),
    ...(currencies.length ? currencies.map((row) => el("div", { class: "lock-run" }, [
      el("span", { class: "name", text: row.name })
    ])) : [el("p", { class: "meta", text: "No currencies saved." })])
  ]));
}
function render() {
  renderCharacterPicker();
  renderBio();
  renderSheet();
  renderChecklist();
  renderJourney();
  renderJournal();
  renderLaunchStrip();
  renderLaunch();
  renderGuild();
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

async function main() {
  loadStore();
  const params = new URLSearchParams(location.search);
  const hash = location.hash.replace("#", "");
  if (TABS.includes(hash)) state.tab = hash;
  if (params.get("c")) state.selected = params.get("c");
  bindTabs();
  showTab(state.tab);
  try {
    const [characters, checklist, stats, addons, ledger, publicChars, screenshots, dungeons, books, guidesFile, attFile, rarityFile, journeyFile, backstoriesFile, journalsFile, launchFile, guildFile, talliesFile] = await Promise.all([
      loadJson("data/characters.json"),
      loadJson("data/checklist.json"),
      loadJson("data/stats.json"),
      loadJson("data/addons.json").catch(() => null),
      loadJson("data/ledger.json").catch(() => ({ characters: {}, rares: [] })),
      loadJson("data/characters.public.json").catch(() => ({ characters: [] })),
      loadJson("data/screenshots.json").catch(() => []),
      loadJson("data/dungeons.json").catch(() => null),
      loadJson("data/library-books.json").catch(() => null),
      loadJson("data/guides.json").catch(() => ({ guides: [] })),
      loadJson("data/att.public.json").catch(() => null),
      loadJson("data/rarity.public.json").catch(() => null),
      loadJson("data/journey.json").catch(() => null),
      loadJson("data/backstories.json").catch(() => ({ backstories: {} })),
      loadJson("data/journals.json").catch(() => ({ entries: [] })),
      loadJson("data/launch.json").catch(() => null),
      loadJson("data/guild.json").catch(() => null),
      loadJson("data/tallies.json").catch(() => ({ tallies: {} }))
    ]);
    state.books = books;
    state.characters = characters;
    state.checklist = checklist;
    state.stats = stats;
    state.addons = addons;
    state.ledger = ledger;
    state.publicChars = publicChars;
    state.screenshots = screenshots;
    state.dungeons = dungeons;
    state.guides = asList(guidesFile && guidesFile.guides);
    state.att = attFile;
    state.rarity = rarityFile;
    state.journey = journeyFile;
    state.backstories = (backstoriesFile && backstoriesFile.backstories) || {};
    state.journals = asList(journalsFile && journalsFile.entries);
    state.launch = launchFile;
    state.guild = guildFile;
    state.tallies = (talliesFile && talliesFile.tallies) || {};
    attCache = null;
    // The Google Sheet is retired: the repo JSON files are the only source.
    // state.checks/attempts/taskChecks start empty and live only in this
    // page view; checklist.json still carries the saved hunt list.
    state.checks = {};
    state.attempts = {};
    state.tasks = [];
    state.taskChecks = {};
    loadHunts();
    loadJourney();
    buildOwned();
    buildDrops();
  } catch (error) {
    document.getElementById("lede").textContent = "The tracker data did not load. Open the GitHub Pages site, or serve this folder over http.";
    console.error(error);
    return;
  }
  // Roster identity comes from data/characters.json alone. A saved or
  // linked id that is not on the roster falls back to the first roster
  // character.
  const explicit = params.get("c");
  const asked = explicit && state.characters.some((c) => c.id === explicit);
  if (asked) state.selected = explicit;
  else if (!state.characters.some((c) => c.id === state.selected)) {
    state.selected = state.characters.length ? state.characters[0].id : "";
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
  document.getElementById("character-picker").addEventListener("change", (event) => selectCharacter(event.target.value));
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
  document.getElementById("quest-search")?.addEventListener("input", (event) => {
    state.questQuery = event.target.value;
    renderQuests();
  });
  document.getElementById("reset-checks").addEventListener("click", () => { resetHunts(); });
  document.getElementById("journey-reset").addEventListener("click", () => { resetJourney(); });
  document.getElementById("scope").addEventListener("change", (event) => {
    state.scope = event.target.value;
    saveStore();
    renderChecklist();
  });
  render();
}

main();
