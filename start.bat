@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem UTF-8 console so Ukrainian menu text displays correctly
rem (save this .bat as UTF-8 without BOM if you use Cyrillic in it).
chcp 65001 >nul
title PowerShell Script Launcher

rem ================================================================
rem  MENU ENTRIES
rem  call :AddItem "file.ps1" "Menu name" "Description" "optional args"
rem  Script files are looked up in the same folder as this .bat.
rem  Avoid "!" in names/descriptions (delayed expansion eats it).
rem ================================================================
set /a N=0
call :AddItem "preinstallWindows.ps1" "Pre-install Windows" "Prepares a fresh Windows installation"
call :AddItem "installApps.ps1"       "Install applications" "Installs the standard set of programs"
call :AddItem "cleanup.ps1"           "Cleanup"              "Removes temporary files and caches"
rem Example with parameters passed to the script:
rem call :AddItem "backup.ps1" "Backup" "Copies user folders to D:\Backup" "-Target 'D:\Backup' -Verbose"

:menu
cls
echo ==================================================
echo              PowerShell Script Launcher
echo ==================================================
echo.
for /L %%i in (1,1,!N!) do (
    echo   [%%i] !NAME[%%i]!
    echo        !DESC[%%i]!
    if not exist "%~dp0!FILE[%%i]!" echo        ^(file not found: !FILE[%%i]!^)
    echo.
)
echo   [0] Exit
echo.
set "CHOICE="
set /p "CHOICE=Select an option: "

if not defined CHOICE goto menu
if "!CHOICE!"=="0" goto end
if not defined FILE[!CHOICE!] (
    echo.
    echo Invalid choice: !CHOICE!
    pause
    goto menu
)

set "SCRIPT=%~dp0!FILE[%CHOICE%]!"
set "SARGS=!ARGS[%CHOICE%]!"

if not exist "!SCRIPT!" (
    echo.
    echo File not found: !SCRIPT!
    pause
    goto menu
)

rem Escape single quotes for the PowerShell string (e.g. paths like "Об'єкти")
set "PSPATH=!SCRIPT:'=''!"

cls
echo Running: !NAME[%CHOICE%]!
echo File:    !SCRIPT!
if defined SARGS echo Args:    !SARGS!
echo --------------------------------------------------
echo.

rem Reads the script explicitly as UTF-8, so Ukrainian text works
rem even if the .ps1 was saved without a BOM.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((Get-Content -LiteralPath '!PSPATH!' -Encoding UTF8 -Raw))) !SARGS!"
set "RC=!ERRORLEVEL!"

echo.
echo --------------------------------------------------
echo Finished with exit code !RC!
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