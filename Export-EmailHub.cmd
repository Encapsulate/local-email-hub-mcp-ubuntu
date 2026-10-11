@echo off
title Export Portable Email Hub
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Export-EmailHub.ps1"
echo.
pause
