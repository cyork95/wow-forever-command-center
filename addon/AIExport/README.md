# AIExport

Copy your World of Warcraft Forever character into an AI chat.

Type `/aixport`, press **Create Export**, and paste the text into Cursor, ChatGPT, Claude, Gemini, or any other assistant. The report covers your level, zone, gold, stats, gear, bags, bank, professions, quests, talents, spells, kills, and addons, plus a **Biography** timeline of what your character has done since you installed AIExport.

AIExport needs no other addon. Everything in the report comes from the game and from AIExport itself. If you use some popular addons, AIExport can also add what they know; see [Companions](#companions).

## Install

1. Download the zip and open it.
2. Copy the `AIExport` folder into `World of Warcraft\_classic_beta_\Interface\AddOns\`. The file `AIExport.toc` must sit directly inside `AddOns\AIExport\`, not in a nested folder.
3. Start the game, open **AddOns** on the character select screen, and make sure AIExport is ticked.

## Commands

| Command | What it does |
| --- | --- |
| `/aixport` | Open the AIExport window |
| `/aixport bio` | Open the Biography tab |
| `/aixport kills` | Open the Kills tab |
| `/aixport panel` | Show or hide the live kill panel |
| `/aixport companions` | Open the Companions tab |
| `/aixport help` | Open the guide and the example AI skill |

Left-click the minimap button to open the window. Right-click it to show or hide the live kill panel.

## The window

The window has five tabs down the left side:

- **Export**: the report sections, grouped into Character, Inventory, Progress, Abilities, Story, and System cards, with **Select All**, **Clear All**, and **Create Export**.
- **Companions**: the optional addons AIExport can read, each with its status and an on/off switch.
- **Biography**: your timeline, 40 lines per page.
- **Kills**: every creature you have killed, with search, sorting, and each creature's drops and gold.
- **Help**: the guide, a **Copy guide** button, and the options (minimap icon, item stats in bags and bank, detailed export, Reload UI).

The export window shows an approximate token count (about 4 characters per token) and the three largest sections, so you can untick what you do not need. Turn on **Detailed export** to get item, spell, and quest IDs back.

## Make an export

1. Type `/aixport`.
2. On the **Export** tab, tick the sections you want, or press **Select All**.
3. Press **Create Export**. The text is already selected.
4. Press Ctrl+C and paste it into your AI chat.

Open your bank and each profession window once per session. The game only lets addons read those while they are open, so AIExport keeps the last copy it saw. The Export tab lists anything not saved yet, or saved more than a week ago, and marks those sections with "!". Until then, AIExport uses Syndicator's bank copy and Profession Master's recipes if those addons are loaded.

## Biography

From the moment it is installed, AIExport writes down what happens to each character it is loaded on:

- Logging in, when level or zone changed since the last session
- Level-ups, with the zone
- Deaths, with the subzone and zone
- The first time you enter each zone in a session
- Quests you turn in, by name
- Achievements you earn
- Learning a profession, and each rise in profession skill
- Every screenshot the game saves, with where it was taken, whether you pressed the key or Memento took it

Nothing is deleted. The Biography tab shows 40 lines per page, with **Older** and **Newer** to move through the rest. Every export includes the whole timeline.

The game saves the full log when you log out or type `/reload`, in:

`World of Warcraft\_classic_beta_\WTF\Account\<account>\<realm>\<character>\SavedVariables\AIExport.lua`

The Biography starts when AIExport is installed. It does not reconstruct earlier play.

## Kills

AIExport counts every creature you or your pet finish off. Creatures another player tagged first are not counted. Inside dungeons and raids the game hides which creature died, so only bosses are recorded there, in the Biography. Loot and gold you take from a corpse are added to that creature.

- The **Kills** tab lists each creature with its kills, level, zone, and when you last killed one. Search by name, sort by most kills, name, or most recent, and click a creature to see its drops and gold.
- **Show live kill panel** on the Kills tab, `/aixport panel`, or right-clicking the minimap button opens a small window with this session's kills, kills per hour, and the last 10 creatures you killed. Drag it where you want it and press **Lock**. It remembers its place. The **Panel background** slider on the Kills tab sets its background from fully clear (0%) to solid (100%).
- Creature tooltips show "Killed 12 times". Untick **Kill count on creature tooltips** on the Kills tab to turn that off.
- The **Kills** export section lists total kills, kills by creature type, your top 25 creatures, items seen dropping, and gold looted.

If KillDex was installed, AIExport copies its kill history once, the first time it loads, so earlier kills carry over. After that KillDex is no longer needed.

## Companions

AIExport never requires another addon. When one of these is loaded, AIExport reads what it saved for the current character and adds a block to the **Companions** section of the export:

| Addon | What it adds |
| --- | --- |
| Syndicator | Your mail, and your bank contents even while the bank is closed |
| KillDex | Total kills, creature types, your top 15 creatures, and items seen dropping. Shown as "Built into AIExport" and left out once AIExport has kills of its own |
| AllTheThings | Deaths, quests, areas explored, time played, and mount, pet, toy, and title counts |
| Nova Instance Tracker | Your saved lockouts and recent instance runs |
| Profession Master | Every recipe you know, grouped by profession |
| Auctionator | The auction price of each stack in your bags, plus a total |
| Memento | The boss kills it recorded |
| Talents Forever | Your planned talent build and saved builds for your class |

Each one is optional. The **Companions** tab shows whether each addon is loaded, installed but not loaded, or not installed, and has a switch to leave it out. Switches are on by default and only work while that addon is loaded. Untick **Companions** on the Export tab to leave them all out.

If one of these addons changes how it saves data, its block says it could not be read instead of breaking the export.

## Use it with an AI

Paste one character per message and say what you want: a leveling plan, a gear check, a profession route, a session recap, or a story about your character. Paste a new export each session; the Biography shows what changed.

`/aixport help` includes an example skill you can save as `SKILL.md` for assistants that load skill files, such as Cursor. It tells the assistant how to check the paste, save it with the date, read each section, and recap the session from the Biography.

The report contains your character name, realm, and gold. Only paste it where you are comfortable sharing that.

## License

MIT. See `LICENSE`.
