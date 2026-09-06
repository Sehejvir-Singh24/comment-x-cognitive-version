$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$env:PUB_CACHE = Join-Path $projectRoot '.pub-cache'
$flutter = Join-Path $projectRoot '.tools\flutter\bin\flutter.bat'
Push-Location -LiteralPath $PSScriptRoot
try {
    & $flutter run
} finally {
    Pop-Location
}
