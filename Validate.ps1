[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$required = @(
    'MichiMetronome/MichiMetronome.xcodeproj/project.pbxproj',
    'MichiMetronome/MichiMetronomeWatch-Info.plist',
    'MichiMetronome/MichiMetronome Watch App/MichiMetronomeApp.swift',
    'MichiMetronome/MichiMetronome Watch App/ContentView.swift',
    'MichiMetronome/MichiMetronome Watch App/MetronomeEngine.swift',
    'MichiMetronome/MichiMetronome Watch App/MetronomeSettings.swift',
    'MichiMetronome/MichiMetronome Watch App/ClickAudioEngine.swift',
    'MichiMetronome/MichiMetronome Watch App/PrivacyInfo.xcprivacy',
    'MichiMetronome/MichiMetronome Watch App/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
)

foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf)) {
        throw "Missing required file: $relative"
    }
}

$projectFile = Get-Content -LiteralPath (
    Join-Path $root 'MichiMetronome/MichiMetronome.xcodeproj/project.pbxproj'
) -Raw

if (-not $projectFile.Contains('PRODUCT_BUNDLE_IDENTIFIER = com.michi0403.michimetronome;')) {
    throw 'Registered root bundle identifier is missing.'
}

if (-not $projectFile.Contains('PRODUCT_BUNDLE_IDENTIFIER = com.michi0403.michimetronome.watchkitapp;')) {
    throw 'Watch bundle identifier is missing.'
}

$forbidden = @(
    'URLSession',
    'NSURLSession',
    'WKWebView',
    'WebView',
    'WatchConnectivity',
    'NWConnection',
    'http://',
    'https://'
)

$sourceRoot = Join-Path $root 'MichiMetronome/MichiMetronome Watch App'

Get-ChildItem -LiteralPath $sourceRoot -Recurse -File |
    Where-Object { $_.Extension -eq '.swift' } |
    ForEach-Object {
        $content = Get-Content -LiteralPath $_.FullName -Raw
        foreach ($token in $forbidden) {
            if ($content.Contains($token)) {
                throw "Offline guard: '$token' found in $($_.FullName)"
            }
        }
    }

Write-Host 'Validation passed: canonical Watch-only distribution project.' -ForegroundColor Green
