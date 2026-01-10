@echo off
echo Starting Flutter IPTV Web Server...
echo.

REM Check if Dart is installed
dart --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Dart is not installed or not in PATH
    echo Please install Dart SDK first
    pause
    exit /b 1
)

REM Get dependencies
echo Installing dependencies...
dart pub get

REM Create data directory
if not exist "data" mkdir data

REM Start the server
echo.
echo Starting server on http://localhost:8080
echo Press Ctrl+C to stop the server
echo.
dart run bin/server.dart