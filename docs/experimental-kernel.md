# Experimental CachyOS kernel

## Purpose

This document records two controlled kernel experiments for the HP ENVY 17-ch0xxx / Realtek ALC245 subsystem `103C:88B5`.

Neither experiment is established as a completed audio fix. Their purpose was to make the model-specific speaker topology deterministic at boot and investigate DAC routing without relying on ephemeral sysfs pin overrides.

## Experiment 1 kernel (2026-09-29)

- Base: CachyOS Linux 7.2.8-1 source/package.
- Experimental package: `linux-cachyos-hp-envy-audio 7.2.8-1`, built and installed on 2026-09-29.
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

The package-build patch was named `hp-envy-17-ch0xxx-audio.patch`; its research copy is `patches/hp-envy-17-ch0xxx-audio-v1.patch`.

## Boot validation

The experiment 1 kernel was booted and tested on the target machine.

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

## Experiment 1 observed topology problem

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

This matters because experiment 1 playback became unexpectedly loud even with a very low PipeWire sink volume. The working hypothesis was that simply enabling the second speaker path was insufficient; the correct fix also needed the intended DAC binding/gain/volume behavior.

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

That existing mechanism motivated experiment 2's chained fixup. The Windows secondary SST path still leaves a separate SOF/topology question.

## Safety/testing protocol

Until unified volume behavior is understood:

- begin listening tests muted;
- use conservative ALSA hardware levels before unmuting PipeWire;
- capture `Master`, `Speaker`, `Bass Speaker`, relevant codec nodes, and PipeWire sink state before each mutation;
- make one state-changing operation at a time;
- capture state again immediately afterward;
- record exactly which physical speaker set was heard; and
- reboot between experiments when a clean baseline is required.

## Experiment 1 status

**PROMISING INFRASTRUCTURE, NOT A FIX.**

Experiment 1 provided a deterministic model-specific starting point. The next engineering question was the correct relationship among pins `0x14`/`0x17`, DACs `0x02`/`0x06`, Realtek's existing ALC245 bass-DAC binding logic, and the Windows `SSTXperi4SPK` / secondary SST configuration.


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

### Experiment 2 implementation

Experiment 2 kept the confirmed HP pin override and chained it to the existing bass-DAC routing fixup. The patch uses the same HP pre-probe pin function as experiment 1, with this fixup entry:

```c
[ALC245_FIXUP_HP_ENVY_17_CH0XXX] = {
    .type = HDA_FIXUP_FUNC,
    .v.func = alc245_fixup_hp_envy_17_ch0xxx,
    .chained = true,
    .chain_id = ALC245_FIXUP_BASS_HP_DAC,
},
```

HDA fixup chaining calls the chained fixup after the current fixup unless `chained_before` is requested. This ordering applies the HP pin definitions before the existing pre-probe routing helper removes DAC `0x06` and chooses the preferred volume-controlled DACs.

The predicted post-boot topology was:

```text
0x14 -> 0x02
0x17 -> 0x03
0x21 -> 0x03
```

This kernel change configures the connection list and preferred DACs before the generic HDA parser builds the routing and controls. The subsequent boot observations below confirm the routing change and mixer behavior.

### Experiment 2 package recipe and recovered history

The pre-build gate called for reviewing the patch to confirm that the only functional change from experiment 1 was chaining the HP pin fixup to `ALC245_FIXUP_BASS_HP_DAC`. That gate is historical: experiment 2 was subsequently built, installed, and booted.

To reproduce the package build from CachyOS Linux `7.2.8-1`:

1. Use package suffix `cachyos-hp-envy-audio-v2`, producing `linux-cachyos-hp-envy-audio-v2 7.2.8-1` and kernel release `7.2.8-1-cachyos-hp-envy-audio-v2`.
2. Add `hp-envy-17-ch0xxx-audio.patch` to the PKGBUILD `source` array, using `patches/hp-envy-17-ch0xxx-audio-v2-bass-dac.patch` as its contents.
3. Use this BLAKE2 checksum for the patch in the corresponding PKGBUILD `b2sums` entry: `7405a9e2bb3f80b85311976744d6030326331031b640db71abd0e9d97812ad3b4cfbe5bace96c64fce0190e846916baa9141f0635564a046ecf02924acf0e87a`.
4. Remove the `linux-cachyos-lto` and `linux-cachyos-lto-headers` `replaces` declarations so the experimental kernel can coexist with the stock fallback kernel.

`dkms-clang.patch` is an upstream CachyOS build input, not HP-Envy-specific research material. The disposable build checkout is not needed to retain the HP experiment.

The canonical v2 research patch is byte-for-byte the patch consumed by the successful package build. The earlier committed copy differs only in context whitespace and is semantically identical under `diff -uw`.

The v2 package was built at approximately 19:50 MDT on 2026-09-29 and installed at approximately 21:44 MDT. Journal evidence confirms a boot of `7.2.8-1-cachyos-hp-envy-audio-v2` at 21:46:40 MDT. That boot persisted until 2026-10-01 19:41. The machine had returned to the stock CachyOS kernel when this history was recovered.

## 2026-09-29 experiment 2 boot result

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

At this stage, no audible conclusion had yet been drawn from experiment 2. DAC controls and listening tests were examined subsequently, as recorded below.


### Experiment 2 DAC-control confirmation

After the routing fix was confirmed, ALSA exposed simple controls named `DAC1` and `DAC2`. The codec dump identifies them as:

```text
Node 0x02: Control: name="DAC1 Playback Volume"
Node 0x03: Control: name="DAC2 Playback Volume"
```

Both nodes are stereo `Amp-Out` DACs with hardware volume capability:

