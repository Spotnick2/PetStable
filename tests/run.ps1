param([string]$Lua = 'C:\Program Files (x86)\Lua\5.1\lua.exe')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$luac = Join-Path (Split-Path -Parent $Lua) 'luac.exe'
Push-Location $root
try {
    foreach ($file in (Get-ChildItem -Path Util.lua,Core.lua,Catalog.lua,CatalogData.lua,CatalogReference.lua,CatalogTeachers.lua,Sightings.lua,PetState.lua,GuideData.lua,GuideModels.lua,GuideAppearances.lua,GuideUI.lua,UpgradesData.lua,UpgradesUI.lua,PetsUI.lua,UI.lua,Tools,tests -Filter '*.lua' -Recurse -File)) {
        & $luac -p $file.FullName
        if ($LASTEXITCODE -ne 0) { throw "Syntax check failed: $($file.Name)" }
    }
    & $Lua tests/test_catalog.lua
    if ($LASTEXITCODE -ne 0) { throw 'Catalog tests failed.' }
    & $Lua tests/test_guide.lua
    if ($LASTEXITCODE -ne 0) { throw 'Guide data tests failed.' }
    & $Lua tests/test_reference.lua
    if ($LASTEXITCODE -ne 0) { throw 'Reference catalog tests failed.' }
    & $Lua tests/test_teachers.lua
    if ($LASTEXITCODE -ne 0) { throw 'Teacher catalog tests failed.' }
    & $Lua tests/test_upgrades.lua
    if ($LASTEXITCODE -ne 0) { throw 'Upgrades data tests failed.' }
    & $Lua tests/test_petstate.lua
    if ($LASTEXITCODE -ne 0) { throw 'Pet state tests failed.' }
    & $Lua tests/test_sightings.lua
    if ($LASTEXITCODE -ne 0) { throw 'Sighting tests failed.' }
    & $Lua tests/test_levelfilter.lua
    if ($LASTEXITCODE -ne 0) { throw 'Level filter tests failed.' }
    & $Lua tests/test_markers.lua
    if ($LASTEXITCODE -ne 0) { throw 'Family marker tests failed.' }
    & $Lua tests/test_reference_ui.lua
    if ($LASTEXITCODE -ne 0) { throw 'Reference UI tests failed.' }
    & $Lua tests/test_addon.lua
    if ($LASTEXITCODE -ne 0) { throw 'Addon tests failed.' }
    & $Lua tests/test_probe.lua
    if ($LASTEXITCODE -ne 0) { throw 'Probe tests failed.' }
    & pwsh -NoProfile -File tests/test_deploy.ps1 -Lua $Lua
    if ($LASTEXITCODE -ne 0) { throw 'Deployment tests failed.' }
} finally { Pop-Location }
