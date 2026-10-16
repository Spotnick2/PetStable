param([string]$LibGlass = (Join-Path $PSScriptRoot '..\..\LibGlass'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = (Resolve-Path -LiteralPath $LibGlass).ProviderPath
$pin = 'fcfd472b30756a51b265969e71deb36cd3524802' # r9
$stage = Join-Path $root ('.test-output\libglass-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
$archive = Join-Path $stage 'r9.zip'
& git -c "safe.directory=$source" -C $source archive --format=zip "--output=$archive" $pin
if ($LASTEXITCODE -ne 0) { throw 'Cannot read the pinned LibGlass r9 commit.' }
Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $stage 'source')
$install = Join-Path $stage 'install'
New-Item -ItemType Directory -Path $install | Out-Null
& pwsh -NoProfile -File (Join-Path $stage 'source\Tools\deploy.ps1') -Addon PetStable -AddOnsPath $install
if ($LASTEXITCODE -ne 0) { throw 'Pinned LibGlass deployment failed.' }
New-Item -ItemType Directory -Path (Join-Path $root 'Libs') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $install 'PetStable\Libs\LibGlass-1.0') -Destination (Join-Path $root 'Libs') -Recurse -Force
Write-Host "Embedded LibGlass r9 ($pin) using its release deployment layout."
