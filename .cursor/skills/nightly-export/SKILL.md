---
name: nightly-export
description: Saves a pasted Dossier (formerly AIExport) dump into exports/, runs the local addon scan, and merges the character into data/stats.json, data/exports/, and data/biography/. Use when the user pastes game details (text with "Exported By: Dossier" or "Exported By: AIExport", "Location:", "Character Stats:", "Character:", or "AddOns Count:"), says "nightly export", "here's my export", or asks to log tonight's session.
---

# Nightly export

The user pastes the text from `/dossier` (or the old `/aixport`) in game. Save it, scan, merge, then commit and open a PR. Do not ask before running the scan.

The player-facing guide and the public example skill live in `addon/Dossier/Guide.lua` (`/dossier help` in game). That guide stays generic. The steps below are for this house sheet only.

## 1. Check the paste

- It must contain a `Character: Name-Realm` line. If it does not, ask for the `/dossier` text and stop.
- One file per character. If the paste has more than one `Character:` line, split it at each `Exported By:` line, or at each `Location:` line for older CharacterExport dumps that have no header.
- Beta guard: if the realm contains `Beta` and the name is Skyrinis, Sorinis, or Malavus, stop and tell the user. Those names are reserved and never go in beta.

## 2. Save the raw dump

- Folder: `exports/beta/` when the realm contains `Beta`, otherwise `exports/live/`.
- File: `<first>-<last>-YYYY-MM-DD.txt` in lowercase, using today's date. Example: `exports/beta/flann-anvilhew-2026-09-25.txt`. If that file exists, add `-2`, `-3`, and so on.
- Write the paste verbatim with the Write tool. Do not trim or reformat it. The scanner reads the date in the file name as `exportedAt`, so the new file becomes the newest dump.
- If the user typed statistics counters (kills, quests, deaths) outside the paste, save them in the JSON step below, not in the raw file.

## 3. Run the scan

`scripts/addons.local.json` must exist and is never committed. If it is missing, copy `scripts/addons.example.json`, set `addonsPath` to `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns`, and continue.

