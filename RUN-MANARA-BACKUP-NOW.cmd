@echo off
title Manara Cloud - Backup Now
cd /d "C:\Users\shraf\Documents\Codex\2026-09-29\i\work\manara-cloud"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CD%\RUN-MANARA-BACKUP.ps1" -Force
echo.
pause
