@echo off
setlocal

rem ---------------------------------------------------------------------------
rem free_space for ioFTPD 8.1.0
rem Edit the settings below. The PowerShell script must be beside this BAT file.
rem ---------------------------------------------------------------------------
set "INCOMING_PATH=D:\ioFTPD\FTP-ROOT-DIR\ISO"
set "MINIMUM_FREE_MB=1000"
set "SECTION_NAME=ISO"
set "IOFTPD_LOG=C:\ioFTPD\logs\ioFTPD.log"

rem Safe test mode: no directories are deleted.
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass ^
  -File "%~dp0free_space_ioftpd_8.1.ps1" ^
  -IncomingPath "%INCOMING_PATH%" ^
  -MinimumFreeMB %MINIMUM_FREE_MB% ^
  -SectionName "%SECTION_NAME%" ^
  -IoFtpdLog "%IOFTPD_LOG%" ^
  -VipDirectories "TEMP" "PRE" ^
  -VipGroups "RiSC" "FLT"

rem After verifying test output, replace the command above with the same command
rem plus these two switches on its final line:
rem   -Delete -Announce

set "SCRIPT_EXIT_CODE=%ERRORLEVEL%"
endlocal & exit /b %SCRIPT_EXIT_CODE%
