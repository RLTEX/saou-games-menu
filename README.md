[Русский](README_RU.md)

# SAO Utils Games Menu

![Games Menu package preview](saou.games.menu/preview.png)

Games Menu is a minimalist game and application launcher widget for **SAO Utils 2** / **NERvGear** on Windows.

Version **1.2.0** turns the widget into a local game library: add launchers, organise cards into folders, customise their appearance, and keep the original game files untouched.

## Highlights

- Discovers `.lnk` and `.url` files from the included `shortcuts/` folder.
- Supports adding one `.lnk`, `.url`, or `.exe` by drag and drop in Edit Mode.
- Gives every card a stable numeric ID based on its launch identity.
- Lets you edit a card's display title, description, and image without renaming its source file.
- Imports selected card images into widget-managed local storage; PNG, JPG/JPEG, and WebP are supported when the runtime can read them.
- Includes Edit Mode with safe launch blocking, card editing, removal, restore, reordering, and moving between folders.
- Supports custom folders, custom folder icons, and adjustable category-icon scale.
- Keeps card order, folder membership, and user overrides after restart.
- Uses local Lucide-based control icons. See [third-party notices](THIRD_PARTY_NOTICES.md).

## Requirements

- Windows with SAO Utils 2 and NERvGear API 1.x.
- Qt 5 / Qt Quick 2.12 runtime included by SAO Utils.
- Windows PowerShell and Windows Script Host.

## Install

1. Download the release archive and extract `saou.games.menu`.
2. Copy that folder to your SAO Utils / NERvGear packages directory.
3. Restart SAO Utils if the package is not shown yet.
4. Open **Games Menu**.
5. Configure the close action once:

   ```text
   Right-click Games Menu
   -> Close Action...
   -> Widget
   -> Hide Widget
   -> Games Menu
   -> OK
   ```

SAO Utils owns the widget's visibility. Use **Show Widget -> Games Menu** or **Toggle Widget -> Games Menu** to open it later.

## Add games

### Shortcut folder

Put `.lnk` or `.url` files in:

```text
saou.games.menu/shortcuts/
```

They appear in the system **ALL** category after the initial scan or a manual Reload.

### Drag and drop

1. Enable **Edit Mode** with the pencil button in the sidebar.
2. Drop one `.lnk`, `.url`, or `.exe` onto the widget.
3. Review the new-card editor and press **Add**.

The original launcher or executable is never renamed, moved, or modified. The widget keeps its own launch reference; managed copies are used where needed to keep launcher cards available.

## Edit cards and folders

Edit Mode prevents accidental launches. It provides these actions:

- Edit a card's display name, description, and image.
- Reset only a custom title or image to return to automatic discovery.
- Reorder cards inside a category with the grip button.
- Drag a card onto another category to move it. When it is already present there, the widget asks whether to copy or move it.
- Hide a card from the launcher and restore it later through **Settings -> Restore**.
- Create, edit, or remove custom categories.
- Assign a custom category image by path or image drop.
- Adjust **Category Icon Scale** in Widget Settings.

The **ALL** category is system-owned and cannot be removed.

## User data and files

Games Menu keeps user state locally and does not write metadata into game files.

| Data | Location | Notes |
| --- | --- | --- |
| Stable IDs and card state | `saou.games.menu/state/items.json` | Generated local state; ignored by Git. |
| User shortcuts | `saou.games.menu/shortcuts/` | Included folder for normal discovery; contents are ignored by Git. |
| Legacy automatic artwork | `saou.games.menu/user-assets/` | Optional basename-based artwork; ignored by Git. |
| Folder images | `saou.games.menu/folder-icons/` | User-provided assets; ignored by Git. |
| Imported card images | `%LOCALAPPDATA%\SAO Utils\Games Menu\custom-images` | Managed copies; the original image is not changed. |
| Imported launchers | `%LOCALAPPDATA%\SAO Utils\Games Menu\managed-shortcuts` | Managed copies when the launcher must survive source removal. |

Before manually replacing the package folder, keep your `config.local.txt`, `shortcuts/`, `state/`, `user-assets/`, and `folder-icons/` folders.

## Configuration

`saou.games.menu/config.txt` contains package defaults. For local changes that must not be committed, create:

```text
saou.games.menu/config.local.txt
```

Common options:

```text
startHidden=false
maxColumns=3
syncSubtitle=true
folderIconScale=1
```

`shortcutsDir` remains available as an advanced override for an external shortcut directory. Most installations should use the included `shortcuts/` folder instead.

## Compatibility

- Existing folders, shortcut discovery, and automatic artwork lookup continue to work.
- Missing custom images or missing source launchers do not crash the widget; the card falls back safely and remains editable.
- Older local card state is preserved and extended automatically.

## Privacy and licensing

Do not commit personal shortcuts, local state, custom images, or configuration files. The repository ignores those paths by default.

Source code is MIT-licensed; see [LICENSE](LICENSE). User artwork, game names, trademarks, and repository image assets have separate rights and notices in [ASSETS_NOTICE.md](ASSETS_NOTICE.md). Lucide notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Release notes

See [CHANGELOG.md](CHANGELOG.md) for version history.
