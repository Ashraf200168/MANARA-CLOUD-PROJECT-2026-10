@echo off
setlocal
cd /d "%~dp0"
title Manara Full Hands-Off Setup
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CD%\SETUP-MANARA-FULL-HANDSOFF.ps1"
endlocal
