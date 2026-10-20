@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Fix-ChaosTheory.ps1" -Undo
if errorlevel 1 echo Restore stopped. See the message above.
pause
