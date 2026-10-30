@echo off
setlocal
title Manara - Publish Book Roadmap API
cd /d "%~dp0"
if not exist ".tools" mkdir ".tools"
set "SUPABASE_HOME=%CD%\.tools\supabase-home"
echo [1/3] Checking the existing Supabase login...
call node_modules\.bin\supabase.cmd projects list --agent no --output-format text >nul 2>&1
if errorlevel 1 (
  echo Complete the secure login in your browser. Do not send keys in chat.
  call node_modules\.bin\supabase.cmd login --agent no --output-format text
  if errorlevel 1 goto :failed
)
echo.
echo [2/3] Applying the book roadmap migration...
call node_modules\.bin\supabase.cmd db push --linked --agent no --output-format text
if errorlevel 1 goto :failed
echo.
echo [3/3] Deploying the API with book roadmaps...
call node_modules\.bin\supabase.cmd functions deploy manara-api --project-ref zgzqoxxhiwrzxsgoqyyb --no-verify-jwt --use-api --agent no --output-format text
if errorlevel 1 goto :failed
echo.
echo MANARA BOOK ROADMAP API PUBLISHED SUCCESSFULLY
echo Now build the Android update with BUILD-MANARA-APP.cmd.
echo Website package: Manara-Cloudflare-Question-Editor-v1.9.1.zip
pause
exit /b 0
:failed
echo.
echo PUBLISH FAILED. Keep this window open and send only the error message.
pause
exit /b 1
