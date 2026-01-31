# ConqPing Installation Script for Windows

$ErrorActionPreference = "Stop"

$repo = "Comquister/ConqPing"
$appName = "conqping"
$installDir = "$env:LOCALAPPDATA\$appName"

# Determine Architecture
$arch = $env:PROCESSOR_ARCHITECTURE
if ($arch -eq "AMD64") {
    $archSuffix = "x64"
} elseif ($arch -eq "ARM64") {
    $archSuffix = "arm64"
} elseif ($arch -eq "x86") {
    $archSuffix = "x86"
} else {
    Write-Error "Unsupported architecture: $arch"
}

$binaryName = "conqping-windows-$archSuffix.exe"
$url = "https://github.com/$repo/releases/latest/download/$binaryName"

Write-Host "Detected Architecture: $archSuffix"

# Create Install Directory
if (!(Test-Path -Path $installDir)) {
    New-Item -ItemType Directory -Force -Path $installDir | Out-Null
}

$destPath = "$installDir\conqping.exe"

if (Test-Path $destPath) {
    Write-Host "Existing installation found. Updating..."
    # Try to stop the process if it's running to avoid file lock errors
    Stop-Process -Name $appName -ErrorAction SilentlyContinue
} else {
    Write-Host "Installing $appName..."
}

Write-Host "Downloading $appName from $url..."

try {
    Invoke-WebRequest -Uri $url -OutFile $destPath
} catch {
    Write-Error "Failed to download ConqPing. Please check your internet connection or if the release exists."
}

Write-Host "Installed to $destPath"

# Add to PATH (User)
$userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
if ($userPath -notlike "*$installDir*") {
    Write-Host "Adding $installDir to User PATH..."
    $newPath = "$userPath;$installDir"
    [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
    $env:Path += ";$installDir"
    Write-Host "Added to PATH. You may need to restart your terminal."
} else {
    Write-Host "$installDir is already in PATH."
}

Write-Host "Installation Complete! You can now run 'conqping <IP>'"
Write-Host "Example: conqping 8.8.8.8"
