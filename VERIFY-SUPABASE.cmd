@echo off
title Manara Cloud - Verify Supabase Login
cd /d "C:\Users\shraf\Documents\Codex\2026-09-29\i\work\manara-cloud"
set "SUPABASE_HOME=%CD%\.tools\supabase-home"
echo Verifying Supabase login...
call node_modules\.bin\supabase.cmd projects list --agent no --output-format text > ".tools\supabase-projects.log" 2>&1
if errorlevel 1 (
  echo Verification failed. Keep this window open and tell Codex.
) else (
  echo Verification succeeded. Tell Codex: verification complete
)
pause
