# Investigation log

Keep this chronological. Every experiment should record the environment, exact change, result, and whether the change was reverted.

## Status vocabulary

- **CONFIRMED** — reproduced and verified on the target laptop.
- **PROMISING** — improved behavior but needs more testing.
- **NO EFFECT** — did not materially change the symptom.
- **REGRESSION** — made behavior worse or broke another audio path.
- **REVERTED** — change was removed after testing.
- **TRANSIENT** — observed on the target machine but the exact enabling state was not preserved or the result cannot yet be reproduced.

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

**CONFIRMED** — research structure created.

## 2026-09-25 — CachyOS baseline: SOF + ALC245 detected

### Observed

- Intel Tiger Lake SOF driver loaded successfully: `sof-audio-pci-intel-tgl`.
- SOF firmware `intel/sof/sof-tgl.ri` loaded and topology `sof-hda-generic-2ch.tplg` selected.
- Realtek codec detected as ALC245.
- The initial environment showed a PCI SSID anomaly rather than the codec subsystem `103c:88b5` being used as desired.
- ALSA exposed `sof-hda-dsp` with analog and HDMI paths.

### Interpretation

**PROMISING** — DSP, firmware, topology, and ALC245 codec initialize; the model-specific HP routing remained unresolved.

## 2026-09-25 — Functional audio confirmed; upper output path unresolved

### Confirmed working

- Lower/bottom internal stereo speaker output is audible on both left and right channels.
- Headphone jack works.
- Microphone works.

### Remaining issue

The upper/top-facing B&O speaker area that is active under Windows is silent under normal Linux operation.

### Result

**PARTIAL SUCCESS** — core audio works; additional HP/B&O speaker path unresolved.

## 2026-09-25 — Windows known-good stack captured

### Key findings

The Windows snapshot confirms a richer stack than the base ALC245 codec driver alone:

- Realtek HDA codec driver bound to `INTELAUDIO\\FUNC_01&VEN_10EC&DEV_0245&SUBSYS_103C88B5...`.
- Intel Smart Sound Technology stack.
- HP/Bang & Olufsen support application.
- Realtek effects/service components.
- Sound Research APO.

Subsequent package/registry analysis identified `SSTXperi4SPK`, model-specific `103C88B5` Realtek data, `SecondaryChannelConfig = 3`, and a second SST-backed Realtek output. See `windows-driver-analysis.md`.

### Result

**STRONG LEAD** — Windows genuinely configures this platform as more than a generic single stereo speaker path.

---

## 2026-09-28/29 — Live codec experiments and reboot recovery

### Goal

Determine whether the additional speaker path could be exposed through ALC245 pin configuration and routing.

### Observed

Live HDA/sysfs experiments changed codec state but did not establish a reproducible upper-speaker fix. Rebooting restored a usable baseline, demonstrating that the runtime experiments were not a persistent solution.

### Result

**NO VERIFIED FIX** — useful topology information was obtained, but live mutation was too stateful to treat as authoritative.

### Process correction

From this point forward, state-changing tests must record pre-state, exact command, post-state, and listening result before another mutation is attempted.

## 2026-09-29 — Model-specific ALC245 kernel fixup prepared

### Goal

Make Linux recognize the HP codec subsystem `103c:88b5` explicitly and expose both candidate internal speaker pins without relying on ad-hoc runtime pin writes.

### Implementation

A minimal Realtek `alc269.c` fixup was prepared for:

- model: HP ENVY 17-ch0xxx;
- codec subsystem: `103c:88b5`;
- fixup identifier: `ALC245_FIXUP_HP_ENVY_17_CH0XXX`;
- pin `0x14`: `0x90170110`;
- pin `0x17`: `0x90170111`.

The patch adds the fixup and a `SND_PCI_QUIRK(0x103c, 0x88b5, ...)` match. The research copy was named `hp-envy-17-ch0xxx-audio.patch`.

### Result

**PROMISING** — sufficient to proceed to a controlled custom-kernel test.

## 2026-09-29 — Custom CachyOS kernel built and installed

### Build

A custom package based on CachyOS 7.2.8 was built successfully as:

`linux-cachyos-hp-envy-audio 7.2.8-1`

It was installed alongside the stock kernel rather than replacing the fallback kernel.

### Boot validation

Running kernel:

`7.2.8-1-cachyos-hp-envy-audio`

Kernel log confirmed:

- codec: Realtek ALC245;
- subsystem: `103c:88b5`;
- model-specific fixup selected for PCI SSID `103c:88b5`;
- autoconfig: `line_outs=2 (0x14/0x17/...) type:speaker`.

Driver pin configs reported:

```text
0x14 0x90170110
0x17 0x90170111
```

### Result

**CONFIRMED** — the custom kernel does what the patch intended at codec initialization. This validates quirk selection, not yet correct four-speaker operation.

## 2026-09-29 — Both physical speaker sets heard once

### Observation

During the first experimental-kernel session, the user audibly heard output from both the lower/bottom and upper/top-facing speaker sets.

### Critical limitation

The exact sequence of runtime mixer/codec state immediately preceding this observation was not preserved. The state therefore cannot currently be reconstructed, and after a later reboot the upper speakers were again silent.

