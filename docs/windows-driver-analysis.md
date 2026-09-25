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


## Live Windows registry confirmation

The live registry capture confirms that the installed Windows driver is actively using the model-specific `103C:88B5` configuration rather than merely shipping dormant support in the package.

### Device binding

The active Realtek class instance reports:

- driver version `6.0.9418.1`;
- INF `oem42.inf` / `IntcAzAudModel.NTamd64`;
- matching device ID `INTELAUDIO\\FUNC_01&VEN_10EC&DEV_0245&SUBSYS_103C88B5`.

### Model-specific settings key

Windows has a dedicated settings subtree named:

`Drv9418_DevType_0245_SS103c88b5`

Notable values include:

- `SecondaryChannelConfig = 3`;
- distinct volume/mute state for `RearLineOutWave3`;
- distinct volume/mute state for `SecondaryLineOutWave`;
- distinct volume/mute state for `RearLineOutWaveSST`;
- distinct volume/mute state for `RearLineOutWaveSST3`;
- per-channel RSA/AMP calibration values and measured impedance-like values for left and right channels.

### SST module binding

The live `SSTPPCfg` key contains one registered SST module:

`ModuleName = sraudio ... device=RearLineOutWaveSST3`

Realtek driver terminology identifies `RearLineOutWaveSST3` as the **second Realtek HD Audio output with SST**, not merely an effects alias for the ordinary primary output.

This is strong evidence that Windows maintains a second SST-backed render path for the internal speaker system.

### Software children

The active ALC245 device instance enumerates software children for:

- HP Audio Hardware Support Application / Bang & Olufsen control HSA;
- Realtek Audio Effects Component;
- Realtek Audio Effects Component (INT);
- Realtek OVWrap2;
- Realtek Audio Universal Service;
- Sound Research Audio Effects Component.

These are attached directly beneath the same physical ALC245 device instance.

## Revised conclusion

The evidence now favors a genuine **additional Windows audio path** over the simpler hypothesis that B&O software merely applies EQ to a single stereo endpoint.

The strongest indicators are:

1. the `SSTXperi4SPK` install section in the Realtek INF;
2. the model-specific `103C88B5` Realtek profile data;
3. `SecondaryChannelConfig = 3`;
4. independent state for primary/secondary/SST/SST3 outputs; and
5. the Sound Research SST module bound specifically to `RearLineOutWaveSST3`, which Realtek labels as its second SST output.

Linux currently exposes only the generic SOF HDA analog stereo route. The unresolved task is therefore to determine how Windows maps this second SST output to the extra physical speaker pair and whether an equivalent path can be enabled using Linux SOF topology, ALSA HDA pin routing, or a model-specific kernel quirk.
