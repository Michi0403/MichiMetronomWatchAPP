[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',

    [string]$TeamId = 'YS97976PCZ',

    [switch]$Simulator
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not [Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
    [Runtime.InteropServices.OSPlatform]::OSX)) {
    throw 'watchOS apps must be built on macOS with Xcode.'
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$project = Join-Path $root 'MichiMetronome/MichiMetronome.xcodeproj'
$derived = Join-Path $root 'artifacts/DerivedData'

& xcodebuild -version
if ($LASTEXITCODE -ne 0) {
    throw 'xcodebuild was not found. Install/select Xcode first.'
}

$sdk = if ($Simulator) { 'watchsimulator' } else { 'watchos' }

$args = @(
    '-project', $project,
    '-target', 'MichiMetronome Watch App',
    '-configuration', $Configuration,
    '-sdk', $sdk,
    '-derivedDataPath', $derived
)

if ($Simulator) {
    $args += 'CODE_SIGNING_ALLOWED=NO'
} else {
    $args += '-allowProvisioningUpdates'
    if (-not [string]::IsNullOrWhiteSpace($TeamId)) {
        $args += "DEVELOPMENT_TEAM=$TeamId"
    }
}

& xcodebuild @args build
if ($LASTEXITCODE -ne 0) {
    throw 'watchOS build failed.'
}

Write-Host 'MichiMetronome canonical watchOS build passed.' -ForegroundColor Green
