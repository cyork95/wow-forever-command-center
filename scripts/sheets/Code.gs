var HUNT_TEXT = {
  id: true,
  parentId: true,
  name: true,
  type: true,
  zone: true,
  minLevel: true,
  priority: true,
  status: true,
  owners: true,
  notes: true,
  how: true,
  source: true,
  mobs: true,
  need: true,
  defaultDone: true,
  tries: true
};

var TASK_TEXT = {
  id: true,
  name: true,
  cadence: true,
  zone: true,
  notes: true
};

var SNAPSHOT_LIMIT = 50000;

function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu("Command center")
    .addItem("Parse import", "parseImportFromSheet")
    .addItem("Install checkboxes", "installCheckboxes")
    .addItem("Add character columns", "addCharacterColumns")
    .addToUi();
}

function parseImportFromSheet() {
  var result = parseImport({ json: null });
  var message = result.ok ? "Import saved." : JSON.stringify(result);
  SpreadsheetApp.getUi().alert(message);
}

function doPost(e) {
  var lock = LockService.getScriptLock();
  try {
    lock.waitLock(15000);
  } catch (err) {
    return respond({ ok: false, error: "The sheet is busy." });
  }
  try {
    var body = {};
    try {
      body = JSON.parse(e.postData && e.postData.contents ? e.postData.contents : "{}");
    } catch (err) {
      return respond({ ok: false, error: "The body is not JSON." });
    }
    var secret = PropertiesService.getScriptProperties().getProperty("WRITE_SECRET") || "";
    if (!secret || String(body.secret || "") !== secret) {
      return respond({ ok: false, error: "bad secret" });
    }
    var action = String(body.action || "");
    if (action === "toggleHunt") return respond(toggleFlag("Hunts", body));
    if (action === "toggleTask") return respond(toggleFlag("Tasks", body));
    if (action === "setTries") return respond(setTries(body));
    if (action === "parseImport") return respond(parseImport(body));
    return respond({ ok: false, error: "unknown action" });
  } catch (err) {
    return respond({ ok: false, error: String(err.message || err) });
  } finally {
    lock.releaseLock();
  }
}

function respond(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function sheetByName(name) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(name);
  if (!sheet) throw new Error("Missing tab " + name);
  return sheet;
}

function headerRow(sheet) {
  var last = Math.max(sheet.getLastColumn(), 1);
  return sheet.getRange(1, 1, 1, last).getValues()[0].map(function (value) {
    return String(value || "").trim();
  });
}

function findRowById(sheet, id) {
  var header = headerRow(sheet);
  var idCol = header.indexOf("id");
  if (idCol < 0) return -1;
  var last = sheet.getLastRow();
  if (last < 2) return -1;
  var values = sheet.getRange(2, idCol + 1, last - 1, 1).getValues();
  var wanted = String(id || "");
  for (var i = 0; i < values.length; i++) {
    if (String(values[i][0]) === wanted) return i + 2;
  }
  return -1;
}

function characterIdsFromConfig() {
  var sheet = sheetByName("Config");
  var values = sheet.getDataRange().getValues();
  if (!values.length) return [];
  var header = values[0].map(function (value) { return String(value || "").trim(); });
  var idCol = header.indexOf("id");
  if (idCol < 0) idCol = 0;
  var ids = [];
  for (var i = 1; i < values.length; i++) {
    var id = String(values[i][idCol] || "").trim();
    if (id) ids.push(id);
  }
  return ids;
}

function configName(id) {
  var sheet = sheetByName("Config");
  var values = sheet.getDataRange().getValues();
  if (values.length < 2) return "";
  var header = values[0].map(function (value) { return String(value || "").trim(); });
  var idCol = Math.max(header.indexOf("id"), 0);
  var nameCol = header.indexOf("name");
  if (nameCol < 0) nameCol = 1;
  var wanted = String(id || "");
  for (var i = 1; i < values.length; i++) {
    if (String(values[i][idCol] || "").trim() === wanted) return String(values[i][nameCol] || "").trim();
  }
  return "";
}

