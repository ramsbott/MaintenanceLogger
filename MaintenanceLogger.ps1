<#
.SYNOPSIS
    Installs Maintenance Logger

.DESCRIPTION
    Performs the following:
        • Verifies Administrator privileges
        • Creates installation directory
        • Copies MaintenanceLogger.ps1
        • Creates Event Source
        • Creates Public Desktop shortcut
        • Optionally copies icon
#>

$ErrorActionPreference = "Stop"

$InstallFolder = "C:\Program Files\Maintenance Logger"

$ScriptName = "MaintenanceLogger.ps1"
$IconName = "MaintenanceLogger.ico"

$EventLog = "Application"
$EventSource = "MaintenanceLogger"

Write-Host ""
Write-Host "======================================="
Write-Host " Maintenance Logger Installer"
Write-Host "======================================="
Write-Host ""

# Verify Administrator

$Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($Identity)

if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Host ""
    Write-Host "ERROR: Installer must be run as Administrator."
    Write-Host ""

    Pause
    exit 1
}

Write-Host "Running as Administrator..."

# Create Installation Folder

if (!(Test-Path $InstallFolder))
{
    Write-Host "Creating installation folder..."

    New-Item `
        -ItemType Directory `
        -Path $InstallFolder | Out-Null
}

# Copy PowerShell Script

$SourceScript = Join-Path $PSScriptRoot $ScriptName

if (!(Test-Path $SourceScript))
{
    Write-Host ""
    Write-Host "$ScriptName not found."
    Write-Host "Place this installer beside the script."
    Pause
    exit 1
}

Copy-Item `
    $SourceScript `
    "$InstallFolder\$ScriptName" `
    -Force

Write-Host "Copied MaintenanceLogger.ps1"

# Copy Icon (optional)

$SourceIcon = Join-Path $PSScriptRoot $IconName

if (Test-Path $SourceIcon)
{
    Copy-Item `
        $SourceIcon `
        "$InstallFolder\$IconName" `
        -Force

    Write-Host "Copied icon."
}

# Create Event Source

if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource))
{
    Write-Host "Creating Windows Event Source..."

    New-EventLog `
        -LogName $EventLog `
        -Source $EventSource

    Write-Host "Event Source created."
}
else
{
    Write-Host "Event Source already exists."
}

# Create Desktop Shortcut

Write-Host "Creating Desktop Shortcut..."

$Shell = New-Object -ComObject WScript.Shell

$Shortcut = $Shell.CreateShortcut(
    "C:\Users\Public\Desktop\Maintenance Logger.lnk"
)

$Shortcut.TargetPath = "powershell.exe"

$Shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$InstallFolder\$ScriptName`""

$Shortcut.WorkingDirectory = $InstallFolder

if (Test-Path "$InstallFolder\$IconName")
{
    $Shortcut.IconLocation = "$InstallFolder\$IconName"
}

$Shortcut.Save()

Write-Host "Desktop shortcut created."

Write-Host ""
Write-Host "======================================="
Write-Host " Installation Complete"
Write-Host "======================================="
Write-Host ""

Write-Host "Installed to:"
Write-Host "  $InstallFolder"

Write-Host ""
Write-Host "Desktop Shortcut:"
Write-Host "  C:\Users\Public\Desktop\Maintenance Logger.lnk"

Write-Host ""
Write-Host "Event Source:"
Write-Host "  MaintenanceLogger"

Write-Host ""
Pause