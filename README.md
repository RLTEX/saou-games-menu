[English](README.md) | [Русский](README_RU.md)
# SAO Utils Games Menu
![SAOU Games Menu Preview](assets/Preview.gif)

SAO Utils Games Menu is an SAO-style launcher widget for SAO Utils 2 /
NERvGear. Version 1.1.0 ships with an included `shortcuts/` directory: place
`.lnk` or `.url` files there and they appear in the system `ALL` folder.

The widget still launches through the existing Windows shortcut / URI flow and
closes through the configured SAO Utils `Hide Widget -> Games Menu` action.

## Package Structure

The release package already contains the directories needed for normal use:

```text
saou.games.menu/
├─ assets/
├─ folder-icons/
├─ qml/
├─ runtime/
├─ shortcuts/
├─ tools/
├─ user-assets/
├─ config.txt
├─ module.qml
└─ package.json
```

For normal installation, use the included `saou.games.menu/shortcuts/`
directory. `runtime/` and `tools/` are technical package directories used by
the compatible shortcut discovery mechanism.

## Features

- SAO-style interface for SAO Utils 2 / NERvGear.
- Automatic discovery of `.lnk` and `.url` files from the included `shortcuts/` directory.
- Optional external `shortcutsDir` override for advanced setups.
- System `ALL` folder containing every discovered shortcut.
- Custom folders configured by shortcut basename.
- Folder sidebar with custom folder icons.
- Dynamic game cards using the existing `GameCard` component.
- Custom game artwork from `user-assets/`.
- Windows `.lnk` shortcut support.
- Windows `.url` shortcut support.
- Legacy direct launch URI support, including Steam URIs such as `steam://rungameid/1465360`.
- Launch overlay and launch-failed state.
- Close animation after clicking the X button or launching a game.

## Requirements

- SAO Utils 2.
- NERvGear API 1.x.
- Qt 5.
- Qt Quick 2.12.
- Qt Quick Controls 2.12.
- Windows PowerShell, included with supported Windows installations.
- Windows `.lnk` or `.url` shortcut files for automatic discovery.

## Installation

1. Download the release ZIP.
2. Extract the `saou.games.menu` folder.
3. Copy `saou.games.menu` into your SAO Utils 2 / NERvGear packages directory.
4. Place `.lnk` or `.url` files into the included `saou.games.menu/shortcuts/` directory.
5. Restart SAO Utils 2 if it was already running.

## Initial Setup

Games Menu uses a NERvGear `ActionSource` for system-level closing. SAO Utils
must own the real widget visibility, so configure the close action once:

```text
Right-click Games Menu
-> Close Action...
-> Widget
-> Hide Widget
-> Games Menu
-> OK
```

Without this setup, the X button and automatic close after launching a game
cannot hide the widget. To open the menu from a SAO Utils button or tile, use:

```text
Show Widget -> Games Menu
```

`Toggle Widget -> Games Menu` can also be used after the close action is set.

## Configuration

Edit:

```text
saou.games.menu/config.txt
```

For private local settings that should not be committed, create:

```text
saou.games.menu/config.local.txt
```

The loader reads `config.local.txt` first. If it does not exist, it uses
`config.txt`.

The default config does not need `shortcutsDir`. If `shortcutsDir` is absent or
empty, Games Menu scans:

```text
saou.games.menu/shortcuts/
```

Advanced users can override the shortcut folder:

```text
shortcutsDir=C:\Games\Shortcuts
```

Windows paths can use normal backslashes.

## Full Config Example

```text
configVersion=2
startHidden=false
maxColumns=3

folder=favorites|FAVORITES
    game=ZZZ
    game=NTE

folder=racing|RACING
    game=SnowRunner

folder=rhythm|RHYTHM
    game=Muse Dash

# Optional advanced override:
# shortcutsDir=C:\Games\Shortcuts
```

## Shortcut Discovery

Place `.lnk` or `.url` files into the included `shortcuts/` directory. Games
Menu scans that folder and creates one launcher card per discovered shortcut.
For compatibility with the tested SAO Utils runtime, discovery refreshes when
the widget component loads, when `shortcutsDir` changes, and when the existing
open animation hook runs. It does not use a live directory watcher.

