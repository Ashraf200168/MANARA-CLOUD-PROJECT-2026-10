@echo off
setlocal
title Manara Backup Setup
cd /d "%~dp0"

echo Starting Manara automatic encrypted backup setup...
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0SETUP-MANARA-AUTOMATIC-BACKUP.ps1"

if errorlevel 1 (
  echo.
  echo The setup returned an error. Keep this window open and send Codex only the error message.
  echo Never send a Supabase secret key or backup password.
  pause
)
endlocal
