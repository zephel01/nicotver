@echo off
rem nicotver installer for Windows (no admin required)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
echo.
pause
