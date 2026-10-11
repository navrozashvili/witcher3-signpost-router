# Installs Minimap Zoom into the game.
param([string]$GameDir = "D:\SteamLibrary\steamapps\common\The Witcher 3")

$ErrorActionPreference = "Stop"
if (-not (Test-Path (Join-Path $GameDir "bin"))) { throw "Not a Witcher 3 folder: $GameDir" }

$cfgDir = Join-Path $GameDir "bin\config\r4game\user_config_matrix\pc"
$modDst = Join-Path $GameDir "mods\modMinimapZoom"

if (Test-Path $modDst) { Remove-Item $modDst -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $GameDir "mods") | Out-Null
Copy-Item (Join-Path $PSScriptRoot "mods\modMinimapZoom") (Join-Path $GameDir "mods") -Recurse -Force
Copy-Item (Join-Path $PSScriptRoot "bin\config\r4game\user_config_matrix\pc\modMinimapZoom.xml") $cfgDir -Force

Get-ChildItem $modDst -Recurse -File | ForEach-Object { Write-Output "Installed $($_.FullName)" }
Write-Output "Installed $(Join-Path $cfgDir 'modMinimapZoom.xml')"
