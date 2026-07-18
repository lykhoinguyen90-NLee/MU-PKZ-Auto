$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Source = Join-Path $Root 'MU-PKZ_AutoHunt.ahk'
$Icon = Join-Path $Root 'MU-PKZ_AutoHunt.ico'
$Dist = Join-Path $Root 'dist'
$Output = Join-Path $Dist 'MU-PKZ_AutoHunt.exe'

$CompilerCandidates = @(
    'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe',
    'C:\Program Files (x86)\AutoHotkey\Compiler\Ahk2Exe.exe'
)
$Compiler = $CompilerCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $Compiler) {
    throw 'Ahk2Exe.exe was not found. Install AutoHotkey v1.1 first.'
}

$CompilerDir = Split-Path -Parent $Compiler
$Unicode32 = Join-Path $CompilerDir 'Unicode 32-bit.bin'
if (-not (Test-Path -LiteralPath $Unicode32)) {
    throw 'Unicode 32-bit.bin was not found in the Compiler directory.'
}
if (-not (Test-Path -LiteralPath $Source)) {
    throw "Missing source: $Source"
}
if (-not (Test-Path -LiteralPath $Icon)) {
    throw "Missing icon: $Icon"
}

New-Item -ItemType Directory -Force -Path $Dist | Out-Null

$FullDist = [IO.Path]::GetFullPath($Dist).TrimEnd('\') + '\'
$FullOutput = [IO.Path]::GetFullPath($Output)
if (-not $FullOutput.StartsWith($FullDist, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to replace an output outside the dist directory.'
}
if (Test-Path -LiteralPath $Output) {
    Remove-Item -LiteralPath $Output -Force
}

& $Compiler /in $Source /out $Output /bin $Unicode32 /icon $Icon
$deadline = [DateTime]::UtcNow.AddSeconds(10)
while (-not (Test-Path -LiteralPath $Output) -and [DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Milliseconds 100
}
if (-not (Test-Path -LiteralPath $Output)) {
    throw 'Ahk2Exe did not create the output file.'
}

& $Output --syntax-check
$SelfTest = Join-Path $env:TEMP ('mupkz_macro_selftest_' + [Guid]::NewGuid().ToString('N') + '.txt')
& $Output "--macro-self-test=$SelfTest"
$testDeadline = [DateTime]::UtcNow.AddSeconds(5)
while (-not (Test-Path -LiteralPath $SelfTest) -and [DateTime]::UtcNow -lt $testDeadline) {
    Start-Sleep -Milliseconds 100
}
if (-not (Test-Path -LiteralPath $SelfTest)) {
    throw 'Macro self-test output was not created.'
}
$TestText = Get-Content -LiteralPath $SelfTest -Raw -Encoding UTF8
$TestText
if ($TestText -match '(?m)^FAIL') {
    throw 'Macro self-test failed.'
}

$File = Get-Item -LiteralPath $Output
$Hash = Get-FileHash -LiteralPath $Output -Algorithm SHA256
Write-Host ('Build OK: {0} ({1:N0} bytes)' -f $File.FullName, $File.Length) -ForegroundColor Green
Write-Host ('SHA-256: {0}' -f $Hash.Hash) -ForegroundColor Cyan
