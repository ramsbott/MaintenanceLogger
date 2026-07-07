# MaintenanceLogger.ps1

$ErrorActionPreference = "Stop"

$EventLogName = "Application"
$EventSource  = "MaintenanceLogger"

$Categories = @(
    "Data Transfer (low to high)",
    "Data Transfer (high to high)",
    "Data Transfer (high to low)",
    "User Account Creation",
    "User Account Modification",
    "Service Account Creation",
    "Service Account Modification",
    "New VM",
    "Hardware Install",
    "Hardware Move",
    "Hardware Removed",
    "Hardware Sanitization",
    "Software Install",
    "Software Uninstall",
    "Patching",
    "AV Definition Update",
    "System Reboot",
    "Admin/Root Login (name account in description)",
    "Group Account Login (name account in description)",
    "Other"
)

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class LogonUtil {
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool LogonUser(
        string lpszUsername,
        string lpszDomain,
        string lpszPassword,
        int dwLogonType,
        int dwLogonProvider,
        out IntPtr phToken
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);
}
"@

$LoggedInUser = "$env:USERDOMAIN\$env:USERNAME"
$Computer = $env:COMPUTERNAME

$PerformedByInput = Read-Host "Who performed the action? Press Enter for logged in user [$LoggedInUser]"

if ([string]::IsNullOrWhiteSpace($PerformedByInput)) {
    $PerformedBy = $LoggedInUser
}
else {
    $AttemptedUser = $PerformedByInput.Trim()

    if ($AttemptedUser -match "\\") {
        $Domain = $AttemptedUser.Split("\")[0]
        $Username = $AttemptedUser.Split("\")[1]
    }
    else {
        $Domain = $env:USERDOMAIN
        $Username = $AttemptedUser
    }

    $SecurePassword = Read-Host "Enter password for $Domain\$Username" -AsSecureString
    $Ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    $PlainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Ptr)

    $Token = [IntPtr]::Zero

    $AuthSuccess = [LogonUtil]::LogonUser(
        $Username,
        $Domain,
        $PlainPassword,
        2,
        0,
        [ref]$Token
    )

    $PlainPassword = $null

    if ($AuthSuccess) {
        [LogonUtil]::CloseHandle($Token) | Out-Null
        $PerformedBy = "$Domain\$Username"
    }
    else {
        $FailureTime = Get-Date -Format "yyyy-MM-dd hh:mm tt"

        $FailureMessage = @"
Maintenance Logger Failed Authentication Attempt

Logged In User: $LoggedInUser
Computer: $Computer
Attempted Performed By User: $Domain\$Username
Failure Time: $FailureTime

Result:
Authentication failed. Maintenance entry was not accepted.
"@

        Write-EventLog `
            -LogName $EventLogName `
            -Source $EventSource `
            -EventId 1001 `
            -EntryType Warning `
            -Message $FailureMessage

        Write-Host ""
        Write-Host "Authentication failed."
        Write-Host "This failed attempt has been logged."
        Start-Sleep -Seconds 3
        exit
    }
}

$DefaultEventTime = Get-Date
$DefaultEventTimeText = $DefaultEventTime.ToString("hh:mm tt")

do {
    $EventTimeInput = Read-Host "Enter event time [hh:mm AM/PM] or press Enter for now [$DefaultEventTimeText]"

    if ([string]::IsNullOrWhiteSpace($EventTimeInput)) {
        $EventTime = $DefaultEventTime
        $ValidTime = $true
    }
    else {
        $Today = Get-Date -Format "yyyy-MM-dd"
        $DateTimeString = "$Today $EventTimeInput"

        $ValidTime = [datetime]::TryParseExact(
            $DateTimeString,
            "yyyy-MM-dd hh:mm tt",
            $null,
            [System.Globalization.DateTimeStyles]::None,
            [ref]$EventTime
        )

        if (-not $ValidTime) {
            Write-Host ""
            Write-Host "Invalid format. Please enter time like:"
            Write-Host "  08:30 AM"
            Write-Host "  01:15 PM"
            Write-Host ""
        }
    }
} until ($ValidTime)

$EventTimeText = $EventTime.ToString("yyyy-MM-dd hh:mm tt")

Write-Host ""
Write-Host "Select Maintenance Category:"
for ($i = 0; $i -lt $Categories.Count; $i++) {
    Write-Host "$($i + 1). $($Categories[$i])"
}

do {
    $Selection = Read-Host "Enter category number"
} until ($Selection -as [int] -and $Selection -ge 1 -and $Selection -le $Categories.Count)

$Category = $Categories[$Selection - 1]

do {
    $Entry = Read-Host "Enter maintenance description"

    if ([string]::IsNullOrWhiteSpace($Entry)) {
        Write-Host "Description cannot be blank."
    }
} until (-not [string]::IsNullOrWhiteSpace($Entry))

$Message = @"
Maintenance Work Logged

Performed By: $PerformedBy
Logged In User: $LoggedInUser
Computer: $Computer
Event Time: $EventTimeText
Category: $Category

Description:
$Entry
"@

Write-EventLog `
    -LogName $EventLogName `
    -Source $EventSource `
    -EventId 1000 `
    -EntryType Information `
    -Message $Message

Write-Host ""
Write-Host "Maintenance entry logged successfully."
Start-Sleep -Seconds 3
