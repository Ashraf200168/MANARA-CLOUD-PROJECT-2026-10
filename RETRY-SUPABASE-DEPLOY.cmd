@echo off
setlocal
title Manara Cloud - Retry Supabase Deployment
cd /d "C:\Users\shraf\Documents\Codex\2026-09-29\i\work\manara-cloud"
set "SUPABASE_HOME=%CD%\.tools\supabase-home"
set "STATUS=%CD%\.tools\supabase-deploy-status.log"

> "%STATUS%" echo RETRY_STARTED %DATE% %TIME%
>> "%STATUS%" echo LINK_ALREADY_OK

echo.
echo [1/2] Retrying the database migration...
call node_modules\.bin\supabase.cmd db push --linked --agent no --output-format text
if errorlevel 1 goto :db_failed
>> "%STATUS%" echo DATABASE_OK

echo.
echo [2/2] Deploying the Manara API Edge Function...
call node_modules\.bin\supabase.cmd functions deploy manara-api --project-ref zgzqoxxhiwrzxsgoqyyb --no-verify-jwt --agent no --output-format text
if errorlevel 1 goto :function_failed
>> "%STATUS%" echo FUNCTION_OK
>> "%STATUS%" echo COMPLETE

echo.
echo Deployment completed successfully.
echo Tell Codex: deployment complete
pause
exit /b 0

:db_failed
>> "%STATUS%" echo DATABASE_FAILED
echo Database migration failed again. Supabase may still be experiencing the Management API incident.
echo Keep this window open and tell Codex: database failed
pause
exit /b 1

:function_failed
>> "%STATUS%" echo FUNCTION_FAILED
echo Database completed, but function deployment failed.
echo Keep this window open and tell Codex: function failed
pause
exit /b 1
