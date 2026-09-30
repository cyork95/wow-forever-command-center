# Using it with an AI

Paste one character per message. Say what you want in the same message as the export, or in the line above it. Paste a new export each session. The Biography shows what changed.

The report contains your character name, realm, and gold. Only paste it where you are comfortable sharing that.

`/dossier help` includes this same skill text, and **Copy guide** puts the in-game guide on the clipboard.

## Before you paste

On the Export tab, leave ticked only the sections the question needs. The window shows an approximate token count and the three largest sections. Biography, completed quests, and profession recipes are often the heavy ones. **Detailed export** is for when you need item, spell, and quest IDs. See [[Making an export]].

If a line says `unavailable`, `cached`, `Saved copy from`, or `Missing:`, that part is the last saved copy or it was never opened. Tell the assistant to treat it that way, or open the bank or profession window, make a new export, and paste again.

## Prompt starters

Put the request first, then the export.

**Leveling plan**

> I am playing this character on WoW Forever. From this Dossier export, give me a leveling plan for the next few levels. Use only zones, quests, and skills that are in the report. Say what I finished recently from the Biography.

**Gear check**

> Read the Equipment section. Tell me the weakest slots for my class and level, and which pieces are fine to keep. Do not invent items that are not in the report.

**Profession route**

> Look at Skills and Profession Details. Orange and Yellow recipes still give skill-ups, Green rarely, Grey does not. Tell me what to craft next, and which reagents are already on my shopping list.

**Shopping-list farm**

> Read the Shopping list section. The short items come first. Give me a gathering or vendor route for what I still need, using the zones in Location and Biography. Skip anything marked ready.

**Session recap**

> Recap this play session in a short paragraph. Use This session, the Biography lines from today, and Recent sessions only as comparison. Include kills per hour, gold, and XP if they are in the report.

**A story of the character**

> Write a short in-character recap of the Biography. Keep every death, zone, and quest turn-in that is actually listed. Do not add events from before the first Biography line.

## How to read a short report

| In the paste | Meaning |
| --- | --- |
| `Exported By: Dossier` | Start of one character. An older paste may say `Exported By: AIExport`. |
| `Character:` | Name and realm. One of these per report. |
| `Location:` and `Character Stats:` | Zone, level, gold, XP, health. |
| `Equipment:` | One line per gear slot. |
| `Skills:` and `Profession Details:` | Ranks and recipes. |
| `Biography:` | Dated timeline. Each line is `HH:MM event`. |
| `Kills:` | Totals, creature types, top creatures, drops, gold looted. |
| `Sessions:` | `This session:`, then `== Gathered ==`, then `== Recent sessions ==`. |
| `Shopping list:` | Short items, then `Crafting:`, then `Ready:`. |
| `Statistics:` | The game's lifetime counters, one `== Category ==` block. A missing statistic has no value yet. |
| `Companions:` | Optional blocks such as `== Syndicator ==`. Absent when those addons are off or not installed. |

Two `Exported By:` lines means two characters. Ask the assistant to treat each block on its own.

## Example skill

Some assistants, such as Cursor, can load a saved instruction file called a skill. Save the text below as `SKILL.md` in a folder named `dossier`, for example `.cursor/skills/dossier/SKILL.md` in your project, or paste it at the start of a chat in any other assistant.

```markdown
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
- "Kills:" lists total kills, kills by creature type, the most-killed creatures, and items seen dropping.
- "Sessions:" starts with "This session:", the current play session with hourly rates. "== Gathered ==" lists lifetime gathering by type, and "== Recent sessions ==" has one dated line per past session.
- "Shopping list:" is what the player plans to gather or buy. Short items come first, one line each with what they have and need; "Crafting:" lines are recipes they plan to make, and "Ready:" lists what is done.
- "Statistics:" holds the game's own lifetime counters, one "== Category ==" block each. A statistic that is not listed has no value yet.
- "Companions:" holds optional blocks such as "== Syndicator ==". They only appear when the player has those addons.

## Answer

Start with a short recap of the session from the Biography, then answer what the user asked. Name real quests, zones, and items from the report. Keep advice to things the character can do at its current level.
```
