@echo off
title Manara Cloud - Open Encrypted Backup
cd /d "C:\Users\shraf\Documents\Codex\2026-09-29\i\work\manara-cloud"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CD%\RESTORE-MANARA-BACKUP.ps1"
echo.
pause
