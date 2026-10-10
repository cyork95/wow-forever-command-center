# CurseForge page

Project: https://legacy.curseforge.com/wow/addons/dossier-your-character-ready-for-ai

Paste the summary into the project summary field. Paste the description into the project description. Paste the changelog into the file changelog when you upload the zip. Screenshots are uploaded by hand. This file is left out of the addon zip.

Upload file: `dist/Dossier-2.2.18.zip`

## Name

Dossier — Your Character, Ready for AI

## Summary

Paste your World of Warcraft Forever character into any AI chat. Gear, quests, professions, kills, sessions, mail, lockouts, tasks, notes, and a biography that writes itself.

## Description

# Dossier — Your Character, Ready for AI

Type `/dossier`, press **Create Export**, and paste. ChatGPT, Claude, Gemini, Cursor, or any other assistant can then see your level, zone, gold, gear, bags, bank, professions, quests, talents, spells, kills, and how the last few sessions went. Ask for a leveling plan, a gear check, a profession route, or a recap of the night.

Dossier is for World of Warcraft Forever. It needs no other addon.

## What it keeps

- **Export.** Sections grouped into cards. The window shows an approximate token count and the three largest sections, so you can leave out what you do not need. **Detailed export** puts item, spell, and quest IDs back.
- **Biography.** From the day you install it, Dossier writes logins, level-ups, deaths, new zones, quest turn-ins, achievements, boss kills, profession gains, and every screenshot. Nothing is deleted.
- **Kills.** Every creature you or your pet finish. Tooltips can say how many times. Loot and gold stay with that creature. Rare names are marked on the list. An old KillDex history is copied in once.
- **Session.** A timer that starts on your first kill, loot, gold, or XP. Kills, gathering, gold, and XP per hour, plus time to the next level. A small panel you can show, lock, and fade. The last 20 sessions are kept.
- **Mail.** Letters you send and receive, with who, subject, gold, and items. Dossier does not send, take, or return mail.
- **Lockouts.** The instances you are saved to, and a short diary of runs you enter and leave.
- **Tasks.** Things you mean to finish each day, each week, each month, each year, or just once. Done greys out the button and the line changes to Done today, Done this week, and so on. Undo puts it back on the schedule. Edit and Delete stay on each task. A zone panel can show tasks, shopping, and rares here.
- **Notes.** Their own tab. Each note has a title and a body. Two notes sit on a line, and the body wraps so the whole note shows. Edit and Delete stay on each box.
- **Shopping list.** What you mean to gather or buy, against what is already in your bags and bank. Shift-click a recipe to add its reagents. Dossier reminds you at vendors. It never buys or moves anything.
- **Screenshotter.** A shot on level-ups, deaths, achievements, boss kills, and similar moments, with the reason written into the Biography.
- **Switches.** Biography, Kills, Session, Mail, Lockouts, Tasks, Notes, Shopping list, Screenshotter, and Other addons each turn off from the Options tab, or with `/dossier off`. Off means that part stops watching the game and leaves the export. Saved history stays.

Completed quests stay in Questie. A turn-in is still a Biography line, and it can still mark a matching task done. Opening a profession window still fills the recipe section of an export. Dossier does not keep its own profession-rank list.

## A report in four steps

1. Type `/dossier`.
2. Tick the sections you want, or press **Select All**.
3. Press **Create Export**. The text is already selected.
4. Ctrl+C, then paste it into the chat with what you want.

Open your bank and each profession window once. The game only lets an addon read those while they are open, so Dossier keeps the last copy and marks anything missing on the Export tab.

Paste one character per message, and paste a new export when you want the assistant caught up. The Biography is what changed.

The report includes your character name, realm, and gold. Paste it only where you are comfortable sharing that.

## Optional companions

If you already use them, Dossier can add their character data to the report. Other addons is one switch. The export works with none of them.

- Journalator (gold for the last 7 days)
- Altoholic (saved reputation, and profession ranks when that addon already has them)
- Syndicator (mail and bank)
- AllTheThings (deaths, quests, time played, collection counts)
- Nova Instance Tracker (lockouts)
- Profession Master (recipes)
- Auctionator (bag prices)
- Talents Forever (planned builds)
- KillDex (one-time copy of an old kill history)
- Memento (Dossier pauses its own screenshots while Memento is loaded, so you do not get two of each)

Want another addon covered? Ask in the comments.

## Links

- [Player wiki](https://github.com/cyork95/wow-forever-command-center/wiki) — install, export, each tab, and how to use the report with an AI
- [York.Dev](https://yorkdevelops.com/links/) — site, writing, and other projects
- [Buy Me a Coffee](https://buymeacoffee.com/coyofroyo) — if Dossier is useful to you

## Changelog

Paste this into the changelog field for the 2.2.18 file.

2.2.18

- A hunter pet or a warlock demon kill counts for that character when the pet's target dies, the same as your own killing blow. A creature another player tagged first is not counted.
- The export can include the combat pet that is out, or the last one dismissed, and the pets in the stable. Combat pet can be switched off on the Options tab, or left out of one export.

## Screenshots

Upload these in order. Crop each one to the window. The dusk background can stay as a thin edge. Do not upload a second Screenshotter frame. The project avatar is `dist/curseforge-logo.png`, not a carousel image.

1. Export text window, the retake showing `Health: 486/486`. Keep the token line and the report header in frame.
2. Export tab. Cards, Create Export, and the last-export token count.
3. Shopping list, with a have / need line and one item marked ready.
4. Screenshotter, one frame. The tighter of the two Sep 29 shots.

Optional, after clicking a creature so its drops show: the Kills tab. The KillDex copy line is useful. An empty drops box is not.

Still to take before the page goes live:

- Biography with real events (a level, a zone, a quest).
- Session panel on the open world, timer and rates visible.
- Options tab only if there is room after those.

No image files are stored in this repo for the carousel. Use the retake for the export text, not the Sep 29 shot that shows `n/a`.

## Short posts

**X / Discord:** Dossier copies your WoW Forever character into text. `/dossier`, Create Export, paste it into whatever AI you use. It also keeps a biography, kill log, session rates, mail, lockouts, tasks, notes, a shopping list, and screenshots of the big moments. Each of those can be turned off. https://legacy.curseforge.com/wow/addons/dossier-your-character-ready-for-ai

**Links page entry:** Dossier — Your Character, Ready for AI. https://legacy.curseforge.com/wow/addons/dossier-your-character-ready-for-ai

## Page settings

- Category: Data Export. Add Achievements or Miscellaneous only if CurseForge asks for a second.
- Game version: the Forever / classic beta client this build targets. The first paragraph already says Forever so a retail player does not install it by mistake.
- York and Buy Me a Coffee stay in the Links section at the bottom of the description, after what the addon does. The player wiki link stays with them.
- Wiki URL field (the project's external user wiki, separate from the description): `https://github.com/cyork95/wow-forever-command-center/wiki`
