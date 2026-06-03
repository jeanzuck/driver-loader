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
set "SC_LAST_LOG=%TEMP%\%SERVICE_NAME%_sc_last.log"
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
call :QueryDriverState
if defined DRIVER_STATE (
  powershell -Command "Write-Host ' [SERVICE] Driver is ' -NoNewline; Write-Host 'LOADED' -ForegroundColor Green"
  if /i "%DRIVER_STATE%"=="RUNNING" (
    powershell -Command "Write-Host ' [STATUS] State: ' -NoNewline; Write-Host 'RUNNING' -ForegroundColor Green"
  ) else (
    powershell -Command "Write-Host ' [STATUS] State: ' -NoNewline; Write-Host 'STOPPED' -ForegroundColor Red"
  )
) else (
  powershell -Command "Write-Host ' [SERVICE] Driver is ' -NoNewline; Write-Host 'UNLOADED' -ForegroundColor Red"
)

echo ================================================
echo.
echo 1. Load and start driver
echo 2. Stop and unload driver
echo 3. Start driver
echo 4. Stop driver
echo 5. Load driver
echo 6. Unload driver
echo 0. Exit
echo.
set /p "choice=Enter your choice (0-6): "

if "%choice%"=="1" goto LOAD_AND_START
if "%choice%"=="2" goto STOP_AND_UNLOAD
if "%choice%"=="3" goto START_DRIVER
if "%choice%"=="4" goto STOP_DRIVER
if "%choice%"=="5" goto LOAD_ONLY
if "%choice%"=="6" goto UNLOAD_ONLY
if "%choice%"=="0" goto EXIT
echo Invalid choice. Please try again.
timeout /t 2 >nul
goto MENU

:LOAD_AND_START
echo.
echo ================================================
echo Loading and Starting Driver...
echo ================================================

:: Check if the driver file exists
call :RequireDriverFile
if errorlevel 1 (
  pause
  goto MENU
)

:: Check for existing driver service
call :CheckServiceExists

:: Create the driver service if needed
if not defined SERVICE_EXISTS (
  call :CreateService
  if errorlevel 1 (
    pause
    goto MENU
  )
)

:: Start the driver service
echo Starting driver service "%SERVICE_NAME%"...
call :RunSc sc start "%SERVICE_NAME%"
if errorlevel 1 (
  call :WAIT_FOR_RUNNING
  if defined START_OK goto LOAD_AND_START_SUCCESS
  powershell -Command "Write-Host 'Error: Failed to start driver service.' -ForegroundColor Red"
  call :PrintLastScOutput
  if not defined SERVICE_EXISTS (
    powershell -Command "Write-Host 'Removing failed service...' -ForegroundColor Red"
    call :RunSc sc delete "%SERVICE_NAME%"
  )
  pause
  goto MENU
)

:: Success message
:LOAD_AND_START_SUCCESS
powershell -Command "Write-Host 'Driver loaded and started successfully!' -ForegroundColor Green"
pause
goto MENU

:STOP_AND_UNLOAD
echo.
echo ================================================
echo Stopping and Unloading Driver...
echo ================================================

:: Check if service exists
call :RequireServiceExists
if errorlevel 1 (
  pause
  goto MENU
)

echo Stopping driver service...
call :RunSc sc stop "%SERVICE_NAME%"
if errorlevel 1 (
  powershell -Command "Write-Host 'Warning: Failed to stop driver service before deleting.' -ForegroundColor Yellow"
  call :PrintLastScOutput
)
timeout /t 2 >nul

echo Deleting driver service...
call :RunSc sc delete "%SERVICE_NAME%"
if errorlevel 1 (
  powershell -Command "Write-Host 'Error: Failed to delete driver service.' -ForegroundColor Red"
  call :PrintLastScOutput
  pause
  goto MENU
)
timeout /t 2 >nul

powershell -Command "Write-Host 'Driver stopped and unloaded successfully!' -ForegroundColor Green"
pause
goto MENU

:START_DRIVER
echo.
echo ================================================
echo Starting Driver...
echo ================================================

:: Check if service exists
call :RequireServiceExists
if errorlevel 1 (
  pause
  goto MENU
)

echo Starting driver service...
call :RunSc sc start "%SERVICE_NAME%"
if errorlevel 1 (
  call :WAIT_FOR_RUNNING
  if defined START_OK goto START_DRIVER_SUCCESS
  powershell -Command "Write-Host 'Error: Failed to start driver service.' -ForegroundColor Red"
  call :PrintLastScOutput
  pause
  goto MENU
)

:START_DRIVER_SUCCESS
powershell -Command "Write-Host 'Driver started successfully!' -ForegroundColor Green"
pause
goto MENU

:STOP_DRIVER
echo.
echo ================================================
echo Stopping Driver...
echo ================================================

:: Check if service exists
call :RequireServiceExists
if errorlevel 1 (
  pause
  goto MENU
)

