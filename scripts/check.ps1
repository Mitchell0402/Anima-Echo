[CmdletBinding()]
param(
    [string]$Godot = $env:GODOT_BIN,
    [switch]$SkipImportRefresh,
    [switch]$Smoke
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path -LiteralPath (Join-Path $ScriptDir "..")

function Resolve-GodotExecutable {
    param([string]$Requested)

    if (-not [string]::IsNullOrWhiteSpace($Requested)) {
        if (Test-Path -LiteralPath $Requested) {
            return (Resolve-Path -LiteralPath $Requested).Path
        }
        return $Requested
    }

    $candidateNames = @(
        "godot",
        "godot4",
        "godot_console",
        "godot.exe",
        "godot4.exe",
        "godot_console.exe"
    )

    foreach ($name in $candidateNames) {
        $command = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $command) {
            return $command.Source
        }
    }

    throw "Godot executable not found. Set GODOT_BIN or pass -Godot."
}

$GodotExe = Resolve-GodotExecutable -Requested $Godot

function Invoke-GodotStep {
    param(
        [string]$Name,
        [string[]]$Arguments
    )

    Write-Host ""
    Write-Host "== $Name =="
    & $GodotExe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
}

if (-not $SkipImportRefresh) {
    Invoke-GodotStep -Name "Refresh Godot imports" -Arguments @(
        "--headless",
        "--editor",
        "--quit",
        "--path",
        $ProjectRoot
    )
}

Invoke-GodotStep -Name "Run project regression suite" -Arguments @(
    "--headless",
    "--path",
    $ProjectRoot,
    "-s",
    "res://tests/project/run_all.gd"
)

if ($Smoke) {
    Invoke-GodotStep -Name "Smoke start town" -Arguments @(
        "--headless",
        "--path",
        $ProjectRoot,
        "--quit-after",
        "3"
    )

    Invoke-GodotStep -Name "Smoke start mine" -Arguments @(
        "--headless",
        "--path",
        $ProjectRoot,
        "res://scenes/mine/test_scene.tscn",
        "--quit-after",
        "3"
    )
}

Write-Host ""
Write-Host "All requested checks passed."
