```powershell
#Requires -Version 5.1
$ErrorActionPreference = "Stop"

# ── Event Log Setup ──────────────────────────────────────────────────────────
$EventLogName = "Application"
$EventSource  = "MaintenanceLogger"

if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
    New-EventLog -LogName $EventLogName -Source $EventSource
}

$Categories = @(
    "Data Transfer",
    "User Account Creation",
    "User Account Modification",
    "Hardware Install",
    "Software Install",
    "Patching",
    "System Reboot",
    "Other"
)

# ── AD Auth Helper ────────────────────────────────────────────────────────────
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class LogonUtil {
    [DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern bool LogonUser(
        string lpszUsername, string lpszDomain, string lpszPassword,
        int dwLogonType, int dwLogonProvider, out IntPtr phToken);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr hObject);
}
"@

$LoggedInUser = "$env:USERDOMAIN\$env:USERNAME"
$Computer     = $env:COMPUTERNAME

# ── Windows Forms GUI ─────────────────────────────────────────────────────────
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form                  = New-Object System.Windows.Forms.Form
$form.Text             = "Maintenance Logger"
$form.Size             = New-Object System.Drawing.Size(520, 560)
$form.StartPosition    = "CenterScreen"
$form.FormBorderStyle  = "FixedDialog"
$form.MaximizeBox      = $false
$form.BackColor        = [System.Drawing.Color]::FromArgb(245, 245, 247)
$form.Font             = New-Object System.Drawing.Font("Segoe UI", 9)

# ── Helper: label + control row ───────────────────────────────────────────────
function Add-Row {
    param($form, $labelText, $control, $y)
    $lbl           = New-Object System.Windows.Forms.Label
    $lbl.Text      = $labelText
    $lbl.Location  = New-Object System.Drawing.Point(30, $y)
    $lbl.Size      = New-Object System.Drawing.Size(140, 20)
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
    $lbl.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $control.Location = New-Object System.Drawing.Point(30, ($y + 22))
    $control.Size     = New-Object System.Drawing.Size(440, 28)
    $form.Controls.Add($lbl)
    $form.Controls.Add($control)
}

# ── Title bar panel ───────────────────────────────────────────────────────────
$titlePanel            = New-Object System.Windows.Forms.Panel
$titlePanel.Dock       = "Top"
$titlePanel.Height     = 60
$titlePanel.BackColor  = [System.Drawing.Color]::FromArgb(30, 30, 30)

$titleLabel            = New-Object System.Windows.Forms.Label
$titleLabel.Text       = "  🔧  Maintenance Logger"
$titleLabel.Dock       = "Fill"
$titleLabel.ForeColor  = [System.Drawing.Color]::White
$titleLabel.Font       = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$titleLabel.TextAlign  = "MiddleLeft"
$titlePanel.Controls.Add($titleLabel)
$form.Controls.Add($titlePanel)

# ── Performed By ──────────────────────────────────────────────────────────────
$txtPerformedBy        = New-Object System.Windows.Forms.TextBox
$txtPerformedBy.Text   = $LoggedInUser
Add-Row $form "Performed By (DOMAIN\Username)" $txtPerformedBy 80

# ── Password (shown only when Performed By differs from logged-in user) ───────
$lblPassword           = New-Object System.Windows.Forms.Label
$lblPassword.Text      = "Password (required if different user)"
$lblPassword.Location  = New-Object System.Drawing.Point(30, 152)
$lblPassword.Size      = New-Object System.Drawing.Size(300, 20)
$lblPassword.ForeColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
$lblPassword.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

$txtPassword           = New-Object System.Windows.Forms.TextBox
$txtPassword.Location  = New-Object System.Drawing.Point(30, 174)
$txtPassword.Size      = New-Object System.Drawing.Size(440, 28)
$txtPassword.PasswordChar = '*'
$txtPassword.Enabled   = $false

$form.Controls.Add($lblPassword)
$form.Controls.Add($txtPassword)

# Enable/disable password field based on whether user changed the name
$txtPerformedBy.Add_TextChanged({
    $txtPassword.Enabled = ($txtPerformedBy.Text.Trim() -ne $LoggedInUser)
})

# ── Event Date & Time ─────────────────────────────────────────────────────────
$lblDateTime           = New-Object System.Windows.Forms.Label
$lblDateTime.Text      = "Event Date & Time"
$lblDateTime.Location  = New-Object System.Drawing.Point(30, 218)
$lblDateTime.Size      = New-Object System.Drawing.Size(200, 20)
$lblDateTime.ForeColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
$lblDateTime.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

$dtPicker              = New-Object System.Windows.Forms.DateTimePicker
$dtPicker.Location     = New-Object System.Drawing.Point(30, 240)
$dtPicker.Size         = New-Object System.Drawing.Size(440, 28)
$dtPicker.Format       = "Custom"
$dtPicker.CustomFormat = "yyyy-MM-dd  hh:mm tt"
$dtPicker.ShowUpDown   = $true
$dtPicker.Value        = Get-Date

$form.Controls.Add($lblDateTime)
$form.Controls.Add($dtPicker)

# ── Category ──────────────────────────────────────────────────────────────────
$cboCategory           = New-Object System.Windows.Forms.ComboBox
$cboCategory.DropDownStyle = "DropDownList"
$Categories | ForEach-Object { $cboCategory.Items.Add($_) | Out-Null }
$cboCategory.SelectedIndex = 0
Add-Row $form "Category" $cboCategory 290

# ── Description ───────────────────────────────────────────────────────────────
$lblDesc               = New-Object System.Windows.Forms.Label
$lblDesc.Text          = "Description"
$lblDesc.Location      = New-Object System.Drawing.Point(30, 362)
$lblDesc.Size          = New-Object System.Drawing.Size(200, 20)
$lblDesc.ForeColor     = [System.Drawing.Color]::FromArgb(80, 80, 80)
$lblDesc.Font          = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

$txtDesc               = New-Object System.Windows.Forms.TextBox
$txtDesc.Location      = New-Object System.Drawing.Point(30, 384)
$txtDesc.Size          = New-Object System.Drawing.Size(440, 80)
$txtDesc.Multiline     = $true
$txtDesc.ScrollBars    = "Vertical"

$form.Controls.Add($lblDesc)
$form.Controls.Add($txtDesc)

# ── Status label ──────────────────────────────────────────────────────────────
$lblStatus             = New-Object System.Windows.Forms.Label
$lblStatus.Location    = New-Object System.Drawing.Point(30, 478)
$lblStatus.Size        = New-Object System.Drawing.Size(340, 20)
$lblStatus.ForeColor   = [System.Drawing.Color]::FromArgb(120, 120, 120)
$form.Controls.Add($lblStatus)

# ── Submit Button ─────────────────────────────────────────────────────────────
$btnSubmit             = New-Object System.Windows.Forms.Button
$btnSubmit.Text        = "Log Entry"
$btnSubmit.Location    = New-Object System.Drawing.Point(360, 472)
$btnSubmit.Size        = New-Object System.Drawing.Size(110, 34)
$btnSubmit.BackColor   = [System.Drawing.Color]::FromArgb(30, 30, 30)
$btnSubmit.ForeColor   = [System.Drawing.Color]::White
$btnSubmit.FlatStyle   = "Flat"
$btnSubmit.Font        = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnSubmit.Cursor      = [System.Windows.Forms.Cursors]::Hand

$btnSubmit.Add_Click({
    $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 120)
    $lblStatus.Text = ""

    $performedByRaw = $txtPerformedBy.Text.Trim()
    $description    = $txtDesc.Text.Trim()

    #