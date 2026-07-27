@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "SECTIONS=%SCRIPT_DIR%dzsbot-df-sections.tsv"
set "OUTPUT=C:\ioFTPD\logs\dzsbot-df.tsv"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%dzsbot_df.ps1" -SectionsFile "%SECTIONS%" -OutputFile "%OUTPUT%"

endlocal
