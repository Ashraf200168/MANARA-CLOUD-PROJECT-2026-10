@echo off
setlocal EnableExtensions
title Manara Cloud - Allow Cloudflare Pages
cd /d "C:\Users\shraf\Documents\Codex\2026-09-29\i\work\manara-cloud"
set "SUPABASE_HOME=%CD%\.tools\supabase-home"

echo Enter the exact Cloudflare Pages URL, for example:
echo https://manara-cloud-preview.pages.dev
echo.
set /p "PAGES_URL=Cloudflare URL: "
if not defined PAGES_URL goto :missing

for /f "usebackq delims=" %%U in (`powershell -NoProfile -Command "$value=$env:PAGES_URL; $match=[regex]::Match($value,'https://[a-z0-9-]+\.pages\.dev','IgnoreCase'); if($match.Success){$match.Value.TrimEnd('/')}"`) do set "PAGES_URL=%%U"
echo %PAGES_URL%| findstr /R /I "^https://[a-z0-9-][a-z0-9-]*\.pages\.dev$" >nul || goto :invalid

echo.
echo Allowing %PAGES_URL% to call the Manara API...
call node_modules\.bin\supabase.cmd secrets set "ALLOWED_ORIGINS=%PAGES_URL%,http://localhost:8788" --project-ref zgzqoxxhiwrzxsgoqyyb
if errorlevel 1 goto :failed

echo.
echo Cloudflare origin saved successfully.
echo Tell Codex the exact URL: %PAGES_URL%
pause
exit /b 0

:missing
echo No URL was entered. Nothing changed.
pause
exit /b 1

:invalid
echo The entered text does not contain a valid https://PROJECT.pages.dev address.
echo Nothing changed. Copy the address from the browser address bar and try again.
pause
exit /b 1

:failed
echo Failed to save the Cloudflare origin. Keep this window open and send the error to Codex.
pause
exit /b 1
