param(
    [switch]$Probe,
    [string]$AddOnsPath = 'C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns',
    [string]$Lua = 'C:\Program Files (x86)\Lua\5.1\lua.exe'
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $Probe) { throw 'Only developer probe deployment exists yet. Use -Probe explicitly.' }
if (-not (Test-Path -LiteralPath $AddOnsPath -PathType Container)) { throw "AddOns directory not found: $AddOnsPath" }
$hostRoot = if ($env:FOREVERPROBE) { $env:FOREVERPROBE } else { Join-Path (Split-Path -Parent $repoRoot) 'ForeverProbe' }
$hostDeploy = Join-Path $hostRoot 'Tools\deploy.ps1'
if (-not (Test-Path -LiteralPath $hostDeploy -PathType Leaf)) { throw "ForeverProbe checkout not found at $hostRoot" }
$source = Join-Path $repoRoot 'Tools\PetStableProbe'
$toc = Join-Path $source 'PetStableProbe.toc'
$scripts = @(Get-Content -LiteralPath $toc | Where-Object { $_ -match '\.lua$' -and $_ -notmatch '^#' } | ForEach-Object { $_.Trim() })
if (-not $scripts.Count) { throw 'Probe TOC lists no Lua files.' }
$luac = Join-Path (Split-Path -Parent $Lua) 'luac.exe'
foreach ($script in $scripts) {
    $file = Join-Path $source $script
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing probe file: $file" }
    & $luac -p $file
    if ($LASTEXITCODE -ne 0) { throw "Syntax check failed: $file" }
}
# The host must deploy successfully before touching the module's destination.
& pwsh -NoProfile -File $hostDeploy -AddOnsPath $AddOnsPath -Lua $Lua
if ($LASTEXITCODE -ne 0) { throw 'ForeverProbe deploy failed; PetStableProbe was not touched.' }
$destination = Join-Path (Resolve-Path -LiteralPath $AddOnsPath).ProviderPath 'PetStableProbe'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
foreach ($file in (@('PetStableProbe.toc') + $scripts)) {
    Copy-Item -LiteralPath (Join-Path $source $file) -Destination (Join-Path $destination $file) -Force
}
Write-Host "Deployed PetStableProbe to $destination. In game: /reload, then /fp steps ps discover for creature observations."
Write-Host 'If a procedure is already running, use /fp steps show to resume it instead of starting another.'
