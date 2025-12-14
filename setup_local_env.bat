@echo off
setlocal
echo ==========================================
echo   Flutter IPTV - Local Environment Setup
echo ==========================================
echo.

REM Check if Flutter is in PATH
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Flutter SDK not found in PATH.
    echo Please install Flutter and add it to your PATH variable.
    pause
    exit /b 1
)

echo [1/4] Installing dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo [ERROR] Failed to get packages.
    pause
    exit /b 1
)

echo.
echo [2/4] Verifying Windows Platform Support...
if not exist windows\CMakeLists.txt (
    echo     - Missing Windows build files. Generating...
    call flutter create . --platforms=windows
) else (
    echo     - Windows platform files detected. Skipping generation to protect custom code.
)

echo.
echo [3/4] Verifying Android Platform Support...
if not exist android\gradlew (
    echo     - Missing Android Gradle wrapper. Generating...
    call flutter create . --platforms=android
    
    REM Re-apply our custom compileSdk version if needed
    echo     - Note: You might need to check android/app/build.gradle manually if customized settings were overwritten.
    echo       We recommend compileSdk = 34.
) else (
    echo     - Android platform files detected.
)

echo.
echo [4/4] Finalizing...
echo.
echo ==========================================
echo          Setup Completed Successfully!
echo ==========================================
echo.
echo You can now run the app using:
echo    flutter run -d windows
echo    flutter run -d chrome
echo.
pause
