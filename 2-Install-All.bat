@echo off
rem Reads the script explicitly as UTF-8, so Ukrainian text works
rem even if the .ps1 was saved without a BOM.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((Get-Content -LiteralPath '%~dp0InstallGroupApplications.ps1' -Encoding UTF8 -Raw)))"