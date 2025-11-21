@echo off
setlocal

REM Check if Python is installed
where python >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is not installed or not in PATH.
    echo.
    echo Please install Python from https://www.python.org/downloads/
    echo Make sure to check "Add Python to PATH" during installation.
    echo.
    pause
    exit /B 1
)

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"

REM Run the Python update script
python "%SCRIPT_DIR%update.py"

REM Exit with the same code as the Python script
exit /B %ERRORLEVEL%
