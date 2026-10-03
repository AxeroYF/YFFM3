@echo off
setlocal
cd /d "%~dp0"
set "APPDATA=%~dp0tools\godot\user_data"
if not exist "%APPDATA%" mkdir "%APPDATA%"
start "" "%~dp0tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0player-card-demo" --log-file "%~dp0player-card-demo\artifacts\play.log"
