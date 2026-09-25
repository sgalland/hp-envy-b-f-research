# hp-envy-b-f-research

Research repository for diagnosing and reproducing Linux audio support on an HP Envy laptop with Bang & Olufsen speakers.

## Goals

1. Identify the laptop's exact audio hardware, codec, DSP/amp path, firmware, and kernel driver state.
2. Determine why the built-in speakers fail or behave incorrectly under Linux.
3. Record experiments so failed approaches are not repeated.
4. Produce a small, idempotent script that applies only the settings actually required.
5. Keep the result usable from a CachyOS live environment booted through Ventoy, with persistence as an optional convenience rather than a requirement.

## Repository layout

- `docs/hardware.md` — confirmed hardware and software facts.
- `docs/investigation-log.md` — chronological experiments and outcomes.
- `docs/ventoy-persistence.md` — notes for preserving live-session changes.
- `scripts/collect-audio-info.sh` — gathers a reproducible diagnostic snapshot.
- `scripts/apply-audio-fix.sh` — reserved for the final verified fix; do not add speculative changes here.

## Working rule

**Diagnose first, automate second.**

The eventual fix script should be derived from a known-good manual procedure, not used as a place to accumulate guesses.

## Current status

Initial research scaffolding is in place. Hardware-specific findings are still TBD and should be populated from a real CachyOS session on the target laptop.
