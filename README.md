# MaintenanceLogger

MaintenanceLogger is a lightweight digital maintenance log entry tool for Windows systems, with Linux support planned for a future release.

The project provides a standardized way for administrators and authorized users to record maintenance activities such as software installations, patching, user account changes, hardware installations, data transfers, and system reboots. Entries are written to the Windows Application Event Log so they can be reviewed locally in Event Viewer or collected by enterprise logging platforms such as Splunk, Microsoft Sentinel, or another SIEM.

---

## Features

- Logs maintenance activities directly to the Windows Event Log
- Automatically records:
  - Logged-in user
  - User who performed the maintenance action
  - Computer name
  - Event time
  - Maintenance category
  - Free-text maintenance description
- Allows a different user to be entered as the person who performed the action
- Requires authentication when logging work for another user
- Logs failed authentication attempts
- Uses standardized maintenance categories
- Includes an installer that can request administrator elevation
- Creates a desktop shortcut for users
- No code-signing certificate required
- No external dependencies
- Designed for enterprise, offline, and air-gapped environments

---

## Maintenance Categories

- Data Transfer (low to high)
- Data Transfer (high to high)
- Data Transfer (high to low)
- User Account Creation
- User Account Modification
- Service Account Creation
- Service Account Modification
- New VM
- Hardware Install
- Hardware Move
- Hardware Removed
- Hardware Sanitization
- Software Install
- Software Uninstall
- Patching
- AV Definition Update
- System Reboot
- Admin/Root Login (name account in description)
- Group Account Login (name account in description)
- Other

---

## Requirements

- Windows 10 or later
- Windows Server 2019 or later
- Windows PowerShell 5.1
- Administrator privileges for installation

---

## Project Files

Recommended project layout:

```text
MaintenanceLogger
├── Install-MaintenanceLogger.ps1
├── MaintenanceLogger.ps1
├── MaintenanceLogger.ico
└── README.md
```

`MaintenanceLogger.ico` is optional. If it is not present, the desktop shortcut will use the default PowerShell icon.

---

## Installation

Clone the repository or download the project files.

Run the installer from PowerShell:

```powershell
.\Install-MaintenanceLogger.ps1
```

The installer will:

- Request Administrator privileges if it is not already elevated
- Create the installation folder:

```text
C:\Program Files\Maintenance Logger
```

- Copy `MaintenanceLogger.ps1` to the installation folder
- Copy `MaintenanceLogger.ico` if present
- Create the Windows Event Log source:

```text
MaintenanceLogger
```

- Create a Public Desktop shortcut:

```text
C:\Users\Public\Desktop\Maintenance Logger.lnk
```

---

## Usage

Double-click the **Maintenance Logger** desktop shortcut.

The script prompts for:

1. Who performed the action
2. Password authentication if a different user is entered
3. Event time, defaulting to the current time
4. Maintenance category
5. Free-text maintenance description

After submission, the event is written to:

```text
Windows Logs > Application
```

Event source:

```text
MaintenanceLogger
```

---

## Event IDs

| Event ID | Type | Description |
|---:|---|---|
| 1000 | Information | Maintenance activity successfully logged |
| 1001 | Warning | Failed authentication attempt while attempting to log maintenance for another user |

---

## Example Successful Event

```text
Maintenance Work Logged

Performed By: DOMAIN\jsmith
Logged In User: DOMAIN\administrator
Computer: SERVER01
Event Time: 2026-07-07 02:15 PM
Category: Patching

Description:
Installed July Windows security updates and rebooted server.
```

---

## Example Failed Authentication Event

```text
Maintenance Logger Failed Authentication Attempt

Logged In User: DOMAIN\administrator
Computer: SERVER01
Attempted Performed By User: DOMAIN\jsmith
Failure Time: 2026-07-07 02:21 PM

Result:
Authentication failed. Maintenance entry was not accepted.
```

---

## Security Notes

MaintenanceLogger is intended to support auditability and operational accountability.

- The logged-in user is always recorded.
- The claimed maintenance performer is recorded.
- If the claimed performer is different from the logged-in user, authentication is required.
- Failed authentication attempts are logged to the Windows Application Event Log.
- Events are stored in the Windows Event Log rather than a local text file.
- The application can be installed under `C:\Program Files\Maintenance Logger` to prevent standard users from modifying the script.

Because this project does not require a code-signing certificate, the desktop shortcut launches PowerShell with a process-scoped execution policy bypass. This does not permanently change the system execution policy.

---

## SIEM / Splunk Collection

MaintenanceLogger events can be collected by forwarding the Windows Application Event Log and filtering on:

```text
Source = MaintenanceLogger
```

Useful fields to extract include:

- Performed By
- Logged In User
- Computer
- Event Time
- Category
- Description
- Event ID

---

## Roadmap

Potential future enhancements:

- Windows GUI using WinForms or WPF
- Category drop-down menu
- Date picker and time picker
- Ticket number field
- Change request field
- Optional comments field
- CSV export
- MSI installer
- Group Policy deployment support
- Linux logger/syslog support
- Optional script signing support

---

## Repository

GitHub:

```text
https://github.com/ramsbott/MaintenanceLogger
```

---

## License

MIT License
