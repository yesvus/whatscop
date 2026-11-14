# WhatsCop

Read-only macOS WhatsApp media disk analyzer. Shows per-chat and per-file-type disk use and an age-based estimate. No deletion, message reading, database access, network access, or third-party dependencies.

Requirements: macOS with the native WhatsApp client and Python 3.9+.

## Usage

    ./whatscop
    ./whatscop --top 20 --older-than 180
    ./whatscop --show-ids
    ./whatscop --json

Optional local CLI installation:

    install -m 755 whatscop "$HOME/.local/bin/whatscop"

Run tests:

    python3 -m unittest discover -s tests -v

By default, chat IDs are redacted. The --show-ids option exposes identifiers and can reveal private details in logs. No chat messages or attachment contents are opened.

The native WhatsApp desktop app currently stores attachments in a Media directory within its shared Group Container. This location is an undocumented implementation detail and may change.

## Safety

- The scanner reads filesystem metadata only, never file contents or SQLite databases.
- It never modifies files, deletes media, or runs on a schedule.
- Symlinks are skipped and errors are reported.
- File modification age is not message age, and old media is not necessarily disposable.
- Allocated size is estimated using filesystem blocks. APFS clones and compression can cause discrepancies with actual space recoverable.
- Delete actual attachments through WhatsApp's own storage management tools, not by manipulating its live data directories.

This is a deliberately small first release, not a general-purpose macOS cleaner.
