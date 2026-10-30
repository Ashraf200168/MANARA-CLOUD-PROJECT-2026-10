@echo off
setlocal
title Manara - Schedule Backup Every 3 Days
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SCHEDULE-MANARA-BACKUP.ps1"
set "SCHEDULE_EXIT=%ERRORLEVEL%"
echo.
pause
exit /b %SCHEDULE_EXIT%
