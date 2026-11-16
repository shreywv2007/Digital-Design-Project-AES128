# Compile and run both testbenches with Icarus Verilog.
# Usage (from the repo root):  powershell -ExecutionPolicy Bypass -File sim\run_sim.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$iverilog = (Get-Command iverilog -ErrorAction SilentlyContinue).Source
if (-not $iverilog) { $iverilog = "C:\iverilog\bin\iverilog.exe" }
$vvp = Join-Path (Split-Path $iverilog) "vvp.exe"

$rtl = @(Get-ChildItem rtl -Recurse -Filter *.v |
         Where-Object { $_.Name -ne "de10_lite_top.v" } |
         ForEach-Object { $_.FullName })
New-Item -ItemType Directory -Force sim\out | Out-Null

$failed = $false
foreach ($tb in "tb_aes_cores", "tb_aes_top") {
    Write-Host "=== $tb ===" -ForegroundColor Cyan
    & $iverilog -g2005 -Wall -Wno-timescale -o "sim\out\$tb.vvp" -s $tb "tb\$tb.v" @rtl
    if ($LASTEXITCODE -ne 0) { $failed = $true; continue }
    $out = & $vvp -n "sim\out\$tb.vvp"
    $out | ForEach-Object { Write-Host $_ }
    if (-not ($out -match "ALL \d+ .* PASSED")) { $failed = $true }
}

# Also make sure the board wrapper compiles
Write-Host "=== de10_lite_top (compile only) ===" -ForegroundColor Cyan
& $iverilog -g2005 -Wall -Wno-timescale -o "sim\out\de10.vvp" -s de10_lite_top "rtl\top\de10_lite_top.v" @rtl
if ($LASTEXITCODE -ne 0) { $failed = $true } else { Write-Host "compiles OK" }

if ($failed) { Write-Host "SOME TESTS FAILED" -ForegroundColor Red; exit 1 }
Write-Host "ALL TESTBENCHES PASSED" -ForegroundColor Green
