@echo off
title StreakMind APK Builder
echo ==================================================
echo         MOMENTUM APK BUILD HELPER SCRIPT
echo ==================================================
echo.

:: 1. Add Flutter to local PATH temporarily for this script session
set "FLUTTER_BIN=C:\Users\DELL\flutter\bin"

if exist "%FLUTTER_BIN%" (
    echo [INFO] Found Flutter SDK at: %FLUTTER_BIN%
    echo [INFO] Adding Flutter to local PATH environment...
    set "PATH=%FLUTTER_BIN%;%PATH%"
) else (
    echo [WARNING] Flutter SDK was not found at standard path: %FLUTTER_BIN%
    echo           It will fallback to the system PATH.
)

echo.
echo ==================================================
echo [STEP 0/3] Cleaning previous build artifacts...
echo ==================================================
call flutter clean
echo.
echo ==================================================
echo [STEP 1/3] Fetching project packages...
echo ==================================================
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] 'flutter pub get' failed. Check your network or directory structure.
    goto end
)

echo.
echo ==================================================
echo [STEP 2/3] Generating local Hive adapters...
echo ==================================================
call flutter pub run build_runner build --delete-conflicting-outputs
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Code generation failed.
    goto end
)

echo.
echo ==================================================
echo [STEP 3/3] Compiling Release Android APK...
echo ==================================================
call flutter build apk --release
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] 'flutter build apk' failed.
    echo.
    echo NOTE: If this failed due to "No Android SDK found":
    echo 1. Download and install Android Studio (https://developer.android.com/studio)
    echo 2. Open it, select "Tools" - "SDK Manager", and download the command-line tools and a system platform.
    echo 3. The build will then work successfully!
    goto end
)

echo.
echo ==================================================
echo  SUCCESS: APK generated successfully!
echo ==================================================
echo.
echo Your release APK is available at:
echo [ProjectRoot]\build\app\outputs\flutter-apk\app-release.apk
echo.

:end
pause
