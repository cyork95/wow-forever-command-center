# Install

Dossier is for World of Warcraft Forever. Install it in that client's AddOns folder.

## First install

1. Download the zip from the CurseForge project and open it.
2. Copy the `Dossier` folder into `World of Warcraft\_classic_beta_\Interface\AddOns\`.
3. The file `Dossier.toc` must sit directly inside `AddOns\Dossier\`. A zip often unpacks as `AddOns\Dossier\Dossier\Dossier.toc`. Move the inner folder up so the `.toc` is one level under `AddOns`.
4. Start the game, open **AddOns** on the character select screen, and make sure Dossier is ticked.
5. Log in and type `/dossier`.

The addon needs no other addon. When Other addons is on, Dossier can read character data another addon already saved. See [[Companions]].

## Coming from AIExport

Dossier was called AIExport before version 2.0.0. `/aixport` still opens it.

The game keeps each addon's saved data in a file named after the addon, so Dossier cannot read what AIExport saved on its own. Copy it over once, before Dossier runs for the first time. If you skip this, the Biography, kills, and settings start empty. Earlier play from before either addon was installed is still absent. See [[Biography]].

1. Close the game.
2. In each character folder, `World of Warcraft\_classic_beta_\WTF\Account\<account>\<realm>\<character>\SavedVariables\`, copy `AIExport.lua` to `Dossier.lua`.
3. Open `Dossier.lua` in a text editor and change `AIExportDBChar` on the first line to `DossierDBChar`.
4. Delete the `AIExport` folder from `Interface\AddOns`.
5. Install Dossier and start the game.

If AIExport is still loaded, Dossier prints a reminder in chat to turn it off, so kills and screenshots are not recorded twice.

## Updates

After a normal update, `/reload` is enough. When a release says the game needs a full restart, exit to the desktop and start the client again. Those releases add new files, and a reload does not load files that were not there when the client started.

Feature switches added in 2.1.0 are saved for every character on the account, in `WTF\Account\<account>\SavedVariables\Dossier.lua`. Character history stays in that character's `SavedVariables\Dossier.lua`.
