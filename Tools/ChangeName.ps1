# ============================================================
# Script:        ChangeName.ps1
# Repository:    JJenkins0115/u40Tech / Tools
# Description:   Computer NetBIOS Name Modification Utility (GUI Popup)
# Compatibility: Integrated UI Host, VS Code, Standalone Execution
# ============================================================

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

# Ensure Windows Forms and Drawing assemblies are loaded for modal dialogs
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Write-Host "============================================================"
Write-Host " Tool: Change Computer Name"
Write-Host "============================================================"

$CurrentName = $env:COMPUTERNAME
Write-Host "[>] Current Computer Name: $CurrentName"

# ------------------------------------------------------------
# MODAL INPUT DIALOG GENERATION
# ------------------------------------------------------------
# Builds a custom, top-most Form to ensure the dialog pops up 
# cleanly over VS Code or the main u40Tech UI window.

$PromptForm = New-Object System.Windows.Forms.Form
$PromptForm.Text = "U40Tech - Rename Computer"
$PromptForm.Size = New-Object System.Drawing.Size(420, 200)
$PromptForm.StartPosition = "CenterScreen"
$PromptForm.FormBorderStyle = "FixedDialog"
$PromptForm.MaximizeBox = $false
$PromptForm.MinimizeBox = $false
$PromptForm.TopMost = $true
$PromptForm.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$PromptForm.ForeColor = [System.Drawing.Color]::White

# Prompt Instruction Label
$Label = New-Object System.Windows.Forms.Label
$Label.Location = New-Object System.Drawing.Point(20, 20)
$Label.Size = New-Object System.Drawing.Size(360, 30)
$Label.Text = "Current Name: $CurrentName`r`nEnter new NetBIOS computer name:"
$Label.Font = New-Object System.Drawing.Font("Consolas", 9)
$Label.ForeColor = [System.Drawing.Color]::Cyan
$PromptForm.Controls.Add($Label)

# Input TextBox
$TextBox = New-Object System.Windows.Forms.TextBox
$TextBox.Location = New-Object System.Drawing.Point(20, 60)
$TextBox.Size = New-Object System.Drawing.Size(360, 25)
$TextBox.Font = New-Object System.Drawing.Font("Consolas", 10)
$TextBox.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
$TextBox.ForeColor = [System.Drawing.Color]::White
$TextBox.BorderStyle = "FixedSingle"
$PromptForm.Controls.Add($TextBox)

# OK Button
$OkButton = New-Object System.Windows.Forms.Button
$OkButton.Location = New-Object System.Drawing.Point(180, 110)
$OkButton.Size = New-Object System.Drawing.Size(90, 30)
$OkButton.Text = "OK"
$OkButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$OkButton.FlatStyle = "Flat"
$OkButton.FlatAppearance.BorderColor = [System.Drawing.Color]::Cyan
$OkButton.ForeColor = [System.Drawing.Color]::Cyan
$PromptForm.Controls.Add($OkButton)

# Cancel Button
$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Location = New-Object System.Drawing.Point(290, 110)
$CancelButton.Size = New-Object System.Drawing.Size(90, 30)
$CancelButton.Text = "Cancel"
$CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$CancelButton.FlatStyle = "Flat"
$CancelButton.FlatAppearance.BorderColor = [System.Drawing.Color]::Gray
$CancelButton.ForeColor = [System.Drawing.Color]::LightGray
$PromptForm.Controls.Add($CancelButton)

$PromptForm.AcceptButton = $OkButton
$PromptForm.CancelButton = $CancelButton

# Focus input field upon popup display
$PromptForm.Add_Shown({
    $PromptForm.Activate()
    $TextBox.Focus()
})

# Display popup modally
$DialogResult = $PromptForm.ShowDialog()

# ------------------------------------------------------------
# INPUT VALIDATION & EXECUTION LOGIC
# ------------------------------------------------------------

if ($DialogResult -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "[*] Operation canceled by user."
    exit 0
}

$NewName = $TextBox.Text

if ([string]::IsNullOrWhiteSpace($NewName)) {
    Write-Host "[-] Error: Computer name entry was empty. Operation aborted."
    exit 1
}

$NewName = $NewName.Trim()

if ($NewName.Length -gt 15) {
    Write-Host "[-] Error: NetBIOS computer name cannot exceed 15 characters."
    exit 1
}

if ($NewName -notmatch '^[a-zA-Z0-9-]+$') {
    Write-Host "[-] Error: Name contains invalid characters. Only letters, numbers, and hyphens are permitted."
    exit 1
}

if ($NewName.Equals($CurrentName, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Host "[!] Warning: Target name is identical to the current computer name."
    exit 0
}

Write-Host "[>] Initiating rename operation: $CurrentName -> $NewName"

try {
    Rename-Computer -NewName $NewName -Force -ErrorAction Stop
    Write-Host "[+] Computer name updated successfully to '$NewName'."
    Write-Host "[!] A system reboot is required for changes to take effect."
}
catch {
    Write-Host "[-] Rename Operation Failed: $($_.Exception.Message)"
    exit 1
}
