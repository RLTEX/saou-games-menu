[English](README.md) | [Русский](README_RU.md)
# SAO Utils Games Menu

![SAOU Games Menu Preview](assets/Preview.gif)

SAO Utils Games Menu is an SAO-style launcher widget for SAO Utils 2 /
NERvGear. Version 1.1.0 ships with an included `shortcuts/` directory: place
`.lnk` or `.url` files there and they appear in the system `ALL` folder.

The widget launches through the existing Windows shortcut / URI flow and closes
through the configured SAO Utils `Hide Widget -> Games Menu` action.

## Package Structure

The release package already contains the directories needed for normal use:

```text
saou.games.menu/
|-- assets/
|-- folder-icons/
|-- qml/
|-- runtime/
|-- shortcuts/
|-- state/
|-- tools/
|-- user-assets/
|-- config.txt
|-- module.qml
`-- package.json
```

Use the included `saou.games.menu/shortcuts/` directory for normal
installation. `runtime/`, `state/`, and `tools/` are package-local technical
directories used by discovery and stable ID storage.

## Features

- Automatic discovery of `.lnk` and `.url` files from the included `shortcuts/` directory.
- Stable numeric game IDs based on launch identity, not shortcut filename.
- System `ALL` folder containing every discovered shortcut.
- Custom folders configured by numeric ID.
- Optional external `shortcutsDir` override for advanced setups.
- Custom game artwork from `user-assets/<CurrentShortcutBaseName>.png`.
- Custom folder icons from `folder-icons/<folderId>.png`.
- Windows `.lnk`, Windows `.url`, and legacy direct URI launch support.
- Configurable subtitle inheritance through `syncSubtitle`.
- Close animation after clicking X or launching a game.

## Requirements

- SAO Utils 2.
- NERvGear API 1.x.
- Qt 5 / Qt Quick 2.12 / Qt Quick Controls 2.12.
- Windows PowerShell and Windows Script Host, included with supported Windows installations.
- Windows `.lnk` or `.url` shortcut files for automatic discovery.

## Installation

1. Download the release ZIP.
2. Extract the `saou.games.menu` folder.
3. Copy `saou.games.menu` into your SAO Utils 2 / NERvGear packages directory.
4. Place `.lnk` or `.url` files into the included `saou.games.menu/shortcuts/` directory.
5. Open Games Menu. Existing shortcuts are discovered automatically on startup.
6. Restart SAO Utils 2 if it was already running and the package was not loaded yet.

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
configVersion=3
startHidden=false
maxColumns=3
syncSubtitle=true

# Game metadata:
# item=<ID>|<Title>|<GlobalSubtitle>

item=1|Game|Game Subtitle
item=2|SnowRunner|OFF-ROAD SIMULATOR

folder=favorites|FAVORITES|4
    game=1
    game=2

folder=racing|RACING|2
    game=2|RACING GAME

# Optional advanced override:
# shortcutsDir=C:\Games\Shortcuts
```

IDs are assigned automatically after discovery. You normally do not invent IDs
for newly discovered games by hand.

## Shortcut Discovery And Stable IDs

Place `.lnk` or `.url` files into the included `shortcuts/` directory. Games
Menu scans that folder and creates one launcher card per discovered shortcut.
On component startup, Games Menu runs one controlled initial discovery refresh,
so shortcuts that already exist in `shortcuts/` appear without pressing Reload.
After adding, removing, renaming, or changing shortcuts later, press Reload in
the bottom-left sidebar controls.

Normal workflow:

```text
Place .lnk/.url into shortcuts/
Open Games Menu
Shortcut appears in ALL
```

For example:

```text
saou.games.menu/shortcuts/SnowRunner.url
```

creates a card titled:

```text
SnowRunner
```

During discovery, Games Menu resolves a launch identity:

- `.url`: reads the real `[InternetShortcut] URL=...` value and normalizes it.
- `.lnk`: reads `TargetPath`, `Arguments`, and `WorkingDirectory` through the Windows shortcut API.

That launch identity receives a stable numeric ID stored in:

```text
saou.games.menu/state/items.json
```

