# Investigation log

Keep this chronological. Every experiment should record the environment, exact change, result, and whether the change was reverted.

## Status vocabulary

- **CONFIRMED** — reproduced and verified on the target laptop.
- **PROMISING** — improved behavior but needs more testing.
- **NO EFFECT** — did not materially change the symptom.
- **REGRESSION** — made behavior worse or broke another audio path.
- **REVERTED** — change was removed after testing.

---

## 2026-09-25 — Repository initialized

### Goal

Establish a reproducible workflow for diagnosing the HP Envy Bang & Olufsen speaker problem under Linux.

### Decisions

- Diagnose the target hardware before applying model-specific fixes found online.
- Capture a complete baseline from CachyOS before modifying ALSA, PipeWire, WirePlumber, kernel parameters, UCM files, firmware, or codec controls.
- Keep the final `apply-audio-fix.sh` idempotent and limited to changes that have been manually verified.
- Treat Ventoy persistence as optional convenience; the fix must remain reproducible without persistence.

### Result

**CONFIRMED** — research structure created. No audio fix has been attempted yet.
