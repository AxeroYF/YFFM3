@echo off
setlocal
cd /d "%~dp0"
set "APPDATA=%~dp0tools\godot\user_data"
if not exist "%APPDATA%" mkdir "%APPDATA%"
"%~dp0tools\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0space-football-demo" --log-file "%~dp0space-football-demo\artifacts\server.log" -- --server --port=28765
