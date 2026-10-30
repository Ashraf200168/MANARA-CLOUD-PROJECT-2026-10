@echo off
setlocal
title Manara - Build Book Roadmap Android Update
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0BUILD-MANARA-BOOK-ROADMAP.ps1"
set "BUILD_EXIT=%ERRORLEVEL%"
echo.
if not "%BUILD_EXIT%"=="0" echo Build failed. Keep this window open and send only the error message.
pause
exit /b %BUILD_EXIT%
