#Requires -Version 5.1

$installers = @(
    @{ Name = 'First app'; File = 'D:\Install\VeraCrypt.Portable.1.26.29.exe' }
    @{ Name = 'Second app'; File = 'D:\Install\VeraCrypt.Portable.1.26.29.exe' }
)

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