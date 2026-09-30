# hp-envy-b-f-research

Research repository for diagnosing and reproducing Linux audio support on an HP Envy 17-ch0xxx laptop with Bang & Olufsen speakers.

## Goals

1. Identify the laptop's exact audio hardware, codec, DSP/amp path, firmware, and kernel driver state.
2. Determine why the additional upper/top-facing speaker pair works under Windows but is normally silent under Linux.
3. Record experiments so failed approaches are not repeated.
4. Produce the smallest upstream-quality Linux fix that reproduces the required hardware behavior safely.
5. Keep any eventual local workaround reproducible on CachyOS until an upstream solution is available.

## Repository layout

- `docs/hardware.md` — confirmed hardware and software facts.
- `docs/investigation-log.md` — chronological experiments and outcomes.
- `docs/windows-driver-analysis.md` — analysis of the known-good Windows audio stack.
- `docs/experimental-kernel.md` — custom-kernel experiment and current conclusions.
- `docs/ventoy-persistence.md` — notes from the original live-environment investigation.
- `scripts/collect-audio-info.sh` — gathers a reproducible diagnostic snapshot.
- `scripts/apply-audio-fix.sh` — reserved for a final verified fix; do not add speculative changes here.

## Working rule

**Diagnose first, automate second.**

The eventual fix script or kernel patch must be derived from a known-good, reproducible procedure. A transient success is evidence, not a fix.

For state-changing audio experiments, record:

1. pre-test state;
2. exact command/change;
3. post-test state;
4. listening result; and
5. whether the change survived reboot or was reverted.

## Current status

The machine is confirmed to use Intel SOF with a Realtek ALC245 codec, subsystem `103C:88B5`. Normal Linux audio provides the lower/bottom internal speakers, headphones, and microphone, but the upper/top-facing B&O speaker pair remains unresolved.

A custom CachyOS 7.2.8 kernel successfully matches a model-specific `103c:88b5` Realtek quirk and exposes two speaker pins (`0x14` and `0x17`). During one experimental-kernel session, audio was audibly produced by both physical speaker sets, proving that the upper speakers are accessible from Linux. The exact runtime state that produced that result was not preserved and has not been reproduced after reboot, so it must not be treated as a known fix.

Current codec evidence shows different output paths: pin `0x14` is routed to DAC `0x02`, which has the normal `Speaker Playback Volume` control and EAPD; pin `0x17` is selected to DAC `0x06`, which has no corresponding hardware playback-volume control. This is consistent with the observed unsafe/loud behavior during experimentation and makes correct routing/volume coupling part of the problem, not merely enabling a second pin.

No target-machine evidence has been found for a Cirrus Logic CS35L41/CSC3551 smart-amplifier path. The active investigation therefore remains focused on ALC245/Realtek/SOF routing and the model-specific Windows four-speaker configuration.
