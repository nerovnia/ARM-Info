#Requires -Version 5.1
<#
.SYNOPSIS
    Показує DeviceName, MAC-адреси та ProductInstanceID (ESET) і копіює їх
    до буфера обміну за натисканням клавіш.

.NOTES
    1 — DeviceName, 2 — MacAddresses, 3 — ProductInstanceID,
    Пробіл — усе разом, Esc — вихід.
    Запускайте від імені адміністратора, якщо папка логів ESET недоступна.
    Файл збережено в UTF-8 з BOM, щоб кирилиця коректно відображалась у PowerShell 5.1.
#>

$logDir  = 'C:\ProgramData\ESET\RemoteAdministrator\Agent\EraAgentApplicationData\Logs'
$pattern = 'InstallConfiguration: ProductInstanceID:\s*([A-Za-z0-9-]+)'

# 1. Ім'я пристрою (Параметри > Система > Про систему > Ім'я пристрою)
$deviceName = [System.Net.Dns]::GetHostName()

# 2. MAC-адреси адаптерів, які Windows позначає як підключені до Інтернету
$macAddresses = @(
    Get-NetConnectionProfile -ErrorAction SilentlyContinue |
        Where-Object { $_.IPv4Connectivity -eq 'Internet' -or $_.IPv6Connectivity -eq 'Internet' } |
        ForEach-Object { (Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue).MacAddress } |
        Where-Object { $_ } |
        ForEach-Object { $_ -replace '-', ':' } |
        Select-Object -Unique
) -join '; '

# 3. ESET ProductInstanceID з найновішого лог-файлу, де він є
$productInstanceId = $null
$idProblem         = $null

if (-not (Test-Path -LiteralPath $logDir)) {
    $idProblem = 'ESET log folder not found'
} else {
    $match = Get-ChildItem -LiteralPath $logDir -Filter 'trace*' -File `
                -ErrorAction SilentlyContinue -ErrorVariable gciErr |
        Sort-Object LastWriteTime |
        Select-String -Pattern $pattern -ErrorAction SilentlyContinue |
        Select-Object -Last 1

    if ($match)      { $productInstanceId = $match.Matches[0].Groups[1].Value }
    elseif ($gciErr) { $idProblem = 'Cannot access logs. Run as administrator.' }
    else             { $idProblem = 'Not found in logs' }
}

if (-not $macAddresses) { $macProblem = 'No adapters with Internet access' }

# --- Вивід ---
$items = [ordered]@{
    DeviceName        = $deviceName
    MacAddresses      = $macAddresses
    ProductInstanceID = $productInstanceId
}
$problems = @{ ProductInstanceID = $idProblem; MacAddresses = $macProblem }

Write-Host ''
foreach ($name in $items.Keys) {
    Write-Host ('{0,-17} : ' -f $name) -NoNewline
    if ($items[$name]) {
        Write-Host $items[$name] -ForegroundColor Cyan
    } else {
        Write-Host "(Not found: $($problems[$name]))" -ForegroundColor Yellow
    }
}
Write-Host ''
Write-Host '  1      — copy DeviceName'        -ForegroundColor DarkGray
Write-Host '  2      — copy MacAddresses'      -ForegroundColor DarkGray
Write-Host '  3      — copy ProductInstanceID' -ForegroundColor DarkGray
Write-Host '  Space — copy all'                -ForegroundColor DarkGray
Write-Host '  Esc    — Exit'                   -ForegroundColor DarkGray
Write-Host ''

# --- Копіювання за клавішами ---
$names = @($items.Keys)   # 1 = DeviceName, 2 = MacAddresses, 3 = ProductInstanceID

while ($true) {
    $key = [Console]::ReadKey($true)

    if ($key.Key -eq [ConsoleKey]::Escape) { break }

    if ($key.Key -eq [ConsoleKey]::Spacebar) {
        # Усі знайдені значення, у тому ж вигляді, що й на екрані
        $lines = foreach ($name in $names) {
            if ($items[$name]) { '{0,-17} : {1}' -f $name, $items[$name] }
        }
        if ($lines) {
            Set-Clipboard -Value ($lines -join "`r`n")
            Write-Host 'All information has been copied to the clipboard.' -ForegroundColor Green
        } else {
            Write-Host 'No data to copy' -ForegroundColor Yellow
        }
        continue
    }

    # Цифри 1-3 (основна клавіатура або NumPad)
    $index = '123'.IndexOf($key.KeyChar)
    if ($index -lt 0) { continue }

    $name  = $names[$index]
    $value = $items[$name]
    if ($value) {
        Set-Clipboard -Value $value
        Write-Host "$name Copied to the clipboard" -ForegroundColor Green
    } else {
        Write-Host "$name nothing was found, so nothing was copied." -ForegroundColor Yellow
    }
}