### Result

**TRANSIENT / IMPORTANT** — this is direct evidence that Linux can reach the upper physical speakers on this machine. It is **not** a known fix and must not be documented as one.

## 2026-09-29 — Unsafe/uncontrolled loudness observed

### Observation

During the experimental-kernel testing, output became unexpectedly very loud even while the PipeWire sink was set to a very low volume. Mixer isolation tests also showed that the two speaker controls did not behave as a simple pair of equally volume-controlled outputs.

### Result

**REGRESSION / SAFETY CONCERN** — enabling the second path without understanding its gain/volume relationship is not acceptable as a final fix.

Future listening tests should begin muted and use conservative hardware/software levels.

## 2026-09-29 — Reboot: upper speakers silent again

### Environment

Kernel remained:

`7.2.8-1-cachyos-hp-envy-audio`

Driver pin configs remained:

```text
0x14 0x90170110
0x17 0x90170111
```

After reboot, the upper speakers were completely silent; the lower speaker path remained recoverable.

### Result

**CONFIRMED** — the model-specific pin fixup alone is insufficient. The transient both-speaker state depended on additional runtime state that the reboot removed.

## 2026-09-29 — Mixer and codec topology captured

### Mixer state

ALSA exposes:

- `Master` playback volume/switch;
- `Speaker` playback volume/switch;
- `Bass Speaker` playback switch.

`Bass Speaker` has a switch but no independent playback-volume control.

### NID 0x14

- `Speaker Playback Switch`.
- pin control `0x40` (`OUT`).
- EAPD `0x2` enabled.
- single connection to DAC `0x02`.
- DAC `0x02` owns `Speaker Playback Volume`.

### NID 0x17

- `Bass Speaker Playback Switch`.
- pin control `0x40` (`OUT`).
- four candidate connections: `0x02 0x03 0x06 0x08`.
- selected connection displayed as `0x06`.
- DAC `0x06` is an audio output with no normal playback-volume control.

### Interpretation

**STRONG LEAD** — the two speaker pins are not currently equivalent. `0x14 → 0x02` follows the ordinary speaker-volume path, whereas `0x17 → 0x06` bypasses that DAC volume control. This provides a concrete hardware explanation to investigate for the loud/uncontrolled second path.

Kernel-source inspection also found existing ALC245 bass-DAC/fixup logic that deliberately considers DAC binding and the special behavior of node `0x06`; this should be studied before inventing new routing behavior.

## 2026-09-29 — Attempt to change 0x17 connection selector did not stick

### Test

With the PipeWire sink muted:

```text
sudo hda-verb /dev/snd/hwC0D0 0x17 SET_CONNECT_SEL 0
sudo hda-verb /dev/snd/hwC0D0 0x17 GET_CONNECT_SEL 0
```

The SET command returned normally, but the following GET still returned selector value `0x2`, and `/proc/asound/card0/codec#0` continued to show `0x06*` as selected.

### Result

**NO EFFECT** — a simple runtime selector write is not sufficient to reroute NID `0x17` on this configuration.

## 2026-09-29 — Codec identity and SOF path reconfirmed

### Captured identity

```text
Codec: Realtek ALC245
Address: 0
Vendor Id: 0x10ec0245
Subsystem Id: 0x103c88b5
Revision Id: 0x100001
```

SOF uses:

- `sof-audio-pci-intel-tgl`;
- firmware `intel/sof/sof-tgl.ri`;
- topology `intel/sof-tplg/sof-hda-generic-2ch.tplg`.

The custom kernel log explicitly reports the `103c:88b5` fixup and two speaker line-outs.

### Result

**CONFIRMED** — we are debugging the intended codec and model-specific kernel path.

## 2026-09-29 — CS35L41/CSC3551 hypothesis tested and not supported

### Read-only checks

The target machine was checked for Cirrus smart-amplifier evidence in:

- ACPI device names;
- I2C device names;
- loaded modules;
- kernel log; and
- DSDT strings.

No `CS35`, `CSC3551`, `CS35L41`, `Cirrus`, or matching amplifier device was found in those checks.

### Result

**NO SUPPORTING EVIDENCE** — stop treating CS35L41/CSC3551 as the leading target-machine explanation unless new evidence appears.

## Current investigation boundary

Known facts now support this narrower problem statement:

1. Windows configures `103C:88B5` as a four-speaker/SST-capable platform.
2. Linux SOF + ALC245 normally drives the lower speaker pair only.
3. The custom kernel reliably exposes pins `0x14` and `0x17` as the intended model-specific speaker pair.
4. Linux produced sound from both physical speaker sets at least once.
5. That success did not survive reboot and its exact runtime state is unknown.
6. `0x14` and `0x17` currently follow different DAC/volume paths, with `0x17 → 0x06` lacking ordinary hardware playback volume.
7. A direct runtime connection-selector write to `0x17` did not stick.
8. No target-machine evidence currently supports an external CS35L41 smart-amplifier path.

The next work should investigate the existing upstream ALC245 bass-DAC/bind-DAC fixup machinery and the SOF/Realtek relationship to the Windows secondary SST path. Do not resume blind codec writes.
