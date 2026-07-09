# SAO Utils Games Menu

SAO Utils Games Menu is a configurable games launcher widget for SAO Utils 2 /
NERvGear. It shows an SAO-style animated menu, builds game cards from a user
config, launches shortcuts or launch URIs, and then closes through a configured
SAO Utils action.

## Features

- SAO-style interface for SAO Utils 2 / NERvGear.
- Configurable games without editing QML.
- Dynamic game cards.
- Vertical scrolling grid with `maxColumns`.
- Custom game artwork from `user-assets/`.
- Windows `.lnk` shortcut support.
- Windows `.url` shortcut support.
- Direct launch URI support, including Steam URIs such as `steam://rungameid/1465360`.
- Launch overlay and launch-failed state.
- Close animation after clicking the X button or launching a game.

## Requirements

- SAO Utils 2.
- NERvGear API 1.x.
- Qt 5.
- Qt Quick 2.12.
- Qt Quick Controls 2.12.
- Windows shortcuts or launch URIs for games.

## Releases

For normal use, download the ready-made ZIP from GitHub Releases. Cloning the
repository is mainly useful if you want to edit or develop the widget.

## Installation

1. Download the release ZIP.
2. Extract the `saou.games.menu` folder.
3. Copy `saou.games.menu` into your SAO Utils 2 / NERvGear packages directory.
4. Restart SAO Utils 2 if it was already running.

## Initial Setup

Games Menu uses a NERvGear `ActionSource` for system-level closing. SAO Utils
must own the real widget visibility, so you need to configure the close action
once:

```text
Right-click Games Menu
-> Close Action...
-> Widget
-> Hide Widget
-> Games Menu
-> OK
```

Without this setup, the X button and automatic close after launching a game
cannot hide the widget. This is the expected configuration step for the current
architecture.

To open the menu from a SAO Utils button or tile, configure that button as:

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

Windows paths can use normal backslashes:

```text
shortcutsDir=C:\Games\Shortcuts
```

## Full Config Example

```text
shortcutsDir=C:\Games\Shortcuts
startHidden=false
maxColumns=3

game=Game|Game.lnk|game.png|GAME DESCRIPTION
game=SnowRunner|SnowRunner.url|snowrunner.png|SNOWRUNNER
game=SnowRunner URI|steam://rungameid/1465360|snowrunner.png|SNOWRUNNER
```

## Game Line Format

```text
game=Title|Shortcut|Image|Description|Accent|Id
```

Required fields:

- `Title` - card title.
- `Shortcut` - `.lnk`, `.url`, absolute path, or direct launch URI.
- `Image` - image file name from `user-assets/`, or a supported explicit path.

Optional fields:

- `Description` - bottom card text. On hover it is replaced by `LAUNCH  >`.
- `Accent` - hover border and bottom line color, for example `#74DFFF`.
- `Id` - internal id. If omitted, it is generated from `Title`.

Examples:

```text
game=Game|Game.lnk|game.png|GAME DESCRIPTION
game=SnowRunner|SnowRunner.url|snowrunner.png|SNOWRUNNER
game=SnowRunner|steam://rungameid/1465360|snowrunner.png|SNOWRUNNER
```

If `Shortcut` is `Game`, the widget appends `.lnk` and launches
`Game.lnk`. If it already ends with `.lnk`, ends with `.url`, or is a direct URI
such as `steam://rungameid/1465360`, the value is kept as-is.

## Images

For normal use, put game images in:

```text
saou.games.menu/user-assets/
```

Then reference only the file name:

```text
game=Game|Game.lnk|game.png|GAME DESCRIPTION
```

This uses:

```text
saou.games.menu/user-assets/game.png
```

If an image is missing, the path is wrong, or Qt cannot load it, the card falls
back to:

```text
saou.games.menu/assets/placeholder.png
```

## Settings

- `shortcutsDir` - folder with game shortcuts. Relative shortcut names are
  resolved inside this folder.
- `startHidden=true` - asks the configured close action to hide Games Menu after
  SAO Utils starts.
- `maxColumns` - maximum number of cards in one row. The actual number can be
  lower if the widget is narrow.

## Updating

Before replacing files from a new release ZIP, save your user data:

- `saou.games.menu/config.txt`, if you edited it directly.
- `saou.games.menu/config.local.txt`, if you created it.
- `saou.games.menu/user-assets/`, because it contains your game images.

Then replace the package files from the new release ZIP. The project does not
automatically preserve overwritten files during a manual update, so keep your
own copy before replacing the folder.

## Troubleshooting

### Close Button Does Nothing

Configure the close action:

```text
Right-click Games Menu -> Close Action... -> Widget -> Hide Widget -> Games Menu
```

### Steam Game Does Not Launch

Check the `.url` file name in `shortcutsDir`, or use a direct Steam URI:

```text
game=SnowRunner|steam://rungameid/1465360|snowrunner.png|SNOWRUNNER
```

### Image Is Not Displayed

Check that the image exists in `saou.games.menu/user-assets/` and that the file
name in `config.txt` matches exactly. Bare image names are resolved under
`user-assets/`.

### Game Shortcut Is Not Found

Check `shortcutsDir` and the shortcut file name. `.lnk` is appended only when no
extension or launch URI is provided. `.url` and `steam://...` values are kept
unchanged.

## License

The project source code is released under the MIT License. See `LICENSE`.

Repository assets, user-supplied artwork, game names, trademarks, and publisher
intellectual property are not automatically covered by the MIT license. See
`ASSETS_NOTICE.md`.