For example:

```text
saou.games.menu/shortcuts/SnowRunner.url
```

creates a card titled:

```text
SnowRunner
```

The launch target is the real shortcut file path. Games Menu does not write
discovered games back into `config.txt`.

If both `SnowRunner.lnk` and `SnowRunner.url` exist, both appear in `ALL`.
Custom folder membership by basename resolves deterministically to `.lnk`
before `.url`, and the widget logs a warning.

## Images

For custom game artwork, put a PNG in:

```text
saou.games.menu/user-assets/
```

The PNG name must match the shortcut basename:

```text
shortcuts/SnowRunner.url
user-assets/SnowRunner.png
```

If the PNG is missing or Qt cannot load it, the card falls back to:

```text
saou.games.menu/assets/placeholder.png
```

## Folders

`ALL` is a system folder. It always exists, is not stored in `config.txt`, and
contains every discovered `.lnk` and `.url` shortcut.

Custom folders are declared with:

```text
folder=<folderId>|<displayName>
    game=<ShortcutBaseName>
```

`folderId` is a stable internal id. It is also used for the folder icon lookup.
`displayName` is the text shown in the sidebar and can be changed without
renaming the icon.

Folder game entries use shortcut basenames only. Do not put full paths, image
paths, or launch targets in folder membership.

## Folder Icons

Optional folder icons live in:

```text
saou.games.menu/folder-icons/
```

For:

```text
folder=racing|RACING
```

Games Menu looks for:

```text
folder-icons/racing.png
```

If that file is missing, it tries `folder-icons/default.png`. If no default PNG
is present, the sidebar uses a minimal QML fallback icon.

## Settings

- `configVersion=2` - enables the v1.1.0 auto discovery and folder config.
- `shortcutsDir` - optional external shortcut folder override. Leave it absent
  or empty for the included `shortcuts/` directory.
- `startHidden=true` - asks the configured close action to hide Games Menu after
  SAO Utils starts.
- `maxColumns` - maximum number of cards in one row. The actual number can be
  lower if the widget is narrow.

## Legacy Config Compatibility

The old v1 game line format is still parsed as a compatibility path:

```text
game=Title|Shortcut|Image|Description|Accent|Id
```

Legacy entries are shown after discovered shortcuts. They are not the primary
v1.1.0 configuration style; use the included `shortcuts/` directory plus
`folder=` entries for new setups.

## Updating

Before replacing files from a new release ZIP, save your user data:

- `saou.games.menu/config.txt`, if you edited it directly.
- `saou.games.menu/config.local.txt`, if you created it.
- `saou.games.menu/shortcuts/`, because it can contain your personal shortcuts.
- `saou.games.menu/user-assets/`, because it contains your game images.
- `saou.games.menu/folder-icons/`, because it contains your folder icons.

Then replace the package files from the new release ZIP and put your saved user
files back. A full manual folder replacement can overwrite personal shortcuts,
images, icons, and config files.

## Troubleshooting

### Close Button Does Nothing

Configure the close action:

```text
Right-click Games Menu -> Close Action... -> Widget -> Hide Widget -> Games Menu
```

### A Shortcut Does Not Appear

Check that the file exists in the included `saou.games.menu/shortcuts/`
directory, or in the optional external `shortcutsDir` if you configured one.
The file must end with `.lnk` or `.url`.

### A Folder Is Empty

Check that every folder `game=` line uses the shortcut basename without
extension:

```text
game=SnowRunner
```

for either `SnowRunner.lnk` or `SnowRunner.url`.

### Image Is Not Displayed

Check that the image exists in `saou.games.menu/user-assets/` and that its PNG
file name matches the shortcut basename.

### Folder Icon Is Not Displayed

Check that the icon exists in `saou.games.menu/folder-icons/` and is named after
the folder id, for example `racing.png`.

## License

The project source code is released under the MIT License. See `LICENSE`.

Repository assets, user-supplied artwork, game names, trademarks, and publisher
intellectual property are not automatically covered by the MIT license. See
`ASSETS_NOTICE.md`.
