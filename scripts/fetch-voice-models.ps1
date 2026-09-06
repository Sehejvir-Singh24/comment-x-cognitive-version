$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot
$modelRoot = Join-Path $projectRoot 'patient_app/assets/models'
New-Item -ItemType Directory -Force -Path $modelRoot | Out-Null
$releases = @(
 @{Folder='vits-piper-en_US-lessac-medium'; Tag='tts-models'}
)
foreach ($release in $releases) {
 $archive = Join-Path $env:TEMP ($release.Folder + '.tar.bz2')
 $url = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/' + $release.Tag + '/' + $release.Folder + '.tar.bz2'
 Invoke-WebRequest -Uri $url -OutFile $archive
 & tar -xf $archive -C $modelRoot
 if ($LASTEXITCODE -ne 0) { throw 'Model extraction failed' }
}
$manifest = Get-Content (Join-Path $PSScriptRoot 'model-checksums.json') -Raw | ConvertFrom-Json
foreach ($entry in $manifest) {
 $file = Join-Path $modelRoot $entry.path
 if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entry.sha256) { throw ('Model checksum mismatch: ' + $entry.path) }
}
Write-Output 'Model assets downloaded and verified.'

