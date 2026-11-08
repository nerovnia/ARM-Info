@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem UTF-8 console so Ukrainian menu text displays correctly
rem (save this .bat as UTF-8 without BOM if you use Cyrillic in it).
chcp 65001 >nul
title PowerShell Script Launcher

rem ---- ANSI colors (Windows 10/11) ----
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "C_RESET=%ESC%[0m"
set "C_TITLE=%ESC%[96m"
set "C_LINE=%ESC%[36m"
set "C_NUM=%ESC%[93m"
set "C_NAME=%ESC%[97m"
set "C_DESC=%ESC%[90m"
set "C_OK=%ESC%[92m"
set "C_ERR=%ESC%[91m"
set "C_PROMPT=%ESC%[92m"

rem ================================================================
rem  MENU ENTRIES
rem  call :AddItem "file.ps1" "Menu name" "Description" "optional args"
rem  Script files are looked up in the same folder as this .bat.
rem  Avoid "!" in names/descriptions (delayed expansion eats it).
rem ================================================================
set /a N=0
call :AddItem "preinstallWindows.ps1" "Pre-install Windows" "Prepares a fresh Windows installation"
call :AddItem "InstallGroupApplications.ps1"       "Install applications" "Installs the standard set of programs"
call :AddItem "Get-DeviceInventory.ps1"           "Get info about workstation"              "Get MAC Address, Computer Name, ESET License ID"
call :AddItem "GetFlashStickInfo.ps1"           "Get info about USB Flash"              "Get info about USB Flash-Sticks"
rem Example with parameters passed to the script:
rem call :AddItem "backup.ps1" "Backup" "Copies user folders to D:\Backup" "-Target 'D:\Backup' -Verbose"

:menu
cls
echo !C_LINE!===============================================================!C_RESET!
echo !C_TITLE!           Enterprise Application Package Installer !C_RESET!
echo !C_TITLE!                             (2026)!C_RESET!
echo !C_LINE!===============================================================!C_RESET!
echo.
for /L %%i in (1,1,!N!) do (
    echo   !C_NUM![%%i]!C_RESET! !C_NAME!!NAME[%%i]!!C_RESET!
    echo        !C_DESC!!DESC[%%i]!!C_RESET!
    if not exist "%~dp0!FILE[%%i]!" echo        !C_ERR!^(file not found: !FILE[%%i]!^)!C_RESET!
    echo.
)
echo   !C_ERR![0] Exit!C_RESET!
echo.
set "CHOICE="
set /p "CHOICE=!C_PROMPT!Select an option: !C_RESET!"

if not defined CHOICE goto menu
if "!CHOICE!"=="0" goto end
if not defined FILE[!CHOICE!] (
    echo.
    echo !C_ERR!Invalid choice: !CHOICE!!C_RESET!
    pause
    goto menu
)

set "SCRIPT=%~dp0!FILE[%CHOICE%]!"
set "SARGS=!ARGS[%CHOICE%]!"

if not exist "!SCRIPT!" (
    echo.
    echo !C_ERR!File not found: !SCRIPT!!C_RESET!
    pause
    goto menu
)

rem Escape single quotes for the PowerShell string (e.g. paths like "Об'єкти")
set "PSPATH=!SCRIPT:'=''!"

cls
echo !C_TITLE!Running:!C_RESET! !C_NAME!!NAME[%CHOICE%]!!C_RESET!
echo !C_DESC!File:    !SCRIPT!!C_RESET!
if defined SARGS echo !C_DESC!Args:    !SARGS!!C_RESET!
echo !C_LINE!--------------------------------------------------!C_RESET!
echo.

rem Reads the script explicitly as UTF-8, so Ukrainian text works
rem even if the .ps1 was saved without a BOM.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((Get-Content -LiteralPath '!PSPATH!' -Encoding UTF8 -Raw))) !SARGS!"
set "RC=!ERRORLEVEL!"

echo.
echo !C_LINE!--------------------------------------------------!C_RESET!
if "!RC!"=="0" (
    echo !C_OK!Finished successfully ^(exit code 0^)!C_RESET!
) else (
    echo !C_ERR!Finished with exit code !RC!!C_RESET!
)
pause
goto menu

:end
endlocal
exit /b 0

rem ================================================================
:AddItem
set /a N+=1
set "FILE[%N%]=%~1"
set "NAME[%N%]=%~2"
set "DESC[%N%]=%~3"
set "ARGS[%N%]=%~4"
exit /b