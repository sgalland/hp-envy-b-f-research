# Windows driver package analysis

Analysis date: 2026-09-25

## Executive finding

The exported Windows Realtek package contains explicit configuration for the HP subsystem `103C:88B5`, and that configuration is not merely generic stereo.

The base Realtek INF, `hdxssthpnb.inf`, maps:

`INTELAUDIO\FUNC_01&VEN_10EC&DEV_0245&SUBSYS_103C88B5`

to `IntcAzAudModel`.

That install section applies:

`HPModelAddReg, RtHdaBaseAddReg, SSTXperi4SPKAddReg`

The `SSTXperi4SPKAddReg` section enables an SST speaker-effects profile:

```ini
[SSTXperi4SPKAddReg]
HKR,SSTPPCfg\{D9C95249-EDFC-4046-96EC-15D2EB12C74E}\SPK\EFX,Enabled,0x10001,1
HKR,SSTPPCfg\{D9C95249-EDFC-4046-96EC-15D2EB12C74E}\SPK\EFX,Position,0x10001,1
```

The section name itself contains `4SPK`, which is strong evidence that the Windows package treats this HP platform as a four-speaker configuration rather than only the two-channel generic ALC245 path currently visible under Linux.

## Device-specific Realtek data

The large Realtek data file `RTAIODAT.DAT` contains an embedded ZIP-like entry tree with a directory specifically for this exact HP subsystem:

`rtkhdasetting/103C88B5/`

Within it is:

`gen3p1pkey.zip`

which contains:

`gen3p1pkey.dat`

The inner DAT file is a proprietary binary profile. It is approximately 28 KiB and is not self-describing text, but its existence proves that the Realtek Windows stack ships model-specific configuration data for `103C88B5`.

This is a much stronger lead than generic HP/B&O branding alone.

## APO / effects stack

The exported package also includes:

- Realtek APO 2
- Realtek INT APO 2
- Sound Research APO data
- HP / Bang & Olufsen HSA
- Realtek Universal Service
- Realtek OVWrap2

The Sound Research package includes separate output/content presets, including headphone and general-output effect presets.

The B&O HSA appears to be the Windows support/control application layer, while the base Realtek INF and Realtek data package contain the lower-level machine-specific configuration.

## Implication for Linux

The Linux baseline currently exposes a working stereo ALC245 path through SOF, but no explicit four-speaker route.

The Windows driver package provides evidence for two layers that Linux does not currently reproduce:

1. an SST/Realtek four-speaker configuration path; and
2. model-specific binary tuning/configuration for `103C88B5`.

This strongly supports the user's observation that the bottom stereo speakers work under CachyOS while an additional upper/top-facing speaker path active in Windows remains silent.

## Recommended next investigation

Do not attempt to translate the proprietary `gen3p1pkey.dat` blindly.

Instead:

1. Capture the live Windows endpoint configuration and registry values for the ALC245 device, especially the `SSTPPCfg` subtree and endpoint channel masks.
2. Determine whether Windows exposes the internal endpoint as 2-channel or 4-channel at the WASAPI level.
3. Compare codec pin/verb state between Windows and Linux if a safe read-only mechanism is available.
4. Search upstream Linux kernel/ALSA/SOF sources and issue history for HP `103C:88B5`, `SSTXperi4SPK`, or equivalent four-speaker ALC245 support.
5. Only after the hardware path is identified should we experiment with Linux codec quirks, UCM topology, or DSP routing.

