@echo off
setlocal

set "FLUTTER_ROOT=C:\flutter"
set "DART=%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe"
set "FLUTTER_TOOL=%FLUTTER_ROOT%\bin\cache\flutter_tools.snapshot"
set "FLUTTER_PACKAGES=%FLUTTER_ROOT%\packages\flutter_tools\.dart_tool\package_config.json"

if not exist "%DART%" (
  echo Dart was not found at "%DART%".
  exit /b 1
)

if not exist "%FLUTTER_TOOL%" (
  echo Flutter tool snapshot was not found at "%FLUTTER_TOOL%".
  exit /b 1
)

echo Select a target:
echo [1] Chrome web release (recommended)
echo [2] Chrome web debug
echo [3] Edge web release
echo [4] Windows desktop debug
set /p choice=Choice [1]:

if "%choice%"=="" set "choice=1"

if "%choice%"=="1" (
  "%DART%" --packages="%FLUTTER_PACKAGES%" "%FLUTTER_TOOL%" run -d chrome --release
) else if "%choice%"=="2" (
  "%DART%" --packages="%FLUTTER_PACKAGES%" "%FLUTTER_TOOL%" run -d chrome --web-browser-flag=--disable-extensions --web-browser-flag=--disable-background-networking
) else if "%choice%"=="3" (
  "%DART%" --packages="%FLUTTER_PACKAGES%" "%FLUTTER_TOOL%" run -d edge --release
) else if "%choice%"=="4" (
  "%DART%" --packages="%FLUTTER_PACKAGES%" "%FLUTTER_TOOL%" run -d windows
) else (
  echo Unknown choice "%choice%".
  exit /b 1
)
