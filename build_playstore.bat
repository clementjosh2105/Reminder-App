@echo off
setlocal EnableExtensions
title StreakMind Play Store Builder

cd /d "%~dp0"

echo ==================================================
echo       STREAKMIND PLAY STORE RELEASE BUILDER
echo ==================================================
echo.

set "FLUTTER_BIN=C:\Users\DELL\flutter\bin"

if exist "%FLUTTER_BIN%\flutter.bat" (
    echo [INFO] Found Flutter SDK at: %FLUTTER_BIN%
    set "PATH=%FLUTTER_BIN%;%PATH%"
) else (
    echo [WARNING] Flutter SDK was not found at: %FLUTTER_BIN%
    echo           Falling back to Flutter from system PATH.
)

echo.
echo [SECURITY NOTE]
echo Do not ship a real Groq API key in a production APK/AAB.
echo Use Firebase Functions or another backend for production AI calls.
echo.
set /p GROQ_API_KEY=Optional Groq API key for this build, or press Enter to skip: 

set "DART_DEFINE_ARGS="
if not "%GROQ_API_KEY%"=="" (
    set "DART_DEFINE_ARGS=--dart-define=GROQ_API_KEY=%GROQ_API_KEY%"
    echo [INFO] Groq key will be included via dart-define.
) else (
    echo [INFO] No Groq key supplied. App will use local fallback messages.
)

echo.
echo ==================================================
echo [STEP 0/5] Checking Flutter installation...
echo ==================================================
call flutter --version
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Flutter is not available.
    goto end
)

echo.
echo ==================================================
echo [STEP 1/5] Cleaning previous build artifacts...
echo ==================================================
call flutter clean
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] flutter clean failed.
    goto end
)

echo.
echo ==================================================
echo [STEP 2/5] Fetching project packages...
echo ==================================================
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] flutter pub get failed.
    goto end
)

echo.
echo ==================================================
echo [STEP 3/5] Generating Hive adapters...
echo ==================================================
call dart run build_runner build --delete-conflicting-outputs
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Code generation failed.
    goto end
)

echo.
echo ==================================================
echo [STEP 4/5] Running analysis and tests...
echo ==================================================
call flutter analyze
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] flutter analyze failed.
    goto end
)

call flutter test
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] flutter test failed.
    goto end
)

echo.
echo ==================================================
echo [STEP 5/5] Building Play Store app bundle...
echo ==================================================
call flutter build appbundle --release %DART_DEFINE_ARGS%
if %ERRORLEVEL% neq 0 (
    echo.
    if exist "build\app\outputs\bundle\release\app-release.aab" (
        echo [WARNING] Flutter reported a build error, but app-release.aab was created.
        echo.
        echo Most likely issue:
        echo Native debug symbols could not be stripped because the Android SDK/NDK
        echo command-line tools or licenses are incomplete.
        echo.
        echo Fix before trusting this as the final Play Store artifact:
        echo 1. Install Android SDK Command-line Tools from Android Studio SDK Manager.
        echo 2. Run: flutter doctor --android-licenses
        echo 3. Run: flutter doctor -v
        echo.
        echo Output:
        echo build\app\outputs\bundle\release\app-release.aab
        goto end
    ) else (
        echo [ERROR] Play Store app bundle build failed.
        echo.
        echo Check these before retrying:
        echo 1. Android SDK command-line tools are installed.
        echo 2. Android licenses are accepted: flutter doctor --android-licenses
        echo 3. Release signing is configured in android\app\build.gradle.kts.
        goto end
    )
)

if exist "build\app\outputs\bundle\release\app-release.aab" (
    echo.
    echo ==================================================
    echo  SUCCESS: Play Store AAB generated successfully!
    echo ==================================================
    echo.
    echo Output:
    echo build\app\outputs\bundle\release\app-release.aab
) else (
    echo.
    echo [ERROR] Build finished but app-release.aab was not found.
)

:end
set "GROQ_API_KEY="
pause
endlocal
