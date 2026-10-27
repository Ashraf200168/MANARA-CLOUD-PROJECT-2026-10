@echo off
setlocal
title Manara Cloud - Deploy Supabase Backend
cd /d "C:\Users\shraf\Documents\Codex\2026-09-29\i\work\manara-cloud"
set "SUPABASE_HOME=%CD%\.tools\supabase-home"
set "STATUS=%CD%\.tools\supabase-deploy-status.log"

> "%STATUS%" echo STARTED %DATE% %TIME%
echo.
echo [1/3] Linking Manara Cloud to Supabase...
echo If asked, type the database password you chose when creating the project.
call node_modules\.bin\supabase.cmd link --project-ref zgzqoxxhiwrzxsgoqyyb --agent no --output-format text
if errorlevel 1 goto :link_failed
>> "%STATUS%" echo LINK_OK

echo.
echo [2/3] Applying the database migration...
call node_modules\.bin\supabase.cmd db push --linked --agent no --output-format text
if errorlevel 1 goto :db_failed
>> "%STATUS%" echo DATABASE_OK

echo.
echo [3/3] Deploying the Manara API Edge Function...
call node_modules\.bin\supabase.cmd functions deploy manara-api --project-ref zgzqoxxhiwrzxsgoqyyb --no-verify-jwt --agent no --output-format text
if errorlevel 1 goto :function_failed
>> "%STATUS%" echo FUNCTION_OK
>> "%STATUS%" echo COMPLETE

echo.
echo Deployment completed successfully.
echo Tell Codex: deployment complete
pause
exit /b 0

:link_failed
>> "%STATUS%" echo LINK_FAILED
echo Linking failed. Keep this window open and tell Codex: link failed
pause
exit /b 1

:db_failed
>> "%STATUS%" echo DATABASE_FAILED
echo Database migration failed. Keep this window open and tell Codex: database failed
pause
exit /b 1

:function_failed
>> "%STATUS%" echo FUNCTION_FAILED
echo Function deployment failed. Keep this window open and tell Codex: function failed
pause
exit /b 1
