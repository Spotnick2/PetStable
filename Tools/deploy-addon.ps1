param([string]$AddOnsPath = 'C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns',
    [string]$Lua = 'C:\Program Files (x86)\Lua\5.1\lua.exe')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$lib = Join-Path $root 'Libs\LibGlass-1.0'
if (-not (Test-Path -LiteralPath (Join-Path $lib 'LibGlass-1.0.xml'))) { throw 'Run Tools/embed-libglass.ps1 first.' }
$luac = Join-Path (Split-Path -Parent $Lua) 'luac.exe'
foreach ($name in @('Core.lua','Catalog.lua','CatalogData.lua','CatalogReference.lua','Sightings.lua','GuideData.lua','GuideModels.lua','GuideAppearances.lua','GuideUI.lua','UI.lua')) {
    & $luac -p (Join-Path $root $name)
    if ($LASTEXITCODE -ne 0) { throw "Invalid Lua: $name" }
}
if (-not (Test-Path -LiteralPath $AddOnsPath)) { throw 'AddOns directory does not exist.' }
$dest = Join-Path $AddOnsPath 'PetStable'
New-Item -ItemType Directory -Path (Join-Path $dest 'Libs') -Force | Out-Null
Copy-Item -LiteralPath $lib -Destination (Join-Path $dest 'Libs') -Recurse -Force
foreach ($name in @('PetStable.toc','Core.lua','Catalog.lua','CatalogData.lua','CatalogReference.lua','Sightings.lua','GuideData.lua','GuideModels.lua','GuideAppearances.lua','GuideUI.lua','UI.lua')) {
    Copy-Item -LiteralPath (Join-Path $root $name) -Destination (Join-Path $dest $name) -Force
}
Write-Host 'Deployed PetStable. In game: /reload, then /petstable.'