The state file maps `launchKey -> numeric ID`. It is local user state, ignored
by Git, and should not be edited manually.

When a new launch identity is found, Games Menu assigns the next numeric ID and
adds one global metadata line:

```text
item=<ID>|<CurrentShortcutBaseName>|Game Subtitle
```

Only the global `item=` metadata line is created automatically. Games Menu does
not automatically add games to `FAVORITES`, `RACING`, or any other custom
folder.

The literal `Game Subtitle` text is only a hint for the user. It is not shown on
cards and is not treated as an explicit subtitle for `syncSubtitle`. Replace it
with your own text to show a subtitle.

Renaming a shortcut changes the title but keeps the same ID when the launch
target is the same. For example, if `Zenless Zone Zero.url` and `ZZZ.url` both
contain `URL=steam://rungameid/2513410`, the existing item is updated:

```text
item=1|Zenless Zone Zero|ACTION RPG
```

becomes:

```text
item=1|ZZZ|ACTION RPG
```

The subtitle is preserved and folder membership remains:

```text
game=1
```

If two shortcuts have the same visible basename but different launch identities,
they receive different numeric IDs. Basename is presentation data, not game
identity.

## Images

For custom game artwork, put a PNG in:

```text
saou.games.menu/user-assets/
```

Recommended game artwork:

- 1200 × 900 px
- aspect ratio 4:3
- PNG recommended

The PNG name still matches the current shortcut basename:

```text
shortcuts/SnowRunner.url
user-assets/SnowRunner.png
```

After renaming `SnowRunner.url` to `My Game.url`, the matching artwork name is:

```text
user-assets/My Game.png
```

If the PNG is missing or Qt cannot load it, the card falls back to:

```text
saou.games.menu/assets/placeholder.png
```

Game card image caching is disabled, so replacing
`user-assets/<CurrentShortcutBaseName>.png` can be picked up after reopening or
pressing Reload.

## Folders

`ALL` is a system folder. It always exists, is not stored in `config.txt`, and
contains every discovered `.lnk` and `.url` shortcut.

Custom folders are declared with numeric IDs:

```text
folder=<folderId>|<displayName>|<maxColumns>
    game=<ID>
    game=<ID>|<FolderSubtitle>
```

`folderId` is a stable internal id. It is also used for the folder icon lookup.
`displayName` is the text shown in the sidebar and can be changed without
renaming the icon.
`maxColumns` is optional. If it is absent, that folder uses the global
`maxColumns`. `ALL` always uses the global `maxColumns`.

Folder entries reference the stable game ID. They do not store title, launch
target, shortcut path, or image path. Title is stored once in the global
`item=<ID>|<Title>|<GlobalSubtitle>` line and is inherited by every folder that
uses `game=<ID>`.

Subtitle sync is controlled by:

```text
syncSubtitle=true
```

With `syncSubtitle=true`, one unique explicit non-empty subtitle for the same
ID is inherited between `ALL` and folder occurrences. Different explicit
subtitles are treated as intentional: the folder with its own subtitle keeps it,
folders without one fall back to the global `item=` subtitle if present, and
`ALL` uses the global subtitle or stays empty.

With `syncSubtitle=false`, there is no inheritance. `ALL` uses only
`item=<ID>|<Title>|<GlobalSubtitle>`, and each folder uses only its own
`game=<ID>|<FolderSubtitle>` value.

## Folder Icons

Optional folder icons live in:

```text
saou.games.menu/folder-icons/
```

Recommended folder icons:

- 512 × 512 px
- transparent PNG
- the icon should occupy most of the canvas without large empty margins

For:

```text
folder=racing|RACING|2
```

Games Menu looks for:

```text
folder-icons/racing.png
```

For the system `ALL` folder, Games Menu looks for:

```text
folder-icons/all.png
```

If that file is missing, it tries `folder-icons/default.png`. If no default PNG
is present, the sidebar uses a minimal QML fallback icon.

## Settings

