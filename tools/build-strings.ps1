# Builds the English menu-label files for both mods and checks every key round-trips.
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$tool = Join-Path $PSScriptRoot "w3strings.ps1"

$targets = @(
    @{ Src = "src\strings\en.txt";          Out = "src\mods\modSignpostRouter\content\en.w3strings"; FirstId = 2112230000 },
    @{ Src = "minimap-zoom\strings\en.txt"; Out = "minimap-zoom\mods\modMinimapZoom\content\en.w3strings"; FirstId = 2112231000 }
)

foreach ($t in $targets) {
    $src = Join-Path $repo $t.Src
    $out = Join-Path $repo $t.Out
    & $tool -Source $src -Out $out -FirstId $t.FirstId
    foreach ($line in [IO.File]::ReadAllLines($src, [Text.Encoding]::UTF8)) {
        if ($line.Trim() -eq "" -or $line.StartsWith("#")) { continue }
        $i = $line.IndexOf("|")
        $key = $line.Substring(0, $i); $want = $line.Substring($i + 1)
        $got = & $tool -Read $out -Key $key
        if ($got -ne $want) { throw "Round-trip failed for ${key}: '$got' <> '$want'" }
    }
    "Verified $($t.Out)"
}
