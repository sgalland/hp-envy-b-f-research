# Hardware and software inventory

This file records **confirmed facts** about the target HP Envy laptop. Do not promote guesses or forum matches into this file until the target machine verifies them.

## Machine identity

- HP product name: HP ENVY Laptop 17-ch0xxx
- Audio codec subsystem: `103C:88B5`
- HP product number / SKU: TBD
- BIOS version: TBD
- BIOS date: TBD
- CPU: Intel platform using Tiger Lake-generation SOF driver support
- Chipset: TBD

## Linux environment

- Distribution: CachyOS
- Experimental kernel: `7.2.8-1-cachyos-hp-envy-audio`
- Audio stack: PipeWire/WirePlumber over ALSA/SOF/HDA
- SOF PCI driver: `sof-audio-pci-intel-tgl`
- SOF firmware: `intel/sof/sof-tgl.ri`
- SOF topology: `intel/sof-tplg/sof-hda-generic-2ch.tplg`
- PipeWire version: TBD
- WirePlumber version: TBD
- ALSA library / utilities version: TBD

## Audio hardware

### PCI / platform controllers

- Intel Smart Sound Technology / Sound Open Firmware audio path is active under Linux.
- Windows device observed: `INTELAUDIO\\CTLR_DEV_A0C8&LINKTYPE_06&DEVTYPE_06&VEN_8086&DEV_AE50&SUBSYS_88B5103C&REV_0001` (Intel Smart Sound Technology for USB Audio).

### ALSA / SOF card

- Linux card 0 is exposed as `sof-hda-dsp`.
- HDA codec address: 0.

### Codec

- Realtek ALC245.
- Vendor/device ID: `0x10ec0245`.
- HP codec subsystem ID: `0x103c88b5`.
- Codec revision: `0x100001`.
- Windows device: `INTELAUDIO\\FUNC_01&VEN_10EC&DEV_0245&SUBSYS_103C88B5&REV_1000`.

### Internal speaker pins

The experimental `103c:88b5` kernel quirk exposes two line-out pins as speakers:

- NID `0x14`, driver pin config `0x90170110`.
- NID `0x17`, driver pin config `0x90170111`.

Observed topology/state:

#### NID 0x14

- Pin type: output with EAPD.
- Pin control: `0x40` (`OUT`).
- EAPD: `0x2` (enabled).
- Connection: fixed to NID `0x02`.
- Mixer control: `Speaker Playback Switch`.
- DAC `0x02` exposes `Speaker Playback Volume`.

#### NID 0x17

- Pin type: output-capable pin exposed as `Bass Speaker` by ALSA.
- Pin control: `0x40` (`OUT`).
- Connections: `0x02`, `0x03`, `0x06`, `0x08`.
- Observed selected connection: `0x06`.
- Mixer control: `Bass Speaker Playback Switch`.
- DAC `0x06` has no normal hardware playback-volume control.
- A runtime `SET_CONNECT_SEL 0` attempt did not persist: a following `GET_CONNECT_SEL` still returned selector value `0x2`.

### Physical speaker behavior

- Lower/bottom internal stereo speakers: confirmed working under Linux.
- Upper/top-facing B&O speaker pair: normally silent under Linux.
- **Important transient observation:** during one custom-kernel test session, both physical speaker sets were audibly active. The exact preceding runtime state was not captured and the result has not been reproduced after reboot. This proves accessibility, not a known fix.
- During the same experimental period, output became unexpectedly/dangerously loud relative to the configured PipeWire volume. This is consistent with an independently routed output path that is not governed by the ordinary `Speaker Playback Volume` control, but the exact cause is not yet proven.

### External smart amplifiers

No evidence for a Cirrus Logic CS35L41/CSC3551 path has been found on the target machine:

- no matching ACPI audio/amp device;
- no matching I2C device name;
- no loaded CS35/Cirrus module;
- no CS35/CSC3551/Cirrus kernel-log entry; and
- no matching `CSC3551`, `CS35L41`, or `Cirrus` string in the DSDT scan performed during the investigation.

Therefore CS35L41 is **not a current target-machine hypothesis** unless new hardware evidence appears.

### Internal microphone

- Confirmed working under Linux.
- SOF reports two DMICs in NHLT tables.

### Headphone / headset path

- Headphone output confirmed working under Linux.
- Headphone pin reported as NID `0x21`.

### HDMI / DisplayPort audio

- HDA HDMI codec support is loaded and HDMI/DP endpoints are enumerated.
- Functional playback test status: TBD.

## Kernel modules observed

Relevant loaded modules include:

- `snd_sof_pci_intel_tgl`
- `snd_sof_intel_hda_generic`
- `snd_sof_intel_hda_common`
- `snd_sof_intel_hda`
- `snd_hda_codec_alc269`
- `snd_hda_codec_realtek_lib`
- `snd_hda_codec_generic`
- `snd_hda_codec_hdmi`
- `snd_hda_core`

## Known working functions

- [x] Lower/bottom built-in stereo speakers
- [ ] Upper/top-facing B&O speaker pair (transiently heard, not reproducible)
- [x] Headphones
- [ ] Headset microphone — not separately confirmed
- [x] Internal microphone
- [ ] HDMI/DP audio — enumerated, playback not confirmed
- [ ] Safe unified volume control for all internal speakers
- [ ] Suspend/resume without audio regression

## Windows comparison

The known-good Windows Realtek package explicitly configures subsystem `103C:88B5` with `SSTXperi4SPK`, model-specific Realtek data, and a second SST-backed output path. See `docs/windows-driver-analysis.md`.
