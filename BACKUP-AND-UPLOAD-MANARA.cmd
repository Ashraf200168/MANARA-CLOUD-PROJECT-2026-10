@echo off
setlocal
title Manara - Backup and Upload Latest Update
if /i "%~1"=="--scheduled" goto scheduled
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0BACKUP-AND-UPLOAD-MANARA.ps1"
set "UPLOAD_EXIT=%ERRORLEVEL%"
echo.
if not "%UPLOAD_EXIT%"=="0" echo The operation did not finish. Keep this window open and send only the error.
pause
exit /b %UPLOAD_EXIT%

:scheduled
powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0BACKUP-AND-UPLOAD-MANARA.ps1" -Scheduled
exit /b %ERRORLEVEL%
