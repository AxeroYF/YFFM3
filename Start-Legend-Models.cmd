@echo off
setlocal
cd /d "%~dp0"
set "APPDATA=%~dp0tools\godot\user_data"
if not exist "%APPDATA%" mkdir "%APPDATA%"
rem Open the live development project's complete legend model gallery.
start "" "%~dp0tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0space-football-demo" --log-file "%~dp0space-football-demo\artifacts\legend-gallery.log" -- --models
