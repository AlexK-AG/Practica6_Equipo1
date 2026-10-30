# Godot-SQLite dependency

Pinned upstream release: [v4.8](https://github.com/2shady4u/godot-sqlite/releases/tag/v4.8).
License: MIT, retained in LICENSE.md.
Download SHA-256 (addons.zip): f81531b5b9f1d4f422e9f882c409701adf197a17f894ca65ee2fa25759c25270.

This project includes the upstream Windows x86_64 debug/release libraries and
Android arm64/x86_64 debug/release libraries from the same v4.8 archive. The
GDExtension manifest is restricted to these included targets. Godot loads this
extension automatically; no backend service or editor-plugin activation is
required. Other operating systems still need their matching upstream libraries.
This package does not change the game's Godot version or SQLite schema.


## Project integration

The GDScript integration is in `scripts/persistence/campaign_store.gd`, managed
by the `Campaign` autoload in `scripts/persistence/campaign.gd`. Game events use
`scripts/persistence/game_events.gd`. The game writes SQLite directly; Node.js is
only needed for the separate local web reader in `web/server.mjs`.

See [storage documentation](../../docs/README_SQLITE.md),
[event documentation](../../docs/README_EVENTS.md) and
[local web instructions](../../web/README.md). Reorganizing project resources
does not replace these native libraries or their upstream license.
