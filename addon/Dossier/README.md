# Dossier

Copy your World of Warcraft Forever character into an AI chat.

Type `/dossier`, press **Create Export**, and paste the text into Cursor, ChatGPT, Claude, Gemini, or any other assistant. The report covers your level, zone, gold, stats, gear, bags, bank, professions, quests, talents, spells, kills, play sessions, in-game statistics, and addons, plus a **Biography** timeline of what your character has done since you installed Dossier. The **Session** timer tracks kills, gathering, gold, and XP per hour, like Gathering. The **Shopping list** tracks what you plan to gather or buy. The **Screenshotter** takes screenshots at big moments, like Memento. Every one of these can be switched off on the **Features** tab.

Dossier needs no other addon. Everything in the report comes from the game and from Dossier itself. If you use some popular addons, Dossier can also add what they know; see [Companions](#companions).

Dossier was called **AIExport** before version 2.0.0. `/aixport` still works. See [Coming from AIExport](#coming-from-aiexport) to keep your Biography, kills, and settings.

## Install

1. Download the zip and open it.
2. Copy the `Dossier` folder into `World of Warcraft\_classic_beta_\Interface\AddOns\`. The file `Dossier.toc` must sit directly inside `AddOns\Dossier\`, not in a nested folder.
3. Start the game, open **AddOns** on the character select screen, and make sure Dossier is ticked.

## Coming from AIExport

The game keeps each addon's saved data in a file named after the addon, so Dossier cannot read what AIExport saved on its own. Copy it over once, before Dossier runs for the first time:

1. Close the game.
2. In each character folder, `World of Warcraft\_classic_beta_\WTF\Account\<account>\<realm>\<character>\SavedVariables\`, copy `AIExport.lua` to `Dossier.lua`.
3. Open `Dossier.lua` in a text editor and change `AIExportDBChar` on the first line to `DossierDBChar`.
4. Delete the `AIExport` folder from `Interface\AddOns\`, install Dossier, and start the game.

If AIExport is still loaded, Dossier prints a reminder in chat to turn it off.

## Commands

| Command | What it does |
| --- | --- |
| `/dossier` | Open the Dossier window |
| `/dossier bio` | Open the Biography tab |
| `/dossier kills` | Open the Kills tab |
| `/dossier session` | Open the Session tab |
| `/dossier panel` | Show or hide the live session panel |
| `/dossier shop` | Open the Shopping tab |
| `/dossier shots` | Open the Screenshotter tab |
| `/dossier shot` | Take a screenshot now |
| `/dossier companions` | Open the Companions tab |
| `/dossier features` | Open the Features tab |
| `/dossier off <feature>` | Turn a feature off: `bio`, `kills`, `session`, `shop`, `shots`, or `companions` |
| `/dossier on <feature>` | Turn it back on |
| `/dossier help` | Open the guide and the example AI skill |

Left-click the minimap button to open the window. Right-click it to show or hide the live session panel.

## The window

The window has nine tabs down the left side. A feature you turn off on the Features tab also hides its tab.

- **Export**: the report sections, grouped into Character, Inventory, Progress, Abilities, Story, and System cards, with **Select All**, **Clear All**, and **Create Export**.
- **Biography**: your timeline, 40 lines per page.
- **Kills**: every creature you have killed, with search, sorting, and each creature's drops and gold.
- **Session**: the session timer, this session's kills, gathering, gold, and XP, and the live session panel options.
- **Shopping**: the items and recipes you plan to gather or buy, with what you have and what you still need.
- **Screenshotter**: automatic screenshots at big moments, with a switch for each moment.
- **Companions**: the optional addons Dossier can read, each with its status and an on/off switch.
- **Features**: a switch for each part of Dossier.
- **Help**: the guide, a **Copy guide** button, and the options (minimap icon, item stats in bags and bank, detailed export, Reload UI).

The export window shows an approximate token count (about 4 characters per token) and the three largest sections, so you can untick what you do not need. Turn on **Detailed export** to get item, spell, and quest IDs back.

## Make an export

1. Type `/dossier`.
2. On the **Export** tab, tick the sections you want, or press **Select All**.
3. Press **Create Export**. The text is already selected.
4. Press Ctrl+C and paste it into your AI chat.

Open your bank and each profession window once per session. The game only lets addons read those while they are open, so Dossier keeps the last copy it saw. The Export tab lists anything not saved yet, or saved more than a week ago, and marks those sections with "!". Until then, Dossier uses Syndicator's bank copy and Profession Master's recipes if those addons are loaded.

## Biography

From the moment it is installed, Dossier writes down what happens to each character it is loaded on:

- Logging in, when level or zone changed since the last session
- Level-ups, with the zone
- Deaths, with the subzone and zone
- The first time you enter each zone in a session
- Quests you turn in, by name
- Achievements you earn
- Learning a profession, and each rise in profession skill
- Every screenshot the game saves, with where it was taken, whether you pressed the key or the Screenshotter or Memento took it. Screenshotter shots also say why, for example "Screenshot: Reached level 12, in Westfall".

Nothing is deleted. The Biography tab shows 40 lines per page, with **Older** and **Newer** to move through the rest. Every export includes the whole timeline.

The game saves the full log when you log out or type `/reload`, in:

`World of Warcraft\_classic_beta_\WTF\Account\<account>\<realm>\<character>\SavedVariables\Dossier.lua`

The Biography starts when Dossier is installed. It does not reconstruct earlier play.

## Kills

Dossier counts every creature you or your pet finish off. Creatures another player tagged first are not counted. Inside dungeons and raids the game hides which creature died, so only bosses are recorded there, in the Biography. Loot and gold you take from a corpse are added to that creature.

- The **Kills** tab lists each creature with its kills, level, zone, and when you last killed one. Search by name, sort by most kills, name, or most recent, and click a creature to see its drops and gold.
- Creature tooltips show "Killed 12 times". Untick **Kill count on creature tooltips** on the Kills tab to turn that off.
- The **Kills** export section lists total kills, kills by creature type, your top 25 creatures, items seen dropping, and gold looted.

The **Statistics** export section, also in the Progress card and on by default, copies the Statistics tab of the Achievements window: every statistic that has a value, such as deaths, gold acquired, and quests completed, grouped by category. Statistics with no value yet are left out.

If KillDex was installed, Dossier copies its kill history once, the first time it loads, so earlier kills carry over. After that KillDex is no longer needed.

## Session

The **Session** tab times one stretch of play, so Gathering is no longer needed. The timer starts by itself with your first kill, loot, gold, or XP, and tracks:

- Kills, and kills per hour
- Items gathered: herbs, ore and stone, leather, cloth, cooking and fish, elemental, enchanting, and jewelcrafting materials, reagents, holiday items, and consumables. Untick a type under **Count as gathered** to stop counting it. Quest items are off at first.
- Gold gained or spent, and XP, each with an hourly rate, plus the time to your next level at this pace

**Pause** stops the clock and **Start** goes on. **Reset** ends the session, saves it in your last 20 sessions, and starts a new one. **Previous sessions** on the tab lists them by date and time, with how long each lasted, the zone, kills, gathering, gold, and XP. Money from the mailbox or guild bank is not counted as earned. A `/reload` keeps the session going; after more than 10 minutes logged out, the old session is saved and a new one starts.

**Show the session panel**, `/dossier panel`, or right-clicking the minimap button opens a small window with the timer, kills, gathering, gold, XP, and your last creatures. Pick which lines it shows, drag it where you want it, and press **Lock**. The **Panel background** slider sets its background from fully clear (0%) to solid (100%). Left-click the panel title to pause or start, right-click it to reset, and point at it to see your top 15 items gathered with their hourly rates. The panel keeps your last 10 creatures, so it stops growing; the Session tab has the full item list.

The **Sessions** export section, in the Story card and on by default, has the current session with hourly rates, everything you have ever gathered grouped by type, and your last 10 sessions. **Detailed export** adds item IDs and lists every item and saved session.

Gathering's own totals are account-wide, so they are not copied in. Dossier counts gathering per character from the day you update.

## Shopping list

The **Shopping** tab keeps a list of what you plan to gather or buy and counts what you already have in your bags and bank. It only keeps track: Dossier never buys anything or moves items for you.

Click the box at the top, shift-click an item from your bags, a vendor, or a profession window, and press Enter or **Add**. You can also drag an item onto the box, or type its name or item ID.

- A new item starts at one stack. **+** and **-** change how many you want (hold Shift for 5), and **x** removes it.
- Shift-click a recipe from a profession window to add its reagents, times how many you want to craft. If the game has not shown Dossier the reagents yet, the tab asks you to open that profession window once. Each craft lowers the count by one.
- Each line shows what you have against what you need, and **ready** or **need 8**. Point at a line to see bags and bank counts and why you need it.
- **Clear finished** removes the items you now have enough of.
- **Remind me at vendors and on login** prints a chat line at login when you are short of anything, and at a vendor that sells something on the list.

The bank count uses the copy Dossier saved the last time your bank was open. The **Shopping list** export section, in the Inventory card and on by default, lists what you are short of, the recipes you plan to craft, and what is ready.

If Consumable-Connoisseur is loaded, Dossier copies this character's restock list once, into an empty shopping list. Connoisseur's auto-buying, bank stashing and withdrawing, reputation purchases, consumable upgrades, and starter lists are left out, because Dossier records the character instead of acting for it.

## Features

Every part of Dossier can be turned off on the **Features** tab, or with `/dossier off <feature>` and `/dossier on <feature>`: Biography, Kills, Session, Shopping list, Screenshotter, and Companions.

A feature that is off stops completely: its game events are no longer watched, its tab is hidden, its section on the Export tab is greyed out with "(off)" and left out of the report, and its commands say how to turn it back on. Turning Session off also hides the session panel and saves the current session to Previous sessions. Turning Companions off stops Dossier reading any other addon.

Nothing a feature saved is deleted, so its history comes back when you turn it on. The switches apply to every character on the account and are saved in `WTF\Account\<account>\SavedVariables\Dossier.lua`. The Export tab, its other sections, and Help are always on.

## Screenshotter

The **Screenshotter** tab takes screenshots for you at big moments, so Memento is no longer needed. **Take screenshots automatically** turns it all on or off, and each moment has its own switch:

- Level up, death, and achievement earned
- Dungeon or raid boss killed
- Battleground or arena ends, and duel finished
- New mount, pet, toy, or recipe
- Login, and every 5 to 60 minutes (both off at first)

Two moments within 3 seconds, such as a level-up that also earns an achievement, share one screenshot. The options hide the interface for the shot (skipped in combat), add a name, level, and date stamp while it is hidden, play a camera sound, and print a chat line. **Take test screenshot** or `/dossier shot` takes one right away, even when automatic screenshots are off.

While Memento is loaded, the Screenshotter pauses and says so on the tab. Disable Memento in the AddOns list to let Dossier take over.

Screenshots are saved in `World of Warcraft\_classic_beta_\Screenshots` with the game's usual names, because addons cannot rename files. Each one is noted in the Biography with the reason, so a tool that reads the Biography can name and caption them.

## Companions

Dossier never requires another addon. When one of these is loaded, Dossier reads what it saved for the current character and adds a block to the **Companions** section of the export:

| Addon | What it adds |
| --- | --- |
| Syndicator | Your mail, and your bank contents even while the bank is closed |
| KillDex | Total kills, creature types, your top 15 creatures, and items seen dropping. Shown as "Built into Dossier" and left out once Dossier has kills of its own |
| AllTheThings | Deaths, quests, areas explored, time played, and mount, pet, toy, and title counts |
| Nova Instance Tracker | Your saved lockouts and recent instance runs |
| Profession Master | Every recipe you know, grouped by profession |
| Auctionator | The auction price of each stack in your bags, plus a total |
| Memento | The boss kills it recorded. Shown as "Built into Dossier" while the Screenshotter is on and Memento is not loaded |
| Talents Forever | Your planned talent build and saved builds for your class |

Each one is optional. The **Companions** tab shows whether each addon is loaded, installed but not loaded, or not installed, and has a switch to leave it out. Switches are on by default and only work while that addon is loaded. Untick **Companions** on the Export tab to leave them all out.

If one of these addons changes how it saves data, its block says it could not be read instead of breaking the export.

## Use it with an AI

Paste one character per message and say what you want: a leveling plan, a gear check, a profession route, a session recap, or a story about your character. Paste a new export each session; the Biography shows what changed.

`/dossier help` includes an example skill you can save as `SKILL.md` for assistants that load skill files, such as Cursor. It tells the assistant how to check the paste, save it with the date, read each section, and recap the session from the Biography.

The report contains your character name, realm, and gold. Only paste it where you are comfortable sharing that.

## License

MIT. See `LICENSE`.
