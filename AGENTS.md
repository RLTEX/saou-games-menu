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
confirmed by the user as the known-good baseline. v1.1.0 discovery, folders, and
stable-ID work must stay layered on top of that lifecycle unless a new issue is
separately reproduced and confirmed.

Current lifecycle invariants:

- Games are discovered from the included `saou.games.menu/shortcuts/` directory
  by default and grouped by declarative configuration, not hardcoded in QML.
- `shortcutsDir` is only an optional external directory override for advanced
  setups.
- Closing is based on `NVG.ActionSource`.
- SAO Utils owns system widget visibility.
- The close action is called with `closeActionSource.trigger()`.
- On component startup, `startHidden` performs one startup-only visibility
  reconcile: `true` hides through `closeActionSource.trigger()`, `false` shows
  by setting the host view visible once after SAO Utils restores saved state.
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

Do not add visibility watchdogs, polling, `restoreHostView`,
`handleHostViewVisibility`, `restoringHostView`, `lastHostViewVisible`, extra
visibility state machines, or `NVG.View.exposed` hacks unless a new confirmed
bug requires a researched fix.

## Stable ID Invariants

- Basename is presentation data, not game identity.
- Each auto-discovered game is identified by a stable numeric ID.
- Numeric ID maps to a normalized launch key in
  `saou.games.menu/state/items.json`.
- The state file is local user state. Keep generated `items.json` ignored by
  Git and keep `saou.games.menu/state/.gitkeep` tracked.
- A shortcut rename with the same launch key preserves the numeric ID.
- The current shortcut basename controls the current game title.
- Global item metadata references numeric ID:
  `item=<ID>|<Game Name>|<Game Subtitle>`.
- Folder membership references numeric ID:
  `game=<ID>`.
- Title is stored globally once per ID. Folder entries do not store title.
- Folder cards inherit title from the global item / current discovered shortcut
  for the same ID.
- Subtitle is stored globally once per ID. Folder entries do not store subtitle.
- The same global subtitle is shown in `ALL` and every folder for that game.
- Artwork still matches the current basename:
  `user-assets/<CurrentShortcutBaseName>.png`.
- Do not reintroduce basename as folder/config identity.
- Do not write launch targets, generated launch entries, image paths, or folder
  memberships back into `config.txt`.
- Auto-add may only create or update global v3 `item=<ID>|<Title>|...` lines
  after a fresh matching discovery result.
- Updating title after a rename must preserve the existing global subtitle and
  must not change folder membership.
- v2 basename config was experimental. Controlled v2-to-v3 migration may run
  only when current discovery maps a basename unambiguously to one numeric ID.
  Ambiguous v2 lines must remain as explicit unmigrated comments with warnings;
  do not fuzzy-match names.

## Reload Button Invariants

- Reload is a momentary action button, not a toggle.
- Reload visual state must be only idle, hover, pressed, or temporary
  refresh-running appearance.
- Reload visual state must not remain permanently active after refresh
  completes.
- A visual Reload fix must not trigger discovery architecture rewrites.

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

For v1.1.0 discovery, folders, and stable IDs, also verify:

11. Empty included `shortcuts/` does not crash and shows an empty state.
12. Adding a `.lnk` to included `shortcuts/` makes it appear in `ALL`.
13. Adding a `.url` to included `shortcuts/` makes it appear in `ALL`.
14. Removing a shortcut removes it from `ALL`.
15. `user-assets/<CurrentShortcutBaseName>.png` is used when present.
16. Missing game PNG falls back to `assets/placeholder.png`.
17. A configured custom folder shows discovered games by numeric ID.
18. Missing custom folder icon falls back to `folder-icons/default.png` or the
    QML fallback icon.
19. Changing `displayName` does not change icon lookup by `folderId`.
20. A configured game ID missing from the effective shortcut directory does not
    crash the widget.
21. Paths and shortcut basenames containing spaces work.
22. Renaming a shortcut with the same launch key preserves ID and updates title.
23. Repeated Reload clicks do not leave the button permanently highlighted.

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
  normalization, ID-based subtitle resolution, and fallback values.
- `saou.games.menu/qml/ShortcutDiscovery.qml` owns helper-based scanning of the
  included `../shortcuts` package directory, or the optional external
  `shortcutsDir` override, for `.lnk` and `.url` files. It resolves discovered
  shortcuts through the stable-ID update helper before exposing normalized
  launcher items.
- `saou.games.menu/qml/FolderSidebar.qml` owns the folder navigation UI, folder
  icon fallback display, open-shortcuts button, and momentary Reload button.
- `saou.games.menu/config.txt` is the primary user-facing configuration file. It
  supports normal Windows paths with backslashes and uses `configVersion=3`.
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
- `saou.games.menu/state/` is package-local user identity state. Keep
  `.gitkeep` tracked, but keep generated `items.json` ignored by Git.
- `saou.games.menu/runtime/` is for generated discovery/cache files. Keep
  `.gitkeep` tracked and generated cache contents ignored by Git.
- `saou.games.menu/tools/discover-shortcuts.ps1` is the bundled Windows helper
  used by `ShortcutDiscovery.qml` to enumerate `.lnk` and `.url` files without
  `Qt.labs.folderlistmodel`. It must only write discovery results and must not
  mutate `config.txt` or `state/items.json`.