function ensureCharacterColumns(sheet) {
  characterIdsFromConfig().forEach(function (id) {
    var header = headerRow(sheet);
    if (header.indexOf(id) !== -1) return;
    var triesAt = header.indexOf("tries");
    var col;
    if (triesAt === -1) {
      col = Math.max(sheet.getLastColumn(), 1) + 1;
    } else {
      col = triesAt + 1;
      sheet.insertColumnBefore(col);
    }
    sheet.getRange(1, col).setValue(id);
    var last = sheet.getLastRow();
    if (last >= 2) sheet.getRange(2, col, last - 1, 1).insertCheckboxes();
  });
}

function addCharacterColumns() {
  ensureCharacterColumns(sheetByName("Hunts"));
  ensureCharacterColumns(sheetByName("Tasks"));
  SpreadsheetApp.getUi().alert("Character columns are in place.");
}

function installCheckboxes() {
  ["Hunts", "Tasks"].forEach(function (name) {
    var sheet = sheetByName(name);
    var textFields = name === "Hunts" ? HUNT_TEXT : TASK_TEXT;
    var ids = {};
    characterIdsFromConfig().forEach(function (id) { ids[id] = true; });
    var header = headerRow(sheet);
    header.forEach(function (label, index) {
      if (!label || textFields[label] || !ids[label]) return;
      var last = sheet.getLastRow();
      if (last < 2) return;
      var range = sheet.getRange(2, index + 1, last - 1, 1);
      var values = range.getValues();
      range.insertCheckboxes();
      range.setValues(values.map(function (row) {
        return [String(row[0]).toUpperCase() === "TRUE"];
      }));
    });
  });
  SpreadsheetApp.getUi().alert("Checkboxes installed.");
}

function toggleFlag(tabName, body) {
  var sheet = sheetByName(tabName);
  ensureCharacterColumns(sheet);
  var id = String(body.id || "").trim();
  var characterId = String(body.characterId || "").trim();
  var row = findRowById(sheet, id);
  if (row < 0) return { ok: false, error: "unknown id" };
  var col = headerRow(sheet).indexOf(characterId);
  if (col < 0) return { ok: false, error: "unknown character" };
  var cell = sheet.getRange(row, col + 1);
  cell.insertCheckboxes();
  cell.setValue(!!body.checked);
  return { ok: true };
}

function setTries(body) {
  var sheet = sheetByName("Hunts");
  var id = String(body.id || "").trim();
  var characterId = String(body.characterId || "").trim();
  if (!id || !characterId) return { ok: false, error: "missing id" };
  var row = findRowById(sheet, id);
  if (row < 0) return { ok: false, error: "unknown id" };
  var header = headerRow(sheet);
  var col = header.indexOf("tries");
  if (col < 0) {
    col = header.length;
    sheet.getRange(1, col + 1).setValue("tries");
  }
  var cell = sheet.getRange(row, col + 1);
  var tries = {};
  var raw = String(cell.getValue() || "").trim();
  if (raw) {
    try {
      var parsed = JSON.parse(raw);
      if (parsed && typeof parsed === "object") tries = parsed;
    } catch (err) {
      tries = {};
    }
  }
  var count = Math.max(0, Math.floor(Number(body.count) || 0));
  if (count === 0) delete tries[characterId];
  else tries[characterId] = count;
  cell.setValue(JSON.stringify(tries));
  return { ok: true };
}

function professionText(list) {
  if (!list || !list.length) return "";
  return list.map(function (skill) {
    if (!skill || !skill.name) return "";
    if (skill.max) return skill.name + " " + skill.current + "/" + skill.max;
    if (skill.current === undefined || skill.current === null) return skill.name;
    return skill.name + " " + skill.current;
  }).filter(Boolean).join(", ");
}

