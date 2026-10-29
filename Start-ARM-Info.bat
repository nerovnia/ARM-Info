@echo off
echo Doing some work...
REM powershell  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
powershell -NoProfile -ExecutionPolicy Bypass -File "Get-DeviceInventory.ps1"

pause




