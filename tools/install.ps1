# Installs Signpost Router into the game and removes the feasibility probe.
param([string]$GameDir = "D:\SteamLibrary\steamapps\common\The Witcher 3")

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$cfgDir = Join-Path $GameDir "bin\config\r4game\user_config_matrix\pc"

foreach ($old in @((Join-Path $GameDir "mods\modSignpostRouterProbe"), (Join-Path $cfgDir "modSignpostRouterProbe.xml"))) {
    if (Test-Path $old) { Remove-Item $old -Recurse -Force; Write-Output "Removed $old" }
}

$modDst = Join-Path $GameDir "mods\modSignpostRouter"
if (Test-Path $modDst) { Remove-Item $modDst -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $GameDir "mods") | Out-Null
Copy-Item (Join-Path $repo "src\mods\modSignpostRouter") (Join-Path $GameDir "mods") -Recurse -Force
Copy-Item (Join-Path $repo "src\bin\config\r4game\user_config_matrix\pc\modSignpostRouter.xml") $cfgDir -Force

Get-ChildItem $modDst -Recurse -File | ForEach-Object { Write-Output "Installed $($_.FullName)" }
Write-Output "Installed $(Join-Path $cfgDir 'modSignpostRouter.xml')"
