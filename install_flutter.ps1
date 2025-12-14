$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "      Flutter SDK Auto-Installer" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Define paths
$InstallDir = "C:\flutter"
$ZipUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.9-stable.zip"
$ZipPath = "$env:TEMP\flutter_sdk.zip"

# Check if already installed
if (Test-Path "$InstallDir\bin\flutter.bat") {
    Write-Host "[Info] Flutter is already installed at $InstallDir" -ForegroundColor Green
    goto UpdatePath
}

# 2. Download
Write-Host "[1/3] Downloading Flutter SDK..." -ForegroundColor Yellow
Write-Host "      URL: $ZipUrl"
Write-Host "      This may take a few minutes depending on your internet speed..."

try {
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing
    Write-Host "      Download complete!" -ForegroundColor Green
} catch {
    Write-Host "[Error] Download failed: $_" -ForegroundColor Red
    exit 1
}

# 3. Extract
Write-Host "[2/3] Extracting to $InstallDir..." -ForegroundColor Yellow
# Create directory if it handles extraction path differently, but usually the zip contains 'flutter' folder
# So we extract to C:\ which results in C:\flutter
try {
    Expand-Archive -Path $ZipPath -DestinationPath "C:\" -Force
    Write-Host "      Extraction complete!" -ForegroundColor Green
} catch {
    Write-Host "[Error] Extraction failed: $_" -ForegroundColor Red
    exit 1
}

:UpdatePath
# 4. Update PATH
Write-Host "[3/3] Updating Environment Variables..." -ForegroundColor Yellow
$BinPath = "$InstallDir\bin"
$CurrentPath = [Environment]::GetEnvironmentVariable("Path", "User")

if ($CurrentPath -notlike "*$BinPath*") {
    $NewPath = "$CurrentPath;$BinPath"
    [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
    Write-Host "      Successfully added $BinPath to User Path." -ForegroundColor Green
    Write-Host "      NOTE: You may need to restart your terminal/IDE for changes to take effect." -ForegroundColor Magenta
} else {
    Write-Host "      Path is already configured." -ForegroundColor Green
}

# Clean up
if (Test-Path $ZipPath) { Remove-Item $ZipPath }

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "      Installation Finished!" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Please RESTART your terminal/editor to use the 'flutter' command."
Write-Host "Then run 'flutter doctor' to verify."
