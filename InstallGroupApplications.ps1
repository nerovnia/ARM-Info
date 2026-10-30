#Requires -Version 5.1

# How it works:
# 
#       -Wait blocks until the installer exits, so the second install never starts early.
#       -PassThru returns the process object, so you can read ExitCode and stop if the first install failed. There’s no point installing the second app if it depends on the first one.
#
#   - Exit codes: 0 means success, 3010 means success but a reboot is needed, and 1641 means the installer started a reboot itself. Anything else is an error.
# 
# Silent switches depend on the installer type:
# 
#------------------------------------------------------------------------------------------
# Type	                |            Typical silent arguments
# ----------------------+------------------------------------------------------------------
# .msi	                |    msiexec.exe /i "file.msi" /qn /norestart
# .exe, InstallShield	|    /s or /S /v"/qn"
# .exe, Inno Setup	    |    /VERYSILENT /NORESTART
# .exe, NSIS	        |    /S (capital S)
#------------------------------------------------------------------------------------------


# Example:
#    @{ Name = 'First app';  File = 'msiexec.exe'; Args = '/i "D:\work\ESET\first.msi" /qn /norestart' }
#    @{ Name = 'Second app'; File = 'D:\work\ESET\second.exe'; Args = '/silent' }

$installers = @(
    @{ Name = 'First app';  File = 'msiexec.exe'; Args = '/i "D:\work\ESET\first.msi" /qn /norestart' }
    @{ Name = 'Second app'; File = 'D:\work\ESET\second.exe'; Args = '/silent' }
)

foreach ($app in $installers) {
    Write-Host "Installing $($app.Name)..." -ForegroundColor Cyan

    $process = Start-Process -FilePath $app.File -ArgumentList $app.Args -Wait -PassThru
    $code = $process.ExitCode

    if ($code -eq 0) {
        Write-Host "$($app.Name) installed successfully." -ForegroundColor Green
    }
    elseif ($code -eq 3010 -or $code -eq 1641) {
        Write-Host "$($app.Name) installed, reboot required." -ForegroundColor Yellow
    }
    else {
        Write-Host "$($app.Name) failed with exit code $code. Stopping." -ForegroundColor Red
        break
    }
}