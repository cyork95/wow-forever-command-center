const WRITE_KEY = "wow-forever-sheet-write";

const HUNT_FIELDS = new Set([
  "id", "parentId", "name", "type", "zone", "minLevel", "priority", "status",
  "owners", "notes", "how", "source", "mobs", "need", "defaultDone", "tries"
]);

const TASK_FIELDS = new Set(["id", "name", "cadence", "zone", "notes"]);

const config = {
  characters: "",
  hunts: "",
  tasks: "",
  scriptUrl: "",
  writeSecret: "",
  writeSource: ""
};

function parseCsv(text) {
  const rows = [];
  let row = [];
  let cell = "";
  let inQuotes = false;
  const src = String(text || "").replace(/^\uFEFF/, "");
  for (let i = 0; i < src.length; i += 1) {
    const c = src[i];
    if (inQuotes) {
      if (c === '"') {
        if (src[i + 1] === '"') {
          cell += '"';
          i += 1;
        } else {
          inQuotes = false;
        }
      } else {
        cell += c;
      }
    } else if (c === '"') {
      inQuotes = true;
    } else if (c === ",") {
      row.push(cell);
      cell = "";
    } else if (c === "\n") {
      row.push(cell);
      rows.push(row);
      row = [];
      cell = "";
    } else if (c !== "\r") {
      cell += c;
    }
  }
  if (cell.length || row.length) {
    row.push(cell);
    rows.push(row);
  }
  return rows.filter((entry) => entry.some((value) => String(value).trim() !== ""));
}

function rowsToObjects(rows) {
  if (!rows.length) return [];
  const header = rows[0].map((key) => String(key || "").trim());
  return rows.slice(1).map((row) => {
    const obj = {};
    header.forEach((key, index) => {
      if (key) obj[key] = row[index] === undefined ? "" : row[index];
    });
    return obj;
  }).filter((obj) => Object.values(obj).some((value) => String(value).trim() !== ""));
}

function isTrue(value) {
  return String(value || "").trim().toUpperCase() === "TRUE";
}

function splitList(value) {
  const text = String(value || "").trim();
  if (!text) return [];
  if (text.startsWith("[")) {
    try {
      const parsed = JSON.parse(text);
      return Array.isArray(parsed) ? parsed.map((item) => String(item)) : [];
    } catch {
      return [];
    }
  }
  return text.split("|").map((item) => item.trim()).filter(Boolean);
}

function checkMap(row, skip) {
  const checks = {};
  Object.keys(row).forEach((key) => {
    if (!key || skip.has(key)) return;
    checks[key] = isTrue(row[key]);
  });
  return checks;
}

function charactersToStats(rows) {
  const characters = {};
  let updated = null;
  rows.forEach((row) => {
    const id = String(row.id || "").trim();
    if (!id) return;
    let snapshot = {};
    const raw = String(row.snapshot || "").trim();
    if (raw) {
      try {
        const parsed = JSON.parse(raw);
        if (parsed && typeof parsed === "object") snapshot = parsed;
      } catch {
        snapshot = {};
      }
    }
    characters[id] = snapshot;
    const stamp = String(row.exportedAt || "").trim();
    if (stamp && (!updated || stamp > updated)) updated = stamp.slice(0, 10);
  });
  return { updated, characters };
}

function huntsToState(rows) {
  const checks = {};
  const attempts = {};
  const parents = [];
  const parts = [];
  rows.forEach((row) => {
    const id = String(row.id || "").trim();
    if (!id) return;
    checks[id] = checkMap(row, HUNT_FIELDS);
    const tries = String(row.tries || "").trim();
    if (tries) {
      try {
        const parsed = JSON.parse(tries);
        if (parsed && typeof parsed === "object") attempts[id] = parsed;
      } catch {
        attempts[id] = {};
      }
    }
    if (id.startsWith("book:")) return;
    const item = {
      id,
      name: row.name || "",
      type: row.type || "",
      zone: row.zone || "",
      minLevel: Number(row.minLevel) || 0,
      priority: row.priority || "",
      status: row.status || "",
      owners: splitList(row.owners),
      notes: row.notes || "",
      how: row.how || "",
      source: row.source || "",
      mobs: splitList(row.mobs),
      parentId: String(row.parentId || "").trim()
    };
    if (String(row.need || "").trim()) item.need = Number(row.need);
    item.defaultDone = isTrue(row.defaultDone);
    if (item.parentId) parts.push(item);
    else parents.push(item);
  });
  const byId = new Map(parents.map((item) => [item.id, item]));
  parts.forEach((part) => {
    const parent = byId.get(part.parentId);
    if (!parent) return;
    if (!parent.parts) parent.parts = [];
    const piece = {
      id: part.id,
      name: part.name,
      how: part.how,
      mobs: part.mobs
    };
    parent.parts.push(piece);
  });
  return { checklist: parents, checks, attempts };
}

