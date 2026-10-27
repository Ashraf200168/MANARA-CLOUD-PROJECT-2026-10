@echo off
setlocal
title Manara - Publish Mobile API Update
cd /d "C:\Users\shraf\Documents\Codex\2026-09-29\i\work\manara-cloud"
set "SUPABASE_HOME=%CD%\.tools\supabase-home"
> ".tools\publish-mobile-status.log" echo RUNNING

echo Checking the Supabase login...
call node_modules\.bin\supabase.cmd projects list --agent no --output-format text >nul 2>&1
if errorlevel 1 (
  echo A secure Supabase login is required.
  echo Approve the login in your browser. Do not share the token with anyone.
  call node_modules\.bin\supabase.cmd login --agent no --output-format text
  if errorlevel 1 goto :failed
)

echo.
echo [1/2] Applying the student-profile and certificate database migrations...
call node_modules\.bin\supabase.cmd db push --linked --agent no --output-format text
if errorlevel 1 goto :failed

echo.
echo [2/2] Publishing the student-profile, exam-review, certificate, and Manara API update...
call node_modules\.bin\supabase.cmd functions deploy manara-api --project-ref zgzqoxxhiwrzxsgoqyyb --no-verify-jwt --agent no --output-format text
if errorlevel 1 goto :failed

echo.
echo MANARA MOBILE API UPDATE PUBLISHED SUCCESSFULLY
echo You may now install and test Manara-App-v1.4.1-full-sheikh-exam-arm64.apk
> ".tools\publish-mobile-status.log" echo SUCCESS
pause
exit /b 0

:failed
echo.
echo The update was not published. Keep this window open and send the error to Codex.
> ".tools\publish-mobile-status.log" echo FAILED
pause
exit /b 1
