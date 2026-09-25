param(
    [string]$OutputDirectory = ("hp-envy-windows-endpoints-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
)

$ErrorActionPreference = "SilentlyContinue"
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

function Export-Tree {
    param([string]$Path,[string]$Name)
    $out = Join-Path $OutputDirectory ($Name + ".txt")
    if (Test-Path $Path) {
        Get-ChildItem $Path -Recurse |
            ForEach-Object {
                "===== $($_.Name) ====="
                Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue | Format-List *
            } | Out-File $out -Width 4096
    }
}

Export-Tree "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render" "mmdevices-render"
Export-Tree "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture" "mmdevices-capture"

$rtk = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96c-e325-11ce-bfc1-08002be10318}\0003"
Export-Tree "$rtk\InterfaceSetting" "realtek-interface-setting"
Export-Tree "$rtk\Settings\Drv9418_DevType_0245_SS103c88b5" "realtek-88b5-settings"
Export-Tree "$rtk\SSTPPCfg" "realtek-sstppcfg"

Get-PnpDevice -Class AudioEndpoint -PresentOnly |
    Format-List Status,Class,FriendlyName,InstanceId |
    Out-File (Join-Path $OutputDirectory "audio-endpoints.txt") -Width 4096

try {
    Compress-Archive -Path $OutputDirectory -DestinationPath "$OutputDirectory.zip" -Force
} catch {}

Write-Host "Endpoint snapshot written to $OutputDirectory"
if (Test-Path "$OutputDirectory.zip") {
    Write-Host "ZIP: $OutputDirectory.zip"
}
