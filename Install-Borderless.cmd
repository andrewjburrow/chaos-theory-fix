@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Fix-ChaosTheory.ps1" -Borderless
if errorlevel 1 echo Installation stopped. See the message above.
pause
