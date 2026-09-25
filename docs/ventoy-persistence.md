# Ventoy persistence strategy

Ventoy normally boots an ISO as a fresh live environment. Changes made inside that live session should therefore be assumed temporary unless the distribution itself provides persistence or Ventoy persistence is configured.

Ventoy provides a persistence plugin that associates an ISO with a writable persistence image. Ventoy's documentation includes Arch Linux among supported persistence examples and documents the filesystem label `vtoycow` for Arch-style persistence images.

CachyOS is Arch-based, but this project should **not** depend on persistence working correctly with a particular CachyOS ISO.

## Recommended workflow

1. Boot CachyOS from Ventoy without persistence.
2. Run `scripts/collect-audio-info.sh`.
3. Diagnose the audio failure and test changes manually.
4. Record every experiment in `docs/investigation-log.md`.
5. Once a minimal working procedure is known, encode only those required changes in `scripts/apply-audio-fix.sh`.
6. Test the script from another clean live boot.
7. Only then configure Ventoy persistence if convenient.

This gives us two independent recovery mechanisms:

- a reproducible setup script; and
- optionally, a persistent live environment.

## Why the script remains primary

Persistence can preserve accidental state as easily as intentional state. A script documents exactly which changes are necessary and remains useful if:

- the CachyOS ISO is replaced;
- the Ventoy persistence file is lost;
- Linux is installed to disk later;
- a package or kernel update breaks the workaround; or
- the fix turns out to apply to other Arch-derived systems.

## Ventoy configuration

Do not create the final `ventoy.json` for this laptop until the actual CachyOS ISO filename and persistence-image location are known.

Reference:

- Ventoy Persistence Plugin documentation: https://www.ventoy.net/en/plugin_persistence.html
