param([string]$CloudConfig)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$flutter = Join-Path $projectRoot '.tools\flutter\bin\flutter.bat'
Push-Location -LiteralPath $PSScriptRoot
try {
 if ($CloudConfig) {
  if (-not (Test-Path -LiteralPath $CloudConfig)) { throw 'Cloud configuration file was not found' }
  & $flutter run "--dart-define-from-file=$CloudConfig"
 } else { & $flutter run }
 if ($LASTEXITCODE -ne 0) { throw 'Flutter run failed; inspect the output above' }
} finally { Pop-Location }

