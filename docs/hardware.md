# Hardware and software inventory

This file records **confirmed facts** about the target HP Envy laptop. Do not promote guesses or forum matches into this file until the target machine verifies them.

## Machine identity

- HP product name: HP ENVY Laptop 17-ch0xxx
- HP product number / SKU: TBD
- BIOS version: TBD
- BIOS date: TBD
- CPU: TBD
- Chipset: TBD

## Linux environment

- Distribution: CachyOS live environment
- Boot method: Ventoy
- Kernel: TBD
- Kernel command line: TBD
- PipeWire version: TBD
- WirePlumber version: TBD
- ALSA library / utilities version: TBD

## Audio hardware

### PCI / platform controllers

- Intel Smart Sound Technology audio controller present.
- Windows device: `INTELAUDIO\\CTLR_DEV_A0C8&LINKTYPE_06&DEVTYPE_06&VEN_8086&DEV_AE50&SUBSYS_88B5103C&REV_0001` (Intel Smart Sound Technology for USB Audio).

### ALSA cards

TBD

### Codecs

- Realtek ALC245 (`VEN_10EC`, `DEV_0245`).
- HP subsystem ID: `103C:88B5`.
- Windows device: `INTELAUDIO\\FUNC_01&VEN_10EC&DEV_0245&SUBSYS_103C88B5&REV_1000`.

### DSP / Sound Open Firmware

- Intel Smart Sound Technology is present on the Windows configuration.
- Linux SOF/HDA binding still needs to be confirmed from the CachyOS diagnostic snapshot.

### Speaker amplifiers

- **Not yet confirmed on the target machine.**
- Research strongly suggests this HP Envy 17 / ALC245 family may use Cirrus Logic CS35L41 smart amplifiers (`CSC3551`) over I2C. Similar HP Envy 17 systems fail under Linux when BIOS ACPI `_DSD` properties for those amplifiers are missing.
- Confirm by checking CachyOS kernel logs for `cs35l41-hda`, `CSC3551`, `ACPI _DSD`, or `Platform not supported` before applying any workaround.

### Internal microphone

TBD

### Headphone / headset path

TBD

### HDMI / DisplayPort audio

TBD

## Kernel modules

TBD

## Firmware

TBD

## UCM configuration

TBD

## Known working functions

- [ ] Built-in speakers
- [ ] Headphones
- [ ] Headset microphone
- [ ] Internal microphone
- [ ] HDMI/DP audio
- [ ] Volume controls
- [ ] Suspend/resume without audio regression

## Notes

Populate this document from output produced by `scripts/collect-audio-info.sh` and from verified manual tests.
