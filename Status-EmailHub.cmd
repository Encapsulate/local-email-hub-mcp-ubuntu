@echo off
title Local Email Hub Status
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Status-EmailHub.ps1"
echo.
pause
