# ConqPing Installation Script for Windows

$ErrorActionPreference = "Stop"

$repo = "Comquister/ConqPing"
$appName = "conqping"
$installDir = "$env:LOCALAPPDATA\$appName"

# --- Function: Get Java Version ---
function Get-Java-Version {
    try {
        $javaVer = java -version 2>&1
        if ($LASTEXITCODE -ne 0) { return 0 }
        
        # Parse version string (e.g., "1.8.0_202", "17.0.1")
        # Matches patterns like: version "1.8..., version "11...
        if ($javaVer -match 'version "(\d+)\.(\d+).*?"') { 
            # Old format: 1.x
            if ($matches[1] -eq "1") { return [int]$matches[2] } 
            return [int]$matches[1]
        } elseif ($javaVer -match 'version "(\d+).*?"') {
            # New format: 9, 11, 17...
            return [int]$matches[1]
        }
        return 0
    } catch {
        return 0
    }
}

# --- Detect Java Status ---
$javaVersion = Get-Java-Version
$javaStatus = "Missing"
$canUseJava = $false
$javaMsg = ""

if ($javaVersion -ge 8) {
    $javaStatus = "Available (Java $javaVersion detected)"
    $canUseJava = $true
} elseif ($javaVersion -gt 0) {
    $javaStatus = "Disabled (Java $javaVersion is too old, requires 8+)"
} else {
    $javaStatus = "Disabled (No Java installation found)"
}

# --- Menu Selection ---
Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "      ConqPing Installer Selection      " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[1] Install Native Binary (Recommended)" -ForegroundColor Green
Write-Host "    - No dependencies required."
Write-Host "    - Best performance."
Write-Host ""

if ($canUseJava) {
    Write-Host "[2] Install Java JAR" -ForegroundColor Yellow
} else {
    Write-Host "[2] Install Java JAR ($javaStatus)" -ForegroundColor DarkGray
}
Write-Host "    - Requires Java 8+ installed."
Write-Host "    - Cross-platform JAR."
Write-Host ""

$selection = Read-Host "Select option [1/2] (Default: 1)"

if ([string]::IsNullOrWhiteSpace($selection)) { $selection = "1" }

if ($selection -eq "2") {
    if (-not $canUseJava) {
        Write-Error "Cannot select Option 2: $javaStatus"
    }
    $installType = "JAR"
} else {
    $installType = "Native"
}

# --- Installation Logic ---

if ($installType -eq "Native") {
    # Determine Architecture
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch -eq "AMD64") {
        $archSuffix = "x64"
    } elseif ($arch -eq "ARM64") {
        # Emulation support for Windows on ARM
        Write-Warning "Windows ARM64 detected. Installing x64 binary (runs via emulation)."
        $archSuffix = "x64"
    } elseif ($arch -eq "x86") {
        Write-Error "x86 (32-bit) is not supported in this release."
    } else {
        Write-Error "Unsupported architecture: $arch"
    }
    
    $binaryName = "conqping-windows-$archSuffix.exe"
    $targetFile = "conqping.exe"
} else {
    $binaryName = "ConqPing.jar"
    $targetFile = "ConqPing.jar"
}

$url = "https://github.com/$repo/releases/latest/download/$binaryName"

Write-Host "`nInstalling ConqPing ($installType)..." -ForegroundColor Cyan

# Create Install Directory
if (!(Test-Path -Path $installDir)) {
    New-Item -ItemType Directory -Force -Path $installDir | Out-Null
}

$destPath = "$installDir\$targetFile"

# Download
Write-Host "Downloading from $url..."
try {
    Invoke-WebRequest -Uri $url -OutFile $destPath
} catch {
    Write-Error "Failed to download. Check connection or release existence."
}

# If JAR, create wrapper script
if ($installType -eq "JAR") {
    $wrapperPath = "$installDir\conqping.cmd"
    $wrapperContent = "@echo off`njava -jar `"%~dp0ConqPing.jar`" %*"
    Set-Content -Path $wrapperPath -Value $wrapperContent
    Write-Host "Created wrapper script: $wrapperPath"
}

Write-Host "Installed to $installDir" -ForegroundColor Green

# Add to PATH (User)
$userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
if ($userPath -notlike "*$installDir*") {
    Write-Host "Adding to User PATH..."
    $newPath = "$userPath;$installDir"
    [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
    $env:Path += ";$installDir"
}

Write-Host "`nInstallation Complete! You can now run 'conqping <IP>'" -ForegroundColor Cyan
