@echo off
title Manara Cloud - Supabase Login
cd /d "C:\Users\shraf\Documents\Codex\2026-09-29\i\work\manara-cloud"
set "SUPABASE_HOME=%CD%\.tools\supabase-home"
echo.
echo Manara Cloud - Supabase secure login
echo Press Enter when Supabase asks, then approve the login in your browser.
echo Do not share any password or token in chat.
echo.
call node_modules\.bin\supabase.cmd login --agent no --output-format text
echo.
echo Login command finished. Keep this window open and tell Codex: login complete
pause
