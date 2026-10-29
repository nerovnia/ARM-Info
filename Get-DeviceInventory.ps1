#Requires -Version 5.1
<#
.SYNOPSIS
    Показує DeviceName, ProductInstanceID (ESET) та MAC-адреси, а потім
    по натисканню пробілу копіює їх по черзі до буфера обміну.

.NOTES
    Пробіл — скопіювати наступне значення, Esc — вихід.
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
    $idProblem = 'папку логів ESET не знайдено'
} else {
    $match = Get-ChildItem -LiteralPath $logDir -Filter 'trace*' -File `
                -ErrorAction SilentlyContinue -ErrorVariable gciErr |
        Sort-Object LastWriteTime |
        Select-String -Pattern $pattern -ErrorAction SilentlyContinue |
        Select-Object -Last 1

    if ($match)      { $productInstanceId = $match.Matches[0].Groups[1].Value }
    elseif ($gciErr) { $idProblem = 'немає доступу до логів, запустіть від адміністратора' }
    else             { $idProblem = 'не знайдено в логах' }
}

if (-not $macAddresses) { $macProblem = 'немає адаптерів з доступом до Інтернету' }

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
        Write-Host "(не знайдено: $($problems[$name]))" -ForegroundColor Yellow
    }
}
Write-Host ''
Write-Host 'Пробіл — скопіювати наступне значення до буфера обміну, Esc — вихід' -ForegroundColor DarkGray

# --- Копіювання по пробілу ---
$names = @($items.Keys)
$i = 0
while ($i -lt $names.Count) {
    $key = [Console]::ReadKey($true)
    if ($key.Key -eq [ConsoleKey]::Escape)   { break }
    if ($key.Key -ne [ConsoleKey]::Spacebar) { continue }

    $name  = $names[$i]
    $value = $items[$name]
    if ($value) {
        Set-Clipboard -Value $value
        Write-Host "$name скопійовано до буфера обміну" -ForegroundColor Green
    } else {
        Write-Host "$name не знайдено, пропущено" -ForegroundColor Yellow
    }
    $i++
}

if ($i -ge $names.Count) {
    Write-Host ''
    Write-Host 'Усі значення скопійовано.' -ForegroundColor DarkGray
}