---
name: dossier
description: Reads a pasted Dossier character report from World of Warcraft Forever. Use when the user pastes text that starts with "Exported By: Dossier" or "Exported By: AIExport" (its old name), or contains "Character:" and "Biography:" lines.
---

# Dossier report

The user pastes a text report made in game with /dossier.

## Check the paste

- It must contain a "Character: Name-Realm" line. If it does not, ask the user to run /dossier, press Create Export, and paste the whole text.
- One report is one character. If there are two "Exported By:" lines, treat each block as its own character.
- Do not invent data. If a section is missing or says "unavailable", "cached", or "Saved copy from", say so instead of guessing.

## Save it

If you can write files, save the paste unchanged as exports/<name>-<realm>-YYYY-MM-DD.txt using today's date. Add -2, -3 if the file exists. Keep older files; they are the history.

## Read it

- Level, zone, gold, and XP come from "Character Stats:" and "Location:".
- Gear is under "Equipment:", one line per slot with item level, quality, and stats.
- Professions are under "Skills:" and "Profession Details:". Learned recipes are grouped by difficulty color: Orange and Yellow still give skill-ups, Green rarely, Grey never.
- The "Biography:" section is a dated timeline. Each line is "HH:MM event". Use it to see what happened since the last report: levels gained, deaths, new zones, quests turned in, profession gains.
- "Kills:" lists total kills, kills by creature type, the most-killed creatures, and items seen dropping. A pet or guardian killing blow is included in that character's totals.
- "Combat pet:" is the summoned hunter beast, warlock demon, or other combat pet. Status is Out or Dismissed. Family, level, diet, happiness, and abilities are included when the game provides them. "Stable" lists the other pets that character can call. "No combat pet." means none. Battle pets stay in Collections. Use the pet that is out, and the stable, when suggesting a pet or a different tactic.
- "Sessions:" starts with "This session:", the current play session with hourly rates. "== Gathered ==" lists lifetime gathering by type, and "== Recent sessions ==" has one dated line per past session.
- "Shopping list:" is what the player plans to gather or buy. Short items come first, one line each with what they have and need; "Crafting:" lines are recipes they plan to make, and "Ready:" lists what is done.
- "Statistics:" holds the game's own lifetime counters, one "== Category ==" block each. A statistic that is not listed has no value yet.
- "Gold, last 7 days" and "Saved standings" come from Journalator and Altoholic when Other addons is on. "Profession:" and "Rare:" stay when those switches are on.

## Answer

Start with a short recap of the session from the Biography, then answer what the user asked. Name real quests, zones, and items from the report. Keep advice to things the character can do at its current level. Suggest a pet or a tactic only from the Combat pet section and the stable, not from a pet the report does not list.
