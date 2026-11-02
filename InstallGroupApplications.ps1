#Requires -Version 5.1

param(
    # Text file with the list of installers. Default: installers.txt next to this script.
    [string]$ListFile = (Join-Path $PSScriptRoot 'installers.txt')
)

# List file format (save it as UTF-8 so Cyrillic paths are read correctly):
#   - One installer per line.
#   - Either just a path:          D:\Scratch\peazip-11.4.0.WIN64.exe
#   - Or Name | Path | Arguments:  Chrome | D:\Scratch\Chrome\ChromeSetup.exe | /silent /install
#     (Arguments are optional.)
#   - Empty lines and lines starting with # are ignored.

if (-not (Test-Path -LiteralPath $ListFile)) {
    Write-Host "List file not found: $ListFile" -ForegroundColor Red
    exit 1
}

$installers = foreach ($line in Get-Content -LiteralPath $ListFile -Encoding UTF8) {
    $line = $line.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { continue }

    $parts = $line -split '\|', 3 | ForEach-Object { $_.Trim().Trim('"') }

    if ($parts.Count -eq 1) {
        # Only a path: use the file name (without extension) as the display name.
        @{
            Name = [System.IO.Path]::GetFileNameWithoutExtension($parts[0])
            File = $parts[0]
            Args = ''
        }
    }
    else {
        @{
            Name = $parts[0]
            File = $parts[1]
            Args = if ($parts.Count -ge 3) { $parts[2] } else { '' }
        }
    }
}

if (-not $installers) {
    Write-Host "No installers found in $ListFile" -ForegroundColor Yellow
    exit 0
}

Write-Host "Loaded $(@($installers).Count) installer(s) from $ListFile" -ForegroundColor Gray

foreach ($app in $installers) {
    Write-Host "Installing $($app.Name)..." -ForegroundColor Cyan

    if (-not (Test-Path -LiteralPath $app.File) -and $app.File -ne 'msiexec.exe') {
        Write-Host "$($app.Name): file not found: $($app.File). Stopping." -ForegroundColor Red
        break
    }

    # Pass -ArgumentList only when Args has text; an empty value makes Start-Process fail.
    $params = @{
        FilePath = $app.File
        Wait     = $true
        PassThru = $true
    }
    if (-not [string]::IsNullOrWhiteSpace($app.Args)) {
        $params.ArgumentList = $app.Args
    }

    try {
        $process = Start-Process @params -ErrorAction Stop
    }
    catch {
        Write-Host "$($app.Name) could not be started: $($_.Exception.Message) Stopping." -ForegroundColor Red
        break
    }

    $code = $process.ExitCode

    if ($code -eq 0) {
        Write-Host "$($app.Name) installed successfully." -ForegroundColor Green
    }
    elseif ($code -eq 3010 -or $code -eq 1641) {
        Write-Host "$($app.Name) installed, reboot required." -ForegroundColor Yellow
    }
    elseif ($code -eq 1602) {
        Write-Host "$($app.Name) was cancelled. Stopping." -ForegroundColor Yellow
        break
    }
    else {
        Write-Host "$($app.Name) failed with exit code $code. Stopping." -ForegroundColor Red
        break
    }
}
