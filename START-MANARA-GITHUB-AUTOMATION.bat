@echo off
title Manara GitHub Automation Setup
cd /d "%~dp0"
echo Starting Manara GitHub automation setup...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SETUP-MANARA-GITHUB-AUTOMATION.ps1"

