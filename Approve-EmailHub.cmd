@echo off
title Email Hub - Human Send Approval
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Approve-EmailHub.ps1"
echo.
pause

