[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$required = @(
    'MichiMetronomeWatch/MichiMetronomeWatch.xcodeproj/project.pbxproj',
    'MichiMetronomeWatch/MichiMetronomeWatchApp.swift',
    'MichiMetronomeWatch/ContentView.swift',
    'MichiMetronomeWatch/MetronomeEngine.swift',
    'MichiMetronomeWatch/MetronomeSettings.swift',
    'MichiMetronomeWatch/ClickAudioEngine.swift'
)

foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf)) {
        throw "Missing required file: $relative"
    }
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

Get-ChildItem -LiteralPath (Join-Path $root 'MichiMetronomeWatch') -Recurse -File |
    Where-Object { $_.Extension -eq '.swift' } |
    ForEach-Object {
        $content = Get-Content -LiteralPath $_.FullName -Raw
        foreach ($token in $forbidden) {
            if ($content.Contains($token)) {
                throw "Offline guard: '$token' found in $($_.FullName)"
            }
        }
    }

Write-Host 'Validation passed: standalone/offline watch app.' -ForegroundColor Green