function tasksToState(rows) {
  const tasks = [];
  const taskChecks = {};
  rows.forEach((row) => {
    const id = String(row.id || "").trim();
    if (!id) return;
    tasks.push({
      id,
      name: row.name || "",
      cadence: row.cadence || "once",
      zone: row.zone || "",
      notes: row.notes || ""
    });
    taskChecks[id] = checkMap(row, TASK_FIELDS);
  });
  return { tasks, taskChecks };
}

async function fetchJson(path) {
  const response = await fetch(path, { cache: "no-cache" });
  if (!response.ok) throw new Error(`${path} ${response.status}`);
  return response.json();
}

async function loadConfig() {
  config.writeSource = "";
  config.scriptUrl = "";
  config.writeSecret = "";
  try {
    const pub = await fetchJson("data/sheet.json");
    config.characters = String(pub.characters || "");
    config.hunts = String(pub.hunts || "");
    config.tasks = String(pub.tasks || "");
  } catch {
    config.characters = "";
    config.hunts = "";
    config.tasks = "";
  }
  try {
    const local = await fetchJson("data/sheet.local.json");
    config.scriptUrl = String(local.scriptUrl || "");
    config.writeSecret = String(local.writeSecret || "");
    if (local.characters) config.characters = String(local.characters);
    if (local.hunts) config.hunts = String(local.hunts);
    if (local.tasks) config.tasks = String(local.tasks);
    if (config.scriptUrl && config.writeSecret) config.writeSource = "file";
  } catch {
    try {
      const saved = JSON.parse(localStorage.getItem(WRITE_KEY) || "{}");
      config.scriptUrl = String(saved.scriptUrl || "");
      config.writeSecret = String(saved.writeSecret || "");
      if (config.scriptUrl && config.writeSecret) config.writeSource = "browser";
    } catch {
      config.scriptUrl = "";
      config.writeSecret = "";
    }
  }
}

async function fetchCsv(url) {
  const response = await fetch(url, { cache: "no-cache" });
  if (!response.ok) throw new Error(`${response.status}`);
  return rowsToObjects(parseCsv(await response.text()));
}

async function loadLive() {
  await loadConfig();
  if (!config.characters || !config.hunts || !config.tasks) return null;
  try {
    const [characters, hunts, tasks] = await Promise.all([
      fetchCsv(config.characters),
      fetchCsv(config.hunts),
      fetchCsv(config.tasks)
    ]);
    const stats = charactersToStats(characters);
    const huntState = huntsToState(hunts);
    const taskState = tasksToState(tasks);
    return {
      stats,
      checklist: huntState.checklist,
      checks: huntState.checks,
      attempts: huntState.attempts,
      tasks: taskState.tasks,
      taskChecks: taskState.taskChecks
    };
  } catch (error) {
    console.error(error);
    return null;
  }
}

function canWrite() {
  return !!(config.scriptUrl && config.writeSecret);
}

function readWriteSettings() {
  return { scriptUrl: config.scriptUrl, writeSecret: config.writeSecret };
}

function saveWriteSettings(scriptUrl, writeSecret) {
  const next = {
    scriptUrl: String(scriptUrl || "").trim(),
    writeSecret: String(writeSecret || "")
  };
  localStorage.setItem(WRITE_KEY, JSON.stringify(next));
  if (config.writeSource !== "file") {
    config.scriptUrl = next.scriptUrl;
    config.writeSecret = next.writeSecret;
    config.writeSource = next.scriptUrl && next.writeSecret ? "browser" : "";
  }
}

async function post(action, fields) {
  if (!canWrite()) return { ok: false, error: "Sheet writes are not set up." };
  try {
    const response = await fetch(config.scriptUrl, {
      method: "POST",
      redirect: "follow",
      headers: { "Content-Type": "text/plain;charset=utf-8" },
      body: JSON.stringify(Object.assign({ secret: config.writeSecret, action }, fields || {}))
    });
    const data = await response.json();
    if (!data || data.ok !== true) return data || { ok: false, error: "The sheet did not save." };
    return data;
  } catch (error) {
    console.error(error);
    return { ok: false, error: "The sheet did not save." };
  }
}

window.SheetStore = {
  loadConfig,
  loadLive,
  post,
  canWrite,
  readWriteSettings,
  saveWriteSettings,
  writeSource: () => config.writeSource
};
