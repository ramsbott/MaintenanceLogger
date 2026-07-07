<#
.SYNOPSIS
    Installs Maintenance Logger.
#>

$ErrorActionPreference = "Stop"

$InstallFolder = "C:\Program Files\Maintenance Logger"
$ScriptName    = "MaintenanceLogger.ps1"
$IconName      = "MaintenanceLogger.ico"

$EventLog      = "Application"
$EventSource   = "MaintenanceLogger"

# Self-elevate if not running as Administrator
$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)

if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevation required. Requesting Administrator privileges..."

    Start-Process powershell.exe `
        -Verb RunAs `
        -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""

    exit
}

Write-Host ""
Write-Host "======================================="
Write-Host " Maintenance Logger Installer"
Write-Host "======================================="
Write-Host ""

# Create install folder
if (!(Test-Path $InstallFolder)) {
    New-Item -ItemType Directory -Path $InstallFolder | Out-Null
    Write-Host "Created install folder: $InstallFolder"
}
else {
    Write-Host "Install folder already exists: $InstallFolder"
}

# Copy MaintenanceLogger.ps1
$SourceScript = Join-Path $PSScriptRoot $ScriptName

if (!(Test-Path $SourceScript)) {
    Write-Host ""
    Write-Host "ERROR: $ScriptName not found."
    Write-Host "Place this installer in the same folder as $ScriptName."
    Pause
    exit 1
}

Copy-Item $SourceScript "$InstallFolder\$ScriptName" -Force
Write-Host "Copied $ScriptName"

# Copy icon if available
$SourceIcon = Join-Path $PSScriptRoot $IconName

if (Test-Path $SourceIcon) {
    Copy-Item $SourceIcon "$InstallFolder\$IconName" -Force
    Write-Host "Copied $IconName"
}
else {
    Write-Host "Icon not found. Shortcut will use default PowerShell icon."
}

# Create Windows Event Source
if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
    New-EventLog -LogName $EventLog -Source $EventSource
    Write-Host "Created Event Source: $EventSource"
}
else {
    Write-Host "Event Source already exists: $EventSource"
}

# Create Public Desktop shortcut
$ShortcutPath = "C:\Users\Public\Desktop\Maintenance Logger.lnk"

$Shell = New-Object -ComObject WScript.Shell
$Shortcut = $Shell.CreateShortcut($ShortcutPath)

$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$InstallFolder\$ScriptName`""
$Shortcut.WorkingDirectory = $InstallFolder

if (Test-Path "$InstallFolder\$IconName") {
    $Shortcut.IconLocation = "$InstallFolder\$IconName"
}

$Shortcut.Save()

Write-Host "Created desktop shortcut: $ShortcutPath"

Write-Host ""
Write-Host "======================================="
Write-Host " Installation Complete"
Write-Host "======================================="
Write-Host ""
Write-Host "Installed to:"
Write-Host "  $InstallFolder"
Write-Host ""
Write-Host "Shortcut:"
Write-Host "  $ShortcutPath"
Write-Host ""
Write-Host "Event Log:"
Write-Host "  $EventLog"
Write-Host ""
Write-Host "Event Source:"
Write-Host "  $EventSource"
Write-Host ""

Pause