echo Stopping driver service...
call :RunSc sc stop "%SERVICE_NAME%"
if errorlevel 1 (
  powershell -Command "Write-Host 'Error: Failed to stop driver service.' -ForegroundColor Red"
  call :PrintLastScOutput
  pause
  goto MENU
)

powershell -Command "Write-Host 'Driver stopped successfully!' -ForegroundColor Green"
pause
goto MENU

:LOAD_ONLY
echo.
echo ================================================
echo Loading Driver...
echo ================================================

:: Check if the driver file exists
call :RequireDriverFile
if errorlevel 1 (
  pause
  goto MENU
)

:: Check for existing driver service
call :CheckServiceExists
if defined SERVICE_EXISTS (
  powershell -Command "Write-Host 'Driver is already loaded.' -ForegroundColor Green"
  pause
  goto MENU
)

:: Create the driver service
call :CreateService
if errorlevel 1 (
  pause
  goto MENU
)

powershell -Command "Write-Host 'Driver loaded successfully!' -ForegroundColor Green"
pause
goto MENU

:UNLOAD_ONLY
echo.
echo ================================================
echo Unloading Driver...
echo ================================================

:: Check if service exists
call :RequireServiceExists
if errorlevel 1 (
  pause
  goto MENU
)

call :QueryDriverState
if /i "%DRIVER_STATE%"=="RUNNING" (
  powershell -Command "Write-Host 'Driver is running. Stop it before unloading.' -ForegroundColor Yellow"
  pause
  goto MENU
)

echo Deleting driver service...
call :RunSc sc delete "%SERVICE_NAME%"
if errorlevel 1 (
  powershell -Command "Write-Host 'Error: Failed to delete driver service.' -ForegroundColor Red"
  call :PrintLastScOutput
  pause
  goto MENU
)

powershell -Command "Write-Host 'Driver unloaded successfully!' -ForegroundColor Green"
pause
goto MENU

:WAIT_FOR_RUNNING
set "START_OK="
set /a "RETRY=0"
:WAIT_LOOP
call :QueryDriverState
if /i "%DRIVER_STATE%"=="RUNNING" set "START_OK=1" & goto :EOF
if /i "%DRIVER_STATE%"=="START_PENDING" (
  set /a "RETRY+=1"
  if %RETRY% lss 6 (
    timeout /t 1 >nul
    goto WAIT_LOOP
  )
)
goto :EOF

:RequireDriverFile
if not exist "%DRIVER_PATH%" (
  powershell -Command "Write-Host 'Error: Driver file not found at: %DRIVER_PATH%' -ForegroundColor Red"
  powershell -Command "Write-Host 'Please make sure the driver file is in the same directory as this script.' -ForegroundColor Red"
  exit /b 1
)
powershell -Command "Write-Host 'Driver file found: %DRIVER_PATH%' -ForegroundColor Green"
exit /b 0

:RequireServiceExists
call :RunSc sc query "%SERVICE_NAME%"
if errorlevel 1 (
  powershell -Command "Write-Host 'Driver is not loaded.' -ForegroundColor Yellow"
  call :PrintLastScOutput
  exit /b 1
)
exit /b 0

:CheckServiceExists
set "SERVICE_EXISTS="
sc query "%SERVICE_NAME%" >nul 2>&1
if not errorlevel 1 set "SERVICE_EXISTS=1"
exit /b 0

:CreateService
echo Creating driver service "%SERVICE_NAME%"...
call :RunSc sc create "%SERVICE_NAME%" binPath= "%DRIVER_PATH%" type= kernel start= demand
if errorlevel 1 (
  powershell -Command "Write-Host 'Error: Failed to create driver service.' -ForegroundColor Red"
  call :PrintLastScOutput
  exit /b 1
)
exit /b 0

:RunSc
%* >"%SC_LAST_LOG%" 2>&1
set "SC_LAST_EXIT=%ERRORLEVEL%"
exit /b %SC_LAST_EXIT%

:PrintLastScOutput
if defined SC_LAST_EXIT powershell -Command "Write-Host 'sc exit code: %SC_LAST_EXIT%' -ForegroundColor Yellow"
if exist "%SC_LAST_LOG%" (
  for %%L in ("%SC_LAST_LOG%") do if %%~zL gtr 0 (
    powershell -Command "Write-Host 'sc output:' -ForegroundColor Yellow"
    type "%SC_LAST_LOG%"
  ) else (
    powershell -Command "Write-Host 'sc did not provide additional details.' -ForegroundColor Yellow"
  )
) else (
  powershell -Command "Write-Host 'sc log file was not created.' -ForegroundColor Yellow"
)
exit /b 0

:QueryDriverState
set "DRIVER_STATE="
for /f "tokens=3,4" %%A in ('sc query "%SERVICE_NAME%" ^| findstr /C:"STATE"') do set "DRIVER_STATE=%%B"
exit /b 0

:EXIT
echo.
echo Exiting...
exit /b 0
