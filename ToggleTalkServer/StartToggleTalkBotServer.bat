@echo off
echo ToggleTalk Flask Server Startup Script
echo =====================================

REM Check if we're on Windows
echo Checking system...
ver >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Windows system detected
) else (
    echo This script is designed for Windows systems
    pause
    exit /b 1
)

REM Check if Python is installed
echo Checking Python installation...
python --version >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Python is installed
) else (
    echo Python is not installed or not in PATH
    echo Please install Python 3.7 or later
    pause
    exit /b 1
)

REM Check if virtual environment exists, create if not
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
    if %ERRORLEVEL% NEQ 0 (
        echo Failed to create virtual environment
        pause
        exit /b 1
    )
    echo Virtual environment created
) else (
    echo Virtual environment already exists
)

REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat
if %ERRORLEVEL% NEQ 0 (
    echo Failed to activate virtual environment
    pause
    exit /b 1
)
echo Virtual environment activated

REM Upgrade pip
echo Upgrading pip...
python -m pip install --upgrade pip
if %ERRORLEVEL% NEQ 0 (
    echo Failed to upgrade pip
    pause
    exit /b 1
)

REM Install requirements
echo Installing requirements...
pip install -r requirements_windows.txt
if %ERRORLEVEL% NEQ 0 (
    echo Failed to install requirements
    pause
    exit /b 1
)
echo Requirements installed

REM Set environment variables
echo Setting environment variables...
set AUTHORIZED_CHAT_ID=1767023771
if "%SERVER_PORT%"=="" set SERVER_PORT=7850

REM Start the Flask server
echo Starting ToggleTalk Flask Server...
echo The server will be available at http://localhost:%SERVER_PORT%
echo Press Ctrl+C to stop the server
python ToggleTalkBotServer.py

REM Deactivate virtual environment when done
echo Deactivating virtual environment...
call venv\Scripts\deactivate.bat

echo Server stopped
pause