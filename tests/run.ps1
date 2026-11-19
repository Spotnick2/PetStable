<#
    run.ps1 - Syntax-check the Lua, run every tests\test_*.lua under Lua 5.1 through
    WowTestKit at the commit tests\kit.pin names (its scripts\run.ps1), then the
    deployment tests.

        pwsh tests/run.ps1
        pwsh tests/run.ps1 -Lua "C:\path\to\lua5.1.exe"
        pwsh tests/run.ps1 -KitDev      # the ..\WowTestKit working copy, not the pin

    test_addon and test_methods load the embedded LibGlass from Libs\LibGlass-1.0
    (Tools\embed-libglass.ps1 puts the .pkgmeta pin, r12, there), or from
    $env:PETSTABLE_LIBGLASS. test_probe loads ..\ForeverProbe (or $env:FOREVERPROBE).
#>
param([string]$Lua = 'C:\Program Files (x86)\Lua\5.1\lua.exe', [switch]$KitDev)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$luac = Join-Path (Split-Path -Parent $Lua) 'luac.exe'
Push-Location $root
try {
    # The kit's runner only warns without luac, so it isn't given the files: this is the check.
    foreach ($file in (Get-ChildItem -Path Util.lua,Core.lua,Catalog.lua,CatalogData.lua,CatalogReference.lua,CatalogTeachers.lua,CatalogFamilies.lua,CatalogSpells.lua,Sightings.lua,PetState.lua,GuideData.lua,GuideModels.lua,GuideAppearances.lua,GuideUI.lua,UpgradesData.lua,UpgradesUI.lua,PetsUI.lua,Toast.lua,TargetButton.lua,TeacherAlert.lua,UI.lua,Tools,tests -Filter '*.lua' -Recurse -File)) {
        & $luac -p $file.FullName
        if ($LASTEXITCODE -ne 0) { throw "Syntax check failed: $($file.Name)" }
    }
    Remove-Item -LiteralPath 'luac.out' -ErrorAction SilentlyContinue
} finally { Pop-Location }

. (Join-Path $PSScriptRoot 'kit.ps1')
$kit = Get-WowTestKit -RepoRoot $root -KitDev:$KitDev
& (Join-Path $kit 'scripts\run.ps1') -RepoRoot $root -Lua $Lua
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Push-Location $root
try {
    & pwsh -NoProfile -File tests/test_deploy.ps1 -Lua $Lua
    if ($LASTEXITCODE -ne 0) { throw 'Deployment tests failed.' }
} finally { Pop-Location }