- `configVersion=3` - enables the stable numeric ID model.
- `item=<ID>|<Title>|<GlobalSubtitle>` - global metadata for an auto-discovered game.
- `Game Subtitle` - placeholder text used for newly auto-added `item=` lines;
  it is not displayed until replaced with custom text.
- `folder=<folderId>|<displayName>|<maxColumns>` - declares a custom folder and
  can optionally override the global `maxColumns` for that folder.
- `game=<ID>` - adds that game ID to a custom folder.
- `game=<ID>|<FolderSubtitle>` - adds that game ID with a folder-specific subtitle.
- `syncSubtitle=true` - default; inherits one unique explicit subtitle per ID.
- `syncSubtitle=false` - disables subtitle inheritance between `ALL` and folders.
- `shortcutsDir` - optional external shortcut folder override. Leave it absent
  or empty for the included `shortcuts/` directory.
- `startHidden=true` - asks the configured close action to hide Games Menu after
  SAO Utils starts.
- `maxColumns` - maximum number of cards in one row. The actual number can be
  lower if the widget is narrow.

## v2 Migration

The basename-based `configVersion=2` model was experimental during v1.1.0
development. Current v1.1.0 config uses `configVersion=3`.

On discovery or Reload, Games Menu attempts a controlled v2-to-v3 migration only
when the current discovered shortcut basename maps unambiguously to one stable
ID. For example:

```text
item=ULTRAKILL|FAST-PACED FPS
folder=favorites|FAVORITES
    game=ULTRAKILL|MY FAVORITE FPS
```

can become:

```text
item=2|ULTRAKILL|FAST-PACED FPS
folder=favorites|FAVORITES
    game=2|MY FAVORITE FPS
```

If a v2 entry cannot be matched unambiguously, Games Menu does not guess. It
keeps the data as a commented `# Unmigrated v2 ...` line and logs a warning.

## Legacy Config Compatibility

The old v1 game line format is still parsed as a compatibility path:

```text
game=Title|Shortcut|Image|Description|Accent|Id
```

Legacy entries are shown after discovered shortcuts. They are not the primary
v1.1.0 configuration style; use the included `shortcuts/` directory plus
`folder=` entries for new setups.

Press Reload after changing `config.txt`; this reloads folders, `item=`
metadata, shortcut discovery, generated metadata lines, subtitle resolution,
and user artwork without restarting SAO Utils.

## Updating

Before replacing files from a new release ZIP, save your user data:

- `saou.games.menu/config.txt`, if you edited it directly.
- `saou.games.menu/config.local.txt`, if you created it.
- `saou.games.menu/shortcuts/`, because it can contain your personal shortcuts.
- `saou.games.menu/state/`, because it contains stable game ID mappings.
- `saou.games.menu/user-assets/`, because it contains your game images.
- `saou.games.menu/folder-icons/`, because it contains your folder icons.

Then replace the package files from the new release ZIP and put your saved user
files back. A full manual folder replacement can overwrite personal shortcuts,
stable IDs, images, icons, and config files.

## Troubleshooting

### Close Button Does Nothing

Configure the close action:

```text
Right-click Games Menu -> Close Action... -> Widget -> Hide Widget -> Games Menu
```

### A Shortcut Does Not Appear

Check that the file exists in the included `saou.games.menu/shortcuts/`
directory, or in the optional external `shortcutsDir` if you configured one.
The file must end with `.lnk` or `.url`, then press Reload in the bottom-left
sidebar controls.

### A Folder Is Empty

Check that every folder `game=` line uses the numeric ID from the matching
`item=` line:

```text
item=2|SnowRunner|OFF-ROAD SIMULATOR

folder=racing|RACING|2
    game=2
```

### Image Is Not Displayed

Check that the image exists in `saou.games.menu/user-assets/` and that its PNG
file name matches the current shortcut basename.

### Folder Icon Is Not Displayed

Check that the icon exists in `saou.games.menu/folder-icons/` and is named after
the folder id, for example `racing.png`.

## License

The project source code is released under the MIT License. See `LICENSE`.

Repository assets, user-supplied artwork, game names, trademarks, and publisher
intellectual property are not automatically covered by the MIT license. See
`ASSETS_NOTICE.md`.
