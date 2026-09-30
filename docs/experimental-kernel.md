# Experimental CachyOS kernel

## Purpose

This document records the controlled kernel experiment for the HP ENVY 17-ch0xxx / Realtek ALC245 subsystem `103C:88B5`.

The experiment is **not a completed audio fix**. Its purpose is to make the model-specific speaker topology deterministic at boot so the remaining routing problem can be investigated without relying on ephemeral sysfs pin overrides.

## Kernel

- Base: CachyOS Linux 7.2.8-1 source/package.
- Experimental package: `linux-cachyos-hp-envy-audio 7.2.8-1`.
- Running release observed after installation: `7.2.8-1-cachyos-hp-envy-audio`.
- Installed alongside the stock CachyOS kernel so a known-good fallback remains available.

## Realtek fixup

The experimental `sound/hda/codecs/realtek/alc269.c` change adds a model-specific fixup:

`ALC245_FIXUP_HP_ENVY_17_CH0XXX`

and a PCI subsystem match equivalent to:

```c
SND_PCI_QUIRK(0x103c, 0x88b5, "HP ENVY 17-ch0xxx",
              ALC245_FIXUP_HP_ENVY_17_CH0XXX)
```

The fixup assigns:

```text
0x14 0x90170110
0x17 0x90170111
```

The research patch was named:

`hp-envy-17-ch0xxx-audio.patch`

## Boot validation

The experimental kernel has been booted successfully on the target machine.

Kernel log confirms:

```text
ALC245: picked fixup for PCI SSID 103c:88b5
autoconfig for ALC245: line_outs=2 (0x14/0x17/0x0/0x0/0x0) type:speaker
```

The live codec reports:

```text
Codec: Realtek ALC245
Vendor Id: 0x10ec0245
Subsystem Id: 0x103c88b5
Revision Id: 0x100001
```

and `/sys/class/sound/hwC0D0/driver_pin_configs` reports the intended `0x14` and `0x17` values.

Therefore the quirk selection and pin configuration are **CONFIRMED**.

## What the experiment proved

The custom kernel proved several useful things:

1. Linux can match this machine by its real codec subsystem `103c:88b5`.
2. Both candidate internal speaker pins can be exposed deterministically at boot.
3. ALSA creates separate `Speaker` and `Bass Speaker` controls from that topology.
4. During one session using this kernel, the user heard both the lower and upper physical speaker sets.

Point 4 is especially important: the upper speakers are not inherently unreachable from Linux.

## What it did not prove

The kernel fixup did **not** establish a complete solution.

After reboot, the upper speakers returned to silence even though:

- the experimental kernel was still running;
- the `103c:88b5` fixup still matched; and
- the driver pin configs remained correct.

The both-speaker success therefore depended on additional runtime state that was not preserved.

The exact command/state sequence that produced the transient success is unknown. Do not reconstruct it from memory and do not describe the pin fixup itself as the fix.

## Current topology problem

### Speaker pin 0x14

NID `0x14` has one connection:

```text
0x14 -> 0x02
```

It has EAPD support and uses the normal `Speaker Playback Volume` associated with DAC `0x02`.

### Bass Speaker pin 0x17

NID `0x17` advertises:

```text
0x02 0x03 0x06 0x08
```

with `0x06` selected in the observed codec state:

```text
0x17 -> 0x06
```

DAC `0x06` is an audio output but does not expose the normal hardware playback-volume control present on `0x02`.

This matters because experimental playback became unexpectedly loud even with a very low PipeWire sink volume. The current working hypothesis is that simply enabling the second speaker path is insufficient; the correct fix must also reproduce the intended DAC binding/gain/volume behavior.

## Selector experiment

A muted runtime test attempted:

```sh
sudo hda-verb /dev/snd/hwC0D0 0x17 SET_CONNECT_SEL 0
sudo hda-verb /dev/snd/hwC0D0 0x17 GET_CONNECT_SEL 0
```

The following GET still returned `0x2`, and the codec dump continued to mark `0x06*` as selected.

Result: **NO EFFECT**. Do not assume a raw `SET_CONNECT_SEL` write can solve the routing problem.

## Relevant upstream code lead

Inspection of the Realtek ALC245 code found existing bass-DAC/DAC-binding fixup machinery, including `ALC245_FIXUP_BASS_HP_DAC`. The code specifically has to account for DAC node `0x06` and its lack of volume control.

That existing mechanism is now more relevant than adding more speculative pin writes. Before changing the experimental patch, determine whether this HP model should compose the pin fixup with an existing ALC245 DAC-binding/bass-speaker fixup, or whether the Windows secondary SST path implies a different SOF/topology requirement.

## Safety/testing protocol

Until unified volume behavior is understood:

- begin listening tests muted;
- use conservative ALSA hardware levels before unmuting PipeWire;
- capture `Master`, `Speaker`, `Bass Speaker`, relevant codec nodes, and PipeWire sink state before each mutation;
- make one state-changing operation at a time;
- capture state again immediately afterward;
- record exactly which physical speaker set was heard; and
- reboot between experiments when a clean baseline is required.

## Current status

**PROMISING INFRASTRUCTURE, NOT A FIX.**

Keep the experimental kernel because it provides a deterministic model-specific starting point. The next engineering question is the correct relationship among pins `0x14`/`0x17`, DACs `0x02`/`0x06`, Realtek's existing ALC245 bass-DAC binding logic, and the Windows `SSTXperi4SPK` / secondary SST configuration.
