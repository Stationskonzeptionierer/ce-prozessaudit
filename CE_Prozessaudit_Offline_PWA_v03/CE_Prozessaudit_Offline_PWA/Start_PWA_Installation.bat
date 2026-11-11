@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start_PWA_Installation.ps1"
echo.
echo Falls ein Fehler angezeigt wurde, bitte Fehlermeldung notieren.
pause