Run from the repo root. On this machine the Shell tool needs `required_permissions: ["all"]`, and PowerShell 5 does not accept `&&`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/scan-addons.ps1
```

Read the output:

- `Wrote N addons to data/addons.json` means the addon list refreshed.
- `Merged <name> into data/stats.json (<id>)` means the sheet updated. It also writes `data/exports/<name>-<date>.json`.
- `Updated <name> from Nova Instance Tracker, Syndicator, ...` means the scan read that character's addon saves under `WTF`. This runs even without a paste. The saves are written when the user logs out or types `/reload`, so a character still logged in shows last session's numbers.
- `Skipped unmatched character: <name>` means the name is not in `data/characters.json`. Ask whether to add them, with race, class, spec, and professions from the dump. Do not guess a spec. After adding them, run the scan again.
- Some dumps carry only the first name (`Character: Trendirun-Realm`). The scan matches those on the roster's first name, so keep the full name from the one over the character's head in a screenshot.

The scan pulls these from addon saves, so none of their in-game export buttons are needed:

- Syndicator: item names in bags, bank, mail, and worn gear. Hunts with a matching name check themselves on the site.
- Profession Master: known recipes and profession skill. A recipe hunt checks itself once the recipe is learned.
- AllTheThings: time played, deaths, quests, areas explored, and collection counts.
- Nova Instance Tracker: level, gold, and lockouts when its save is newer than the dump.
- KillDex: total kills, creature types, and the top five mobs. It also logs kills of mobs named in a hunt's `mobs` list, and marks hunt items it saw drop, so a hunt checks itself as looted even after the item is sold.
- Questie: finished quest ids. Names, levels, and zones come from QuestieDB and are rewritten into `data/quests.json`, so commit that file when it changes. A `Resolved Quests` list in the dump fills names the database does not have. The quests still in the log are not in the save.
- Forever Dungeon Journal: its boss, loot, and quest tables live in the addon's Lua file. The scan rewrites `data/dungeons.json` from them, so commit that file when it changes.
- Memento: its save holds settings and boss kills. Its screenshots are handled in the next section.
- Dossier: the Biography timeline in each character's `Dossier.lua` (or `AIExport.lua` before the 2.0.0 rename). The scan prints `Wrote N biography events for <name> to data/biography/<id>.json` and keeps events already in that file.

## 3b. Name the new screenshots

Dossier's Screenshotter (AIExport 1.6.0 and later) takes screenshots into `<game>\Screenshots` on level-ups, deaths, achievements, boss kills, and similar moments. Older shots came from Memento. The scan adds each new file to `data/screenshots.json` with `who: null`.

AIExport 1.2.0 and later records a `screenshot` event in the Biography each time the game saves one. When a roster character's `data/biography/<id>.json` has a screenshot event within 10 seconds of a file's `takenAt`, the scan sets `who` to that character and prints `Named N screenshots from Dossier biography events`.

Screenshotter events also carry a `reason`, such as `Reached level 12`. The scan copies it into an empty `caption` and prints `Captioned N screenshots from Screenshotter reasons`. Those captions are fine as they are. Shots whose event has no reason (the player pressed Print Screen, or Memento took it) still need a `caption`.

Once `who` is known, the scan names the files `YYYY-MM-DD_HHMM_Character-Name_reason.jpg`, using the caption for the reason (`screenshot` when there is none). The website copy under `assets/shots/<id>/` gets that name, and a full-size copy goes to `<game>\Screenshots\Dossier\` (recorded as `archive`). It prints `Named N files`. Setting or changing a caption renames both copies on the next run. The game's original files are never moved, so `source` keeps matching.

Whatever is left is printed as `Screenshots with no character yet (N): ...`. This happens for shots taken before AIExport 1.2.0, or on a character without it. For each of those entries:

1. Open the image from `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Screenshots\<source>` with the Read tool.
2. The Screenshotter and Memento hide the UI, but the player's own name stays over their head. Set `who` to that full name, for example `Flann Anvilhew`. If the name is not visible (a loading screen, say), use the character from the nearest shot in the same session. If you still cannot tell, ask the user.
3. Set `caption` to one short sentence about what the shot shows: the quest, the boss, the level, or the place. Only name places and NPCs you can read or are sure of.

Then run the scan again. Shots whose `who` is on the roster get a 1280px copy under `assets/shots/<id>/`, and the site shows them in that character's card. Shots of characters not on the roster stay in the log with `file: null` and are not published.

## 4. Add statistics the dump cannot carry

The scan does not read the export's Statistics section. It fills the `Character` and `Kills` groups from the saves above. If the user gave other counters, add them to that character in `data/stats.json` under `statistics`, using the shape in `data/EXPORTS.md`. The scanner keeps them on later runs.

## 5. Report what changed

Run `git diff --stat` and read the diff for `data/stats.json`. Tell the user in a few sentences: level, zone, gold, profession skill changes, new recipes, and new or removed addons. Name any hunt from `data/checklist.json` that now checks itself because the item or recipe showed up. New hunts go to the Farm Sheet and `data/checklist.json`, not the Roster Doc.

## 6. Commit and open a PR

Follow `.cursor/rules/commit-and-pr.mdc`.

- Start from an up-to-date `main` on a branch named `export-YYYY-MM-DD`. If that branch already has an open PR tonight, push to it instead.
- Stage only the new raw file under `exports/`, `data/addons.json`, `data/stats.json`, the new `data/exports/*.json`, `data/screenshots.json`, new files under `assets/shots/`, changed files under `data/biography/`, `data/quests.json` when the quest catalog changes, and `data/characters.json` if a character was added.
- Never stage `scripts/addons.local.json`.
- Commit message example: `Log Flann's Sep 25 beta session so the sheet shows level 12 and the new Mining skill.`
- Push, run `gh pr create`, and return the PR URL.
