# Changelog

## 1.2.0

### Added

- Persistent per-card data: stable card ID, custom title, description, image, folder, and order.
- Edit Mode with launch protection and card-editor actions.
- Local image import, image reset, and safe fallback when a source image is missing.
- Drag-and-drop addition of `.lnk`, `.url`, and `.exe` launchers.
- Managed launcher copies for cards that must remain available after the original shortcut is removed.
- Card ordering, moving between categories, duplicate copy-or-move choice, and hidden-card restore.
- Category creation, editing, removal, custom icons, scrolling, and icon-scale setting.
- Local Lucide-based control icons with third-party notices.

### Changed

- The user-facing documentation now describes the 1.2.0 workflow.
- User files and generated runtime state remain excluded from Git by default.

### Compatibility

- Existing shortcut discovery, legacy automatic artwork, configuration, and local card state continue to work.