- `saou.games.menu/tools/update-config-items.ps1` is the bundled Windows helper
  used after QML accepts a fresh discovery result whose `requestId` matches the
  active request. It resolves or creates numeric IDs, persists
  `state/items.json`, updates global v3 `item=` metadata titles, adds missing
  global item stubs, and performs controlled v2 migration.
- `saou.games.menu/tools/run-hidden.vbs` is the bundled hidden-process wrapper.
  QML launches helpers through `wscript.exe` and this VBS wrapper so
  `powershell.exe` is hidden and waited for.

## Rules For Future Changes

- Do not hardcode user games in QML.
- Main.qml and GameCard.qml must not parse the config file format. They should
  receive only normalized config and discovery objects.
- Prefer text config v3:
  `configVersion=3`, optional `shortcutsDir=...`,
  `folder=<folderId>|<displayName>|<maxColumns>`, nested `game=<ID>` lines,
  and optional global `item=<ID>|<Game Name>|<Game Subtitle>` metadata lines.
- Newly auto-added v3 item stubs should use
  `item=<ID>|<CurrentShortcutBaseName>|Game Subtitle`; the literal
  `Game Subtitle` is a user hint and must normalize to an empty subtitle until
  the user replaces it.
- Keep limited legacy text config support for
  `game=Title|Shortcut|Image|Description|Accent|Id` in a clearly separated
  compatibility path.
- Keep legacy one-line JS registration through
  `addGame(title, shortcut, image, options)`.
- Auto-discovered game images should resolve to
  `user-assets/<CurrentShortcutBaseName>.png`. Do not load images from the
  shortcut directory; that fallback behaved inconsistently in SAO Utils.
- Auto-discovered cards should have an empty subtitle unless matching v3
  global `item=` metadata provides one at runtime.
- `GameCard` image cache should stay disabled for user artwork refresh;
  replacing `user-assets/<CurrentShortcutBaseName>.png` should be picked up
  after reopening Games Menu or pressing Reload.
- If `shortcutsDir` is absent or empty, `ShortcutDiscovery.qml` must use
  `Qt.resolvedUrl("../shortcuts")`, which resolves from the `qml/` component
  directory to the package-level `saou.games.menu/shortcuts/`.
- Do not require the user to manually create `shortcuts/`; it is part of the
  package structure and must remain present before first launch.
- `ALL` must not be user-configurable or removable from config.
- User folder icons resolve from `folder-icons/<folderId>.png`; missing icons
  should use `folder-icons/default.png` or the QML fallback.
- Games Menu performs exactly one initial controlled discovery refresh on
  component startup. Reopening the widget must not automatically run discovery.
  Manual Reload in the sidebar is used for later refreshes. Manual Reload must
  reload `ConfigLoader.load()`, then run the same `shortcutDiscovery.refresh()`
  flow used by startup. Do not trigger discovery refresh from `animateIn()` or
  couple refresh to widget visibility lifecycle.
- Prevent overlapping refresh calls. If a refresh is already running, ignore a
  second Reload request until the helper result or timeout completes.
- Discovery result freshness is bounded by `requestId`. QML may only apply a
  discovery result when `result.requestId` exactly matches the active request.
  Results from previous requests must not update `ShortcutDiscovery.items`,
  rebuild models, or trigger config metadata auto-add.
- Auto-add metadata must use only fresh items from the matching active request.
  Previous `ShortcutDiscovery.items`, previous `discoveredGames`, previous `ALL`
  model contents, stale `runtime/discovery.json`, and stale request results must
  never be used for config auto-add during a new refresh.
- Duplicate global `item=` metadata is deterministic: parser reads top-to-bottom,
  logs a warning for duplicate IDs, and the last explicit entry wins.
- All discovery success, error, malformed-result timeout, config-update failure,
  and timeout paths must release the refresh busy state.
- Folder-specific subtitles are not part of the current config model. For
  legacy configs, `game=<ID>|<text>` may be accepted as `game=<ID>`, but the old
  folder-specific text must be ignored.
- Subtitle resolution must stay deterministic and centralized outside
  `Repeater`/`GameCard` bindings. Use only global `item=` metadata for
  auto-discovered shortcut subtitles.
- `description` is the preferred option name for bottom card text. `subtitle`
  remains supported as a legacy alias. On hover, the bottom description should
  be replaced by `LAUNCH  >`.
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

## Git Workflow

- After completing and validating a requested task, create one focused commit
  automatically.
- Use a short descriptive commit message in English.
- One logical task = one commit.
- Do not combine unrelated changes in one commit.
- Do not push automatically.
- Do not merge branches automatically.
- Release commits are created only when explicitly requested.

## Privacy And Release Hygiene

- Do not add personal paths, game-specific private images, tokens, passwords,
  API keys, OAuth data, service tokens, private keys, or other secrets to the
  repository.
- Keep `config.local.txt`, legacy local configs, shortcut files, `.url` files,
  `user-assets/`, `folder-icons/`, user contents of `shortcuts/`, generated
  runtime files, and generated `state/items.json` ignored by Git.
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
  bundled `tools/run-hidden.vbs` through `wscript.exe`; the VBS wrapper launches
  PowerShell with hidden window style and waits for it to finish. Discovery
  writes `runtime/discovery.json`; stable ID/config update writes
  `runtime/config-update.json`; QML reads those files with `XMLHttpRequest`;
  stdout is not required.
- Do not launch `powershell.exe` directly from QML for discovery or config
  update. Direct console launch can show a PowerShell window before
  `-WindowStyle Hidden` is applied.
