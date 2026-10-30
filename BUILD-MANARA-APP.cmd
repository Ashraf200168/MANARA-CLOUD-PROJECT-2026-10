@echo off
setlocal
title Manara - Build Latest Android Update
call "%~dp0BUILD-MANARA-BOOK-ROADMAP.cmd"
exit /b %ERRORLEVEL%
