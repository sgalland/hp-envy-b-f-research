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


## 2026-09-29 source trace: ALC245 bass-DAC routing

The exact CachyOS `cachyos-7.2.8-1` source was traced before proposing another live test.

### What `ALC245_FIXUP_BASS_HP_DAC` actually does

`ALC245_FIXUP_BASS_HP_DAC` is a thin wrapper around `alc285_fixup_thinkpad_x1_gen7`. It does not write vendor coefficients or directly enable an amplifier.

At `HDA_FIXUP_ACT_PRE_PROBE`, that routing helper:

- replaces NID `0x17`'s connection list with only DACs `0x02` and `0x03`, explicitly excluding `0x06`;
- sets preferred DAC pairs to:
  - `0x14 -> 0x02`
  - `0x17 -> 0x03`
  - `0x21 -> 0x03`.

The source comment explains the reason: DAC `0x06` is unused because it lacks a volume amplifier.

At `HDA_FIXUP_ACT_BUILD`, the helper renames the generated per-DAC volume controls to `DAC1 Playback Volume` and `DAC2 Playback Volume` so desktop audio software does not manipulate them as ordinary independent speaker controls; the intended user-facing control is Master volume.

This is directly relevant to the target machine because its observed broken topology is `0x17 -> 0x06`, and the uncontrolled-volume incident is consistent with the exact failure mode the upstream helper is designed to avoid.

### Upstream provenance

The generic ALC245 fixup was added for the Minisforum V3 SE. Its patch rationale explicitly describes rerouting bass speakers away from a DAC without volume control. The author reported that routing NID `0x17` through selector 0 or 1 made bass-speaker volume controllable and chose the ThinkPad routing because it permits tuning the ratio between the two speaker sets.

The exact CachyOS 7.2.8 source includes that fixup and maps the Minisforum V3 SE to it.

### Closely related existing fixes

The same source contains two other patterns worth keeping separate from DAC routing:

1. Lenovo Yoga bass-speaker fixes also remove `0x06`/ `0x08` from NID `0x17` and explicitly prefer volume-controlled DACs.
2. HP-specific amplifier initialization exists independently of routing. For example:
   - ALC245 Spectre x360 systems toggle GPIO0 during codec init to enable an amplifier.
   - An ALC274 HP Envy AiO fix toggles GPIO2 on playback prepare/cleanup.

These HP examples demonstrate that speaker routing and amplifier enable can be separate problems. There is not yet evidence that this HP ENVY 17 uses either of those exact GPIO sequences.

### Proposed kernel experiment 2

The narrow next experiment is to keep the confirmed HP pin override and chain it to the existing bass-DAC routing fixup:

```c
[ALC245_FIXUP_HP_ENVY_17_CH0XXX] = {
    .type = HDA_FIXUP_PINS,
    .v.pins = (const struct hda_pintbl[]) {
        { 0x14, 0x90170110 },
        { 0x17, 0x90170111 },
        { }
    },
    .chained = true,
    .chain_id = ALC245_FIXUP_BASS_HP_DAC,
},
```

HDA fixup chaining calls the chained fixup after the current fixup unless `chained_before` is requested. This ordering is appropriate here: apply the HP pin definitions, then let the existing pre-probe routing helper remove DAC `0x06` and choose the preferred volume-controlled DACs.

Expected post-boot topology for this experiment:

```text
0x14 -> 0x02
0x17 -> 0x03
0x21 -> 0x03
```

This proposal is preferable to another runtime `hda-verb SET_CONNECT_SEL` attempt because the connection list and preferred DACs are changed before the generic HDA parser builds the routing and controls.

### Experiment-2 gate

Do not build or install kernel experiment 2 until the patch is reviewed to confirm that the only functional change from experiment 1 is chaining the HP pin fixup to `ALC245_FIXUP_BASS_HP_DAC`.

After boot, verify topology and mixer controls before any audible test. Begin playback muted and at conservative hardware/software levels.

If correct routing restores safe volume control but the upper speakers remain silent, investigate HP-specific amplifier initialization as a separate hypothesis rather than adding it to the same experiment.


## 2026-09-29 experiment 2 boot result

Experiment 2 was built and installed as a distinct package/kernel:

- package: `linux-cachyos-hp-envy-audio-v2 7.2.8-1`
- running release: `7.2.8-1-cachyos-hp-envy-audio-v2`

The actual experiment-2 implementation kept the experiment-1 helper function and chained its fixup to `ALC245_FIXUP_BASS_HP_DAC`:

```c
[ALC245_FIXUP_HP_ENVY_17_CH0XXX] = {
    .type = HDA_FIXUP_FUNC,
    .v.func = alc245_fixup_hp_envy_17_ch0xxx,
    .chained = true,
    .chain_id = ALC245_FIXUP_BASS_HP_DAC,
},
```

This is the authoritative implementation; the earlier proposal that showed the HP fixup directly as `HDA_FIXUP_PINS` was illustrative rather than the exact built patch.

Boot validation confirms the model fixup matched:

```text
ALC245: picked fixup for PCI SSID 103c:88b5
autoconfig for ALC245: line_outs=2 (0x14/0x17/0x0/0x0/0x0) type:speaker
```

NID `0x14` remains bound to `0x02`.

For NID `0x17`, the hardware codec dump still advertises all four physical connection candidates:

```text
Connection: 4
    0x02 0x03* 0x06 0x08
```

but the HDA driver's override is now visible separately:

```text
In-driver Connection: 2
    0x02 0x03
```

and `0x03` is selected. This is the expected result of `ALC245_FIXUP_BASS_HP_DAC`: DAC `0x06` is no longer available to the driver's routing for the bass-speaker pin, while the volume-controlled DAC `0x03` is selected.

Therefore the experiment-2 routing change is **CONFIRMED**.

Before audible testing, the observed mixer state was deliberately safe:

- Master: 0%, muted
- Speaker switch: off
- Bass Speaker switch: on
- PipeWire default sink: 2%, muted

No audible conclusion has yet been drawn from experiment 2. The next gate is to inspect the generated DAC controls and then perform a deliberately low-volume listening test.