```text
ofs=0x57, nsteps=0x57, stepsize=0x02
```

and both were observed at raw amp value `0x00` before audible testing.

This confirms that experiment 2 moved NID `0x17` away from the no-volume DAC `0x06` and onto DAC `0x03`, which has a real hardware playback-volume control. The expected safe control model is therefore now present at the codec level. Audible behavior still needs to be tested separately.


### Experiment 2 Master-volume binding confirmation

With both individual simple controls `DAC1` and `DAC2` displaying 100% / 0 dB, setting the ALSA `Master` control to 1% changed the underlying codec amp values for both DACs to:

```text
0x02 Amp-Out vals: [0x01 0x01]
0x03 Amp-Out vals: [0x01 0x01]
```

The ALSA control list contains one `Master Playback Volume` plus the separate `DAC1 Playback Volume` and `DAC2 Playback Volume` controls.

This confirms that the Master control supplies common attenuation to both volume-capable speaker DACs even though the individual DAC simple controls remain displayed at unity. This is the intended safe gain topology for the first audible experiment-2 test.


### Experiment 2 first audible test

The first audible test was intentionally run at the minimum safe settings established above: ALSA Master 1%, both speaker switches enabled, and PipeWire at 1%. No sound was heard.

This result is **not** treated as evidence that the speaker paths failed. At these settings the hardware Master attenuation is about -64.5 dB and PipeWire adds substantial additional software attenuation, so the combined level can reasonably be below audibility. The next test should raise only one gain layer at a time while retaining the confirmed volume-controlled DAC routing.


### Experiment 2 second audible test

A second audible test increased ALSA Master to 50% while keeping PipeWire at 5%, with both Speaker and Bass Speaker switches enabled. The same short system sound produced no audible output.

Unlike the first 1%/1% test, this is no longer reasonably explained by excessive attenuation alone. Experiment 2 has confirmed the intended 0x17 -> 0x03 routing and common Master attenuation, but audible speaker output remains absent under the tested state. The next diagnostic step is to verify the active PipeWire sink/route and codec stream state during playback before changing any additional codec state or introducing amplifier-enable hypotheses.


### Experiment 2 PipeWire route check

The default PipeWire sink was verified as the internal SOF HDA speaker path, not HDMI:

```text
api.alsa.card.name = "sof-hda-dsp"
api.alsa.path = "hw:sofhdadsp"
node.description = "... Speaker"
node.name = "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink"
```

Therefore the silent tests were not caused by accidentally targeting an HDMI sink.

A post-test inspection taken after the sink had been muted showed:

```text
Master: 51%, off
Speaker: off
Bass Speaker: on
0x02 Amp-Out vals: [0x2c 0x2c]
0x03 Amp-Out vals: [0x2c 0x2c]
```

This shows that PipeWire/UCM muting can drive the ALSA Master and Speaker switches off while retaining the underlying DAC gain values. Consequently, post-mute mixer state cannot be used as evidence for the exact switch state that existed during playback. The next diagnostic should capture mixer and codec state while the PipeWire sink is actively unmuted, before re-muting it.


### Experiment 2 PipeWire-to-ALSA volume mapping

With no audio stream running, PipeWire was set to 5% and unmuted. The corresponding ALSA/codec state was:

```text
PipeWire: 0.05, unmuted
Master: 0 [0%] [-65.25 dB], on
Speaker: on
Bass Speaker: on
0x02 Amp-Out vals: [0x00 0x00]
0x03 Amp-Out vals: [0x00 0x00]
```

Therefore a PipeWire sink level of 5% maps to the minimum hardware gain step on this codec. A silent listening result at 5% is not evidence of routing failure. PipeWire is the preferred control surface for subsequent tests; direct `amixer Master` changes should be avoided while characterizing normal desktop behavior.


### Experiment 2 20-percent volume mapping

With no audio stream running, PipeWire was set to 20% and unmuted. The corresponding codec state was:

```text
PipeWire: 0.20
Master: 32 [37%] [-41.25 dB], on
0x02 Amp-Out vals: [0x20 0x20]
0x03 Amp-Out vals: [0x20 0x20]
```

Both DACs continue to track together through the common Master control. This provides a conservative but non-minimum gain point for the next audible test.


### Experiment 2 audible result at 20 percent

A short PipeWire-routed system sound was played at PipeWire 20%, corresponding to ALSA Master 32 / -41.25 dB and raw amp value 0x20 on both DAC1 and DAC2. No audible output was heard.

This is now strong evidence that experiment 2 corrected the unsafe DAC routing and gain-control topology without restoring speaker output. The next diagnostic should verify that an active playback stream is actually assigned to the expected HDA converters while sound is being played. If stream assignment is correct and output remains silent, investigation should move to a separate speaker/amplifier-enable or platform-initialization hypothesis rather than further DAC-routing changes.


### Experiment 2 active-stream confirmation

During repeated playback at PipeWire 20%, both speaker DACs were observed on the same active HDA stream:

```text
Node 0x02: Converter: stream=1, channel=0
Node 0x03: Converter: stream=1, channel=0
```

At the same time, the default PipeWire sink remained the internal `sof-hda-dsp` Speaker sink at volume 0.20.

Combined with the previously confirmed topology:

```text
0x14 -> 0x02
0x17 -> 0x03
```

and nonzero hardware gain on both DACs, this establishes a complete software routing chain from PipeWire to both HDA speaker converters while audible output remains absent.

Conclusion: experiment 2 successfully corrected the DAC-routing and gain-control problem, but speaker output still requires an additional platform-specific enable/initialization step. Further DAC-routing experiments are not the next priority. The next research branch should focus on HP-specific speaker/amplifier initialization or other platform state that Windows establishes and Linux does not.
