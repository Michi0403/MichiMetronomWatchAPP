[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',

    [string]$TeamId = '',

    [switch]$Simulator
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not [Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
    [Runtime.InteropServices.OSPlatform]::OSX)) {
    throw 'watchOS apps must be built on macOS with Xcode.'
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$project = Join-Path $root 'MichiMetronomeWatch/MichiMetronomeWatch.xcodeproj'
$derived = Join-Path $root 'artifacts/DerivedData'

& xcodebuild -version
if ($LASTEXITCODE -ne 0) {
    throw 'xcodebuild was not found. Install/select Xcode first.'
}

$args = @(
    '-project', $project,
    '-scheme', 'MichiMetronome Watch',
    '-configuration', $Configuration,
    '-derivedDataPath', $derived,
    '-destination', $(if ($Simulator) {
        'generic/platform=watchOS Simulator'
    } else {
        'generic/platform=watchOS'
    })
)

if (-not $Simulator) {
    $args += '-allowProvisioningUpdates'
    if (-not [string]::IsNullOrWhiteSpace($TeamId)) {
        $args += "DEVELOPMENT_TEAM=$TeamId"
    }
}

& xcodebuild @args build
if ($LASTEXITCODE -ne 0) {
    throw 'watchOS build failed.'
}

Write-Host 'MichiMetronome watchOS build passed.' -ForegroundColor Green
