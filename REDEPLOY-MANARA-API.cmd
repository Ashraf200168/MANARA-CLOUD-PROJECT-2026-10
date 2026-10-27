@echo off
setlocal
title Manara Cloud - Migrate and Redeploy API
cd /d "C:\Users\shraf\Documents\Codex\2026-09-29\i\work\manara-cloud"
set "SUPABASE_HOME=%CD%\.tools\supabase-home"
set "STATUS=%CD%\.tools\manara-api-redeploy-status.log"

> "%STATUS%" echo STARTED %DATE% %TIME%
echo [1/2] Applying pending database migrations...
call node_modules\.bin\supabase.cmd db push --linked --agent no --output-format text
if errorlevel 1 goto :migration_failed
>> "%STATUS%" echo DATABASE_OK

echo.
echo [2/2] Redeploying the Manara API...
call node_modules\.bin\supabase.cmd functions deploy manara-api --project-ref zgzqoxxhiwrzxsgoqyyb --no-verify-jwt --agent no --output-format text
if errorlevel 1 goto :failed

>> "%STATUS%" echo FUNCTION_OK
>> "%STATUS%" echo COMPLETE
echo.
echo Manara API redeployed successfully.
echo Tell Codex: API redeployed
pause
exit /b 0

:failed
>> "%STATUS%" echo FUNCTION_FAILED
echo Function redeployment failed. Keep this window open and tell Codex: redeploy failed
pause
exit /b 1

:migration_failed
>> "%STATUS%" echo DATABASE_FAILED
echo Database migration failed. The API was not redeployed, so its schema stays compatible.
echo Keep this window open and tell Codex: migration failed
pause
exit /b 1
