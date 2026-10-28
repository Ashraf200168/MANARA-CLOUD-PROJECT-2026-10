@echo off
setlocal EnableExtensions
set "PROJECT=%~dp0"
set "PROJECT_SAFE=%PROJECT:~0,-1%"

call :restore "RUN-MANARA-MAINTENANCE.ps1"
if errorlevel 1 exit /b 21
call :restore "SYNC-MANARA-PUBLIC-GITHUB.ps1"
if errorlevel 1 exit /b 22

if /i "%~1"=="--repair-only" exit /b 0

powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "%PROJECT%RUN-MANARA-MAINTENANCE.ps1"
exit /b %ERRORLEVEL%

:restore
set "TARGET=%~1"
if exist "%PROJECT%%TARGET%" exit /b 0

for %%R in (HEAD HEAD~1 HEAD~2 HEAD~3 HEAD~4 HEAD~5 HEAD~6 HEAD~7 HEAD~8 HEAD~9 HEAD~10) do (
  git -c "safe.directory=%PROJECT_SAFE%" -C "%PROJECT%" show %%R:%TARGET% > "%PROJECT%%TARGET%.recovering" 2>nul
  if not errorlevel 1 (
    for %%S in ("%PROJECT%%TARGET%.recovering") do if %%~zS GTR 100 (
      move /y "%PROJECT%%TARGET%.recovering" "%PROJECT%%TARGET%" >nul
      exit /b 0
    )
  )
  if exist "%PROJECT%%TARGET%.recovering" del /q "%PROJECT%%TARGET%.recovering" >nul 2>&1
)

echo MANARA SELF-REPAIR FAILED: %TARGET% could not be recovered from Git history.
exit /b 1
