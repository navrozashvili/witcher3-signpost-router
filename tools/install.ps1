# Installs Signpost Router into the game and removes the feasibility probe.
param(
    [string]$GameDir = "D:\SteamLibrary\steamapps\common\The Witcher 3",
    [string]$JumpKey = "IK_F2"
)

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

# Signpost Jump key outside menus: bind the SRSignpostJump action under [Exploration] in input.settings.
$inputFile = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "The Witcher 3\input.settings"
if (-not (Test-Path $inputFile)) {
    Write-Output "input.settings not found; add '$JumpKey=(Action=SRSignpostJump)' under [Exploration] yourself"
} elseif (Get-Process witcher3 -ErrorAction SilentlyContinue) {
    Write-Output "The game is running and rewrites input.settings on exit; close it and run this again to bind the jump key"
} else {
    $lines = [Collections.Generic.List[string]][IO.File]::ReadAllLines($inputFile)
    $lines.RemoveAll([Predicate[string]]{ param($l) $l -match "\(Action=SRSignpostJump\)" }) | Out-Null
    $at = $lines.IndexOf("[Exploration]")
    if ($at -lt 0) { throw "No [Exploration] section in $inputFile" }
    $lines.Insert($at + 1, "$JumpKey=(Action=SRSignpostJump)")
    [IO.File]::WriteAllLines($inputFile, $lines)
    Write-Output "Bound $JumpKey to Signpost Jump in $inputFile"
}
