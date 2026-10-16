param([string]$LibGlass = (Join-Path $PSScriptRoot '..\..\LibGlass'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = (Resolve-Path -LiteralPath $LibGlass).ProviderPath
$pin = '7b1b1e6c08f040d3fa495aa5f4308f160d5495d9' # r8
$stage = Join-Path $root ('.test-output\libglass-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
$archive = Join-Path $stage 'r8.zip'
& git -c "safe.directory=$source" -C $source archive --format=zip "--output=$archive" $pin
if ($LASTEXITCODE -ne 0) { throw 'Cannot read the pinned LibGlass r8 commit.' }
Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $stage 'source')
$install = Join-Path $stage 'install'
New-Item -ItemType Directory -Path $install | Out-Null
& pwsh -NoProfile -File (Join-Path $stage 'source\Tools\deploy.ps1') -Addon PetStable -AddOnsPath $install
if ($LASTEXITCODE -ne 0) { throw 'Pinned LibGlass deployment failed.' }
New-Item -ItemType Directory -Path (Join-Path $root 'Libs') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $install 'PetStable\Libs\LibGlass-1.0') -Destination (Join-Path $root 'Libs') -Recurse -Force
Write-Host "Embedded LibGlass r8 ($pin) using its release deployment layout."
