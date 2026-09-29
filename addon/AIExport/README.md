# AIExport

Copy your World of Warcraft Forever character into an AI chat.

Type `/aixport`, press **Create Export**, and paste the text into Cursor, ChatGPT, Claude, Gemini, or any other assistant. The report covers your level, zone, gold, stats, gear, bags, bank, professions, quests, talents, spells, and addons, plus a **Biography** timeline of what your character has done since you installed AIExport.

AIExport needs no other addon. Everything in the report comes from the game and from AIExport itself.

## Install

1. Download the zip and open it.
2. Copy the `AIExport` folder into `World of Warcraft\_classic_beta_\Interface\AddOns\`. The file `AIExport.toc` must sit directly inside `AddOns\AIExport\`, not in a nested folder.
3. Start the game, open **AddOns** on the character select screen, and make sure AIExport is ticked.

## Commands

| Command | What it does |
| --- | --- |
| `/aixport` | Open the export window |
| `/aixport bio` | Open the Biography timeline |
| `/aixport help` | Show the guide and the example AI skill |

Left-click the minimap button to open the export window.

## Make an export

1. Type `/aixport`.
2. Tick the sections you want, or press **Select All**.
3. Press **Create Export**. The text is already selected.
4. Press Ctrl+C and paste it into your AI chat.

Open your bank and each profession window once per session. The game only lets addons read those while they are open, so AIExport keeps the last copy it saw.

## Biography

From the moment it is installed, AIExport writes down what happens to each character it is loaded on:

- Logging in, when level or zone changed since the last session
- Level-ups, with the zone
- Deaths, with the subzone and zone
- The first time you enter each zone in a session
- Quests you turn in, by name
- Achievements you earn
- Learning a profession, and each rise in profession skill

Nothing is deleted. The Biography window shows 40 lines per page, with **Older** and **Newer** to move through the rest. Every export includes the whole timeline.

The game saves the full log when you log out or type `/reload`, in:

`World of Warcraft\_classic_beta_\WTF\Account\<account>\<realm>\<character>\SavedVariables\AIExport.lua`

The Biography starts when AIExport is installed. It does not reconstruct earlier play.

## Use it with an AI

Paste one character per message and say what you want: a leveling plan, a gear check, a profession route, a session recap, or a story about your character. Paste a new export each session; the Biography shows what changed.

`/aixport help` includes an example skill you can save as `SKILL.md` for assistants that load skill files, such as Cursor. It tells the assistant how to check the paste, save it with the date, read each section, and recap the session from the Biography.

The report contains your character name, realm, and gold. Only paste it where you are comfortable sharing that.

## License

MIT. See `LICENSE`.
