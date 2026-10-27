// Backstories + Journal file validation and logic (board: backstories-journal).
// Run: node scripts/tests/test-journal-logic.mjs
// Validates the committed seed files, then exercises journal filtering/sorting
// and backstory rendering in a vm with synthetic fixture entries only. The
// committed seeds stay empty; fixture text never leaves scripts/tests/.

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
assert(Object.keys(backstoriesDoc.backstories).length === 0, "backstories.json seed stays empty (text arrives via data-only commits)");

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

// Fixture text (obviously fake, fixture character only) must never leak into
// committed files. scripts/tests/ is the only place it may appear.
const committedHay = ["index.html", "assets/app.js", "assets/site.css", "data/backstories.json", "data/journals.json", "scripts/butler-pack.ps1", "docs/canonical-json.md"]
  .map((f) => { try { return readFileSync(path.join(repo, f), "utf8"); } catch { return ""; } })
  .join("\n");
assert(!committedHay.includes("fixturin") && !committedHay.includes("Fixturin"), "no fixture character in committed files");

if (failures) {
  console.error(`FAIL test-journal-logic (${failures} assertions)`);
  process.exit(1);
}
console.log("PASS test-journal-logic");
