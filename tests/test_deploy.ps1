param([string]$Lua = 'C:\Program Files (x86)\Lua\5.1\lua.exe')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path $repoRoot ('.test-output\deploy-' + [guid]::NewGuid().ToString('N'))
$hostTools = Join-Path $testRoot 'host\Tools'
$addons = Join-Path $testRoot 'AddOns'
$previousHost = $env:FOREVERPROBE
try {
    New-Item -ItemType Directory -Path $hostTools,$addons -Force | Out-Null
    $env:FOREVERPROBE = Split-Path -Parent $hostTools
    $fakeDeploy = Join-Path $hostTools 'deploy.ps1'
    Set-Content -LiteralPath $fakeDeploy -Value 'param($AddOnsPath, $Lua); exit 7'
    $deploy = Join-Path $repoRoot 'Tools\deploy.ps1'
    $target = Join-Path $addons 'PetStableProbe'
    & pwsh -NoProfile -File $deploy -AddOnsPath $addons -Lua $Lua *> $null
    if ($LASTEXITCODE -eq 0 -or (Test-Path -LiteralPath $target)) { throw 'Deployment must require -Probe.' }
    New-Item -ItemType Directory -Path $target | Out-Null
    $installed = Join-Path $target 'PetStableProbe.lua'
    Set-Content -LiteralPath $installed -Value 'previous installation'
    & pwsh -NoProfile -File $deploy -Probe -AddOnsPath $addons -Lua $Lua *> $null
    if ($LASTEXITCODE -eq 0) { throw 'Failed host deployment must fail the operation.' }
    if ((Get-Content -Raw -LiteralPath $installed).Trim() -ne 'previous installation') { throw 'Failed host deployment modified the module.' }
    Set-Content -LiteralPath $fakeDeploy -Value @'
param($AddOnsPath, $Lua)
$installed = Join-Path $AddOnsPath 'PetStableProbe\PetStableProbe.lua'
if ((Get-Content -Raw -LiteralPath $installed).Trim() -ne 'previous installation') { exit 9 }
Set-Content -LiteralPath (Join-Path $AddOnsPath 'host-deployed') -Value 'ok'
exit 0
'@
    & pwsh -NoProfile -File $deploy -Probe -AddOnsPath $addons -Lua $Lua
    if ($LASTEXITCODE -ne 0) { throw 'Successful host deployment must allow module deployment.' }
    if (-not (Test-Path -LiteralPath (Join-Path $addons 'host-deployed'))) { throw 'Host did not run.' }
    foreach ($name in @('PetStableProbe.lua', 'Training.lua', 'Models.lua', 'Discovery.lua', 'PetStableProbe.toc')) {
        $expected = Get-FileHash -LiteralPath (Join-Path $repoRoot "Tools\PetStableProbe\$name")
        $actual = Get-FileHash -LiteralPath (Join-Path $target $name)
        if ($expected.Hash -ne $actual.Hash) { throw "Deployed file differs: $name" }
    }
    Write-Host 'PASS: deployment opt-in, host failure isolation, host-first ordering, and exact copies'
    & pwsh -NoProfile -File (Join-Path $repoRoot 'Tools\deploy-addon.ps1') -AddOnsPath $addons -Lua $Lua
    if ($LASTEXITCODE -ne 0) { throw 'Player addon deployment failed.' }
    $player = Join-Path $addons 'PetStable'
    foreach ($name in @('Core.lua','UI.lua','PetStable.toc','Libs\LibGlass-1.0\LibGlass.lua','Libs\LibGlass-1.0\Media\rim_thin.tga')) {
        if ((Get-FileHash -LiteralPath (Join-Path $repoRoot $name)).Hash -ne (Get-FileHash -LiteralPath (Join-Path $player $name)).Hash) {
            throw "Player deployment differs: $name"
        }
    }
    if (Test-Path -LiteralPath (Join-Path $player 'Tools')) { throw 'Player addon must not include probes.' }
    Write-Host 'PASS: player addon deployment includes embedded media and excludes probes'
} finally {
    $env:FOREVERPROBE = $previousHost
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath
        $allowed = [IO.Path]::GetFullPath((Join-Path $repoRoot '.test-output')) + [IO.Path]::DirectorySeparatorChar
        if (-not $resolved.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing cleanup outside test directory.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
