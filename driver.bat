@echo off
setlocal enabledelayedexpansion

>nul 2>&1 ( net session ) || (
  echo Requesting admin privileges...
  powershell -Command "Start-Process '%~f0' -Verb RunAs"
  exit /b
)

:: ===== Config =====
set "SERVICE_NAME=%~n0"
set "DRIVER_FILE=%SERVICE_NAME%.sys"
set "DRIVER_PATH=%~dp0%DRIVER_FILE%"
:: ==================

:MENU
cls
echo ================================================
echo           Driver Management Tool
echo ================================================
echo.
echo Service Name: %SERVICE_NAME%
echo Driver File:  %DRIVER_FILE%
echo Driver Path:  %DRIVER_PATH%
echo.
echo ================================================

:: Check driver status
sc query "%SERVICE_NAME%" >nul 2>&1
if %errorlevel% equ 0 (
  powershell -Command "Write-Host ' [STATUS] Driver is currently LOADED' -ForegroundColor Green"
) else (
  powershell -Command "Write-Host ' [STATUS] Driver is currently UNLOADED' -ForegroundColor Yellow"
)

echo ================================================
echo.
echo 1. Load driver
echo 2. Unload driver
echo 3. Exit
echo.
set /p "choice=Enter your choice (1-3): "

if "%choice%"=="1" goto LOAD_DRIVER
if "%choice%"=="2" goto UNLOAD_DRIVER
if "%choice%"=="3" goto EXIT
echo Invalid choice. Please try again.
timeout /t 2 >nul
goto MENU

:LOAD_DRIVER
echo.
echo ================================================
echo Loading Driver...
echo ================================================

:: Check if the driver file exists
if not exist "%DRIVER_PATH%" (
  powershell -Command "Write-Host 'Error: Driver file not found at: %DRIVER_PATH%' -ForegroundColor Red"
  powershell -Command "Write-Host 'Please make sure the driver file is in the same directory as this script.' -ForegroundColor Red"
  pause
  goto MENU
)

powershell -Command "Write-Host 'Driver file found: %DRIVER_PATH%' -ForegroundColor Green"

:: Check for existing driver service
echo Checking for existing driver service...
sc query "%SERVICE_NAME%" >nul 2>&1
if %errorlevel% equ 0 (
  powershell -Command "Write-Host 'Driver is already loaded.' -ForegroundColor Green"
  pause
  goto MENU
)

:: Create the driver service
echo Creating driver service "%SERVICE_NAME%"...
sc create "%SERVICE_NAME%" binPath= "%DRIVER_PATH%" type= kernel start= demand >nul 2>&1
if %errorlevel% neq 0 (
  powershell -Command "Write-Host 'Error: Failed to create driver service.' -ForegroundColor Red"
  pause
  goto MENU
)

:: Start the driver service
echo Starting driver service "%SERVICE_NAME%"...
sc start "%SERVICE_NAME%" >nul 2>&1
if %errorlevel% neq 0 (
  powershell -Command "Write-Host 'Error: Failed to start driver service.' -ForegroundColor Red"
  powershell -Command "Write-Host 'Removing failed service...' -ForegroundColor Red"
  sc delete "%SERVICE_NAME%" >nul 2>&1
  pause
  goto MENU
)

:: Success message
powershell -Command "Write-Host 'Driver loaded successfully!' -ForegroundColor Green"
pause
goto MENU

:UNLOAD_DRIVER
echo.
echo ================================================
echo Unloading Driver...
echo ================================================

:: Check if service exists
sc query "%SERVICE_NAME%" >nul 2>&1
if %errorlevel% neq 0 (
  powershell -Command "Write-Host 'Driver is not loaded.' -ForegroundColor Yellow"
  pause
  goto MENU
)

echo Stopping driver service...
sc stop "%SERVICE_NAME%" >nul 2>&1
timeout /t 2 >nul

echo Deleting driver service...
sc delete "%SERVICE_NAME%" >nul 2>&1
timeout /t 2 >nul

powershell -Command "Write-Host 'Driver unloaded successfully!' -ForegroundColor Green"
pause
goto MENU

:EXIT
echo.
echo Exiting...
exit /b 0