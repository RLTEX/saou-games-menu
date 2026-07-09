# AGENTS.md

This repository contains a configurable Games Menu widget for SAO Utils 2 /
NERvGear.

## CRITICAL

SAO Utils must be the only owner of the widget's system visibility. Games Menu
must close through the configured `NVG.ActionSource` close action, normally set
by the user to `Hide Widget -> Games Menu`.

Do not close the widget by assigning:

```qml
widget.visible = false
```

or:

```qml
panel.visible = false
```

or:

```qml
widget.NVG.View.view.visible = false
```

Direct visibility changes previously caused broken widget status and reopening
behavior with SAO Utils `Show Widget` / `Toggle Widget`.

## Known-good Working Baseline

The current working tree was confirmed by the user as the known-good baseline.
Treat the current `saou.games.menu/qml/Main.qml` lifecycle and visibility flow as
the baseline implementation unless a new issue is separately reproduced and
confirmed.

Current invariants:

- Games are loaded from configuration, not hardcoded in QML.
- Closing is based on `NVG.ActionSource`.
- SAO Utils owns system widget visibility.
- The close action is called with `closeActionSource.trigger()`.
- Do not call `closeActionSource.trigger(widget)` unless official API evidence
  and testing prove a different signature is required.
- The user must configure `Close Action... -> Widget -> Hide Widget -> Games Menu`.
- Do not bring back direct `hostView.visible = false` or
  `widget.NVG.View.view.visible = false` without a separate confirmed
  investigation.
- Do not use `widget.visible = false` or `panel.visible = false` for system
  closing.
- `.lnk`, `.url`, and direct launch URIs are supported.
- Do not automatically append `.lnk` to `.url` files or URI values such as
  `steam://rungameid/1465360`.
- Future lifecycle changes must preserve the confirmed open, close, launch, Show
  Widget, and Toggle Widget behavior.

Do not add visibility watchdogs, polling, `restoreHostView`,
`handleHostViewVisibility`, `restoringHostView`, `lastHostViewVisible`, extra
visibility state machines, or `NVG.View.exposed` hacks unless a new confirmed
bug requires a researched fix.

## Regression Checklist

Any lifecycle or visibility change is incomplete until this checklist has been
verified in SAO Utils 2:

1. Open Games Menu.
2. Close with X.
3. Open again.
4. Launch a normal `.lnk` game.
5. Open Games Menu again.
6. Launch a Steam `.url` shortcut.
7. Open Games Menu again.
8. Launch a direct `steam://` URI.
9. Verify `Show Widget`.
10. Verify `Toggle Widget`.

## Architecture

- `saou.games.menu/package.json` is the NERvGear package manifest.
- `saou.games.menu/module.qml` is the NERvGear module entry and only handles
  module lifecycle logging.
- `saou.games.menu/qml/Main.qml` owns the main widget interface, configured close
  `ActionSource`, show/close animations, launch overlay, launch command
  construction, start-hidden behavior, and dynamic games grid.
- `saou.games.menu/qml/GameCard.qml` owns one game card: image, title, bottom
  description/launch text, hover animation, hover border, bottom hover line, and
  click signal.
- `saou.games.menu/qml/ConfigLoader.js` owns text/legacy JS configuration
  loading, game registration, defaults, normalization, and fallback values.
- `saou.games.menu/config.txt` is the primary user-facing configuration file. It
  supports normal Windows paths with backslashes.
- `saou.games.menu/config.local.txt` is the local user configuration and must
  stay ignored by Git.
- `saou.games.menu/config.local.js` is a legacy local user configuration and
  must stay ignored by Git.
- `saou.games.menu/games.local.js` is a legacy local games list. Keep it ignored
  by Git, but prefer the unified text config file.
- `saou.games.menu/user-assets/` is for user-provided game images and must stay
  ignored except for `.gitkeep`.

## Rules For Future Changes

- Do not hardcode user games in QML.
- Main.qml and GameCard.qml must not know the config file format. They should
  receive only the normalized games array from `ConfigLoader.js`.
- Prefer text config game lines: `game=Title|Shortcut|Image|Description|Accent|Id`.
- Keep legacy one-line JS registration through
  `addGame(title, shortcut, image, options)`.
- Bare image file names passed to config should resolve under `user-assets/`.
  Do not load images from `shortcutsDir`; that fallback behaved inconsistently
  in SAO Utils.
- `description` is the preferred option name for bottom card text. `subtitle`
  remains supported as a legacy alias. On hover, the bottom description should be
  replaced by `LAUNCH  >`.
- Keep compatibility with Qt 5, Qt Quick 2.12, Qt Quick Controls 2.12, NERvGear
  API 1.x, and SAO Utils 2.
- Prefer small, direct changes over large rewrites.
- Preserve the existing show animation, close animation, launch overlay,
  launch-failed state, rounded cards, hover animation, hover border, bottom hover
  line, Windows shortcut launch flow, URI launch flow, and configured close
  action after launch.

## Privacy And Release Hygiene

- Do not add personal paths, game-specific private images, tokens, passwords,
  API keys, OAuth data, service tokens, private keys, or other secrets to the
  repository.
- Keep `config.local.txt`, legacy local configs, shortcut files, `.url` files,
  and `user-assets/` ignored by Git.
- Source code is MIT licensed, but repository assets and user-supplied artwork
  need separate provenance/permission checks.
