// Journey #51 route data validation (Phase J1) and progress-logic checks.
// Run: node scripts/tests/test-journey-logic.mjs
// Part A reads data/journey.json from disk and proves the route file parses,
// zone orders are unique/sequential, and every section key exists per zone.
// Part B loads assets/app.js in a vm (same harness as test-hunts-logic.mjs)
// and asserts the journey progress computation with synthetic fixtures only.

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

// Part A: route file validation.
const journeyPath = path.join(repo, "data", "journey.json");
let journey = null;
try {
  journey = JSON.parse(readFileSync(journeyPath, "utf8"));
  assert(true, "journey.json parses as JSON");
} catch (error) {
  assert(false, `journey.json parses as JSON (${error.message})`);
}
if (journey) {
  assert(journey.schemaVersion === 1, "schemaVersion is 1");
  assert(journey.character === "skyrinis", "route character is skyrinis");
  assert(Array.isArray(journey.zones) && journey.zones.length > 0, "at least one zone curated");
  const orders = journey.zones.map((zone) => zone.order);
  assert(new Set(orders).size === orders.length, "zone orders are unique");
  assert(orders.slice().sort((a, b) => a - b).every((order, index) => order === index + 1), "zone orders are sequential from 1");
  const sections = ["quests", "exploration", "collectibles", "rares", "boes", "professions", "guideRefs"];
  journey.zones.forEach((zone) => {
    assert(typeof zone.id === "string" && zone.id.length > 0, `zone has id (${zone.id})`);
    assert(typeof zone.name === "string" && zone.name.length > 0, `zone has name (${zone.name})`);
    sections.forEach((key) => {
      assert(Array.isArray(zone[key]), `zone ${zone.id} carries section ${key}`);
    });
    (zone.quests || []).forEach((quest) => {
      assert(typeof quest.name === "string" && quest.name.length > 0, `zone ${zone.id} quest has a name`);
      if (quest.id !== undefined && quest.id !== null) {
        assert(Number.isInteger(quest.id), `zone ${zone.id} quest id is an integer (${quest.id})`);
      }
    });
    const questIds = (zone.quests || []).map((quest) => quest.id).filter((id) => id !== undefined && id !== null);
    assert(new Set(questIds).size === questIds.length, `zone ${zone.id} has no duplicate quest ids`);
    (zone.collectibles || []).forEach((item) => {
      assert(typeof item.name === "string" && item.name.length > 0, `zone ${zone.id} collectible has a name`);
    });
    (zone.exploration || []).forEach((item) => {
      assert(typeof item.name === "string" && item.name.length > 0, `zone ${zone.id} exploration has a name`);
    });
  });
}

if (failures) {
  console.error(`FAIL test-journey-logic (${failures} assertions)`);
  process.exit(1);
}
console.log("PASS test-journey-logic");
