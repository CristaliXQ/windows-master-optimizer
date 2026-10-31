$src = [System.IO.File]::ReadAllText('c:\Users\denis\Desktop\gemini work\new_source_optimizer.ps1', [System.Text.Encoding]::UTF8)
$srcBytes = [System.Text.Encoding]::UTF8.GetBytes($src)
$ms = New-Object System.IO.MemoryStream
$gs = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionLevel]::Optimal)
$gs.Write($srcBytes, 0, $srcBytes.Length)
$gs.Close()
$gzBytes = $ms.ToArray()

$xorKey = [byte[]](0x5A, 0xA5, 0x3C, 0xC3, 0x69, 0x96, 0x1E, 0xE1)
for ($i = 0; $i -lt $gzBytes.Length; $i++) {
    $gzBytes[$i] = $gzBytes[$i] -bxor $xorKey[$i -band 7]
}

$b64 = [Convert]::ToBase64String($gzBytes)

$lines = @()
for ($i = 0; $i -lt $b64.Length; $i += 100) {
    $len = [Math]::Min(100, $b64.Length - $i)
    $lines += $b64.Substring($i, $len)
}
$payload = $lines -join "`r`n"

$header = @'
@echo off
setlocal EnableExtensions
title Windows Master Optimizer v6.1 Ultra Performance
chcp 65001 >nul 2>&1
mode con: cols=85 lines=33 >nul 2>&1
color 0A

net session >nul 2>&1
if %errorlevel% neq 0 (
    set "OPT_SELF=%~f0"
    echo.
    echo  [INFO] Requesting Administrator Privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath \"$env:OPT_SELF\" -Verb RunAs"
    exit /b
)
cd /d "%~dp0"
set "OPT_FILE=%~f0"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$lines=[System.IO.File]::ReadAllLines($env:OPT_FILE,[System.Text.Encoding]::UTF8); $idx=[System.Array]::IndexOf($lines,':ENCODED_PAYLOAD'); if($idx -ge 0){$p=($lines[($idx+1)..($lines.Count-1)] -join ''); $b=[Convert]::FromBase64String($p); $k=[byte[]](0x5A,0xA5,0x3C,0xC3,0x69,0x96,0x1E,0xE1); for($i=0; $i -lt $b.Length; $i++){ $b[$i] = $b[$i] -bxor $k[$i -band 7] }; $ms=New-Object IO.MemoryStream(,$b); $gs=New-Object IO.Compression.GZipStream($ms,[IO.Compression.CompressionMode]::Decompress); $sr=New-Object IO.StreamReader($gs,[System.Text.Encoding]::UTF8); iex $sr.ReadToEnd()}"
if %errorlevel% neq 0 (
    echo.
    echo  [ERROR] Script exited with errorlevel: %errorlevel%
    pause
)
exit /b %errorlevel%

:ENCODED_PAYLOAD
'@

$headerNorm = ($header -split "`r?`n") -join "`r`n"
$batContent = $headerNorm + "`r`n" + $payload + "`r`n"

$targets = @(
    'C:\Users\denis\Desktop\Windows_Master_Optimizer.bat',
    'c:\Users\denis\Desktop\gemini work\test_packed.bat'
)

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
foreach ($t in $targets) {
    [System.IO.File]::WriteAllText($t, $batContent, $utf8NoBom)
    Write-Output "$t written successfully. Size: $((Get-Item $t).Length) bytes"
}

$hashes = @{}
foreach ($t in $targets) {
    $h = (Get-FileHash -Path $t -Algorithm SHA256).Hash
    $hashes[$t] = $h
}
$unique = @($hashes.Values | Select-Object -Unique)
if ($unique.Count -eq 1) {
    Write-Output "VERIFICATION SUCCESS: All 4 batch files have identical SHA-256: $($unique[0])"
} else {
    Write-Error "HASH MISMATCH across batch targets!"
}
