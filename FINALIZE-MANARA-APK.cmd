@echo off
setlocal
title Manara - Verify and Save Completed APK
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0BUILD-MANARA-BOOK-ROADMAP.ps1" -FinalizeOnly
set "FINALIZE_EXIT=%ERRORLEVEL%"
echo.
if not "%FINALIZE_EXIT%"=="0" echo Keep this window open and send only the error message.
pause
exit /b %FINALIZE_EXIT%
