@echo off
echo Doing some work...
REM powershell  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
powershell -NoProfile -ExecutionPolicy Bypass -File "ARM-Info.ps1"
pause




