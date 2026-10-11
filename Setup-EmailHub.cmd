@echo off
title Local Email Hub Setup
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-EmailHub.ps1"
echo.
pause

