@echo off
setlocal
set "APPDATA=%~dp0tools\godot\user_data"
if not exist "%APPDATA%" mkdir "%APPDATA%"
"%~dp0tools\godot\Godot_v4.7.2-stable_win64_console.exe" %*
exit /b %errorlevel%
