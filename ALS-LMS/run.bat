@echo off
rem ALS-LMS quick runner: admin (web) and mobile (student_phone)
rem Place this file in the repository root (ALS-LMS). Double-click or run from terminal.
rem Requirements: flutter and code (VS Code CLI) should be in PATH. Android SDK/emulator recommended.

setlocal

rem Get directory of this script (repo root)
set "ROOT=%~dp0"

:MENU
cls
echo ============================================
echo ALS-LMS quick runner - Admin (web) & Mobile
echo ============================================
echo.
echo 1) Run Admin web (Chrome)
echo 2) Run Mobile (Android)
echo 3) Run Both (Admin + Mobile)
echo 4) Build Admin web (release)
echo 5) Build Mobile APK (release)
echo 6) Run flutter pub get for both
echo 7) Open Admin in VS Code
echo 8) Open Mobile in VS Code
echo Q) Quit
echo.
set /p choice=Choose an option: 

if /i "%choice%"=="1" goto RUN_ADMIN
if /i "%choice%"=="2" goto RUN_MOBILE
if /i "%choice%"=="3" goto RUN_BOTH
if /i "%choice%"=="4" goto BUILD_ADMIN
if /i "%choice%"=="5" goto BUILD_MOBILE
if /i "%choice%"=="6" goto PUB_BOTH
if /i "%choice%"=="7" goto OPEN_ADMIN
if /i "%choice%"=="8" goto OPEN_MOBILE
if /i "%choice%"=="Q" goto END
if /i "%choice%"=="q" goto END

echo Invalid choice.
pause
goto MENU

:RUN_ADMIN
echo Launching Admin (web) in a new window...
start "" /D "%ROOT%apps\admin_web" powershell -NoExit -Command "flutter pub get; flutter run -d chrome"
goto MENU

:RUN_MOBILE
echo Launching Mobile (Android) in a new window...
start "" /D "%ROOT%apps\student_phone" powershell -NoExit -Command "flutter pub get; flutter run -d android"
goto MENU

:RUN_BOTH
echo Launching Admin (web) and Mobile (Android)...
start "" /D "%ROOT%apps\admin_web" powershell -NoExit -Command "flutter pub get; flutter run -d chrome"
start "" /D "%ROOT%apps\student_phone" powershell -NoExit -Command "flutter pub get; flutter run -d android"
goto MENU

:BUILD_ADMIN
echo Building Admin (web)...
start "" /D "%ROOT%apps\admin_web" powershell -NoExit -Command "flutter build web --release"
goto MENU

:BUILD_MOBILE
echo Building Mobile (APK release)...
start "" /D "%ROOT%apps\student_phone" powershell -NoExit -Command "flutter build apk --release"
goto MENU

:PUB_BOTH
echo Running flutter pub get for admin and mobile (each in its own window)...
start "" /D "%ROOT%apps\admin_web" powershell -NoExit -Command "flutter pub get"
start "" /D "%ROOT%apps\student_phone" powershell -NoExit -Command "flutter pub get"
goto MENU

:OPEN_ADMIN
echo Opening Admin project in VS Code...
start "" /D "%ROOT%apps\admin_web" cmd /c code .
goto MENU

:OPEN_MOBILE
echo Opening Mobile project in VS Code...
start "" /D "%ROOT%apps\student_phone" cmd /c code .
goto MENU

:END
echo Done.
endlocal
exit /b 0
