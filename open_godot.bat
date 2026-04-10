@echo off
REM Launches Godot editor with release keystore env vars set.

cd /d "%~dp0"

set "GODOT_ANDROID_KEYSTORE_DEBUG_PATH=%USERPROFILE%\.android\debug.keystore"
set "GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey"
set "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android"

set "GODOT_ANDROID_KEYSTORE_RELEASE_PATH=%CD%\android\last-signal.keystore"
set "GODOT_ANDROID_KEYSTORE_RELEASE_USER=last-signal"
set "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=Ycnegremela2@"

start "" "%USERPROFILE%\bin\godot.exe" --path . --editor
