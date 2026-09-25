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

## 2026-09-25 — CachyOS baseline: SOF + ALC245 detected

### Observed

- Intel Tiger Lake SOF driver loaded successfully: `sof-audio-pci-intel-tgl`.
- SOF firmware `intel/sof/sof-tgl.ri` loaded and topology `sof-hda-generic-2ch.tplg` selected.
- Realtek codec detected as ALC245.
- Kernel log reports: `ALC245: picked fixup for PCI SSID 103c:0000`.
- Auto-configuration exposes speaker node 0x17 as `line_outs=1 ... type:speaker`, headphone node 0x21, microphone node 0x19.
- ALSA exposes `sof-hda-dsp` card 0 with HDA Analog device 0, HDA Analog Deep Buffer device 31, and three HDMI outputs.
- No `cs35l41` or `CSC3551` messages appeared in the filtered kernel log.

### Interpretation

**PROMISING** — the DSP, firmware, topology, and ALC245 codec are initializing. The standout anomaly is the PCI subsystem ID `103c:0000` rather than the Windows-observed codec subsystem `103c:88B5`.

Upstream Linux fixes from 2026 document the same HP pattern: a null PCI SSID can cause a vendor-wide HP quirk to match before the Realtek driver falls back to the codec subsystem ID, preventing the model-specific amplifier/fixup path from being selected. This is now the leading hypothesis, but the target codec subsystem ID must be confirmed from Linux before attempting a quirk override.

## 2026-09-25 — Functional audio confirmed; upper output path still unresolved

### Confirmed working on CachyOS kernel 7.1.6-1-cachyos

- Internal stereo speaker output is audible on both left and right channels.
- Speaker output is clear; the primary issue is not general distortion or total speaker failure.
- Headphone jack works.
- Microphone works.
- SOF, ALC245, PipeWire/ALSA playback path, and basic jack/capture support are therefore functional.

### Remaining issue

The user reports that the upper/top-facing B&O speaker area that is active under Windows is silent under Linux. This means the system is **usable but not feature-complete**.

### Revised research direction

Do not treat this as a generic PipeWire/ALSA failure. The next investigation should focus on how HP's Windows audio stack enables the additional physical output path, including:

- Realtek codec pin/fixup behavior for subsystem 103c:88b5;
- any HP-specific codec verb or vendor coefficient programming;
- Windows Realtek/Intel SST driver INF entries for board 88B5;
- HP/Bang & Olufsen APO or extension-driver packages that may configure extra routing;
- ACPI methods/devices that Linux may not currently bind to an audio amplifier;
- comparison of Windows and Linux codec/pin state where practical.

Status: **PARTIAL SUCCESS** — core audio works; additional HP/B&O speaker path remains unresolved.
