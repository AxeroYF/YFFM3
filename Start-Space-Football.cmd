@echo off
setlocal
cd /d "%~dp0"
set "APPDATA=%~dp0tools\godot\user_data"
if not exist "%APPDATA%" mkdir "%APPDATA%"
rem Development entry: run the current Godot project without exporting a client.
start "" "%~dp0tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0space-football-demo" --log-file "%~dp0space-football-demo\artifacts\play.log"
