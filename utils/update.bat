@echo off
setlocal EnableDelayedExpansion

REM Repository metadata used for release lookups.
set "REPO_OWNER=arcane-forge"
set "REPO_NAME=arcane-forge-studio"
set "RELEASE_ASSET_PREFIX=arcane-forge-studio-windows-v"
set "RELEASE_ASSET_SUFFIX=.zip"

REM Paths and files
set "SCRIPT_DIR=%~dp0"
set "VERSION_FILE=%SCRIPT_DIR%version.txt"
set "TEMP_DIR=%TEMP%\arcane_forge_update_%RANDOM%%RANDOM%"
set "DOWNLOAD_PATH=%TEMP_DIR%\latest_release.zip"
set "EXTRACT_DIR=%TEMP_DIR%\extracted"
set "LATEST_META=%TEMP_DIR%\latest_meta.txt"

if not exist "%VERSION_FILE%" (
    echo [ERROR] Missing version.txt in %SCRIPT_DIR%
    exit /B 1
)

set /p CURRENT_VERSION=<"%VERSION_FILE%"
set "CURRENT_VERSION=%CURRENT_VERSION: =%"
if "%CURRENT_VERSION%"=="" set "CURRENT_VERSION=0.0.0"

if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%" >NUL 2>&1

set "API_URL=https://api.github.com/repos/%REPO_OWNER%/%REPO_NAME%/releases/latest"
powershell -NoProfile -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$headers=@{'User-Agent'='arcane-forge-updater'};" ^
  "if($env:GITHUB_TOKEN){$headers['Authorization']='token '+$env:GITHUB_TOKEN}" ^
  "$release=Invoke-RestMethod -Uri '%API_URL%' -Headers $headers;" ^
  "$version=$release.tag_name;" ^
  "if(-not $version){ throw 'Latest release missing tag_name'; }" ^
  "$version=$version.TrimStart('v');" ^
  "$assetName='%RELEASE_ASSET_PREFIX%'+$version+'%RELEASE_ASSET_SUFFIX%';" ^
  "$asset=$release.assets ^| Where-Object { $_.name -eq $assetName } ^| Select-Object -First 1;" ^
  "if(-not $asset){ throw 'Asset '+$assetName+' not found in latest release.' }" ^
  "$asset.browser_download_url, $version ^| Set-Content -Path '%LATEST_META%'"
if errorlevel 1 (
    echo [ERROR] Unable to query latest release info.
    goto :cleanup_fail
)

for /f "usebackq tokens=1 delims=" %%i in ("%LATEST_META%") do set "LATEST_URL=%%i"
for /f "usebackq skip=1 tokens=1 delims=" %%i in ("%LATEST_META%") do set "LATEST_VERSION=%%i"
if "%LATEST_VERSION%"=="" (
    echo [ERROR] Unable to read latest version from metadata.
    goto :cleanup_fail
)

for /f %%i in ('powershell -NoProfile -Command ^
  "$current='%CURRENT_VERSION%'.TrimStart(''v''); $latest='%LATEST_VERSION%'.TrimStart(''v'');" ^
  "try { [version]$current -lt [version]$latest } catch { $true }"') do set "NEEDS_UPDATE=%%i"

if /I not "%NEEDS_UPDATE%"=="True" (
    echo Current version %CURRENT_VERSION% is up to date with latest %LATEST_VERSION%.
    goto :cleanup
)

echo Updating from %CURRENT_VERSION% to %LATEST_VERSION%...
powershell -NoProfile -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$headers=@{'User-Agent'='arcane-forge-updater'};" ^
  "if($env:GITHUB_TOKEN){$headers['Authorization']='token '+$env:GITHUB_TOKEN}" ^
  "Invoke-WebRequest -Uri '%LATEST_URL%' -Headers $headers -OutFile '%DOWNLOAD_PATH%'"
if errorlevel 1 (
    echo [ERROR] Download failed.
    goto :cleanup_fail
)

powershell -NoProfile -Command ^
  "$ErrorActionPreference='Stop';" ^
  "Expand-Archive -Path '%DOWNLOAD_PATH%' -DestinationPath '%EXTRACT_DIR%' -Force"
if errorlevel 1 (
    echo [ERROR] Failed to extract update archive.
    goto :cleanup_fail
)

powershell -NoProfile -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$src='%EXTRACT_DIR%'; $dest='%SCRIPT_DIR%';" ^
  "Copy-Item -Path (Join-Path $src '*') -Destination $dest -Recurse -Force"
if errorlevel 1 (
    echo [ERROR] Failed to apply update.
    goto :cleanup_fail
)

echo Update applied successfully. Now on version %LATEST_VERSION%.
goto :cleanup

:cleanup
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
exit /B 0

:cleanup_fail
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
exit /B 1
