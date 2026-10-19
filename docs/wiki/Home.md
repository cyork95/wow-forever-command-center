# Dossier

Dossier copies your World of Warcraft Forever character into text you can paste into an AI chat. Type `/dossier`, press **Create Export**, and paste. ChatGPT, Claude, Gemini, Cursor, or any other assistant can then see your level, zone, gold, gear, bags, bank, professions, quests, talents, spells, kills, and how the last few sessions went.

Dossier is for World of Warcraft Forever. It needs no other addon. Everything in the report comes from the game and from Dossier itself.

`/dossier help` opens a shorter copy of this guide inside the game, with a button that copies it.

## A report in four steps

1. Type `/dossier`, or left-click the minimap button.
2. On the Export tab, tick the sections you want, or press **Select All**.
3. Press **Create Export**. The text is already selected.
4. Press Ctrl+C, then paste it into the chat with what you want.

Open your bank and each profession window once. The game only lets an addon read those while they are open, so Dossier keeps the last copy and marks anything missing. See [[Making an export]].

Paste one character per message. Paste a new export when you want the assistant caught up. The Biography is what changed. The report includes your character name, realm, and gold. Paste it only where you are comfortable sharing that.

## What it keeps

Each of these can be turned off. Off means that part stops watching the game and leaves the export. Saved history stays. See [[Options]].

- **Export.** The sections, grouped into cards, with an approximate token count so you can leave out what you do not need. [[Making an export]]
- **Biography.** From the day you install it: logins, level-ups, deaths, new zones, quest turn-ins, achievements, boss kills, profession gains, and every screenshot. [[Biography]]
- **Kills.** Every creature you or your pet finish, with loot and gold. [[Kills]]
- **Session.** A timer for kills, gathering, gold, and XP per hour, plus time to the next level. [[Session]]
- **Shopping list.** What you mean to gather or buy, against what is already in your bags and bank. [[Shopping list]]
- **Screenshotter.** A shot on level-ups, deaths, achievements, boss kills, and similar moments. [[Screenshotter]]
- **Other addons.** One switch lets Dossier read character data another addon already saved. [[Companions]]

## Commands

`/dossier` opens the window. The full list is on [[Window and commands]].

## Install

Download the zip from CurseForge and copy the `Dossier` folder into `Interface\AddOns`. If you used AIExport before version 2.0, copy its save over once or the Biography starts empty. Steps are on [[Install]].

## Use the report

Tell the assistant what you want: a leveling plan, a gear check, a profession route, a farming route for the shopping list, a session recap, or a story of the character. Prompt starters and an example skill file are on [[Using it with an AI]].

## If something looks wrong

Bank empty, a tab missing, screenshots quiet, or kills missing inside a dungeon: [[Troubleshooting]].

## Changes

Version history lives with the addon: [CHANGELOG.md](https://github.com/cyork95/wow-forever-command-center/blob/main/addon/Dossier/CHANGELOG.md).