function lookupCharacterId(name) {
  var wanted = String(name || "").trim().toLowerCase();
  if (!wanted) return "";
  var values = sheetByName("Config").getDataRange().getValues();
  if (values.length < 2) return "";
  var header = values[0].map(function (value) { return String(value || "").trim(); });
  var idCol = Math.max(header.indexOf("id"), 0);
  var nameCol = header.indexOf("name");
  if (nameCol < 0) nameCol = 1;
  var wantedFirst = wanted.split(" ")[0];
  var firstHits = [];
  for (var i = 1; i < values.length; i++) {
    var id = String(values[i][idCol] || "").trim();
    var full = String(values[i][nameCol] || "").trim().toLowerCase();
    if (!id || !full) continue;
    if (full === wanted) return id;
    if (full.split(" ")[0] === wantedFirst) firstHits.push(id);
  }
  return firstHits.length === 1 ? firstHits[0] : "";
}

function normalizeImport(data) {
  if (!data || typeof data !== "object") {
    throw new Error("Paste JSON, not the in-game text report.");
  }
  if (data.characters && typeof data.characters === "object" && !Array.isArray(data.characters)) {
    return Object.keys(data.characters).map(function (id) {
      return { id: id, object: data.characters[id] || {} };
    });
  }
  var object = data;
  var id = String(object.id || "").trim();
  if (!id) id = lookupCharacterId(object.character || object.name || "");
  if (!id) throw new Error("No Config row matches this character.");
  return [{ id: id, object: object }];
}

function setCell(sheet, header, row, name, value) {
  var col = header.indexOf(name);
  if (col < 0) return;
  sheet.getRange(row, col + 1).setValue(value);
}

function upsertCharacter(id, object) {
  var text = JSON.stringify(object || {});
  if (text.length > SNAPSHOT_LIMIT) {
    return { id: id, ok: false, error: "snapshot is over 50000 characters" };
  }
  var sheet = sheetByName("Characters");
  var header = headerRow(sheet);
  if (header.indexOf("id") < 0 || header.indexOf("snapshot") < 0) {
    return { id: id, ok: false, error: "Characters is missing its header row." };
  }
  var row = findRowById(sheet, id);
  if (row < 0) row = Math.max(sheet.getLastRow(), 1) + 1;
  setCell(sheet, header, row, "id", id);
  setCell(sheet, header, row, "name", object.character || configName(id) || id);
  setCell(sheet, header, row, "realm", object.realm || "");
  setCell(sheet, header, row, "level", object.level === undefined || object.level === null ? "" : object.level);
  setCell(sheet, header, row, "zone", object.zone || "");
  setCell(sheet, header, row, "subzone", object.subzone || "");
  setCell(sheet, header, row, "goldCopper", object.goldCopper === undefined || object.goldCopper === null ? "" : object.goldCopper);
  setCell(sheet, header, row, "health", object.health || "");
  setCell(sheet, header, row, "powerType", object.powerType || "");
  setCell(sheet, header, row, "playedSeconds", object.playedSeconds === undefined || object.playedSeconds === null ? "" : object.playedSeconds);
  setCell(sheet, header, row, "exportedAt", object.exportedAt || "");
  setCell(sheet, header, row, "professions", professionText(object.professions));
  setCell(sheet, header, row, "snapshot", text);
  return { id: id, ok: true };
}

function parseImport(body) {
  var data = body && body.json ? body.json : null;
  if (!data) {
    var raw = String(sheetByName("Import").getRange("B2").getValue() || "").trim();
    if (!raw) return { ok: false, error: "Import B2 is empty." };
    try {
      data = JSON.parse(raw);
    } catch (err) {
      return { ok: false, error: "Import B2 is not JSON. Paste the character JSON from the scan, not the in-game text report." };
    }
  }
  if (typeof data === "string") {
    try {
      data = JSON.parse(data);
    } catch (err) {
      return { ok: false, error: "That paste is not JSON." };
    }
  }
  var entries;
  try {
    entries = normalizeImport(data);
  } catch (err) {
    return { ok: false, error: String(err.message || err) };
  }
  var results = entries.map(function (entry) {
    return upsertCharacter(entry.id, entry.object || {});
  });
  var ok = results.length > 0 && results.every(function (row) { return row.ok; });
  return { ok: ok, results: results };
}
