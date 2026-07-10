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

## Known-good Lifecycle Baseline

The v1.0.0 `saou.games.menu/qml/Main.qml` lifecycle and visibility flow was
confirmed by the user as the known-good baseline. v1.1.0 discovery and folder
work must stay layered on top of that lifecycle unless a new issue is separately
reproduced and confirmed.

Current lifecycle invariants:

- Games are discovered from the included `saou.games.menu/shortcuts/` directory
  by default and grouped by declarative configuration, not hardcoded in QML.
- `shortcutsDir` is only an optional external directory override for advanced
  setups.
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
- `ALL` is a system folder and must always show all discovered `.lnk` and `.url`
  files from the effective shortcut directory.
- User folders are configured by shortcut basename only. Do not store generated
  discovery entries back into `config.txt`.

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

For v1.1.0 discovery and folders, also verify:

11. Empty included `shortcuts/` does not crash and shows an empty state.
12. Adding a `.lnk` to included `shortcuts/` makes it appear in `ALL`.
13. Adding a `.url` to included `shortcuts/` makes it appear in `ALL`.
14. Removing a shortcut removes it from `ALL`.
15. `user-assets/<ShortcutBaseName>.png` is used when present.
16. Missing game PNG falls back to `assets/placeholder.png`.
17. A configured custom folder shows only matching discovered basenames.
18. Missing custom folder icon falls back to `folder-icons/default.png` or the
    QML fallback icon.
19. Changing `displayName` does not change icon lookup by `folderId`.
20. A configured game missing from the effective shortcut directory does not
    crash the widget.
21. Paths and shortcut basenames containing spaces work.

## Architecture

- `saou.games.menu/package.json` is the NERvGear package manifest.
- `saou.games.menu/module.qml` is the NERvGear module entry and only handles
  module lifecycle logging.
- `saou.games.menu/qml/Main.qml` owns the main widget interface, configured close
  `ActionSource`, show/close animations, launch overlay, launch command
  construction, start-hidden behavior, selected folder state, and dynamic games
  grid orchestration.
- `saou.games.menu/qml/GameCard.qml` owns one game card: image, title, bottom
  description/launch text, hover animation, hover border, bottom hover line, and
  click signal.
- `saou.games.menu/qml/ConfigLoader.js` owns text/legacy JS configuration
  loading, folder registration, limited legacy game registration, defaults,
  normalization, and fallback values.
- `saou.games.menu/qml/ShortcutDiscovery.qml` owns helper-based scanning of the
  included `../shortcuts` package directory, or the optional external
  `shortcutsDir` override, for `.lnk` and `.url` files and emits normalized
  launcher items.
- `saou.games.menu/qml/FolderSidebar.qml` owns the folder navigation UI and
  folder icon fallback display.
- `saou.games.menu/config.txt` is the primary user-facing configuration file. It
  supports normal Windows paths with backslashes and uses `configVersion=2`.
  Normal installations should not need `shortcutsDir`.
- `saou.games.menu/config.local.txt` is the local user configuration and must
  stay ignored by Git.
- `saou.games.menu/config.local.js` is a legacy local user configuration and
  must stay ignored by Git.
- `saou.games.menu/games.local.js` is a legacy local games list. Keep it ignored
  by Git, but prefer the unified text config file.
- `saou.games.menu/user-assets/` is for user-provided game images and must stay
  ignored except for `.gitkeep`.
- `saou.games.menu/folder-icons/` is for user-provided folder icons and must
  stay ignored except for `.gitkeep`.
- `saou.games.menu/shortcuts/` is the included user-facing shortcut directory
  and must be shipped in release ZIPs. Keep `.gitkeep` tracked, but keep user
  `.lnk` and `.url` contents ignored by Git.
- `saou.games.menu/tools/discover-shortcuts.ps1` is the bundled Windows helper
  used by `ShortcutDiscovery.qml` to enumerate `.lnk` and `.url` files without
  `Qt.labs.folderlistmodel`.
- `saou.games.menu/runtime/` is for generated discovery cache files. Keep
  `.gitkeep` tracked and generated cache contents ignored by Git.

## Rules For Future Changes

- Do not hardcode user games in QML.
- Main.qml and GameCard.qml must not parse the config file format. They should
  receive only normalized config and discovery objects.
- Prefer text config v2:
  `configVersion=2`, optional `shortcutsDir=...`,
  `folder=<folderId>|<displayName>`, and nested `game=<ShortcutBaseName>` lines.
- Keep limited legacy text config support for
  `game=Title|Shortcut|Image|Description|Accent|Id` in a clearly separated
  compatibility path.
- Keep legacy one-line JS registration through
  `addGame(title, shortcut, image, options)`.
- Auto-discovered game images should resolve to
  `user-assets/<ShortcutBaseName>.png`. Do not load images from the shortcut
  directory; that fallback behaved inconsistently in SAO Utils.
- Auto-discovered games must not be written back to `config.txt`.
- If `shortcutsDir` is absent or empty, `ShortcutDiscovery.qml` must use
  `Qt.resolvedUrl("../shortcuts")`, which resolves from the `qml/` component
  directory to the package-level `saou.games.menu/shortcuts/`.
- Do not require the user to manually create `shortcuts/`; it is part of the
  package structure and must remain present before first launch.
- If both `.lnk` and `.url` exist with the same basename, keep deterministic
  behavior, do not crash, and log a warning. Folder membership by basename
  prefers `.lnk` over `.url`.
- `ALL` must not be user-configurable or removable from config.
- User folder icons resolve from `folder-icons/<folderId>.png`; missing icons
  should use `folder-icons/default.png` or the QML fallback.
- `description` is the preferred option name for bottom card text. `subtitle`
  remains supported as a legacy alias. On hover, the bottom description should be
  replaced by `LAUNCH  >`.
- Keep compatibility with Qt 5, Qt Quick 2.12, Qt Quick Controls 2.12, NERvGear
  API 1.x, and SAO Utils 2.
- `ShortcutDiscovery.qml` must not use `Qt.labs.folderlistmodel` or
  `FolderListModel`. Use the bundled helper-based discovery unless a separately
  confirmed SAO Utils runtime test proves a better compatible API.
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
  `user-assets/`, `folder-icons/`, and user contents of `shortcuts/` ignored by
  Git.
- Source code is MIT licensed, but repository assets and user-supplied artwork
  need separate provenance/permission checks.

## Future Playtime Note

Do not implement playtime tracking yet. Future Games Menu work may parse Steam
AppID values from direct `steam://...` launch targets or Steam `.url` files and
may later use a separate local tracker for non-Steam apps.

Do not add Steam Web API calls, API keys, SteamID values, network requests, or
playtime counters until that task is explicitly requested.

## Runtime Compatibility

- `Qt.labs.folderlistmodel` is not compatible with the tested SAO Utils 2
  Progressive / NERvGear runtime.
- Using `FolderListModel` in `ShortcutDiscovery.qml` caused Games Menu to fail
  loading and SAO Utils to show `UNKNOWN`.
- The failure was isolated by disabling only `ShortcutDiscovery` while leaving
  the v1.1.0 UI, sidebar, `GameCard`, and ActionSource lifecycle intact.
- Do not reintroduce `Qt.labs.folderlistmodel` or `FolderListModel` without a
  separately confirmed runtime test in SAO Utils.
- Current discovery uses `NVG.SystemCall.execute(executable, arguments)` to run
  the bundled PowerShell helper. The helper writes `runtime/discovery.json`, and
  QML reads that file with `XMLHttpRequest`; stdout is not required.
